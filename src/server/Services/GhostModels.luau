-- Detailed looks for individual ghosts, keyed by ghost id (see GhostConfig).
-- GhostService builds every ghost around a "Body" ball (used for prompts, carrying and the
-- label). A function here adds the ghost's look around that body and returns
-- how high above the body's center the name label should sit, or nil to use the simple look.
--
-- The 3D meshes are made in Studio and kept in ServerStorage.GhostMeshes, named by ghost id.
-- Each is either one MeshPart, or a Model of several MeshParts (e.g. a mesh split into pieces
-- so one piece could be removed). They can't live in git, so they're saved with the place
-- file. If one is missing, the ghost falls back to the simple look instead of breaking.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)

-- Roblox's built-in four-pointed sparkle, for star-shaped particles.
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
-- The Spectre King's rainbow stars (Mythic text is shiny red, but the stars stay rainbow).
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 110)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 80)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 255, 150)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(110, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 120, 255)),
})

local GhostModels = {}

-- Clients animate every model with this tag (see client GhostAnimation).
GhostModels.ANIMATED_TAG = "AnimatedGhost"

local function getMeshTemplate(id: string): Instance?
	local folder = ServerStorage:FindFirstChild("GhostMeshes")
	local template = folder and folder:FindFirstChild(id)
	if template and (template:IsA("MeshPart") or template:IsA("Model")) then
		return template
	end
	return nil
end

-- Makes a mesh piece purely visual and held by welds (not anchored), so it can be animated.
local function makeVisual(part: BasePart)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	-- Tells StealService to leave this part's welds alone when a ghost is carried.
	part:SetAttribute("Animated", true)
end

-- Copies a mesh template, scales it to `height` studs tall, and centres it `offsetY` above the
-- body. The main piece (renamed "Visual") is joined to the body with a Weld that the client
-- animation moves; any other pieces are welded to the main piece and move with it.
-- Returns the main piece and a list of every piece.
local function attachMesh(
	model: Model,
	body: BasePart,
	template: Instance,
	height: number,
	offsetY: number
): (MeshPart, { BasePart })
	local center = body.CFrame * CFrame.new(0, offsetY, 0)
	local mesh: MeshPart
	local pieces: { BasePart } = {}

	if template:IsA("MeshPart") then
		mesh = template:Clone()
		mesh.Size = template.Size * (height / template.Size.Y)
		mesh.CFrame = center
		table.insert(pieces, mesh)
	else
		local copy = (template :: Model):Clone()
		copy:ScaleTo(copy:GetScale() * height / copy:GetExtentsSize().Y)
		copy:PivotTo(center)
		-- The biggest piece is the main one.
		for _, part in copy:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(pieces, part)
				if not mesh or part.Size.Magnitude > mesh.Size.Magnitude then
					mesh = part :: MeshPart
				end
			end
		end
		for _, part in pieces do
			part.Parent = model
			if part ~= mesh then
				local hold = Instance.new("WeldConstraint")
				hold.Part0 = mesh
				hold.Part1 = part
				hold.Parent = part
			end
		end
		copy:Destroy()
	end

	mesh.Name = "Visual"
	for _, part in pieces do
		makeVisual(part)
	end

	local weld = Instance.new("Weld")
	weld.Name = "AnimationWeld"
	weld.Part0 = body
	weld.Part1 = mesh
	weld.C0 = body.CFrame:ToObjectSpace(mesh.CFrame)
	weld.Parent = mesh

	mesh.Parent = model
	CollectionService:AddTag(model, GhostModels.ANIMATED_TAG)
	return mesh, pieces
end

