-- Items: tools that sit in each player's inventory (Roblox's built-in Backpack, the hotbar at the
-- bottom of the screen). Number keys equip/unequip them: slot 1 is the first tool, and so on.
-- - Bat (slot 1, everyone): a hit knocks the player over (RagdollService).
-- - Cage (slot 2, only players in GameConfig.CageAllowedUserIds): the closest player hit is
--   frozen inside a cage (CageService). Long cooldown, but only after a successful cage.
-- - Landmine (only players in GameConfig.LandmineAllowedUserIds): click to place a hidden mine
--   (LandmineService).
-- - Inventory items that are tools (ItemConfig `tool = true`, e.g. the Smoke Bomb): given while
--   equipped in the Inventory (syncItemTools), named by item id, each run by its own service
--   (SmokeBombService, GravityService, UniversalKeyService, CaptureService, ShieldService,
--   MalletService, NukeService; see ITEM_TOOLS).
-- No item works during the nuke's cutscene (everyone is frozen).
-- Either way, a thief who gets hit drops the stolen ghost, which flies home.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notify = require(script.Parent.Parent.Util.Notify)
local CageService = require(script.Parent.CageService)
local CaptureService = require(script.Parent.CaptureService)
local DataService = require(script.Parent.DataService)
local LandmineService = require(script.Parent.LandmineService)
local RagdollService = require(script.Parent.RagdollService)
local GravityService = require(script.Parent.GravityService)
local SmokeBombService = require(script.Parent.SmokeBombService)
local StealService = require(script.Parent.StealService)
local UniversalKeyService = require(script.Parent.UniversalKeyService)
local ShieldService = require(script.Parent.ShieldService)
local MalletService = require(script.Parent.MalletService)
local NukeService = require(script.Parent.NukeService)

local ItemService = {}

local lastSwing: { [Player]: number } = {}
-- When each player's cage can next be used, in server time (workspace:GetServerTimeNow(), the
-- same clock on the server and every device). Only set by a successful cage.
local cageReadyAt: { [Player]: number } = {}
local cageTemplate: Tool
local landmineTemplate: Tool

local function getAliveRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root :: BasePart
	end
	return nil
end

-- The bonk, played from the hit player so everyone nearby hears it. A sound played on the
-- server is heard by every player.
-- The hit sound on the person who got hit (the bat's "bonk" unless another is given). A sound
-- config with `startAt` / `length` only plays that part of the clip.
local function playBonk(target: Player, config: any?)
	local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	config = config or GameConfig.BatHitSound
	local sound = Instance.new("Sound")
	sound.Name = "Bonk"
	sound.SoundId = "rbxassetid://" .. config.soundId
	sound.Volume = config.volume
	sound.PlaybackSpeed = config.pitch
	sound.TimePosition = config.startAt or 0
	sound.Parent = root
	sound:Play()
	Debris:AddItem(sound, config.length or 4)
end

-- Players within `range` and inside the swing's cone (`arcDegrees` wide, centred on where the
-- swinger faces), using server positions, closest first.
-- Each comes with the flat direction from the swinger to them.
type Target = { player: Player, direction: Vector3, distance: number }
local function findTargets(swinger: Player, root: BasePart, range: number, arcDegrees: number): { Target }
	local targets = {}
	-- A target is in the arc when the angle between where the swinger faces and the direction to
	-- them is at most half the arc.
	local minFacing = math.cos(math.rad(arcDegrees / 2))
	for _, target in Players:GetPlayers() do
		local targetRoot = getAliveRoot(target)
		-- Can't hit players who are already knocked over or caged.
		if target == swinger or not targetRoot or not RagdollService.canKnock(target) then
			continue
		end
		local offset = targetRoot.Position - root.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local inArc = flat.Magnitude < 2 or root.CFrame.LookVector:Dot(flat.Unit) >= minFacing
		if offset.Magnitude <= range and inArc then
			-- Straight ahead of the swinger if standing on top of each other.
			local direction = if flat.Magnitude > 0.1 then flat.Unit else root.CFrame.LookVector
			table.insert(targets, { player = target, direction = direction, distance = offset.Magnitude })
		end
	end
	table.sort(targets, function(a, b)
		return a.distance < b.distance
	end)
	return targets
end

-- What each item does when its swing lands.
local function batHits(swinger: Player, targets: { Target }, _tool: Tool)
	for _, target in targets do
		playBonk(target.player)
		StealService.knockLoose(swinger, target.player, "bonked")
		local push = target.direction * GameConfig.BatKnockbackSpeed + Vector3.new(0, GameConfig.BatKnockbackLift, 0)
		RagdollService.knock(target.player, push)
	end
end

