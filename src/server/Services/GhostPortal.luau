-- The ghost portal: an ornate stone archway with a glowing purple portal, a gargoyle keystone,
-- carved pillars, purple flame lanterns and twisted roots. Walkway ghosts float out of one
-- portal and into the other. The front (roots, carvings, lanterns) faces the map; the back
-- is the same stonework without the extra detail.
local Billboard = require(script.Parent.Parent.Util.Billboard)
local Parts = require(script.Parent.Parent.Util.Parts)

local GhostPortal = {}

local STONE = Color3.fromRGB(52, 46, 62)
local STONE_LIGHT = Color3.fromRGB(78, 70, 92)
local STONE_DARK = Color3.fromRGB(34, 30, 42)
local ROOT = Color3.fromRGB(62, 40, 78)
local PURPLE = Color3.fromRGB(150, 70, 255)
local PORTAL_PURPLE = Color3.fromRGB(125, 52, 218) -- the portal surface and its glowing edge
local PURPLE_LIGHT = Color3.fromRGB(225, 170, 255)
local LABEL_ORANGE = Color3.fromRGB(255, 140, 30)

-- The opening is wide and tall enough for the biggest ghost (about 5 studs) to float through.
local OPENING_RADIUS = 5.5 -- half the opening's width, and the radius of its rounded top
local OPENING_SPRING = 8 -- height where the straight sides turn into the rounded top
local FLOOR = 1.3 -- top of the stepped platform
local ARCH_THICKNESS = 1.8
local ARCH_DEPTH = 2.6
local PILLAR_X = 10.5 -- distance from the center to each side pillar

local makePart = Parts.make

-- Glowing parts that ghosts and players pass straight through.
local function makeGlow(parent: Instance, props: { [string]: any }): Part
	props.Material = Enum.Material.Neon
	props.CanCollide = false
	props.CanQuery = false
	props.CastShadow = false
	return makePart(parent, props)
end

-- Blocks laid around the rounded top of the arch. `radius` is measured to the middle of the
-- blocks; `make` is makePart or makeGlow, and `props` sets name/color/material.
local function makeArc(
	parent: Instance,
	frame: CFrame,
	radius: number,
	thickness: number,
	depth: number,
	segments: number,
	make: (Instance, { [string]: any }) -> Part,
	props: { [string]: any }
)
	-- Long enough that neighbouring blocks meet on the outside edge, with no gaps.
	local length = 2 * (radius + thickness / 2) * math.tan(math.pi / segments / 2) + 0.05
	for index = 1, segments do
		local angle = math.pi * (index - 0.5) / segments
		local position = Vector3.new(radius * math.cos(angle), OPENING_SPRING + radius * math.sin(angle), 0)
		local blockProps = table.clone(props)
		blockProps.Size = Vector3.new(length, thickness, depth)
		blockProps.CFrame = frame * CFrame.new(position) * CFrame.Angles(0, 0, angle + math.pi / 2)
		make(parent, blockProps)
	end
end

-- The straight sides below the rounded top, at distance `x` from the center.
local function makeSides(
	parent: Instance,
	frame: CFrame,
	x: number,
	thickness: number,
	depth: number,
	make: (Instance, { [string]: any }) -> Part,
	props: { [string]: any }
)
	local height = OPENING_SPRING - FLOOR
	for _, side in { -1, 1 } do
		local sideProps = table.clone(props)
		sideProps.Size = Vector3.new(thickness, height, depth)
		sideProps.CFrame = frame * CFrame.new(side * x, FLOOR + height / 2, 0)
		make(parent, sideProps)
	end
end

-- Points from `from` to `to` that snake side to side (by up to `wobble` on each axis, in a
-- wave plus a little randomness), so the line looks twisted instead of straight.
local function windingPath(from: Vector3, to: Vector3, steps: number, wobble: Vector3, random: Random): { Vector3 }
	local points = {}
	local phase = random:NextNumber(0, math.pi * 2)
	for step = 0, steps do
		local t = step / steps
		local point = from:Lerp(to, t)
		if step > 0 and step < steps then
			local wave = math.sin(t * math.pi * 3 + phase)
			point += Vector3.new(
				(wave * 0.7 + random:NextNumber(-0.3, 0.3)) * wobble.X,
				random:NextNumber(-1, 1) * wobble.Y,
				(math.cos(t * math.pi * 3 + phase) * 0.5 + random:NextNumber(-0.5, 0.5)) * wobble.Z
			)
		end
		table.insert(points, point)
	end
	return points
