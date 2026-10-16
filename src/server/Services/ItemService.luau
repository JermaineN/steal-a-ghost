-- Items: tools that sit in each player's inventory (Roblox's built-in Backpack, the hotbar at the
-- bottom of the screen). Number keys equip/unequip them: slot 1 is the first tool, and so on.
-- - Bat (slot 1, everyone): a hit knocks the player over (RagdollService).
-- - Cage (slot 2, only players in GameConfig.CageAllowedUserIds): the closest player hit is
--   frozen inside a cage (CageService). Long cooldown, but only after a successful cage.
-- - Landmine (only players in GameConfig.LandmineAllowedUserIds): click to place a hidden mine
--   (LandmineService).
-- Either way, a thief who gets hit drops the stolen ghost, which flies home.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notify = require(script.Parent.Parent.Util.Notify)
local CageService = require(script.Parent.CageService)
local LandmineService = require(script.Parent.LandmineService)
local RagdollService = require(script.Parent.RagdollService)
local StealService = require(script.Parent.StealService)

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
local function playBonk(target: Player)
	local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local config = GameConfig.BatHitSound
	local sound = Instance.new("Sound")
	sound.Name = "Bonk"
	sound.SoundId = "rbxassetid://" .. config.soundId
	sound.Volume = config.volume
	sound.PlaybackSpeed = config.pitch
	sound.Parent = root
	sound:Play()
	Debris:AddItem(sound, 4)
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
	-- Thieves carrying a ghost and caged players can't use items (they can't hold one either).
	if
		not swinger
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

	-- Tool.Activated fires on the server too, so each copy of an item is wired up here.
	local function onToolAdded(item: Instance)
		local usable = ITEMS[item.Name] or item.Name == "Landmine"
		if item:IsA("Tool") and usable and not item:GetAttribute("Wired") then
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
		end)
		if player.Character then
			task.spawn(giveExtraItems, player, player.Character)
		end
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