-- The Tennis Racket: the bat's hit, as high but GameConfig.RacketPushMultiplier times further back.
local function racketHits(swinger: Player, targets: { Target }, _tool: Tool)
	local power = GameConfig.RacketPushMultiplier
	for _, target in targets do
		playBonk(target.player, GameConfig.RacketHitSound)
		StealService.knockLoose(swinger, target.player, "smashed")
		local push = target.direction * GameConfig.BatKnockbackSpeed * power
			+ Vector3.new(0, GameConfig.BatKnockbackLift, 0)
		local immunity = GameConfig.BatHitImmunitySeconds * GameConfig.RacketImmunityMultiplier
		RagdollService.knock(target.player, push, nil, false, immunity)
	end
end

local function cageHits(swinger: Player, targets: { Target }, tool: Tool)
	local target = targets[1] -- only the closest one
	if not target then
		return -- a miss costs nothing
	end
	StealService.knockLoose(swinger, target.player, "caged")
	if CageService.trap(target.player, swinger) then
		Notify.send(target.player, swinger.DisplayName .. " caged you!", "error")
		Notify.send(swinger, "You caged " .. target.player.DisplayName .. "!", "success")
		-- The cooldown starts now. The tool carries it too, so the swinger's device skips the
		-- swing animation until it's ready (BatSwing).
		local readyAt = workspace:GetServerTimeNow() + GameConfig.CageCooldownSeconds
		cageReadyAt[swinger] = readyAt
		tool:SetAttribute("ReadyAt", readyAt)
	end
end

local ITEMS = {
	Bat = { range = GameConfig.BatRange, arc = GameConfig.BatHitArcDegrees, onHit = batHits },
	Cage = { range = GameConfig.CageRange, arc = GameConfig.CageHitArcDegrees, onHit = cageHits },
	-- The Tennis Racket is an Inventory item (named by its item id), swung exactly like the bat.
	tennis_racket = { range = GameConfig.BatRange, arc = GameConfig.BatHitArcDegrees, onHit = racketHits },
}

-- The moment the swing reaches the front.
local function checkHits(swinger: Player, tool: Tool)
	local root = getAliveRoot(swinger)
	-- They may have put the item away, been knocked over, caged, or grabbed a ghost meanwhile.
	if
		not root
		or tool.Parent ~= swinger.Character
		or RagdollService.isRagdolled(swinger)
		or CageService.isCaged(swinger)
		or StealService.getCarry(swinger)
	then
		return
	end
	local item = ITEMS[tool.Name]
	item.onHit(swinger, findTargets(swinger, root, item.range, item.arc), tool)
end

-- Called on the server when a player clicks while holding an item.
local function swing(tool: Tool)
	local character = tool.Parent
	local swinger = Players:GetPlayerFromCharacter(character)
	-- Thieves carrying a ghost, caged and invisible (Smoke Bomb) players can't use items.
	if
		not swinger
		or NukeService.isFrozen()
		or swinger:GetAttribute("Invisible")
		or RagdollService.isRagdolled(swinger)
		or CageService.isCaged(swinger)
		or StealService.getCarry(swinger)
	then
		return
	end
	if tool.Name == "Landmine" then
		LandmineService.tryPlace(swinger) -- no swing; it handles its own cooldown and messages
		return
	end
	local now = os.clock()
	if now - (lastSwing[swinger] or 0) < GameConfig.BatSwingCooldown then
		return
	end
	if tool.Name == "Cage" then
		local waitLeft = (cageReadyAt[swinger] or 0) - workspace:GetServerTimeNow()
		if waitLeft > 0 then
			Notify.send(swinger, "Cage ready in " .. math.ceil(waitLeft) .. "s", "error")
			return
		end
	end
	lastSwing[swinger] = now

	-- Everyone else plays the swing animation (BatSwing on the client); the swinger's own device
	-- already started it the moment they clicked.
	for _, other in Players:GetPlayers() do
		if other ~= swinger then
			Remotes.BatSwing:FireClient(other, character)
		end
	end
	task.delay(GameConfig.BatHitDelay, checkHits, swinger, tool)
end

-- Welds `part` to `handle` and adds it to the tool.
local function addWelded(tool: Tool, handle: BasePart, part: BasePart)
	part.CanCollide = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
	part.Parent = tool
end

