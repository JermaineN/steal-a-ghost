-- Your side of being knocked over (the server switches off your joints in RagdollService).
-- Your own device moves your character, so the knockback push and the "Physics" state (the
-- character stops trying to stand and just tumbles) have to happen here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RagdollClient = {}

-- While floppy, the limbs need to collide with the ground (normally only the root part does)
-- or the body would sink into the floor. The root part stops colliding so it doesn't prop the
-- body up. Remembers the old values to put back.
local savedCollide: { [BasePart]: boolean } = {}

local function setRagdolled(character: Model, on: boolean)
	for _, part in character:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		if on then
			savedCollide[part] = part.CanCollide
			part.CanCollide = part.Name ~= "HumanoidRootPart"
		elseif savedCollide[part] ~= nil then
			part.CanCollide = savedCollide[part]
		end
	end
	if not on then
		table.clear(savedCollide)
	end
end

-- Lying down, the root part sits partly inside the floor. Turning its collision back on there
-- drags the whole body into the floor, so first stand the character upright on top of the
-- ground, facing the way their body was pointing.
local function standUpright(character: Model, humanoid: Humanoid, root: BasePart)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(root.Position + Vector3.new(0, 3, 0), Vector3.new(0, -10, 0), params)
	local groundY = if hit then hit.Position.Y else root.Position.Y
	local standY = groundY + humanoid.HipHeight + root.Size.Y / 2

	local facing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if facing.Magnitude < 0.1 then
		facing = root.CFrame.UpVector * Vector3.new(1, 0, 1) -- lying flat on their back or front
	end
	local position = Vector3.new(root.Position.X, standY, root.Position.Z)
	character:PivotTo(CFrame.lookAt(position, position + facing.Unit))
	root.AssemblyLinearVelocity = Vector3.zero
end

function RagdollClient.start()
	local player = Players.LocalPlayer
	Remotes.Ragdoll.OnClientEvent:Connect(function(on: boolean, velocity: Vector3?)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not character or not humanoid or not root or humanoid.Health <= 0 then
			return
		end
		if on then
			setRagdolled(character, true)
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
			if velocity then
				-- With the joints off, each limb moves on its own, so push every one of them
				-- (pushing only the root would leave the rest of the body dragging it down).
				for _, part in character:GetChildren() do
					if part:IsA("BasePart") then
						part.AssemblyLinearVelocity = velocity
					end
				end
				-- Tumble head over heels in the direction of the push.
				local flat = velocity * Vector3.new(1, 0, 1)
				if flat.Magnitude > 0.1 then
					root.AssemblyAngularVelocity = flat.Unit:Cross(Vector3.yAxis) * -GameConfig.BatKnockbackSpin
				end
			end
		else
			standUpright(character, humanoid, root)
			setRagdolled(character, false)
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

return RagdollClient
