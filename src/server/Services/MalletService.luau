-- The Mega Mallet (a Shop item, used from the hotbar). Click while standing on the ground:
--   1. Wind-up (GameConfig.MegaMalletWindupSeconds): you're pinned in place (root anchored by the
--      server, like the cage) with the mallet raised over your head, while a red cone grows on
--      the ground in front of you so everyone can see where it'll hit.
--   2. Slam: a shockwave and rock spikes rip outward through the cone at MegaMalletWaveSpeed.
--      Everyone the wave reaches inside the cone (MegaMalletRange, MegaMalletHalfAngle each side of
--      where you faced) is launched like a landmine and stays floppy for MegaMalletRagdollSeconds
--      after landing; a thief drops the ghost they were carrying.
-- The wind-up is cancelled if you're knocked over, caged, die or put the mallet away. The server
-- tells every device about the swing (MalletSwing remote) and each one plays the animation and
-- effects itself (client MalletClient), timed to the same slam moment. "MalletUntil" (server time
-- of the slam) is on the player during the wind-up. Cooldown starts on use.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notify = require(script.Parent.Parent.Util.Notify)
local DataService = require(script.Parent.DataService)
local RagdollService = require(script.Parent.RagdollService)
local StealService = require(script.Parent.StealService)

local MalletService = {}

MalletService.ITEM_ID = "mega_mallet"

local HEIGHT_REACH = 25 -- studs above or below the swinger that the wave still hits

-- When each player's mallet can next be used, in server time.
local readyAt: { [Player]: number } = {}

local function getAliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Where the swing comes from: on the ground under the swinger, facing where they face (flat).
local function swingOrigin(character: Model, root: BasePart): CFrame
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	local groundY = if hit then hit.Position.Y else root.Position.Y - 3
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, -1)
	end
	local at = Vector3.new(root.Position.X, groundY, root.Position.Z)
	return CFrame.lookAt(at, at + look.Unit)
end

-- The slam: every player inside the cone is launched when the shockwave reaches them.
local function slam(swinger: Player, origin: CFrame)
	local facing = origin.LookVector
	local minFacing = math.cos(math.rad(GameConfig.MegaMalletHalfAngle))
	local launched = 0
	local pending = 0
	for _, target in Players:GetPlayers() do
		local root = getAliveRoot(target)
		if target == swinger or not root or not RagdollService.canKnock(target) then
			continue
		end
		local offset = root.Position - origin.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local distance = flat.Magnitude
		if distance > GameConfig.MegaMalletRange or math.abs(offset.Y) > HEIGHT_REACH then
			continue
		end
		-- Right on top of the swinger counts as in front.
		if distance > 1 and flat.Unit:Dot(facing) < minFacing then
			continue
		end
		pending += 1
		task.delay(distance / GameConfig.MegaMalletWaveSpeed, function()
			pending -= 1
			local nowRoot = getAliveRoot(target)
			if target.Parent and nowRoot and RagdollService.canKnock(target) then
				launched += 1
				if swinger.Parent then
					StealService.knockLoose(swinger, target, "flattened")
				end
				local away =
					Vector3.new(nowRoot.Position.X - origin.Position.X, 0, nowRoot.Position.Z - origin.Position.Z)
				local direction = if away.Magnitude > 0.1 then away.Unit else facing
				local push = direction * GameConfig.MegaMalletKnockbackSpeed
					+ Vector3.new(0, GameConfig.MegaMalletKnockbackLift, 0)
				RagdollService.knock(target, push, GameConfig.MegaMalletRagdollSeconds, true) -- counted from landing
				Notify.send(target, swinger.DisplayName .. " flattened you with the Mega Mallet!", "error")
			end
			if pending == 0 and launched > 0 and swinger.Parent then
				Notify.send(
					swinger,
					"SMASH! You launched " .. launched .. (if launched == 1 then " player!" else " players!"),
					"success"
				)
			end
		end)
	end
end

-- Called by ItemService when a player clicks while holding the mallet.
function MalletService.tryUse(player: Player, tool: Tool)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if
		DataService.getItemCount(player, MalletService.ITEM_ID) <= 0
		or player:GetAttribute("MalletUntil")
		or player:GetAttribute("Invisible")
		or player:GetAttribute("Caged")
		or player:GetAttribute("Carrying")
		or RagdollService.isRagdolled(player)
	then
		return
	end
	if humanoid.FloorMaterial == Enum.Material.Air then
		Notify.send(player, "Stand on the ground to swing the Mega Mallet!", "error")
		return
	end
	local now = workspace:GetServerTimeNow()
	local waitLeft = (readyAt[player] or 0) - now
	if waitLeft > 0 then
		Notify.send(player, "Mega Mallet ready in " .. math.ceil(waitLeft) .. "s", "error")
		return
	end
	readyAt[player] = now + GameConfig.MegaMalletCooldownSeconds
	tool:SetAttribute("ReadyAt", readyAt[player]) -- the hotbar shows the cooldown from this

	-- Wind-up: pinned in place, facing the way they were, while every device plays it.
	local origin = swingOrigin(character, root)
	local slamAt = now + GameConfig.MegaMalletWindupSeconds
	root.Anchored = true
	player:SetAttribute("MalletUntil", slamAt)
	Remotes.MalletSwing:FireAllClients(character, slamAt, origin)

	task.spawn(function()
		local cancelled = false
		while workspace:GetServerTimeNow() < slamAt do
			if
				not player.Parent
				or player.Character ~= character
				or humanoid.Health <= 0
				or RagdollService.isRagdolled(player)
				or player:GetAttribute("Caged")
				or tool.Parent ~= character -- put the mallet away
			then
				cancelled = true
				break
			end
			RunService.Heartbeat:Wait()
		end
		-- Unpin (a cage pins them itself, and lets go when it opens).
		if root.Parent and not player:GetAttribute("Caged") then
			root.Anchored = false
		end
		if player.Parent then
			player:SetAttribute("MalletUntil", nil)
		end
		if cancelled then
			Remotes.MalletSwing:FireAllClients(character, false)
		else
			slam(player, origin)
		end
	end)
end

-- The mallet's cooldown for a new copy of the tool (after respawning).
function MalletService.readyAt(player: Player): number?
	return readyAt[player]
end

function MalletService.start()
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
	end)
end

return MalletService