-- Builds the bat: a thin grip (the Handle, which the hand holds) and a thicker barrel.
local function buildBat(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Bat"
	tool.ToolTip = "Click to swing. Bonk thieves to get your ghost back"
	tool.TextureId = GameConfig.BatIcon -- the picture in the hotbar
	tool.CanBeDropped = false -- otherwise Backspace drops it on the ground
	-- Where the hand holds the grip; the tilt points the bat up instead of straight ahead.
	tool.Grip = CFrame.new(0, 0, 0.6) * CFrame.Angles(math.rad(-60), 0, 0)
	tool:SetAttribute("Swingable", true) -- BatSwing on the client plays the swing for it

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 1.6)
	handle.Color = Color3.fromRGB(60, 40, 30) -- dark tape on the grip
	handle.Material = Enum.Material.Fabric
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local barrel = Instance.new("Part")
	barrel.Name = "Barrel"
	barrel.Size = Vector3.new(0.5, 0.5, 2.6)
	barrel.Color = Color3.fromRGB(150, 100, 60)
	barrel.Material = Enum.Material.Wood
	-- The barrel sticks out past the grip, away from the hand.
	barrel.CFrame = handle.CFrame * CFrame.new(0, 0, -(handle.Size.Z + barrel.Size.Z) / 2)
	addWelded(tool, handle, barrel)

	return tool
end

-- Builds the Tennis Racket: a dark grip (the Handle) and an orange shaft leading to a round
-- orange frame with white strings, held up like the bat.
local function buildRacket(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "tennis_racket" -- its item id (ItemConfig); the hotbar finds it by this
	tool.ToolTip = "Click to swing. Knocks people three times further than the bat"
	tool.TextureId = GameConfig.RacketIcon
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, 0, 0.6) * CFrame.Angles(math.rad(-60), 0, 0)
	tool:SetAttribute("Swingable", true) -- BatSwing on the client plays the bat's swing for it

	local orange = Color3.fromRGB(255, 140, 30)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 1.4)
	handle.Color = Color3.fromRGB(55, 35, 70)
	handle.Material = Enum.Material.Fabric
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local shaft = Instance.new("Part")
	shaft.Size = Vector3.new(0.22, 0.22, 1.1)
	shaft.Color = orange
	shaft.Material = Enum.Material.SmoothPlastic
	shaft.CFrame = handle.CFrame * CFrame.new(0, 0, -1.25)
	addWelded(tool, handle, shaft)

	-- The head: a round frame across the far end, its face along the racket.
	local headCFrame = handle.CFrame * CFrame.new(0, 0, -2.75)
	local frame = Instance.new("Part")
	frame.Shape = Enum.PartType.Cylinder
	frame.Size = Vector3.new(0.18, 2.3, 2.3)
	frame.Color = orange
	frame.Material = Enum.Material.SmoothPlastic
	frame.CFrame = headCFrame
	addWelded(tool, handle, frame)

	local strings = Instance.new("Part")
	strings.Shape = Enum.PartType.Cylinder
	strings.Size = Vector3.new(0.2, 1.95, 1.95)
	strings.Color = Color3.fromRGB(245, 245, 250)
	strings.Material = Enum.Material.Fabric
	strings.CFrame = headCFrame
	addWelded(tool, handle, strings)

	return tool
end

-- Builds the handheld cage: an orange ring (the Handle) with a small iron cage hanging below it.
local function buildCage(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Cage"
	tool.ToolTip = "Click to swing. Traps the closest player in a cage"
	tool.TextureId = GameConfig.CageIcon
	tool.CanBeDropped = false
	tool:SetAttribute("Swingable", true)

	local iron = Color3.fromRGB(45, 46, 52)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 0.2, 0.6)
	handle.Color = Color3.fromRGB(255, 140, 30)
	handle.Material = Enum.Material.Neon
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	-- Cage body below the hand: roof, floor and corner/middle bars.
	local size = Vector3.new(1.4, 1.6, 1.4)
	local top = handle.CFrame * CFrame.new(0, -0.3, 0)
	local function piece(partSize: Vector3, offset: Vector3)
		local part = Instance.new("Part")
		part.Size = partSize
		part.Color = iron
		part.Material = Enum.Material.Metal
		part.CFrame = top * CFrame.new(offset)
		addWelded(tool, handle, part)
	end
	piece(Vector3.new(size.X, 0.15, size.Z), Vector3.new(0, 0, 0))
	piece(Vector3.new(size.X, 0.15, size.Z), Vector3.new(0, -size.Y, 0))
	for _, x in { -1, 0, 1 } do
		for _, z in { -1, 0, 1 } do
			if x ~= 0 or z ~= 0 then -- bars around the edge, none in the middle
				piece(Vector3.new(0.1, size.Y, 0.1), Vector3.new(x * size.X / 2, -size.Y / 2, z * size.Z / 2))
			end
		end
	end

	return tool
end

