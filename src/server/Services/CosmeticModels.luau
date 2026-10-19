-- How each cosmetic (CosmeticConfig) looks, built in code (except pet meshes made in Studio, see
-- MESH_PETS). CosmeticService decides when to put them on and take them off.
--   aura       particle emitters (plus any light, trail and sound) on attachments in the
--              character's root part
--   pet        a small unanchored model; CosmeticService makes it follow its owner
--   tombstone  a colour and material painted over the base's tombstones
--   flowers    a little model placed beside each grave
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Parts = require(script.Parent.Parent.Util.Parts)
local GhostModels = require(script.Parent.GhostModels)

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

-- Each aura has a list of emitters; each emitter's settings are copied onto a ParticleEmitter,
-- and it's placed at every point in `points` (relative to the root part's centre). Emitters on
-- an attachment emit from that point, so a ring of points makes a ring of particles.
-- Optional extras: `light` (a PointLight), `trail` (a Trail between two points, left behind as
-- you move) and `sound` (a looping sound, a GameConfig sound config). Everything sits on
-- attachments named "CosmeticAura", so removeAura takes it all off.
local function ring(radius: number, height: number, count: number): { Vector3 }
	local points = {}
	for step = 0, count - 1 do
		local angle = step / count * math.pi * 2
		table.insert(points, Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius))
	end
	return points
end
local FEET_RING = ring(1.4, -2.6, 6)

