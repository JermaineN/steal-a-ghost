-- The Nuke (the Spin Wheel's Mythic prize, used from the hotbar): a remote control with a big red
-- button. Clicking it:
--   1. Warning (GameConfig.NukeCountdownSeconds): every device shows "X has launched a nuke!",
--      a countdown and sirens. Players can still run around.
--   2. Cutscene (GameConfig.NukeFallSeconds): everyone is frozen in place (root anchored by the
--      server, like the cage) while every device shows the nuke falling onto the middle of the
--      map from a low camera (client NukeClient).
--   3. Blast: everyone is let go and launched up and away from the middle (the launcher too), and
--      stays floppy for NukeRagdollSeconds after landing; thieves drop the ghost they carry.
-- The server sends one NukeLaunched remote with the times and every device plays its part from
-- that. Only one nuke can be on its way at a time. Cooldown starts on use, and a launch also puts
-- everyone else's nuke on at least NukeSharedCooldownSeconds.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notify = require(script.Parent.Parent.Util.Notify)
local DataService = require(script.Parent.DataService)
local RagdollService = require(script.Parent.RagdollService)
local StealService = require(script.Parent.StealService)

local NukeService = {}

NukeService.ITEM_ID = "nuke"

-- When each player's nuke can next be used, in server time.
local readyAt: { [Player]: number } = {}
-- True from the button press until the blast.
local nukeOnTheWay = false
-- True during the cutscene, while everyone is frozen.
local frozen = false

local function getAliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- The ground in the middle of the map (the walkway runs through 0, 0, 0).
local function groundTarget(): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), params)
	return if hit then hit.Position else Vector3.zero
end

-- Is the nuke cutscene playing? (Items can't be used meanwhile.)
function NukeService.isFrozen(): boolean
	return frozen
end

-- Pins every player in place for the cutscene. Returns the root parts it anchored, so only those
-- are let go afterwards (a cage or a mallet wind-up pins players itself).
local function freezeEveryone(): { BasePart }
	local pinned = {}
	for _, player in Players:GetPlayers() do
		local root = getAliveRoot(player)
		if root and not root.Anchored then
			root.AssemblyLinearVelocity = Vector3.zero
			root.Anchored = true
			table.insert(pinned, root)
		end
	end
	return pinned
end

-- The blast: let everyone go and launch them up and away from the middle.
local function explode(launcher: Player, target: Vector3, pinned: { BasePart })
	for _, root in pinned do
		if root.Parent then
			root.Anchored = false
		end
	end
	local launched = 0
	for _, player in Players:GetPlayers() do
		local root = getAliveRoot(player)
		if not root or not RagdollService.canKnock(player) then
			continue
		end
		launched += 1
		-- A thief drops the ghost they were carrying.
		if player ~= launcher and launcher.Parent then
			StealService.knockLoose(launcher, player, "nuked")
		elseif StealService.getCarry(player) then
			StealService.returnGhost(player, "The nuke knocked the ghost out of your hands! It flew home.")
		end
		local away = Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z)
		local direction = if away.Magnitude > 0.1
			then away.Unit
			else CFrame.Angles(0, math.random() * math.pi * 2, 0).LookVector
		local push = direction * GameConfig.NukeKnockbackSpeed + Vector3.new(0, GameConfig.NukeKnockbackLift, 0)
		RagdollService.knock(player, push, GameConfig.NukeRagdollSeconds, true) -- counted from landing
	end
	if launcher.Parent and launched > 0 then
		Notify.send(
			launcher,
			"BOOM! Your nuke launched " .. launched .. (if launched == 1 then " player!" else " players!"),
			"success"
		)
	end
end

-- Called by ItemService when a player clicks while holding the remote.
function NukeService.tryUse(player: Player, tool: Tool)
	if
		not getAliveRoot(player)
		or DataService.getItemCount(player, NukeService.ITEM_ID) <= 0
		or player:GetAttribute("Invisible")
		or player:GetAttribute("Caged")
		or player:GetAttribute("Carrying")
	then
		return
	end
	if nukeOnTheWay then
		Notify.send(player, "A nuke is already on its way!", "error")
		return
	end
	local now = workspace:GetServerTimeNow()
	local waitLeft = (readyAt[player] or 0) - now
	if waitLeft > 0 then
		Notify.send(player, "Nuke ready in " .. math.ceil(waitLeft) .. "s", "error")
		return
	end
	readyAt[player] = now + GameConfig.NukeCooldownSeconds
	-- The hotbar shows the cooldown from these.
	tool:SetAttribute("ReadyAt", readyAt[player])
	tool:SetAttribute("CooldownTotal", GameConfig.NukeCooldownSeconds)

	-- Everyone else's nuke goes on a shorter cooldown (a longer one already running stays).
	local sharedReadyAt = now + GameConfig.NukeSharedCooldownSeconds
	for _, other in Players:GetPlayers() do
		if other == player or (readyAt[other] or 0) >= sharedReadyAt then
			continue
		end
		readyAt[other] = sharedReadyAt
		local backpack = other:FindFirstChildOfClass("Backpack")
		local otherTool = (backpack and backpack:FindFirstChild(NukeService.ITEM_ID))
			or (other.Character and other.Character:FindFirstChild(NukeService.ITEM_ID))
		if otherTool then
			otherTool:SetAttribute("ReadyAt", sharedReadyAt)
			otherTool:SetAttribute("CooldownTotal", GameConfig.NukeSharedCooldownSeconds)
		end
	end

	-- The button lights up.
	local button = tool:FindFirstChild("Button", true)
	if button and button:IsA("BasePart") then
		button.Material = Enum.Material.Neon
		task.delay(1, function()
			button.Material = Enum.Material.SmoothPlastic
		end)
	end

	nukeOnTheWay = true
	local target = groundTarget()
	local cutsceneAt = now + GameConfig.NukeCountdownSeconds
	local explodeAt = cutsceneAt + GameConfig.NukeFallSeconds
	Remotes.NukeLaunched:FireAllClients(player.DisplayName, cutsceneAt, explodeAt, target)

	task.spawn(function()
		task.wait(cutsceneAt - workspace:GetServerTimeNow())
		frozen = true
		local pinned = freezeEveryone()
		task.wait(explodeAt - workspace:GetServerTimeNow())
		frozen = false
		nukeOnTheWay = false
		explode(player, target, pinned)
	end)
end

-- The nuke's cooldown for a new copy of the tool (after respawning).
function NukeService.readyAt(player: Player): number?
	return readyAt[player]
end

function NukeService.start()
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
	end)
end

return NukeService
