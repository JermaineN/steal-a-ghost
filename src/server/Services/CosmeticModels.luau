-- How each cosmetic (CosmeticConfig) looks, built in code (except pet meshes made in Studio, see
-- MESH_PETS). CosmeticService decides when to put them on and take them off.
--   aura       particle emitters on attachments in the character's root part
--   pet        a small unanchored model; CosmeticService makes it follow its owner
--   tombstone  a colour and material painted over the base's tombstones
--   flowers    a little model placed beside each grave
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Parts = require(script.Parent.Parent.Util.Parts)

local CosmeticModels = {}

local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local function sequence(...: number): NumberSequence
	local values = { ... }
	local keypoints = {}
	for index, value in values do
		table.insert(keypoints, NumberSequenceKeypoint.new((index - 1) / (#values - 1), value))
	end
	return NumberSequence.new(keypoints)
end

---------------------------------------------------------------------------
-- Auras
---------------------------------------------------------------------------

-- Each aura is a list of emitters; each emitter's settings are copied onto a ParticleEmitter,
-- and it's placed at every point in `points` (relative to the root part's centre). Emitters on
-- an attachment emit from that point, so a ring of points makes a ring of particles.
local FEET_RING = {}
for step = 0, 5 do
	local angle = step / 6 * math.pi * 2
	table.insert(FEET_RING, Vector3.new(math.cos(angle) * 1.4, -2.6, math.sin(angle) * 1.4))
end

local AURAS = {
	-- Purple flames licking up from around the feet.
	aura_purple = {
		{
			points = FEET_RING,
			Texture = FIRE_TEXTURE,
			Color = ColorSequence.new(Color3.fromRGB(230, 140, 255), Color3.fromRGB(120, 40, 230)),
			LightEmission = 1,
			Size = sequence(1.8, 1.3, 0),
			Transparency = sequence(0.1, 0.4, 1),
			Lifetime = NumberRange.new(0.6, 1),
			Rate = 14,
			Speed = NumberRange.new(2.5, 4),
			SpreadAngle = Vector2.new(10, 10),
			EmissionDirection = Enum.NormalId.Top,
		},
	},
	-- Gold glitter drifting out all around the body.
	aura_golden = {
		{
			points = { Vector3.new(0, 0.5, 0), Vector3.new(0, -1.5, 0) },
			Texture = SPARKLE_TEXTURE,
			Color = ColorSequence.new(Color3.fromRGB(255, 225, 90), Color3.fromRGB(255, 170, 30)),
			LightEmission = 1,
			Size = sequence(0.8, 0.6, 0),
			Transparency = sequence(0, 0.1, 1),
			Lifetime = NumberRange.new(0.8, 1.3),
			Rate = 30,
			Speed = NumberRange.new(1.5, 2.5),
			RotSpeed = NumberRange.new(-90, 90),
			SpreadAngle = Vector2.new(180, 180),
		},
	},
}

-- Puts an aura on a character's root part: one attachment named "CosmeticAura" per point
-- (attachments only work directly on a part). Take it off with CosmeticModels.removeAura.
function CosmeticModels.aura(cosmeticId: string, root: BasePart)
	for _, settings in AURAS[cosmeticId] or {} do
		for _, point in settings.points do
			local attachment = Instance.new("Attachment")
			attachment.Name = "CosmeticAura"
			attachment.Position = point
			local emitter = Instance.new("ParticleEmitter")
			for key, value in settings do
				if key ~= "points" then
					(emitter :: any)[key] = value
				end
			end
			emitter.Parent = attachment
			attachment.Parent = root
		end
	end
end

function CosmeticModels.removeAura(root: BasePart)
	for _, child in root:GetChildren() do
		if child.Name == "CosmeticAura" then
			child:Destroy()
		end
	end
end

---------------------------------------------------------------------------
-- Pets
---------------------------------------------------------------------------

local function petPart(model: Model, props: { [string]: any }): Part
	local part = Parts.make(model, props)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	return part
end

-- Welds every part of a pet to its body so it moves as one.
local function weldAll(model: Model, body: BasePart)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= body then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = part
			weld.Parent = part
		end
	end
end

local function eyes(model: Model, body: BasePart, spacing: number, height: number, size: number, color: Color3)
	for _, side in { -1, 1 } do
		petPart(model, {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			Color = color,
			Material = Enum.Material.Neon,
			CFrame = body.CFrame * CFrame.new(side * spacing, height, -body.Size.Z / 2 + size * 0.3),
		})
	end
end

local PETS = {
	-- A little jack-o'-lantern with a stem and glowing eyes.
	pet_pumpkin = function(model: Model): BasePart
		local body = petPart(model, {
			Name = "Body",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.6, 1.6, 1.6),
			Color = Color3.fromRGB(255, 130, 20),
			Material = Enum.Material.SmoothPlastic,
			CFrame = CFrame.new(),
		})
		petPart(model, {
			Name = "Stem",
			Size = Vector3.new(0.25, 0.45, 0.25),
			Color = Color3.fromRGB(80, 140, 40),
			Material = Enum.Material.Wood,
			CFrame = CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.rad(12)),
		})
		eyes(model, body, 0.3, 0.15, 0.32, Color3.fromRGB(255, 230, 80))
		petPart(model, {
			Name = "Mouth",
			Size = Vector3.new(0.7, 0.14, 0.2),
			Color = Color3.fromRGB(255, 230, 80),
			Material = Enum.Material.Neon,
			CFrame = CFrame.new(0, -0.3, -0.72),
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 160, 60)
		light.Range = 6
		light.Brightness = 0.8
		light.Parent = body
		return body
	end,
	-- A round purple bat with two wings, pointy ears and red eyes (light enough to see at night).
	pet_bat = function(model: Model): BasePart
		local body = petPart(model, {
			Name = "Body",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.2, 1.2, 1.2),
			Color = Color3.fromRGB(95, 60, 130),
			Material = Enum.Material.SmoothPlastic,
			CFrame = CFrame.new(),
		})
		for _, side in { -1, 1 } do
			petPart(model, {
				Name = "Wing",
				Size = Vector3.new(1.3, 0.1, 0.8),
				Color = Color3.fromRGB(140, 80, 190),
				Material = Enum.Material.SmoothPlastic,
				CFrame = CFrame.new(side * 1.1, 0.2, 0.1) * CFrame.Angles(0, 0, math.rad(side * -20)),
			})
			petPart(model, {
				Name = "Ear",
				Size = Vector3.new(0.2, 0.4, 0.2),
				Color = Color3.fromRGB(95, 60, 130),
				Material = Enum.Material.SmoothPlastic,
				CFrame = CFrame.new(side * 0.3, 0.65, 0) * CFrame.Angles(0, 0, math.rad(side * -15)),
			})
		end
		eyes(model, body, 0.22, 0.1, 0.24, Color3.fromRGB(255, 50, 60))
		return body
	end,
}

