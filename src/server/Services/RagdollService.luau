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

-- Can this player be knocked over right now? Not while already down, just after getting up, or
-- while caged (CageService pins them in place).
-- No knocking someone who is already down, just got up, is caged, has a Gravity well open
-- (Gravity can't be interrupted by hits) or is shielded (ShieldService).
function RagdollService.canKnock(player: Player): boolean
	local shieldUntil = player:GetAttribute("ShieldUntil")
	return not ragdolled[player]
		and os.clock() >= (immuneUntil[player] or 0)
		and player:GetAttribute("Caged") ~= true
		and player:GetAttribute("GravityUntil") == nil
		and not (shieldUntil and workspace:GetServerTimeNow() < shieldUntil)
end

-- Has a launched (floppy) character come back down? Something solid just under the root part,
-- and no longer falling. Uses the positions and speeds their device sends the server.
local function hasLanded(character: Model, root: BasePart): boolean
	if root.AssemblyLinearVelocity.Y < -4 then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	-- Start above the root part: lying down, it can sit partly inside the floor.
	return workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, -6, 0), params) ~= nil
end

-- Waits until the character lands (or GameConfig.RagdollMaxAirSeconds pass, in case they never
-- seem to), giving it a moment to leave the ground first.
local function waitForLanding(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local started = os.clock()
	task.wait(0.3)
	while root and root.Parent and os.clock() - started < GameConfig.RagdollMaxAirSeconds do
		if hasLanded(character, root) then
			return
		end
		task.wait(0.1)
	end
end

-- Knocks the player over, pushing them with `velocity` (studs per second). They stay floppy for
-- `seconds` (the bat's GameConfig.BatRagdollSeconds if not given), counted from the hit, or from
-- when they land if `afterLanding` is true. After getting up they can't be knocked over again for
-- `immunitySeconds` (GameConfig.BatHitImmunitySeconds if not given).
function RagdollService.knock(
	player: Player,
	velocity: Vector3,
	seconds: number?,
	afterLanding: boolean?,
	immunitySeconds: number?
)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 or not RagdollService.canKnock(player) then
		return
	end
	ragdolled[player] = true
	-- A Mega Mallet wind-up pins the swinger in place (MalletService); let go so the hit lands.
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and root.Anchored and player:GetAttribute("MalletUntil") then
		root.Anchored = false
	end

	local joints = getJoints(character)
	-- Without this, switching off the neck joint would count as losing your head.
	humanoid.RequiresNeck = false
	for _, joint in joints do
		(joint :: any).Enabled = false
	end
	Remotes.Ragdoll:FireClient(player, true, velocity)

	task.spawn(function()
		if afterLanding then
			waitForLanding(character)
		end
		task.wait(seconds or GameConfig.BatRagdollSeconds)
		ragdolled[player] = nil
		immuneUntil[player] = os.clock() + (immunitySeconds or GameConfig.BatHitImmunitySeconds)
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
