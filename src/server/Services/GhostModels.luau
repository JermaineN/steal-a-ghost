-- Detailed looks for individual ghosts, keyed by ghost id (see GhostConfig).
-- GhostService builds every ghost around a "Body" ball (used for prompts, carrying and the
-- label). A function here adds the ghost's look around that body and returns
-- how high above the body's center the name label should sit, or nil to use the simple look.
--
-- The 3D meshes are made in Studio and kept in ServerStorage.GhostMeshes, named by ghost id.
-- They can't live in git, so they're saved with the place file. If one is missing, the ghost
-- falls back to the simple look instead of breaking.
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local GhostModels = {}

-- Clients animate every model with this tag (see client GhostAnimation).
GhostModels.ANIMATED_TAG = "AnimatedGhost"

local function getMeshTemplate(id: string): MeshPart?
	local folder = ServerStorage:FindFirstChild("GhostMeshes")
	local mesh = folder and folder:FindFirstChild(id)
	if mesh and mesh:IsA("MeshPart") then
		return mesh
	end
	return nil
end

-- Copies a mesh, scales it to `height` studs tall, and joins it to the body with a Weld that
-- the client animation moves. Returns the mesh.
local function attachMesh(model: Model, body: BasePart, template: MeshPart, height: number, offsetY: number): MeshPart
	local mesh = template:Clone()
	mesh.Name = "Visual"
	mesh.Size = template.Size * (height / template.Size.Y)
	mesh.Anchored = false -- held in place by the weld instead, so it can be animated
	mesh.Massless = true
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false
	mesh.CastShadow = false
	mesh.CFrame = body.CFrame * CFrame.new(0, offsetY, 0)
	-- Tells StealService to leave this part's weld alone when a ghost is carried.
	mesh:SetAttribute("Animated", true)

	local weld = Instance.new("Weld")
	weld.Name = "AnimationWeld"
	weld.Part0 = body
	weld.Part1 = mesh
	weld.C0 = CFrame.new(0, offsetY, 0)
	weld.Parent = mesh

	mesh.Parent = model
	CollectionService:AddTag(model, GhostModels.ANIMATED_TAG)
	return mesh
end

-- Turns a ghost into its mesh: scaled to `heightScale` × the ghost's size, see-through by
-- `transparency` (0.2 unless given), glowing `glowColor`, and animated. Returns the label
-- height and the mesh, or nil if the mesh is missing (the ghost then keeps the simple look).
local function meshGhost(
	model: Model,
	body: BasePart,
	def,
	heightScale: number,
	glowColor: Color3,
	transparency: number?
): (number?, MeshPart?)
	local template = getMeshTemplate(def.id)
	if not template then
		return nil, nil
	end

	local height = def.size * heightScale
	body.Transparency = 1 -- the mesh is the ghost; the body just carries prompts and the label
	local mesh = attachMesh(model, body, template, height, 0.2)
	mesh.Transparency = transparency or 0.2

	local light = body:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = glowColor
		light.Brightness = 2
		light.Range = def.size * 3.5
	end
	return height / 2 + 0.2 + 1.5, mesh
end

-- Wisp: a cute but eerie little ghost of icy blue spirit-fire with a flame crest on its head.
function GhostModels.wisp(model: Model, body: BasePart, def): number?
	local labelHeight, mesh = meshGhost(model, body, def, 1.5, Color3.fromRGB(120, 190, 255))
	if not mesh then
		return nil
	end

	-- Embers drifting up off its flames.
	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(Color3.fromRGB(215, 240, 255), Color3.fromRGB(110, 180, 255))
	embers.LightEmission = 1
	embers.Size = NumberSequence.new(0.25, 0)
	embers.Transparency = NumberSequence.new(0.2, 1)
	embers.Lifetime = NumberRange.new(0.8, 1.5)
	embers.Rate = 6
	embers.Speed = NumberRange.new(0.5, 1.2)
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Parent = mesh

	return labelHeight
end

-- Boo: a chubby, cheeky white ghost with arms up, rosy cheeks and its tongue sticking out.
function GhostModels.boo(model: Model, body: BasePart, def): number?
	return (meshGhost(model, body, def, 1.3, Color3.fromRGB(225, 235, 255)))
end

-- Poltergeist: a grinning, mischievous blob of glowing green slime with big round eyes.
function GhostModels.poltergeist(model: Model, body: BasePart, def): number?
	local slimeGreen = Color3.fromRGB(90, 255, 110)
	local labelHeight, mesh = meshGhost(model, body, def, 1, slimeGreen)
	if not mesh then
		return nil
	end

	-- An extra-strong green glow, and little glowing motes of slime drifting off it.
	local light = body:FindFirstChildOfClass("PointLight")
	if light then
		light.Brightness = 3
		light.Range = def.size * 4
	end
	local motes = Instance.new("ParticleEmitter")
	motes.Color = ColorSequence.new(Color3.fromRGB(190, 255, 170), slimeGreen)
	motes.LightEmission = 1
	motes.Size = NumberSequence.new(0.2, 0)
	motes.Transparency = NumberSequence.new(0.2, 1)
	motes.Lifetime = NumberRange.new(1, 1.8)
	motes.Rate = 5
	motes.Speed = NumberRange.new(0.3, 0.8)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Acceleration = Vector3.new(0, 0.4, 0)
	motes.Parent = mesh

	return labelHeight
end

-- Banshee: a little wailing ghost girl with blue-violet flame hair rising straight up, glowing
-- white eyes and a torn white dress. Only slightly see-through, so her colours stay clean.
-- She keeps the flame flicker, since her hair is fire.
function GhostModels.banshee(model: Model, body: BasePart, def): number?
	local labelHeight, mesh = meshGhost(model, body, def, 1.3, Color3.fromRGB(150, 120, 255), 0.1)
	if not mesh then
		return nil
	end

	-- Faint lavender mist trailing down off her dress.
	local mist = Instance.new("ParticleEmitter")
	mist.Color = ColorSequence.new(Color3.fromRGB(215, 205, 255))
	mist.LightEmission = 0.4
	mist.Size = NumberSequence.new(0.6, 1.4)
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	mist.Lifetime = NumberRange.new(1.2, 2)
	mist.Rate = 6
	mist.Speed = NumberRange.new(0.2, 0.5)
	mist.SpreadAngle = Vector2.new(30, 30)
	mist.EmissionDirection = Enum.NormalId.Bottom
	mist.Parent = mesh

	return labelHeight
end

-- Sheet Ghost: someone hiding under a white bedsheet with eye holes, with their bare feet
-- showing underneath. Solid (not see-through), unlike the others.
function GhostModels.sheet_ghost(model: Model, body: BasePart, def): number?
	local labelHeight, mesh = meshGhost(model, body, def, 1.4, Color3.fromRGB(235, 235, 245), 0)
	if not mesh then
		return nil
	end
	-- Cloth shouldn't stretch like a flame; it just bobs and sways.
	mesh:SetAttribute("Flicker", false)
	return labelHeight
end

return GhostModels
