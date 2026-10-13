-- Animates ghost meshes on this player's screen: a gentle bob up and down, a slow sway, and a
-- flame-like flicker (a quick stretch/squash and a pulsing glow). Ghosts whose mesh sets the
-- "Walk" attribute (the Spectre King) waddle from foot to foot instead, as if walking.
-- The server tags these ghosts "AnimatedGhost" (see server GhostModels) and holds each mesh to
-- the ghost's invisible body with a Weld. Changing that weld here only moves the mesh on this
-- device, so the animation is smooth and nothing extra is sent over the network.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GhostAnimation = {}

local TAG = "AnimatedGhost"
local MAX_DISTANCE = 160 -- don't bother animating ghosts this far from the camera

type Animated = {
	weld: Weld,
	baseC0: CFrame,
	mesh: BasePart,
	baseSize: Vector3,
	flicker: boolean, -- flame-like stretch; off for ghosts that set the mesh's "Flicker" to false
	walk: boolean, -- waddle-walk instead of floating; on when the mesh's "Walk" is true
	light: PointLight?,
	baseBrightness: number,
	phase: number, -- so ghosts don't all move in sync
}
local animated: { [Instance]: Animated } = {}

local function track(model: Instance)
	local mesh = model:WaitForChild("Visual", 5)
	local weld = mesh and mesh:WaitForChild("AnimationWeld", 5)
	if not (mesh and weld and mesh:IsA("BasePart") and weld:IsA("Weld")) or not model.Parent then
		return
	end
	local body = (model :: Model).PrimaryPart
	local light = body and body:FindFirstChildOfClass("PointLight")
	animated[model] = {
		weld = weld,
		baseC0 = weld.C0,
		mesh = mesh,
		baseSize = mesh.Size,
		flicker = mesh:GetAttribute("Flicker") ~= false,
		walk = mesh:GetAttribute("Walk") == true,
		light = light,
		baseBrightness = if light then light.Brightness else 0,
		phase = math.random() * 100,
	}
end

local function animate()
	local camera = Workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
	local now = os.clock()

	for model, ghost in animated do
		if not ghost.mesh.Parent then
			animated[model] = nil
			continue
		end
		if (ghost.mesh.Position - cameraPosition).Magnitude > MAX_DISTANCE then
			continue
		end
		local t = now + ghost.phase

		if ghost.walk then
			-- Waddle walk: rock from foot to foot (pivoting at the feet), bounce up on each step,
			-- turn slightly into each stride, and lean a little forward.
			local step = t * 4
			local feet = ghost.baseSize.Y / 2
			local rock = math.rad(8) * math.sin(step)
			local bounce = math.abs(math.sin(step)) * 0.35
			local turn = math.rad(5) * math.sin(step)
			ghost.weld.C0 = ghost.baseC0
				* CFrame.new(0, bounce - feet, 0)
				* CFrame.Angles(math.rad(-4), turn, rock)
				* CFrame.new(0, feet, 0)
		else
			-- Bob and sway.
			local bob = math.sin(t * 2) * 0.25
			local roll = math.rad(6) * math.sin(t * 1.3)
			local yaw = math.rad(8) * math.sin(t * 0.9)
			ghost.weld.C0 = ghost.baseC0 * CFrame.new(0, bob, 0) * CFrame.Angles(0, yaw, roll)
		end

		-- Flicker like a flame: stretch taller and thinner, then back (keeping its volume).
		if ghost.flicker then
			local stretch = 1 + math.sin(t * 6) * 0.04 + math.sin(t * 9.7) * 0.02
			local thin = 1 / math.sqrt(stretch)
			ghost.mesh.Size = ghost.baseSize * Vector3.new(thin, stretch, thin)
		end

		if ghost.light and ghost.flicker then
			ghost.light.Brightness = ghost.baseBrightness * (0.85 + 0.15 * math.sin(t * 7.3))
		end
	end
end

function GhostAnimation.start()
	for _, model in CollectionService:GetTagged(TAG) do
		task.spawn(track, model)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model)
		task.spawn(track, model)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
		animated[model] = nil
	end)
	RunService.RenderStepped:Connect(animate)
end

return GhostAnimation