-- Turns a ghost into its mesh: scaled to `heightScale` × the ghost's size, see-through by
-- `transparency` (0.2 unless given), raised `lift` studs (for tall ghosts whose feet would
-- otherwise sink into the ground), glowing `glowColor`, and animated. Returns the label
-- height and the mesh, or nil if the mesh is missing (the ghost then keeps the simple look).
local function meshGhost(
	model: Model,
	body: BasePart,
	def,
	heightScale: number,
	glowColor: Color3,
	transparency: number?,
	lift: number?
): (number?, MeshPart?)
	local template = getMeshTemplate(def.id)
	if not template then
		return nil, nil
	end

	local height = def.size * heightScale
	local offsetY = 0.2 + (lift or 0)
	body.Transparency = 1 -- the mesh is the ghost; the body just carries prompts and the label
	local mesh, pieces = attachMesh(model, body, template, height, offsetY)
	for _, piece in pieces do
		piece.Transparency = transparency or 0.2
	end

	local light = body:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = glowColor
		light.Brightness = 2
		light.Range = def.size * 3.5
	end
	return height / 2 + offsetY + 1.5, mesh
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

-- Phantom Knight: a chibi suit of silver armour haunted by teal ghost-light, with a ghost-flame
-- plume, a teal cape and a raised sword. Fully solid.
function GhostModels.phantom_knight(model: Model, body: BasePart, def): number?
	local ghostTeal = Color3.fromRGB(110, 255, 215)
	local labelHeight, mesh = meshGhost(model, body, def, 1.2, ghostTeal, 0)
	if not mesh then
		return nil
	end
	-- Armour shouldn't stretch like a flame; it just floats, bobs and sways.
	mesh:SetAttribute("Flicker", false)

	-- Faint teal ghost-wisps rising off the armour.
	local wisps = Instance.new("ParticleEmitter")
	wisps.Color = ColorSequence.new(Color3.fromRGB(200, 255, 240), ghostTeal)
	wisps.LightEmission = 1
	wisps.Size = NumberSequence.new(0.3, 0)
	wisps.Transparency = NumberSequence.new(0.3, 1)
	wisps.Lifetime = NumberRange.new(0.8, 1.5)
	wisps.Rate = 5
	wisps.Speed = NumberRange.new(0.4, 1)
	wisps.SpreadAngle = Vector2.new(20, 20)
	wisps.EmissionDirection = Enum.NormalId.Top
	wisps.Parent = mesh

	return labelHeight
end

-- Wraith: a dark hooded spirit with horn-like hood points, a shadowed face with glowing eyes,
-- and a tattered cloak. A red glow tints its eyes and surroundings; dark smoke trails off it.
function GhostModels.wraith(model: Model, body: BasePart, def): number?
	local labelHeight, mesh = meshGhost(model, body, def, 1.15, Color3.fromRGB(255, 40, 40), 0.1)
	if not mesh then
		return nil
	end
	-- A cloak shouldn't stretch like a flame; it just floats, bobs and sways.
	mesh:SetAttribute("Flicker", false)

	-- Keep the red glow dim and close, so the Wraith itself still looks dark.
	local light = body:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = Color3.fromRGB(200, 20, 20)
		light.Brightness = 0.8
		light.Range = def.size * 1.6
	end

	-- Dark smoke drifting down off its tattered hem.
	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(Color3.fromRGB(35, 30, 40))
	smoke.LightEmission = 0
	smoke.Size = NumberSequence.new(0.6, 1.6)
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Lifetime = NumberRange.new(1.2, 2)
	smoke.Rate = 8
	smoke.Speed = NumberRange.new(0.2, 0.5)
	smoke.SpreadAngle = Vector2.new(30, 30)
	smoke.EmissionDirection = Enum.NormalId.Bottom
	smoke.Parent = mesh

	return labelHeight
end