-- Pets with a mesh made in Studio. Like the ghosts' ServerStorage.GhostMeshes, these can't live
-- in git, so they're saved with the place in ServerStorage.CosmeticMeshes, named by cosmetic
-- id. Each is a Model with a "Body" part; a wing is a part with a "Hinge" attachment where it
-- joins the body and a "Side" attribute (-1 left, 1 right), which the client flaps (client
-- PetAnimation). If the mesh is missing, the pet is built from parts instead (PETS above).
CosmeticModels.WING_TAG = "FlappingWing"

local MESH_PETS = {
	-- A jack-o'-lantern with bat wings. The face is carved deep into the mesh and painted glowing
	-- yellow inside; a warm light just behind it (the body's "Glow" attachment) makes it shine.
	pet_pumpkin = {
		height = 1.6, -- the body's height in studs
		decorate = function(_model: Model, body: BasePart)
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 150, 40)
			light.Range = 7
			light.Brightness = 1.5
			light.Parent = body:FindFirstChild("Glow") or body
		end,
	},
}

local function meshPet(cosmeticId: string): Model?
	local settings = MESH_PETS[cosmeticId]
	local folder = ServerStorage:FindFirstChild("CosmeticMeshes")
	local template = settings and folder and folder:FindFirstChild(cosmeticId)
	local templateBody = template and template:FindFirstChild("Body")
	if not (template and template:IsA("Model") and templateBody and templateBody:IsA("BasePart")) then
		return nil
	end
	local model = template:Clone()
	model.Name = "Pet"
	local body = model:FindFirstChild("Body") :: BasePart
	model.PrimaryPart = body
	model:ScaleTo(model:GetScale() * settings.height / body.Size.Y)
	model:PivotTo(CFrame.new())
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
		end
	end
	settings.decorate(model, body)

	-- Wings hang off the body on a Weld (not a WeldConstraint), so the client can swing them
	-- around the hinge by changing the weld's C0.
	for _, wing in model:GetChildren() do
		local hinge = wing:FindFirstChild("Hinge")
		if wing:IsA("BasePart") and hinge and hinge:IsA("Attachment") then
			local weld = Instance.new("Weld")
			weld.Name = "WingWeld"
			weld.Part0 = body
			weld.Part1 = wing
			weld.C0 = body.CFrame:ToObjectSpace(hinge.WorldCFrame)
			weld.C1 = hinge.CFrame
			weld.Parent = wing
			CollectionService:AddTag(wing, CosmeticModels.WING_TAG)
		end
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= body and not part:FindFirstChild("WingWeld") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = part
			weld.Parent = part
		end
	end
	return model
end

-- Builds a pet's model (not parented yet), its PrimaryPart the body. Nil if there's no such pet.
function CosmeticModels.pet(cosmeticId: string): Model?
	local fromMesh = meshPet(cosmeticId)
	if fromMesh then
		return fromMesh
	end
	local build = PETS[cosmeticId]
	if not build then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Pet"
	local body = build(model)
	model.PrimaryPart = body
	weldAll(model, body)
	return model
end

---------------------------------------------------------------------------
-- Base decor
---------------------------------------------------------------------------