-- Builds the handheld smoke bomb: a dark purple ball (the Handle) with a glowing purple band and
-- a fuse.
local function buildSmokeBomb(): Tool
	local tool = Instance.new("Tool")
	tool.Name = SmokeBombService.ITEM_ID -- the hotbar finds an item's tool by its item id
	tool.ToolTip = "Click to vanish in a puff of smoke"
	tool.TextureId = GameConfig.SmokeBombIcon
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, 0, 0.2)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Ball
	handle.Size = Vector3.new(1, 1, 1)
	handle.Color = Color3.fromRGB(52, 40, 72)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local band = Instance.new("Part")
	band.Shape = Enum.PartType.Cylinder
	band.Size = Vector3.new(0.2, 1.04, 1.04)
	band.Color = Color3.fromRGB(175, 95, 255)
	band.Material = Enum.Material.Neon
	band.CFrame = handle.CFrame * CFrame.Angles(0, 0, math.rad(90))
	addWelded(tool, handle, band)

	local fuse = Instance.new("Part")
	fuse.Size = Vector3.new(0.12, 0.35, 0.12)
	fuse.Color = Color3.fromRGB(150, 110, 70)
	fuse.Material = Enum.Material.Fabric
	fuse.CFrame = handle.CFrame * CFrame.new(0, 0.6, 0)
	addWelded(tool, handle, fuse)

	return tool
end

-- Builds the handheld gravity orb: a dark core (the Handle) inside a glowing purple shell.
local function buildGravity(): Tool
	local tool = Instance.new("Tool")
	tool.Name = GravityService.ITEM_ID
	tool.ToolTip = "Click to pull everyone nearby toward you"
	tool.TextureId = GameConfig.GravityIcon
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, 0, 0.2)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Ball
	handle.Size = Vector3.new(0.7, 0.7, 0.7)
	handle.Color = Color3.fromRGB(25, 12, 45)
	handle.Material = Enum.Material.Neon
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local shell = Instance.new("Part")
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.new(1.1, 1.1, 1.1)
	shell.Color = Color3.fromRGB(110, 60, 200)
	shell.Material = Enum.Material.ForceField
	shell.CFrame = handle.CFrame
	addWelded(tool, handle, shell)

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(205, 150, 255)
	light.Range = 6
	light.Brightness = 1.5
	light.Parent = handle

	return tool
end

-- Builds the handheld Universal Key: a gold shaft (the Handle) with a round bow and two teeth.
local function buildUniversalKey(): Tool
	local tool = Instance.new("Tool")
	tool.Name = UniversalKeyService.ITEM_ID
	tool.ToolTip = "Click at a locked base's gate to unlock it"
	tool.TextureId = GameConfig.UniversalKeyIcon
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, 0, 0.3)

	local gold = Color3.fromRGB(255, 190, 40)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 1.4)
	handle.Color = gold
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local bow = Instance.new("Part")
	bow.Shape = Enum.PartType.Cylinder
	bow.Size = Vector3.new(0.15, 0.7, 0.7)
	bow.Color = gold
	bow.Material = Enum.Material.Metal
	bow.CFrame = handle.CFrame * CFrame.new(0, 0, 0.95) * CFrame.Angles(0, 0, math.rad(90))
	addWelded(tool, handle, bow)

	for index, length in { 0.35, 0.25 } do
		local tooth = Instance.new("Part")
		tooth.Size = Vector3.new(0.15, length, 0.15)
		tooth.Color = gold
		tooth.Material = Enum.Material.Metal
		tooth.CFrame = handle.CFrame * CFrame.new(0, -length / 2 - 0.08, -0.6 + (index - 1) * 0.25)
		addWelded(tool, handle, tooth)
	end

	local light = Instance.new("PointLight")
	light.Color = gold
	light.Range = 4
	light.Brightness = 1
	light.Parent = bow

	return tool
end