local AURAS = {
	-- Purple flames licking up from around the feet.
	aura_purple = {
		emitters = {
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
	},
	-- A Robux aura, so it's loud: gold glitter bursting out all around, big star flashes
	-- twinkling on and off, gold motes rising from the feet, a warm glow, a gold trail behind
	-- you and a soft chiming loop.
	aura_golden = {
		emitters = {
			-- Glitter bursting out of the body.
			{
				points = { Vector3.new(0, 0.5, 0), Vector3.new(0, -1.5, 0) },
				Texture = SPARKLE_TEXTURE,
				Color = ColorSequence.new(Color3.fromRGB(255, 240, 140), Color3.fromRGB(255, 170, 30)),
				LightEmission = 1,
				Size = sequence(1.3, 1, 0),
				Transparency = sequence(0, 0.1, 1),
				Lifetime = NumberRange.new(0.8, 1.4),
				Rate = 60,
				Speed = NumberRange.new(2, 4),
				Drag = 2,
				RotSpeed = NumberRange.new(-180, 180),
				Rotation = NumberRange.new(0, 360),
				SpreadAngle = Vector2.new(180, 180),
			},
			-- Big star flashes popping on and off around the body.
			{
				points = ring(1.7, 0.3, 4),
				Texture = SPARKLE_TEXTURE,
				Color = ColorSequence.new(Color3.fromRGB(255, 255, 220)),
				LightEmission = 1,
				LightInfluence = 0,
				Size = sequence(0, 3.5, 0),
				Transparency = sequence(0, 0, 0.6),
				Lifetime = NumberRange.new(0.25, 0.4),
				Rate = 5,
				Speed = NumberRange.new(1.5, 3),
				SpreadAngle = Vector2.new(180, 180),
				Rotation = NumberRange.new(0, 90),
			},
			-- Gold motes floating up from a ring at the feet.
			{
				points = FEET_RING,
				Texture = SPARKLE_TEXTURE,
				Color = ColorSequence.new(Color3.fromRGB(255, 215, 60), Color3.fromRGB(255, 250, 200)),
				LightEmission = 1,
				Size = sequence(0.8, 0.5, 0),
				Transparency = sequence(0.1, 0.2, 1),
				Lifetime = NumberRange.new(1.2, 1.8),
				Rate = 8,
				Speed = NumberRange.new(2.5, 4),
				SpreadAngle = Vector2.new(8, 8),
				EmissionDirection = Enum.NormalId.Top,
			},
		},
		light = { point = Vector3.zero, Color = Color3.fromRGB(255, 200, 80), Brightness = 3, Range = 14 },
		trail = {
			from = Vector3.new(0, 1, 0),
			to = Vector3.new(0, -2.2, 0),
			Color = ColorSequence.new(Color3.fromRGB(255, 235, 130), Color3.fromRGB(255, 160, 20)),
			Transparency = sequence(0.35, 0.7, 1),
			LightEmission = 1,
			Lifetime = 0.45,
			FaceCamera = true,
		},
		sound = GameConfig.GoldenAuraSound,
	},
}

local function auraAttachment(root: BasePart, position: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = "CosmeticAura"
	attachment.Position = position
	attachment.Parent = root
	return attachment
end

-- Copies every setting except the ones listed in `skip` onto an instance.
local function apply(instance: Instance, settings: { [string]: any }, skip: { [string]: boolean })
	for key, value in settings do
		if not skip[key] then
			(instance :: any)[key] = value
		end
	end
end

-- Puts an aura on a character's root part (attachments only work directly on a part). Take it
-- off with CosmeticModels.removeAura.
function CosmeticModels.aura(cosmeticId: string, root: BasePart)
	local aura = AURAS[cosmeticId]
	if not aura then
		return
	end
	for _, settings in aura.emitters do
		for _, point in settings.points do
			local emitter = Instance.new("ParticleEmitter")
			apply(emitter, settings, { points = true })
			emitter.Parent = auraAttachment(root, point)
		end
	end
	if aura.light then
		local light = Instance.new("PointLight")
		apply(light, aura.light, { point = true })
		light.Parent = auraAttachment(root, aura.light.point)
	end
	if aura.trail then
		local trail = Instance.new("Trail")
		apply(trail, aura.trail, { from = true, to = true })
		trail.Attachment0 = auraAttachment(root, aura.trail.from)
		trail.Attachment1 = auraAttachment(root, aura.trail.to)
		trail.Parent = trail.Attachment0
	end
	if aura.sound then
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://" .. aura.sound.soundId
		sound.Volume = aura.sound.volume
		sound.Looped = true
		-- Heard only close by.
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 6
		sound.RollOffMaxDistance = aura.sound.maxDistance or 40
		sound.Parent = auraAttachment(root, Vector3.zero)
		sound:Play()
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

-- The Ghost Buddy: a copy of one of the ghosts, at GameConfig.GhostPetScale of its size. It's
-- copied from the clean previews GhostService makes for the Index (no name tag, prompts or
-- light), and tagged so every device plays the ghosts' usual float animation on it.
CosmeticModels.GHOST_PET = "pet_ghost"

local function ghostPet(ghostId: string?): Model?
	local previews = ReplicatedStorage:FindFirstChild("GhostPreviews")
	local template = previews
		and (previews:FindFirstChild(ghostId or "") or previews:FindFirstChild(GameConfig.GhostPetDefault))
	if not (template and template:IsA("Model") and template.PrimaryPart) then
		return nil
	end
	local model = template:Clone()
	model.Name = "Pet"
	local body = model.PrimaryPart :: BasePart
	model:ScaleTo(model:GetScale() * GameConfig.GhostPetScale)
	model:PivotTo(CFrame.new())
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			-- Pieces that aren't joined to anything yet (the simple look's eyes) are welded on.
			local joined = part:FindFirstChildWhichIsA("JointInstance") or part:FindFirstChildOfClass("WeldConstraint")
			if part ~= body and not joined then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = body
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	-- Ghosts the player owns float instead of waddling (the Spectre King), so give it an owner.
	model:SetAttribute("OwnerUserId", 0)
	-- Its owner's device slows it down near its spot so it lags behind (client PetAnimation).
	model:SetAttribute("FollowSpeed", GameConfig.GhostPetFollowSpeed)
	CollectionService:AddTag(model, GhostModels.ANIMATED_TAG)
	return model
end

-- Builds a pet's model (not parented yet), its PrimaryPart the body. Nil if there's no such pet.
-- `ghostId` is the ghost a Ghost Buddy looks like.
function CosmeticModels.pet(cosmeticId: string, ghostId: string?): Model?
	if cosmeticId == CosmeticModels.GHOST_PET then
		return ghostPet(ghostId)
	end
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
