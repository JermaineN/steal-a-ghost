-- How each cosmetic (CosmeticConfig) looks, all built in code. CosmeticService decides when to
-- put them on and take them off.
--   aura       particle emitters on attachments in the character's root part
--   pet        a small unanchored model; CosmeticService makes it follow its owner
--   tombstone  a colour and material painted over the base's tombstones
--   flowers    a little model placed beside each grave
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

-- Builds a pet's model (not parented yet), its PrimaryPart the body. Nil if there's no such pet.
function CosmeticModels.pet(cosmeticId: string): Model?
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

-- Tombstone styles: what the base's tombstones are painted.
CosmeticModels.Tombstones = {
	tomb_gold = { color = Color3.fromRGB(255, 225, 110), material = Enum.Material.Foil },
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