-- Builds the handheld Shield: a small round buckler (the Handle) in spectral blue with a silver
-- rim and a glowing white boss in the middle.
local function buildShield(): Tool
	local tool = Instance.new("Tool")
	tool.Name = ShieldService.ITEM_ID
	tool.ToolTip = "Click to become immune to knockbacks, cages and Gravity"
	tool.TextureId = GameConfig.ShieldIcon
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, 0, 0.2) * CFrame.Angles(0, math.rad(90), 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Cylinder
	handle.Size = Vector3.new(0.25, 1.6, 1.6)
	handle.Color = Color3.fromRGB(80, 200, 255)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local rim = Instance.new("Part")
	rim.Shape = Enum.PartType.Cylinder
	rim.Size = Vector3.new(0.2, 1.8, 1.8)
	rim.Color = Color3.fromRGB(210, 240, 255)
	rim.Material = Enum.Material.Metal
	rim.CFrame = handle.CFrame
	addWelded(tool, handle, rim)

	local boss = Instance.new("Part")
	boss.Shape = Enum.PartType.Ball
	boss.Size = Vector3.new(0.5, 0.5, 0.5)
	boss.Color = Color3.fromRGB(230, 250, 255)
	boss.Material = Enum.Material.Neon
	boss.CFrame = handle.CFrame * CFrame.new(0.15, 0, 0)
	addWelded(tool, handle, boss)

	return tool
end

-- Builds the Mega Mallet: a long wooden handle (the Handle, held near its end) with a huge iron
-- head across the far end. The head's two striking faces glow red, with a dark band round the
-- middle. "Strike" (an attachment on the lower face) is where the slam hits the ground.
local function buildMegaMallet(): Tool
	local tool = Instance.new("Tool")
	tool.Name = MalletService.ITEM_ID
	tool.ToolTip = "Click to slam the ground and launch everyone in front of you"
	tool.TextureId = GameConfig.MegaMalletIcon
	tool.CanBeDropped = false
	-- Held near the end of the handle, tipped up like the bat.
	tool.Grip = CFrame.new(0, 0, 2) * CFrame.Angles(math.rad(-60), 0, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 0.35, 4.8)
	handle.Color = Color3.fromRGB(120, 75, 45)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	-- Grip wraps near the hand.
	for index = 0, 2 do
		local wrap = Instance.new("Part")
		wrap.Size = Vector3.new(0.42, 0.42, 0.18)
		wrap.Color = Color3.fromRGB(30, 22, 28)
		wrap.Material = Enum.Material.Fabric
		wrap.CFrame = handle.CFrame * CFrame.new(0, 0, 2.1 - index * 0.35)
		addWelded(tool, handle, wrap)
	end

	-- The head: across the far end of the handle, its long side up and down.
	local headCFrame = handle.CFrame * CFrame.new(0, 0, -2.6)
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.9, 3.2, 1.9)
	head.Color = Color3.fromRGB(85, 80, 100)
	head.Material = Enum.Material.Metal
	head.CFrame = headCFrame
	addWelded(tool, handle, head)

	local band = Instance.new("Part")
	band.Size = Vector3.new(2.05, 0.5, 2.05)
	band.Color = Color3.fromRGB(35, 30, 45)
	band.Material = Enum.Material.Metal
	band.CFrame = headCFrame
	addWelded(tool, handle, band)

	for _, side in { 1, -1 } do
		local face = Instance.new("Part")
		face.Size = Vector3.new(1.6, 0.2, 1.6)
		face.Color = Color3.fromRGB(255, 70, 50)
		face.Material = Enum.Material.Neon
		face.CFrame = headCFrame * CFrame.new(0, side * 1.62, 0)
		addWelded(tool, handle, face)
		if side == -1 then
			local strike = Instance.new("Attachment")
			strike.Name = "Strike"
			strike.Position = Vector3.new(0, -0.15, 0)
			strike.Parent = face
		end
	end

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 80, 60)
	light.Range = 6
	light.Brightness = 1.2
	light.Parent = head

	return tool
end

-- Builds the Nuke's remote control: a dark box (the Handle, held at its bottom end) with an
-- antenna, a yellow-and-black hazard ring round a big red "Button" and a blinking light.
local function buildNukeRemote(): Tool
	local tool = Instance.new("Tool")
	tool.Name = NukeService.ITEM_ID
	tool.ToolTip = "Press the button to launch a nuke on the whole map"
	tool.TextureId = GameConfig.NukeIcon
	tool.CanBeDropped = false
	-- Held by its bottom end, tipped up towards the face like the bat.
	tool.Grip = CFrame.new(0, 0, 0.55) * CFrame.Angles(math.rad(-60), 0, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.85, 0.4, 1.5)
	handle.Color = Color3.fromRGB(62, 66, 78)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	-- The top face (+Y) carries the controls; the far end (-Z) has the antenna.
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.08, 0.7, 0.7)
	ring.Color = Color3.fromRGB(255, 205, 40)
	ring.Material = Enum.Material.SmoothPlastic
	ring.CFrame = handle.CFrame * CFrame.new(0, 0.22, -0.25) * CFrame.Angles(0, 0, math.rad(90))
	addWelded(tool, handle, ring)

	local button = Instance.new("Part")
	button.Name = "Button"
	button.Shape = Enum.PartType.Cylinder
	button.Size = Vector3.new(0.22, 0.48, 0.48)
	button.Color = Color3.fromRGB(240, 40, 35)
	button.Material = Enum.Material.SmoothPlastic
	button.CFrame = handle.CFrame * CFrame.new(0, 0.3, -0.25) * CFrame.Angles(0, 0, math.rad(90))
	addWelded(tool, handle, button)

	local led = Instance.new("Part")
	led.Shape = Enum.PartType.Ball
	led.Size = Vector3.new(0.14, 0.14, 0.14)
	led.Color = Color3.fromRGB(120, 255, 120)
	led.Material = Enum.Material.Neon
	led.CFrame = handle.CFrame * CFrame.new(0.25, 0.21, 0.4)
	addWelded(tool, handle, led)

	local antenna = Instance.new("Part")
	antenna.Shape = Enum.PartType.Cylinder
	antenna.Size = Vector3.new(1.2, 0.08, 0.08)
	antenna.Color = Color3.fromRGB(150, 150, 160)
	antenna.Material = Enum.Material.Metal
	antenna.CFrame = handle.CFrame * CFrame.new(0.3, 0, -1.3) * CFrame.Angles(0, math.rad(90), 0)
	addWelded(tool, handle, antenna)

	local tip = Instance.new("Part")
	tip.Shape = Enum.PartType.Ball
	tip.Size = Vector3.new(0.2, 0.2, 0.2)
	tip.Color = Color3.fromRGB(255, 60, 45)
	tip.Material = Enum.Material.Neon
	tip.CFrame = handle.CFrame * CFrame.new(0.3, 0, -1.9)
	addWelded(tool, handle, tip)

	return tool
