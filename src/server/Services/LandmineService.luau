-- Landmines: an allowed player clicks with the Landmine to place one at their feet.
--
-- Only the owner can see their mines. The server keeps just their positions (no parts, so nothing
-- reaches other players' devices) and tells only the owner's device where to draw them (the
-- Landmine remote, drawn by LandmineEffects). Anyone else who walks within the trigger radius sets
-- one off: every player in the blast except the owner is launched and knocked over (much harder
-- and longer than the bat), thieves drop their ghost, and everyone sees the explosion
-- (LandmineExploded remote).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notify = require(script.Parent.Parent.Util.Notify)
local RagdollService = require(script.Parent.RagdollService)
local StealService = require(script.Parent.StealService)

local LandmineService = {}

type Mine = { id: number, owner: Player, position: Vector3, armedAt: number }

local minesByOwner: { [Player]: { Mine } } = {} -- oldest first
local readyAt: { [Player]: number } = {} -- server time when they can place again
local nextId = 0

-- Placed mines sit on the ground; a player's root part is about 3 studs above it, so triggers and
-- the blast measure sideways distance and allow this much height difference.
local MAX_HEIGHT_DIFFERENCE = 8

local function getAliveRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root :: BasePart
	end
	return nil
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function isNear(root: BasePart, position: Vector3, radius: number): boolean
	return flatDistance(root.Position, position) <= radius
		and math.abs(root.Position.Y - position.Y) <= MAX_HEIGHT_DIFFERENCE
end

local function removeMine(mine: Mine)
	local mines = minesByOwner[mine.owner]
	local index = mines and table.find(mines, mine)
	if index then
		table.remove(mines, index)
	end
	if mine.owner.Parent then
		Remotes.Landmine:FireClient(mine.owner, "removed", mine.id)
	end
end

local function explode(mine: Mine, triggeredBy: Player)
	removeMine(mine)
	Remotes.LandmineExploded:FireAllClients(mine.position, GameConfig.LandmineExplosionRadius)

	local launched = {}
	for _, target in Players:GetPlayers() do
		local root = getAliveRoot(target)
		if
			target == mine.owner
			or not root
			or not RagdollService.canKnock(target)
			or not isNear(root, mine.position, GameConfig.LandmineExplosionRadius)
		then
			continue
		end
		StealService.knockLoose(mine.owner, target, "blasted")
		-- Away from the mine (or any direction if standing right on top of it).
		local away = Vector3.new(root.Position.X - mine.position.X, 0, root.Position.Z - mine.position.Z)
		local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
		local push = direction * GameConfig.LandmineKnockbackSpeed + Vector3.new(0, GameConfig.LandmineKnockbackLift, 0)
		RagdollService.knock(target, push, GameConfig.LandmineRagdollSeconds, true) -- counted from landing
		table.insert(launched, target)
		if target == triggeredBy then
			Notify.send(target, "You stepped on a hidden landmine!", "error")
		else
			Notify.send(target, "You got caught in a landmine blast!", "error")
		end
	end

	if mine.owner.Parent then
		if #launched == 1 then
			Notify.send(mine.owner, "Your landmine got " .. launched[1].DisplayName .. "!", "success")
		elseif #launched > 1 then
			Notify.send(mine.owner, "Your landmine got " .. #launched .. " players!", "success")
		end
	end
end

-- Called when an allowed player clicks with the Landmine (ItemService checks they can use items).
function LandmineService.tryPlace(player: Player)
	local root = getAliveRoot(player)
	if not root then
		return
	end
	local now = workspace:GetServerTimeNow()
	local waitLeft = (readyAt[player] or 0) - now
	if waitLeft > 0 then
		Notify.send(player, "Next landmine ready in " .. math.ceil(waitLeft) .. "s", "error")
		return
	end

	-- Find the ground under their feet.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -8, 0), params)
	if not hit then
		Notify.send(player, "Stand on the ground to place a landmine.", "error")
		return
	end
	local position = hit.Position

	local mines = minesByOwner[player]
	if not mines then
		mines = {}
		minesByOwner[player] = mines
	end
	for _, mine in mines do
		if (mine.position - position).Magnitude < GameConfig.LandmineMinSpacing then
			Notify.send(player, "Too close to another landmine! Move further away.", "error")
			return
		end
	end

	local replacedOldest = false
	if #mines >= GameConfig.LandmineMaxPlaced then
		removeMine(mines[1])
		replacedOldest = true
	end

	nextId += 1
	local mine: Mine =
		{ id = nextId, owner = player, position = position, armedAt = os.clock() + GameConfig.LandmineArmSeconds }
	table.insert(mines, mine)
	readyAt[player] = now + GameConfig.LandmineCooldownSeconds
	Remotes.Landmine:FireClient(player, "placed", mine.id, position)

	local count = "(" .. #mines .. "/" .. GameConfig.LandmineMaxPlaced .. ")"
	if replacedOldest then
		Notify.send(player, "Landmine placed! Your oldest one was removed " .. count, "success")
	else
		Notify.send(player, "Landmine placed! " .. count, "success")
	end
end

local function checkTriggers()
	local now = os.clock()
	for _, mines in minesByOwner do
		-- Copy the list: an explosion removes the mine from it.
		for _, mine in table.clone(mines) do
			if now < mine.armedAt then
				continue
			end
			for _, player in Players:GetPlayers() do
				local root = getAliveRoot(player)
				-- Players already knocked over or caged don't set mines off (so they aren't wasted).
				if
					player ~= mine.owner
					and root
					and RagdollService.canKnock(player)
					and isNear(root, mine.position, GameConfig.LandmineTriggerRadius)
				then
					explode(mine, player)
					break
				end
			end
		end
	end
end

function LandmineService.start()
	Players.PlayerAdded:Connect(function(player)
		minesByOwner[player] = {}
	end)
	for _, player in Players:GetPlayers() do
		minesByOwner[player] = {}
	end
	-- A player's mines disappear with them.
	Players.PlayerRemoving:Connect(function(player)
		minesByOwner[player] = nil
		readyAt[player] = nil
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.1 then
			elapsed = 0
			checkTriggers()
		end
	end)
end

return LandmineService
