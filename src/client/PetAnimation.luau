-- Flaps pet wings on this player's screen, and floats this player's own pet up and down. The server tags each wing "FlappingWing" (see server
-- CosmeticModels) and holds it to the pet's body with a Weld named "WingWeld" whose C0 sits at
-- the wing's hinge. Turning that C0 here only moves the wing on this device, so the flapping is
-- smooth and nothing extra is sent over the network.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetAnimation = {}

local TAG = "FlappingWing"
local MAX_DISTANCE = 160 -- don't bother animating pets this far from the camera
local FLAP_SPEED = 11 -- radians per second (about 1.75 flaps a second)
local FLAP_ANGLE = math.rad(22) -- how far each wing swings up and down from its resting pose
local BOB_SPEED = 1.6 -- radians per second (one float up and down about every 4 seconds)
local BOB_HEIGHT = 0.3 -- studs above and below its usual height

type Wing = {
	part: BasePart,
	weld: Weld,
	baseC0: CFrame,
	side: number, -- -1 left, 1 right
	phase: number, -- so pets don't all flap in sync
}
local wings: { [Instance]: Wing } = {}

local function track(part: Instance)
	local weld = part:WaitForChild("WingWeld", 5)
	if not (weld and weld:IsA("Weld") and part:IsA("BasePart")) or not part.Parent then
		return
	end
	-- Both wings of one pet share a phase (from their model), so they flap together.
	local model = part.Parent
	local phase = model and model:GetAttribute("FlapPhase")
	if not phase and model then
		phase = math.random() * 100
		model:SetAttribute("FlapPhase", phase)
	end
	wings[part] = {
		part = part,
		weld = weld,
		baseC0 = weld.C0,
		side = part:GetAttribute("Side") or 1,
		phase = phase or 0,
	}
end

-- Makes this player's own pet float up and down. The pet follows an attachment on the root
-- part (server CosmeticService), and this device is the one moving the pet, so moving the
-- attachment here bobs the pet for everyone.
local bobTarget: Attachment? = nil
local bobBase = Vector3.zero
local function bob(now: number)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local target = root and root:FindFirstChild("CosmeticPetTarget")
	if not (target and target:IsA("Attachment")) then
		bobTarget = nil
		return
	end
	if target ~= bobTarget then
		bobTarget = target
		bobBase = target.Position
	end
	target.Position = bobBase + Vector3.new(0, BOB_HEIGHT * math.sin(now * BOB_SPEED), 0)
end

local function animate()
	local camera = Workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
	local now = os.clock()
	bob(now)
	for part, wing in wings do
		if not wing.part.Parent then
			wings[part] = nil
			continue
		end
		if (wing.part.Position - cameraPosition).Magnitude > MAX_DISTANCE then
			continue
		end
		-- Turning around the hinge's front-to-back axis lifts the wing tip up or down; the side
		-- sign makes both tips go up together.
		local angle = FLAP_ANGLE * math.sin(now * FLAP_SPEED + wing.phase)
		wing.weld.C0 = wing.baseC0 * CFrame.Angles(0, 0, -wing.side * angle)
	end
end

function PetAnimation.start()
	for _, part in CollectionService:GetTagged(TAG) do
		task.spawn(track, part)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(part)
		task.spawn(track, part)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(part)
		wings[part] = nil
	end)
	RunService.RenderStepped:Connect(animate)
end

return PetAnimation