end

-- The PolterPuller 4000's colours: purple tank and nozzle, glowing green suction parts.
local VACUUM_PURPLE = Color3.fromRGB(110, 60, 200)
local VACUUM_GREEN = Color3.fromRGB(120, 255, 130)
local VACUUM_METAL = Color3.fromRGB(200, 200, 215)

-- Builds the PolterPuller's nozzle, the part held in the hands: a metal grip (the Handle) with a
-- wide purple suction head and a glowing green mouth. "Mouth" is where the suction beam starts;
-- "HoseEnd" is where the hose from the back tank plugs in.
local function buildPolterPuller(): Tool
	local tool = Instance.new("Tool")
	tool.Name = CaptureService.ITEM_ID
	tool.ToolTip = "Hold it near someone's ghost and press Capture"
	tool.TextureId = GameConfig.PolterPullerIcon
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, -0.1, 0.4)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.45, 0.45, 2)
	handle.Color = VACUUM_METAL
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	-- The suction head: a short wide cylinder at the front, pointing forward (a cylinder's round
	-- faces point along its X axis, so turn it to face along -Z).
	local head = Instance.new("Part")
	head.Shape = Enum.PartType.Cylinder
	head.Size = Vector3.new(0.8, 1.3, 1.3)
	head.Color = VACUUM_PURPLE
	head.Material = Enum.Material.SmoothPlastic
	head.CFrame = handle.CFrame * CFrame.new(0, 0, -1.2) * CFrame.Angles(0, math.rad(90), 0)
	addWelded(tool, handle, head)
	local mouthGlow = Instance.new("Part")
	mouthGlow.Shape = Enum.PartType.Cylinder
	mouthGlow.Size = Vector3.new(0.1, 1.05, 1.05)
	mouthGlow.Color = VACUUM_GREEN
	mouthGlow.Material = Enum.Material.Neon
	mouthGlow.CFrame = handle.CFrame * CFrame.new(0, 0, -1.61) * CFrame.Angles(0, math.rad(90), 0)
	addWelded(tool, handle, mouthGlow)
	local light = Instance.new("PointLight")
	light.Color = VACUUM_GREEN
	light.Range = 6
	light.Brightness = 1.5
	light.Parent = mouthGlow

	local mouth = Instance.new("Attachment")
	mouth.Name = "Mouth"
	mouth.Position = Vector3.new(0, 0, -1.7)
	mouth.Parent = handle
	local hoseEnd = Instance.new("Attachment")
	hoseEnd.Name = "HoseEnd"
	hoseEnd.Position = Vector3.new(0, 0, 1)
	hoseEnd.Parent = handle

	return tool
end

