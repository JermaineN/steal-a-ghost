-- Gravity's pull. While any other player has a gravity well open (the server sets their
-- "GravityUntil" attribute, see GravityService) and you're inside its radius, your character is
-- dragged toward them every frame, and you're slowed to GravityVictimWalkSpeed so you can't walk
-- out of it: everyone caught reaches the middle. It happens on your own device because each
-- player's device moves their own character. The pull stops just short of the centre so you
-- don't jitter on top of them. Caged players stay put (the cage pins them), and shielded
-- players (the Shield item's "ShieldUntil") aren't pulled or slowed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local GravityClient = {}

local STOP_DISTANCE = 3 -- studs from the centre where the pull stops

function GravityClient.start()
	local player = Players.LocalPlayer
	-- While being pulled: the humanoid we slowed and its walk speed before, to put back after.
	local slowed: Humanoid? = nil
	local speedBefore = 0

	local function release()
		-- Only put it back if nothing else changed it meanwhile (e.g. picking up a stolen ghost).
		if slowed and slowed.Parent and slowed.WalkSpeed == GameConfig.GravityVictimWalkSpeed then
			slowed.WalkSpeed = speedBefore
		end
		slowed = nil
	end

	RunService.Heartbeat:Connect(function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local now = workspace:GetServerTimeNow()
		local shieldUntil = player:GetAttribute("ShieldUntil")
		local shielded = shieldUntil and now < shieldUntil
		if not character or not root or not humanoid or player:GetAttribute("Caged") or shielded then
			release()
			return
		end
		local radius = GameConfig.GravityRadius
		local inside = false
		for _, other in Players:GetPlayers() do
			local untilTime = other:GetAttribute("GravityUntil")
			local otherRoot = other ~= player
				and untilTime
				and untilTime > now
				and other.Character
				and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not otherRoot then
				continue
			end
			local offset = otherRoot.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local distance = flat.Magnitude
			if distance <= radius then
				inside = true
				if distance > STOP_DISTANCE then
					-- The pull speed at the edge, rising to about 1.35x near the middle.
					local closeness = 1 - distance / radius
					local speed = GameConfig.GravityPullSpeed * (1 + 0.35 * closeness)
					local step = math.min(speed * dt, distance - STOP_DISTANCE)
					character:PivotTo(character:GetPivot() + flat.Unit * step)
				end
			end
		end

		-- Slowed while inside any well; normal speed again once it closes.
		if inside and slowed ~= humanoid then
			release()
			slowed = humanoid
			speedBefore = humanoid.WalkSpeed
			humanoid.WalkSpeed = GameConfig.GravityVictimWalkSpeed
		elseif not inside and slowed then
			release()
		end
	end)
end

return GravityClient
