-- The bat swing animation, made in code: twists the waist and moves the right arm through a
-- wind-up, the hit, and a follow-through, then back to the normal pose.
--
-- Roblox's Animator sets each joint's Transform (its current pose) every frame. Right after it
-- does (RunService.Stepped), this adds extra rotation on top, so the swing blends with walking and
-- the bat-holding pose. It only changes how the character looks on this device, so every device
-- plays it: your own the moment you click, everyone else's when the server sends BatSwing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local BatSwing = {}

-- Key poses, in degrees. time: seconds from the click. waist: torso twist (+ = to the right).
-- pitch/yaw: the arm raised (+) or lowered (-) / swung left (+) or right (-) at the shoulder.
-- roll: the arm turned along its length, which tips the bat (+ = toward the left).
-- The hit lands around the "contact" pose (GameConfig.BatHitDelay).
type Pose = { time: number, waist: number, pitch: number, yaw: number, roll: number }
local POSES: { Pose } = {
	{ time = 0, waist = 0, pitch = 0, yaw = 0, roll = 0 }, -- holding the bat
	{ time = 0.14, waist = 35, pitch = 0, yaw = -50, roll = -60 }, -- wind-up: bat cocked behind the shoulder
	{ time = 0.24, waist = -10, pitch = -30, yaw = 10, roll = 50 }, -- contact: bat level across the front
	{ time = 0.36, waist = -45, pitch = 0, yaw = 70, roll = 90 }, -- follow-through: bat wraps to the left
	{ time = 0.44, waist = -45, pitch = 0, yaw = 70, roll = 90 }, -- brief hold
	{ time = 0.7, waist = 0, pitch = 0, yaw = 0, roll = 0 }, -- back to holding the bat
}

local playing: { [Model]: RBXScriptConnection } = {}

-- Smooth start and stop between two poses.
local function ease(alpha: number): number
	return alpha * alpha * (3 - 2 * alpha)
end

local function poseAt(elapsed: number): Pose
	for i = 2, #POSES do
		local from, to = POSES[i - 1], POSES[i]
		if elapsed <= to.time then
			local alpha = ease((elapsed - from.time) / (to.time - from.time))
			local function mix(key: string): number
				return (from :: any)[key] + ((to :: any)[key] - (from :: any)[key]) * alpha
			end
			return { time = elapsed, waist = mix("waist"), pitch = mix("pitch"), yaw = mix("yaw"), roll = mix("roll") }
		end
	end
	return POSES[#POSES]
end

function BatSwing.play(character: Model)
	local waistPart = character:FindFirstChild("UpperTorso")
	local armPart = character:FindFirstChild("RightUpperArm")
	local waist = waistPart and waistPart:FindFirstChild("Waist")
	local shoulder = armPart and armPart:FindFirstChild("RightShoulder")
	if not waist or not shoulder then
		return -- not an R15 character
	end
	if playing[character] then
		playing[character]:Disconnect()
	end

	local started = os.clock()
	playing[character] = RunService.Stepped:Connect(function()
		local elapsed = os.clock() - started
		if elapsed >= POSES[#POSES].time or not character.Parent then
			playing[character]:Disconnect()
			playing[character] = nil
			return
		end
		local pose = poseAt(elapsed)
		local rad = math.rad
		-- Rotating before the animated pose turns the joint in the torso's frame; rotating after
		-- turns the arm about its own length.
		local w = waist :: any
		local s = shoulder :: any
		w.Transform = CFrame.Angles(0, rad(-pose.waist), 0) * w.Transform
		s.Transform = CFrame.Angles(rad(pose.pitch), rad(pose.yaw), 0)
			* s.Transform
			* CFrame.Angles(0, rad(pose.roll), 0)
	end)
end

function BatSwing.start()
	local player = Players.LocalPlayer
	local lastSwing = 0

	-- Your own swing plays as soon as you click. The server checks the same cooldown and does
	-- the actual hitting.
	local function onToolAdded(item: Instance)
		if item:IsA("Tool") and item.Name == "Bat" and not item:GetAttribute("SwingWired") then
			item:SetAttribute("SwingWired", true) -- only on this device
			item.Activated:Connect(function()
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local now = os.clock()
				if
					not character
					or not humanoid
					or humanoid:GetState() == Enum.HumanoidStateType.Physics -- knocked over
					or now - lastSwing < GameConfig.BatSwingCooldown
				then
					return
				end
				lastSwing = now
				BatSwing.play(character)
			end)
		end
	end
	local function onCharacter(character: Model)
		character.ChildAdded:Connect(onToolAdded)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end

	Remotes.BatSwing.OnClientEvent:Connect(function(character: Model)
		if character and character.Parent then
			BatSwing.play(character)
		end
	end)
end

return BatSwing