-- The PolterPuller's tank, worn on the back while the nozzle is held: a purple capsule with
-- metal bands and a glowing green window, and a hose from its base to the nozzle.
local function wearVacuumPack(character: Model, tool: Tool)
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	local hoseEnd = tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("HoseEnd")
	if not torso or not hoseEnd or character:FindFirstChild("PolterPack") then
		return
	end
	local pack = Instance.new("Model")
	pack.Name = "PolterPack"
	-- Behind the torso (its back is +Z), standing upright.
	local back = torso.CFrame * CFrame.new(0, 0.1, 1)
	local function piece(props: { [string]: any }, offset: CFrame): Part
		local part = Instance.new("Part")
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
		for key, value in props do
			(part :: any)[key] = value
		end
		part.CFrame = back * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = part
		weld.Parent = part
		part.Parent = pack
		return part
	end
	local upright = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder lies along X; stand it up
	local tank = piece({
		Name = "Tank",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.3, 1.4, 1.4),
		Color = VACUUM_PURPLE,
		Material = Enum.Material.SmoothPlastic,
	}, upright)
	for _, y in { -0.75, 0.75 } do
		piece({
			Name = "Band",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.18, 1.48, 1.48),
			Color = VACUUM_METAL,
			Material = Enum.Material.Metal,
		}, CFrame.new(0, y, 0) * upright)
	end
	piece({
		Name = "Window",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.9, 1.44, 1.44),
		Color = VACUUM_GREEN,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
	}, upright)
	piece({
		Name = "Cap",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.3, 1.3, 1.3),
		Color = VACUUM_PURPLE,
		Material = Enum.Material.SmoothPlastic,
	}, CFrame.new(0, 1.15, 0))

	-- The hose: a dark beam from the bottom of the tank to the nozzle, sagging a little.
	local hoseStart = Instance.new("Attachment")
	hoseStart.Name = "HoseStart"
	hoseStart.Position = Vector3.new(-1.2, 0, 0) -- the tank's bottom end (it's turned on its side)
	hoseStart.Parent = tank
	local hose = Instance.new("Beam")
	hose.Attachment0 = hoseStart
	hose.Attachment1 = hoseEnd
	hose.Color = ColorSequence.new(Color3.fromRGB(70, 60, 85))
	hose.Width0 = 0.4
	hose.Width1 = 0.4
	hose.FaceCamera = true
	hose.Segments = 14
	hose.CurveSize0 = 1.5
	hose.CurveSize1 = -1.5
	hose.Parent = tank

	pack.Parent = character
end