-- Spectre King: the rarest ghost. A chunky blue spectral king with a ghostly beard, a jewelled
-- gold crown, a crimson tunic, a fur-trimmed royal cape, a sceptre and golden boots.
-- Much bigger than the other ghosts, fully solid, glowing gold, and it waddles as if
-- walking (the client's walk animation) instead of the usual float. Gold dust, twinkling stars
-- and a few rainbow stars give it a mythic sparkle without hiding the model.
function GhostModels.spectre_king(model: Model, body: BasePart, def): number?
	local heightScale = 1.5
	-- Ghosts float with their centre 4 studs up; lift the King so his boots stay above the ground.
	local lift = def.size * heightScale / 2 - 2.6
	local gold = Color3.fromRGB(255, 215, 90)
	local labelHeight, mesh = meshGhost(model, body, def, heightScale, gold, 0, lift)
	if not mesh then
		return nil
	end
	mesh:SetAttribute("Flicker", false)
	mesh:SetAttribute("Walk", true)

	local light = body:FindFirstChildOfClass("PointLight")
	if light then
		light.Brightness = 2.5
		light.Range = def.size * 3
	end

	-- He's much bigger than the other ghosts, so his particles are sized up to match.
	-- Royal gold dust drifting off him.
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 245, 200), gold)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.5, 0)
	sparkles.Transparency = NumberSequence.new(0.1, 1)
	sparkles.Lifetime = NumberRange.new(1, 1.8)
	sparkles.Rate = 12
	sparkles.Speed = NumberRange.new(0.15, 0.4)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Acceleration = Vector3.new(0, 0.25, 0)
	sparkles.Parent = mesh

	-- Gold-and-white stars that twinkle in and out on his surface (they grow, then shrink away).
	local twinkles = Instance.new("ParticleEmitter")
	twinkles.Texture = SPARKLE_TEXTURE
	twinkles.Color = ColorSequence.new(Color3.new(1, 1, 1), gold)
	twinkles.LightEmission = 1
	twinkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 1.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	twinkles.Lifetime = NumberRange.new(1, 1.6)
	twinkles.Rate = 5
	twinkles.Speed = NumberRange.new(0)
	twinkles.Rotation = NumberRange.new(0, 360)
	twinkles.RotSpeed = NumberRange.new(-30, 30)
	twinkles.Shape = Enum.ParticleEmitterShape.Box
	twinkles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface -- inside his solid body they'd be hidden
	twinkles.Parent = mesh

	-- A few slow, larger stars that drift upward, shifting through the rainbow.
	local rainbowStars = Instance.new("ParticleEmitter")
	rainbowStars.Texture = SPARKLE_TEXTURE
	rainbowStars.Color = RAINBOW
	rainbowStars.LightEmission = 1
	rainbowStars.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 1.8),
		NumberSequenceKeypoint.new(1, 0),
	})
	rainbowStars.Transparency = NumberSequence.new(0.1, 0.6)
	rainbowStars.Lifetime = NumberRange.new(1.4, 2.2)
	rainbowStars.Rate = 2.5
	rainbowStars.Speed = NumberRange.new(0.3, 0.6)
	rainbowStars.SpreadAngle = Vector2.new(60, 60)
	rainbowStars.EmissionDirection = Enum.NormalId.Top
	rainbowStars.Rotation = NumberRange.new(0, 360)
	rainbowStars.RotSpeed = NumberRange.new(-20, 20)
	rainbowStars.Parent = mesh

	return labelHeight
end

-- Grim Reaper (the Secret ghost): a menacing cartoon reaper in an all-black hood, a grinning
-- skull with glowing eyes, skeletal hands, a scythe and a lantern on a strap, its robe trailing
-- into wispy tendrils. Solid (not see-through), about as tall as the King, with a cold pale
-- glow and lost souls drifting up around him (the Secret rarity aura adds its dark smoke and
-- black and white stars on top).
function GhostModels.secret_1(model: Model, body: BasePart, def): number?
	local heightScale = 1.28
	-- Like the King: lift him so his ragged hem floats just above the ground.
	local lift = def.size * heightScale / 2 - 2.6
	local soulColor = Color3.fromRGB(170, 245, 255)
	local labelHeight, mesh = meshGhost(model, body, def, heightScale, soulColor, 0, lift)
	if not mesh then
		return nil
	end
	-- A robe shouldn't stretch like a flame; it floats, bobs and sways.
	mesh:SetAttribute("Flicker", false)

	local light = body:FindFirstChildOfClass("PointLight")
	if light then
		light.Brightness = 1.5
		light.Range = def.size * 2.5
	end

	-- Lost souls: small pale glowing wisps that slowly rise off him and fade.
	local souls = Instance.new("ParticleEmitter")
	souls.Color = ColorSequence.new(Color3.new(1, 1, 1), soulColor)
	souls.LightEmission = 1
	souls.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.25, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	souls.Transparency = NumberSequence.new(0.2, 0.9)
	souls.Lifetime = NumberRange.new(2, 3)
	souls.Rate = 4
	souls.Speed = NumberRange.new(0.4, 0.8)
	souls.SpreadAngle = Vector2.new(25, 25)
	souls.EmissionDirection = Enum.NormalId.Top
	souls.Acceleration = Vector3.new(0, 0.3, 0)
	souls.Shape = Enum.ParticleEmitterShape.Box
	souls.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	souls.Parent = mesh

	return labelHeight