end

-- A root following `points` (in the portal's frame): thick at the start, thin at the end.
local function makeRoot(parent: Instance, frame: CFrame, points: { Vector3 }, startWidth: number)
	for index = 1, #points - 1 do
		local a = frame * points[index]
		local b = frame * points[index + 1]
		local width = startWidth * (1 - 0.7 * (index - 1) / (#points - 1))
		-- A Cylinder's length runs along its X axis; turn it to point from a to b.
		makePart(parent, {
			Name = "PortalRoot",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new((b - a).Magnitude + width * 0.3, width, width),
			CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0),
			Color = ROOT,
			Material = Enum.Material.Wood,
		})
		-- A knot at each bend hides the joins.
		makePart(parent, {
			Name = "PortalRootKnot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * width * 1.1,
			Position = b,
			Color = ROOT,
			Material = Enum.Material.Wood,
		})
	end
end

-- A stepped stone platform, wider and lower toward the front.
local function makePlatform(parent: Instance, frame: CFrame)
	for _, step in
		{
			{ size = Vector3.new(28, 0.4, 11), y = 0.5, z = 0, color = STONE_DARK },
			{ size = Vector3.new(24, 0.35, 8), y = 0.875, z = 0.6, color = STONE },
			{ size = Vector3.new(18, 0.25, 5.5), y = 1.175, z = 0.6, color = STONE_LIGHT },
		}
	do
		makePart(parent, {
			Name = "PortalStep",
			Size = step.size,
			CFrame = frame * CFrame.new(0, step.y, step.z),
			Color = step.color,
			Material = Enum.Material.Slate,
		})
	end
end

-- A tall carved pillar with a glowing rune, stone bands, a capital and an urn finial with a spike.
local function makePillar(parent: Instance, frame: CFrame, x: number)
	local function block(name: string, size: Vector3, y: number, z: number, color: Color3, material: Enum.Material)
		return makePart(parent, {
			Name = name,
			Size = size,
			CFrame = frame * CFrame.new(x, y, z),
			Color = color,
			Material = material,
		})
	end
	block("PillarPlinth", Vector3.new(4, 1.2, 4), 1.3, 0, STONE_LIGHT, Enum.Material.Slate)
	block("PillarShaft", Vector3.new(3, 11.5, 3), 7.65, 0, STONE, Enum.Material.Slate)
	for _, y in { 4.2, 11 } do
		block("PillarBand", Vector3.new(3.3, 0.35, 3.3), y, 0, STONE_LIGHT, Enum.Material.Concrete)
	end
	-- Carved panel with a glowing rune, on the front only.
	block("PillarPanel", Vector3.new(2.1, 6, 0.15), 7.6, -1.55, STONE_DARK, Enum.Material.Slate)
	makeGlow(parent, {
		Name = "PillarRune",
		Size = Vector3.new(0.9, 0.9, 0.15),
		CFrame = frame * CFrame.new(x, 8.4, -1.65) * CFrame.Angles(0, 0, math.pi / 4),
		Color = PURPLE,
	})
	makeGlow(parent, {
		Name = "PillarRune",
		Size = Vector3.new(0.2, 2.6, 0.12),
		CFrame = frame * CFrame.new(x, 6.2, -1.65),
		Color = PURPLE,
		Transparency = 0.3,
	})
	block("PillarCapital", Vector3.new(3.8, 0.6, 3.8), 13.7, 0, STONE_LIGHT, Enum.Material.Concrete)
	block("PillarCornice", Vector3.new(4.4, 0.5, 4.4), 14.25, 0, STONE, Enum.Material.Slate)
	block("PillarUrn", Vector3.new(2.2, 0.8, 2.2), 14.9, 0, STONE_LIGHT, Enum.Material.Slate)
	makePart(parent, {
		Name = "PillarUrn",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2.2,
		CFrame = frame * CFrame.new(x, 16.1, 0),
		Color = STONE,
		Material = Enum.Material.Slate,
	})
	makePart(parent, {
		Name = "PillarSpike",
		Size = Vector3.new(0.45, 1.8, 0.45),
		CFrame = frame * CFrame.new(x, 17.9, 0) * CFrame.Angles(0, math.pi / 4, 0),
		Color = STONE_LIGHT,
		Material = Enum.Material.Slate,
	})
end

-- The keystone at the top of the arch, carved as a gargoyle with glowing eyes and horns.
local function makeKeystone(parent: Instance, frame: CFrame): BasePart
	local top = OPENING_SPRING + OPENING_RADIUS + ARCH_THICKNESS / 2
	local depth = ARCH_DEPTH + 0.8
	local front = -depth / 2
	local keystone = makePart(parent, {
		Name = "Keystone",
		Size = Vector3.new(2.4, 3, depth),
		CFrame = frame * CFrame.new(0, top + 0.2, 0),
		Color = STONE_LIGHT,
		Material = Enum.Material.Slate,
	})
	-- Face on the front: a heavy brow, glowing eyes, and two fangs.
	makePart(parent, {
		Name = "GargoyleBrow",
		Size = Vector3.new(2, 0.4, 0.4),
		CFrame = frame * CFrame.new(0, top + 1, front - 0.15) * CFrame.Angles(math.rad(-15), 0, 0),
		Color = STONE_DARK,
		Material = Enum.Material.Slate,
	})
	for _, side in { -1, 1 } do
		makeGlow(parent, {
			Name = "GargoyleEye",
			Size = Vector3.new(0.45, 0.3, 0.2),
			CFrame = frame * CFrame.new(side * 0.5, top + 0.6, front - 0.05),
			Color = PURPLE_LIGHT,
		})
		makePart(parent, {
			Name = "GargoyleFang",
			Size = Vector3.new(0.22, 0.5, 0.2),
			CFrame = frame * CFrame.new(side * 0.35, top - 0.45, front - 0.05),
			Color = Color3.fromRGB(150, 145, 160),
			Material = Enum.Material.Slate,
		})
		makePart(parent, {
			Name = "GargoyleHorn",
			Size = Vector3.new(0.4, 1.6, 0.4),
			CFrame = frame
				* CFrame.new(side * 0.95, top + 2.2, front + 0.6)
				* CFrame.Angles(0, 0, side * math.rad(-25)),
			Color = STONE_DARK,
			Material = Enum.Material.Slate,
		})
	end
	-- A small crest on top.
	makePart(parent, {
		Name = "KeystoneCrest",
		Size = Vector3.new(1, 1, 1),
		CFrame = frame * CFrame.new(0, top + 2.3, 0) * CFrame.Angles(0, 0, math.pi / 4),
		Color = STONE,
		Material = Enum.Material.Slate,
	})
	makePart(parent, {
		Name = "KeystoneCrest",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.8,
		CFrame = frame * CFrame.new(0, top + 3.2, 0),
		Color = STONE_LIGHT,
		Material = Enum.Material.Slate,
	})
	return keystone
end

-- The glowing portal surface (shaped exactly like the opening), a bright core, and swirling sparks.
local function makePortalSurface(parent: Instance, frame: CFrame)
	-- Thin horizontal strips that follow the opening's shape. They don't overlap,
	-- so the see-through glow is even everywhere.
	local stripHeight = 0.45
	local top = OPENING_SPRING + OPENING_RADIUS
	local y = FLOOR
	while y < top do
		local middle = y + stripHeight / 2
		local width = 2 * OPENING_RADIUS
		if middle > OPENING_SPRING then
			local rise = middle - OPENING_SPRING
			width = 2 * math.sqrt(math.max(0, OPENING_RADIUS ^ 2 - rise ^ 2))
		end
		if width > 0.3 then
			makeGlow(parent, {
				Name = "PortalSurface",
				Size = Vector3.new(width, stripHeight, 0.3),
				CFrame = frame * CFrame.new(0, middle, 0),
				Color = PORTAL_PURPLE,
				Transparency = 0.3,
			})
		end
		y += stripHeight
	end

	-- Sparks drifting out of the portal, and low purple mist on the steps.
	local emitterPart = makePart(parent, {
		Name = "PortalSparks",
		Size = Vector3.new(OPENING_RADIUS * 2 - 1, top - FLOOR - 1, 0.4),
		CFrame = frame * CFrame.new(0, (FLOOR + top) / 2, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	-- The portal lights up its surroundings.
	local light = Instance.new("PointLight")
	light.Color = PURPLE
	light.Range = 35
	light.Brightness = 3
	light.Shadows = false
	light.Parent = emitterPart
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(PURPLE, PURPLE_LIGHT)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(1.2, 0)
	sparks.Transparency = NumberSequence.new(0.2, 1)
	sparks.Lifetime = NumberRange.new(1.5, 3)
	sparks.Rate = 30
	sparks.Speed = NumberRange.new(0.5, 2)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.RotSpeed = NumberRange.new(-90, 90)
	sparks.Parent = emitterPart

	local mistPart = makePart(parent, {
		Name = "PortalMist",
		Size = Vector3.new(16, 0.2, 6),
		CFrame = frame * CFrame.new(0, FLOOR + 0.2, -2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local mist = Instance.new("ParticleEmitter")
	mist.Color = ColorSequence.new(PURPLE)
	mist.LightEmission = 0.5
	mist.Size = NumberSequence.new(3, 6)
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	mist.Lifetime = NumberRange.new(3, 5)
	mist.Rate = 6
	mist.Speed = NumberRange.new(0.3, 0.8)
	mist.SpreadAngle = Vector2.new(60, 60)
	mist.Acceleration = Vector3.new(0, 0.2, 0)
	mist.Parent = mistPart
end

-- Purple flame lanterns on the front of the arch's sides.
local function makeLanterns(parent: Instance, frame: CFrame)
	local x = OPENING_RADIUS + ARCH_THICKNESS / 2
	local z = -ARCH_DEPTH / 2 - 0.4
	for _, side in { -1, 1 } do
		makePart(parent, {
			Name = "LanternBracket",
			Size = Vector3.new(0.6, 0.35, 0.9),
			CFrame = frame * CFrame.new(side * x, 6.4, z + 0.2),
			Color = STONE_DARK,
			Material = Enum.Material.Metal,
		})
		local flame = makeGlow(parent, {
			Name = "LanternFlame",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.7,
			CFrame = frame * CFrame.new(side * x, 6.9, z),
			Color = PURPLE_LIGHT,
		})
		local fire = Instance.new("Fire")
		fire.Color = PURPLE
		fire.SecondaryColor = PURPLE_LIGHT
		fire.Size = 1.6
		fire.Heat = 4
		fire.Parent = flame
		local light = Instance.new("PointLight")
		light.Color = PURPLE
		light.Range = 12
		light.Brightness = 2
		light.Shadows = false
		light.Parent = flame
	end
end

-- Twisted roots climbing the pillars, crawling over the arch and spreading across the steps.
local function makeRoots(parent: Instance, frame: CFrame, random: Random)
	local archFront = -ARCH_DEPTH / 2 - 0.3
	local archOuter = OPENING_RADIUS + ARCH_THICKNESS + 0.1
	for _, side in { -1, 1 } do
		-- Up the front of the pillars, crossing diagonally.
		makeRoot(
			parent,
			frame,
			windingPath(
				Vector3.new(side * (PILLAR_X + 2.1), 0.7, -2.4),
				Vector3.new(side * (PILLAR_X - 1.3), 12.5, -1.8),
				12,
				Vector3.new(1.1, 0.2, 0.5),
				random
			),
			0.9
		)
		makeRoot(
			parent,
			frame,
			windingPath(
				Vector3.new(side * (PILLAR_X - 1.9), 0.8, -2.8),
				Vector3.new(side * (PILLAR_X + 1.1), 9, -1.8),
				10,
				Vector3.new(1.1, 0.2, 0.5),
				random
			),
			0.7
		)

		-- Up the side of the arch, then over the top toward the keystone.
		local archPoints = {
			Vector3.new(side * archOuter, FLOOR, archFront - 0.3),
			Vector3.new(side * (archOuter + 0.2), (FLOOR + OPENING_SPRING) / 2, archFront),
			Vector3.new(side * archOuter, OPENING_SPRING, archFront),
		}
		local stopAngle = random:NextNumber(0.3, 0.42) * math.pi
		for step = 1, 5 do
			local angle = stopAngle * step / 5
			local radius = archOuter + random:NextNumber(-0.25, 0.25)
			table.insert(
				archPoints,
				Vector3.new(
					side * radius * math.cos(angle),
					OPENING_SPRING + radius * math.sin(angle),
					archFront + random:NextNumber(-0.15, 0.15)
				)
			)
		end
		makeRoot(parent, frame, archPoints, 0.75)

		-- Across the steps and out onto the ground.
		for _, reach in { Vector3.new(13, 0.6, -6), Vector3.new(9, 0.6, -6.8), Vector3.new(15, 0.6, 1.5) } do
			makeRoot(
				parent,
				frame,
				windingPath(
					Vector3.new(side * (OPENING_RADIUS + 1), FLOOR, -1.6),
					Vector3.new(side * reach.X, reach.Y, reach.Z),
					5,
					Vector3.new(0.6, 0.1, 0.6),
					random
				),
				0.8
			)
		end

		-- Thin tendrils hanging from the top of the arch.
		makeRoot(
			parent,
			frame,
			windingPath(
				Vector3.new(side * 2.4, OPENING_SPRING + archOuter - 0.4, archFront - 0.1),
				Vector3.new(side * 3.6, OPENING_SPRING + 4.4, archFront - 0.3),
				3,
				Vector3.new(0.2, 0.1, 0.1),
				random
			),
			0.35
		)
	end
end

-- Builds a portal standing on the ground at `position`, with its front facing `facing`.
function GhostPortal.build(parent: Instance, position: Vector3, facing: Vector3, label: string?)
	local model = Instance.new("Model")
	model.Name = "GhostPortal"
	-- In this frame, X runs across the walkway, Y is up, and -Z is the front.
	local frame = CFrame.lookAt(position, position + facing)
	-- Different seed per portal, so the two don't look identical.
	local random = Random.new(if facing.X > 0 then 7 else 8)

	makePlatform(model, frame)

	-- The arch: straight sides with a rounded top, an outer molding, and a glowing inner edge.
	local stone = { Name = "Arch", Color = STONE, Material = Enum.Material.Slate }
	makeSides(model, frame, OPENING_RADIUS + ARCH_THICKNESS / 2, ARCH_THICKNESS, ARCH_DEPTH, makePart, stone)
	makeArc(model, frame, OPENING_RADIUS + ARCH_THICKNESS / 2, ARCH_THICKNESS, ARCH_DEPTH, 12, makePart, stone)
	local molding = { Name = "ArchMolding", Color = STONE_LIGHT, Material = Enum.Material.Slate }
	local moldingRadius = OPENING_RADIUS + ARCH_THICKNESS + 0.3
	makeSides(model, frame, moldingRadius, 0.6, ARCH_DEPTH + 0.4, makePart, molding)
	makeArc(model, frame, moldingRadius, 0.6, ARCH_DEPTH + 0.4, 14, makePart, molding)
	local edge = { Name = "ArchGlow", Color = PORTAL_PURPLE, Transparency = 0.15 }
	makeSides(model, frame, OPENING_RADIUS + 0.12, 0.25, ARCH_DEPTH + 0.1, makeGlow, edge)
	makeArc(model, frame, OPENING_RADIUS + 0.12, 0.25, ARCH_DEPTH + 0.1, 16, makeGlow, edge)

	local keystone = makeKeystone(model, frame)
	for _, side in { -1, 1 } do
		makePillar(model, frame, side * PILLAR_X)
	end
	makePortalSurface(model, frame)
	makeLanterns(model, frame)
	makeRoots(model, frame, random)

	if label then
		Billboard.create(keystone, {
			size = UDim2.fromOffset(360, 70),
			offset = Vector3.new(0, 5, 0),
			maxDistance = 400,
			font = Enum.Font.Creepster,
			lines = { { text = label, color = LABEL_ORANGE } },
		})
	end

	model.Parent = parent
	return model
end

return GhostPortal