-- Builds the handheld landmine: a squat olive disc (the Handle) with a red light on top.
local function buildLandmine(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Landmine"
	tool.ToolTip = "Click to place a hidden landmine at your feet"
	tool.TextureId = GameConfig.LandmineIcon
	tool.CanBeDropped = false
	-- Hold it flat with the red light facing up, resting just in front of and on top of the hand.
	tool.Grip = CFrame.new(-0.15, 0, 0.45) * CFrame.Angles(0, 0, math.rad(-90))

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Cylinder -- a cylinder's round faces point along its X axis
	handle.Size = Vector3.new(0.35, 1.3, 1.3)
	handle.Color = Color3.fromRGB(88, 94, 74)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local light = Instance.new("Part")
	light.Shape = Enum.PartType.Ball
	light.Size = Vector3.new(0.3, 0.3, 0.3)
	light.Color = Color3.fromRGB(255, 50, 35)
	light.Material = Enum.Material.Neon
	light.CFrame = handle.CFrame * CFrame.new(handle.Size.X / 2, 0, 0)
	addWelded(tool, handle, light)

	return tool
end

-- The items only some players get, in hotbar order after the bat.
local EXTRA_ITEMS = {
	{ name = "Cage", allowed = GameConfig.CageAllowedUserIds },
	{ name = "Landmine", allowed = GameConfig.LandmineAllowedUserIds },
}

-- Inventory items that are tools (ItemConfig `tool = true`), by item id: the tool to hand out
-- and the service that runs it (tryUse when clicked, readyAt for a cooldown that survives
-- respawning). Filled in ItemService.start.
type ItemTool = {
	template: Tool,
	handler: { tryUse: (Player, Tool) -> (), readyAt: (Player) -> number? },
}
local ITEM_TOOLS: { [string]: ItemTool } = {}

-- Makes the player's Backpack hold exactly the tools of their equipped Inventory items: adds the
-- missing ones, removes ones they've unequipped. Runs on every spawn and whenever they equip.
local function syncItemTools(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	if not backpack then
		return
	end
	local equipped = DataService.getEquipped(player)
	for itemId, itemTool in ITEM_TOOLS do
		local existing = backpack:FindFirstChild(itemId) or (character and character:FindFirstChild(itemId))
		local wanted = table.find(equipped, itemId) ~= nil
		if wanted and not existing then
			local tool = itemTool.template:Clone()
			tool:SetAttribute("ReadyAt", itemTool.handler.readyAt(player)) -- a cooldown still running
			tool.Parent = backpack
		elseif not wanted and existing then
			existing:Destroy()
		end
	end
end

-- Gives allowed players their extra items each time their character spawns. Waits until the bat
-- is in their current Backpack (loading can take a while), so these land in the slots after it.
local function giveExtraItems(player: Player, character: Model)
	local templates = { Cage = cageTemplate, Landmine = landmineTemplate }
	while player.Parent and player.Character == character do
		local backpack = player:FindFirstChildOfClass("Backpack")
		local hasBat = backpack and (backpack:FindFirstChild("Bat") or character:FindFirstChild("Bat"))
		if backpack and hasBat then
			for _, extra in EXTRA_ITEMS do
				local owned = backpack:FindFirstChild(extra.name) or character:FindFirstChild(extra.name)
				if table.find(extra.allowed, player.UserId) and not owned then
					local item = templates[extra.name]:Clone()
					if extra.name == "Cage" then
						item:SetAttribute("ReadyAt", cageReadyAt[player]) -- a cooldown still running
					end
					item.Parent = backpack
				end
			end
			return
		end
		task.wait(0.2)
	end
end

function ItemService.start()
	-- StarterPack is copied into every player's Backpack each time their character spawns,
	-- so the bat comes back after a respawn.
	local bat = buildBat()
	bat.Parent = StarterPack
	cageTemplate = buildCage()
	landmineTemplate = buildLandmine()
	ITEM_TOOLS[SmokeBombService.ITEM_ID] = { template = buildSmokeBomb(), handler = SmokeBombService }
	ITEM_TOOLS[GravityService.ITEM_ID] = { template = buildGravity(), handler = GravityService }
	ITEM_TOOLS[UniversalKeyService.ITEM_ID] = { template = buildUniversalKey(), handler = UniversalKeyService }
	ITEM_TOOLS[CaptureService.ITEM_ID] = { template = buildPolterPuller(), handler = CaptureService }
	ITEM_TOOLS[ShieldService.ITEM_ID] = { template = buildShield(), handler = ShieldService }
	ITEM_TOOLS[MalletService.ITEM_ID] = { template = buildMegaMallet(), handler = MalletService }
	ITEM_TOOLS[NukeService.ITEM_ID] = { template = buildNukeRemote(), handler = NukeService }
	-- The racket swings like the bat (no cooldown of its own).
	ITEM_TOOLS.tennis_racket = {
		template = buildRacket(),
		handler = {
			tryUse = function(_player: Player, tool: Tool)
				swing(tool)
			end,
			readyAt = function(_player: Player): number?
				return nil
			end,
		},
	}

	-- Tool.Activated fires on the server too, so each copy of an item is wired up here.
	local function onToolAdded(item: Instance)
		if not item:IsA("Tool") or item:GetAttribute("Wired") then
			return
		end
		local itemTool = ITEM_TOOLS[item.Name]
		if itemTool then
			item:SetAttribute("Wired", true)
			item.Activated:Connect(function()
				local player = Players:GetPlayerFromCharacter(item.Parent)
				if player and not NukeService.isFrozen() then
					itemTool.handler.tryUse(player, item)
				end
			end)
			-- The PolterPuller's tank goes on your back while you hold the nozzle.
			if item.Name == CaptureService.ITEM_ID then
				item.Equipped:Connect(function()
					local character = item.Parent
					if character and character:IsA("Model") then
						wearVacuumPack(character, item :: Tool)
					end
				end)
				local function takeOff()
					for _, player in Players:GetPlayers() do
						local pack = player.Character and player.Character:FindFirstChild("PolterPack")
						if pack and not player.Character:FindFirstChild(CaptureService.ITEM_ID) then
							pack:Destroy()
						end
					end
				end
				item.Unequipped:Connect(takeOff)
				item.Destroying:Connect(takeOff)
			end
		elseif ITEMS[item.Name] or item.Name == "Landmine" then
			item:SetAttribute("Wired", true)
			item.Activated:Connect(function()
				swing(item)
			end)
		end
	end
	-- Each spawn gives the player a brand-new Backpack, so watch for those too.
	local function watchPlayer(player: Player)
		local function onBackpack(backpack: Instance)
			if backpack:IsA("Backpack") then
				backpack.ChildAdded:Connect(onToolAdded)
				for _, item in backpack:GetChildren() do
					onToolAdded(item)
				end
			end
		end
		player.ChildAdded:Connect(onBackpack)
		for _, child in player:GetChildren() do
			onBackpack(child)
		end
		player.CharacterAdded:Connect(function(character)
			giveExtraItems(player, character)
			syncItemTools(player)
		end)
		if player.Character then
			task.spawn(function()
				giveExtraItems(player, player.Character)
				syncItemTools(player)
			end)
		end
		-- Equipping or unequipping an item in the Inventory adds or removes its tool.
		player:GetAttributeChangedSignal("Equipped"):Connect(function()
			syncItemTools(player)
		end)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
		cageReadyAt[player] = nil
	end)
end

return ItemService
