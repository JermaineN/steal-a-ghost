-- Ragdoll: knocks a player over so their body goes floppy for a moment, then stands them up.
--
-- Characters use Roblox's avatar joints: each joint is an AnimationConstraint (holds the pose
-- that animations play) plus a BallSocketConstraint with realistic limits. Turning the
-- AnimationConstraints off leaves only the ball sockets, so the limbs flop. Doing that here on
-- the server makes everyone see it. The hit player's own device moves their character, so it
-- gets the knockback push and the "Physics" state through the Ragdoll remote (RagdollClient).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RagdollService = {}

local ragdolled: { [Player]: boolean } = {}
local immuneUntil: { [Player]: number } = {}

-- The joints that go floppy. "Root" (body to HumanoidRootPart) stays on, so the body and the
-- root part move together.
local function getJoints(character: Model): { Instance }
	local joints = {}
	for _, joint in character:GetDescendants() do
		if joint.ClassName == "AnimationConstraint" and joint.Name ~= "Root" then
			table.insert(joints, joint)
		end
	end
	return joints
end

function RagdollService.isRagdolled(player: Player): boolean
	return ragdolled[player] == true
end

-- Can this player be knocked over right now?
function RagdollService.canKnock(player: Player): boolean
	return not ragdolled[player] and os.clock() >= (immuneUntil[player] or 0)
end

-- Knocks the player over, pushing them with `velocity` (studs per second).
function RagdollService.knock(player: Player, velocity: Vector3)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 or not RagdollService.canKnock(player) then
		return
	end
	ragdolled[player] = true

	local joints = getJoints(character)
	-- Without this, switching off the neck joint would count as losing your head.
	humanoid.RequiresNeck = false
	for _, joint in joints do
		(joint :: any).Enabled = false
	end
	Remotes.Ragdoll:FireClient(player, true, velocity)

	task.delay(GameConfig.BatRagdollSeconds, function()
		ragdolled[player] = nil
		immuneUntil[player] = os.clock() + GameConfig.BatHitImmunitySeconds
		-- They may have respawned or left meanwhile; a new character starts with its joints on.
		if player.Parent and player.Character == character then
			for _, joint in joints do
				(joint :: any).Enabled = true
			end
			humanoid.RequiresNeck = true
			Remotes.Ragdoll:FireClient(player, false)
		end
	end)
end

function RagdollService.start()
	Players.PlayerRemoving:Connect(function(player)
		ragdolled[player] = nil
		immuneUntil[player] = nil
	end)
end

return RagdollService