end

-- Extra particles every ghost of the top rarities gets, on top of its own look (so a new Divine
-- or Secret ghost has them without any extra work). Divine: gold and white sparkles rising like
-- a blessing. Secret: dark smoke with black and white stars flickering in it.
function GhostModels.addRarityAura(body: BasePart, rarity: string, size: number)
	if rarity == "Divine" then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "DivineAura"
		sparkles.Texture = SPARKLE_TEXTURE
		sparkles.Color = Theme.RarityGradients.Divine
		sparkles.LightEmission = 1
		sparkles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, size * 0.25),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparkles.Lifetime = NumberRange.new(1.2, 2)
		sparkles.Rate = 10
		sparkles.Speed = NumberRange.new(0.8, 1.6)
		sparkles.SpreadAngle = Vector2.new(40, 40)
		sparkles.EmissionDirection = Enum.NormalId.Top
		sparkles.Rotation = NumberRange.new(0, 360)
		sparkles.RotSpeed = NumberRange.new(-40, 40)
		sparkles.Parent = body
	elseif rarity == "Secret" then
		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "SecretSmoke"
		smoke.Color = ColorSequence.new(Color3.fromRGB(15, 12, 20))
		smoke.LightEmission = 0
		smoke.Size = NumberSequence.new(size * 0.2, size * 0.45)
		smoke.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		})
		smoke.Lifetime = NumberRange.new(1.4, 2.2)
		smoke.Rate = 10
		smoke.Speed = NumberRange.new(0.4, 0.9)
		smoke.SpreadAngle = Vector2.new(180, 180)
		smoke.Parent = body

		local stars = Instance.new("ParticleEmitter")
		stars.Name = "SecretStars"
		stars.Texture = SPARKLE_TEXTURE
		stars.Color = Theme.RarityGradients.Secret
		stars.LightEmission = 1
		stars.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, size * 0.22),
			NumberSequenceKeypoint.new(1, 0),
		})
		stars.Lifetime = NumberRange.new(0.6, 1.1)
		stars.Rate = 6
		stars.Speed = NumberRange.new(0)
		stars.Rotation = NumberRange.new(0, 360)
		stars.Shape = Enum.ParticleEmitterShape.Sphere
		stars.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		stars.Parent = body
	end
end

-- Sparkles in a mutation's colours around any ghost that has one (MutationConfig), so it stands
-- out on the walkway. Rarer mutations sparkle more.
function GhostModels.addMutationAura(body: BasePart, mutation, size: number)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "MutationAura"
	sparkles.Texture = SPARKLE_TEXTURE
	sparkles.Color = mutation.gradient
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, size * 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Lifetime = NumberRange.new(0.7, 1.2)
	sparkles.Rate = 2 + mutation.multiplier * 3
	sparkles.Speed = NumberRange.new(0.3, 0.8)
	sparkles.Rotation = NumberRange.new(0, 360)
	sparkles.RotSpeed = NumberRange.new(-60, 60)
	sparkles.Shape = Enum.ParticleEmitterShape.Sphere
	sparkles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	sparkles.Parent = body
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