-- Cartoon gold: a darker gold outline peeking out behind the stone, white shine streaks on the
-- front (upper left, like the game's icons) and a few twinkles. `slab` is the stone, `top` its
-- rounded top (a cylinder lying front-to-back); the stone's front is its -Z side.
local GOLD_OUTLINE = Color3.fromRGB(150, 80, 5)
local function decorateGold(folder: Instance, slab: BasePart, top: BasePart?)
	local function decor(props)
		props.CanCollide = false
		props.CanQuery = false
		props.CanTouch = false
		props.CastShadow = false
		return Parts.make(folder, props)
	end
	-- Outline: slightly bigger dark-gold copies just behind the stone.
	decor({
		Name = "GoldOutline",
		Size = slab.Size + Vector3.new(0.5, 0.25, -0.1),
		CFrame = slab.CFrame * CFrame.new(0, -0.125, 0.1),
		Color = GOLD_OUTLINE,
		Material = Enum.Material.SmoothPlastic,
	})
	if top then
		decor({
			Name = "GoldOutline",
			Shape = Enum.PartType.Cylinder,
			Size = top.Size + Vector3.new(-0.1, 0.5, 0.5),
			CFrame = top.CFrame * CFrame.new(-0.1, 0, 0),
			Color = GOLD_OUTLINE,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	-- Shine: glowing white streaks on the front, following the rounded top's curve on the
	-- viewer's upper left (+X, since the front faces -Z).
	local front = -slab.Size.Z / 2 - 0.01
	for _, streak in
		{
			{ x = 0.95, y = 2.1, length = 1.2, width = 0.22, angle = 42 },
			{ x = 1.4, y = 1.3, length = 0.35, width = 0.22, angle = 10 },
		}
	do
		decor({
			Name = "GoldShine",
			Size = Vector3.new(streak.width, streak.length, 0.02),
			CFrame = slab.CFrame * CFrame.new(streak.x, streak.y, front) * CFrame.Angles(0, 0, math.rad(streak.angle)),
			Color = Color3.new(1, 1, 1),
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		})
	end
	-- Twinkles: a few star sparkles popping on and off over the stone.
	local twinkle = Instance.new("ParticleEmitter")
	twinkle.Name = "CosmeticDecor"
	twinkle.Texture = SPARKLE_TEXTURE
	twinkle.Color = ColorSequence.new(Color3.fromRGB(255, 250, 210))
	twinkle.LightEmission = 1
	twinkle.Size = sequence(0, 1, 0)
	twinkle.Lifetime = NumberRange.new(0.5, 0.8)
	twinkle.Rate = 2
	twinkle.Speed = NumberRange.new(0)
	twinkle.Rotation = NumberRange.new(0, 360)
	twinkle.Parent = slab
	-- A soft warm glow: a dim gold light just in front of the stone (much softer than the
	-- collect pad, which is drawn fullbright).
	local glowPoint = Instance.new("Attachment")
	glowPoint.Name = "CosmeticDecor"
	glowPoint.Position = Vector3.new(0, 0.3, -1.6)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 200, 80)
	glow.Brightness = 0.8
	glow.Range = 6
	glow.Shadows = false
	glow.Parent = glowPoint
	glowPoint.Parent = slab
end

-- Tombstone styles: what the base's tombstones are painted. `trimColor` (the plinth and the
-- grave's border; defaults to `color`), `reflectance` and `textColor` (the R.I.P. carving) are
-- optional; `decorate` adds extra parts into the folder it's given and
-- children named "CosmeticDecor" to the stone (CosmeticService removes both).
CosmeticModels.Tombstones = {
	tomb_gold = {
		color = Color3.fromRGB(255, 220, 60),
		trimColor = Color3.fromRGB(240, 175, 30), -- the plinth and the grave's border

		material = Enum.Material.SmoothPlastic,
		reflectance = 0.08,
		textColor = Color3.fromRGB(130, 70, 5),
		decorate = decorateGold,
	},
}

local FLOWERS = {
	-- Pale glowing lilies: three stems, each with a bright bloom.
	flowers_lily = function(model: Model, base: CFrame)
		for index, offset in { Vector3.new(-0.4, 0, 0.1), Vector3.new(0.3, 0, -0.2), Vector3.new(0.1, 0, 0.4) } do
			local height = 1 + index * 0.25
			Parts.make(model, {
				Name = "Stem",
				Size = Vector3.new(0.12, height, 0.12),
				Color = Color3.fromRGB(70, 150, 70),
				Material = Enum.Material.Grass,
				CanCollide = false,
				CanQuery = false,
				CFrame = base * CFrame.new(offset + Vector3.new(0, height / 2, 0)),
			})
			Parts.make(model, {
				Name = "Bloom",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.55,
				Color = Color3.fromRGB(170, 235, 255),
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				CFrame = base * CFrame.new(offset + Vector3.new(0, height + 0.15, 0)),
			})
		end
	end,
}

-- Builds one bunch of flowers standing on `base` (a CFrame on the ground). Nil if there's no
-- such flower.
function CosmeticModels.flowers(cosmeticId: string, base: CFrame): Model?
	local build = FLOWERS[cosmeticId]
	if not build then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Flowers"
	build(model, base)
	return model
end

return CosmeticModels
