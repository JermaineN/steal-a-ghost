-- Halloween look for the generated map: night sky, pumpkin lamps, a graveyard behind the bases,
-- an iron fence, a haunted mansion, and glowing portals where the walkway ghosts come and go.
-- Visual only: nothing here changes gameplay. Turn it off with GameConfig.HalloweenMap = false.
local Lighting = game:GetService("Lighting")

local Billboard = require(script.Parent.Parent.Util.Billboard)
local Parts = require(script.Parent.Parent.Util.Parts)

local HalloweenDecor = {}

local PUMPKIN = Color3.fromRGB(235, 110, 20)
local GLOW_ORANGE = Color3.fromRGB(255, 140, 30)
local CANDLE = Color3.fromRGB(255, 205, 90)
local PURPLE = Color3.fromRGB(150, 70, 255)
local SPIRIT_GREEN = Color3.fromRGB(120, 255, 170)
local STONE = Color3.fromRGB(95, 90, 105)
local DEAD_WOOD = Color3.fromRGB(50, 38, 34)
local IRON = Color3.fromRGB(22, 20, 28)

local FENCE_MARGIN_X = 30 -- studs between the walkway ends and the fence
local FENCE_HALF_Z = 125 -- fence distance from the walkway, front to back
local CLIFF_GAP_X = 30 -- studs between the fence's short sides and the cliffs
local CLIFF_GAP_Z = 60 -- room for the mansion and big trees between the fence and the cliffs
local CLIFF_HEIGHT = NumberRange.new(80, 140)
local CLIFF_DEPTH = NumberRange.new(40, 60)

-- Same seed every server, so the graveyard always looks the same.
local random = Random.new(1031)

local makePart = Parts.make

local function addLight(part: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = part
end

-- Night time, purple haze, a big moon, and a slight purple tint.
local function setupLighting()
	Lighting.ClockTime = 21.5
	Lighting.Brightness = 0.2 -- sun/moon strength; barely visible at night
	-- Overall brightness, like a camera's exposure. This is the one to tune: try -0.5 (darker) to 1 (brighter).
	Lighting.ExposureCompensation = -0.5
	Lighting.Ambient = Color3.fromRGB(90, 75, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(145, 120, 185)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(110, 80, 150)
	atmosphere.Decay = Color3.fromRGB(60, 25, 70)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.5
	atmosphere.Parent = Lighting

	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.MoonAngularSize = 25
	sky.StarCount = 4000
	sky.Parent = Lighting

	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "HalloweenTint"
	tint.TintColor = Color3.fromRGB(235, 220, 255)
	tint.Brightness = 0.05
	tint.Contrast = 0.1
	tint.Saturation = 0.15
	tint.Parent = Lighting
end

-- Dead-grass ground (removes the Baseplate's grid texture) and a cobblestone walkway.
local function restyleGround(mapFolder: Folder, decor: Folder, walkwayLength: number)
	local ground = workspace:FindFirstChild("Baseplate") or mapFolder:FindFirstChild("Ground")
	if ground and ground:IsA("BasePart") then
		ground.Color = Color3.fromRGB(42, 48, 38)
		ground.Material = Enum.Material.Ground
		for _, child in ground:GetChildren() do
			if child:IsA("Texture") then
				child:Destroy()
			end
		end
	end

	local walkway = mapFolder:FindFirstChild("Walkway") :: BasePart
	walkway.Color = Color3.fromRGB(75, 65, 85)
	walkway.Material = Enum.Material.Cobblestone
	for _, side in { -1, 1 } do
		makePart(decor, {
			Name = "WalkwayEdge",
			Size = Vector3.new(walkwayLength, 0.2, 0.4),
			Position = Vector3.new(0, 0.7, side * 6.2),
			Color = GLOW_ORANGE,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		})
	end
end

-- A jack-o'-lantern. `cframe` is the pumpkin's center; its face points along cframe.LookVector.
local function makePumpkin(parent: Instance, cframe: CFrame, scale: number, lightRange: number?)
	local model = Instance.new("Model")
	model.Name = "Pumpkin"

	local radius = 1.3 * scale
	local body = makePart(model, {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * radius * 2,
		CFrame = cframe,
		Color = PUMPKIN,
		Material = Enum.Material.SmoothPlastic,
	})
	-- Two slightly smaller balls on the sides make it look wider and lumpier.
	for _, side in { -1, 1 } do
		makePart(model, {
			Name = "Lobe",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2.3 * scale,
			CFrame = cframe * CFrame.new(side * 0.45 * scale, -0.05 * scale, 0),
			Color = PUMPKIN,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	makePart(model, {
		Name = "Stem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 0.35, 0.35) * scale,
		CFrame = cframe * CFrame.new(0, radius + 0.2 * scale, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(70, 90, 40),
		Material = Enum.Material.Wood,
	})

	-- Glowing face: two diamond eyes and a wide mouth, poking out of the front.
	local face = {
		{ CFrame.new(-0.45, 0.3, -1.12) * CFrame.Angles(0, 0, math.pi / 4), Vector3.new(0.4, 0.4, 0.4) },
		{ CFrame.new(0.45, 0.3, -1.12) * CFrame.Angles(0, 0, math.pi / 4), Vector3.new(0.4, 0.4, 0.4) },
		{ CFrame.new(0, -0.35, -1.15), Vector3.new(1.1, 0.3, 0.4) },
	}
	for _, feature in face do
		local offset, size = feature[1], feature[2]
		makePart(model, {
			Name = "Face",
			Size = size * scale,
			CFrame = cframe * CFrame.new(offset.Position * scale) * offset.Rotation,
			Color = CANDLE,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		})
	end

	if lightRange then
		addLight(body, GLOW_ORANGE, lightRange, 2)
	end
	model.Parent = parent
	return model
end

-- An iron lamp post with a lit jack-o'-lantern on top, facing `facing`.
local function makeLampPost(parent: Instance, position: Vector3, facing: Vector3)
	local height = 10
	makePart(parent, {
		Name = "LampPost",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 0.6, 0.6),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = IRON,
		Material = Enum.Material.Metal,
	})
	local top = position + Vector3.new(0, height + 1, 0)
	makePumpkin(parent, CFrame.lookAt(top, top + facing), 0.8, 20)
end

-- Stone pillars with pumpkins on each side of a base's entrance.
local function decoratePlot(parent: Instance, plot)
	local half = plot.size / 2
	for _, side in { -1, 1 } do
		local base = plot.cframe * CFrame.new(side * (half + 0.5), 0, -half)
		makePart(parent, {
			Name = "GatePillar",
			Size = Vector3.new(2.4, 11, 2.4),
			CFrame = base * CFrame.new(0, 5.5, 0),
			Color = STONE,
			Material = Enum.Material.Slate,
		})
		makePumpkin(parent, base * CFrame.new(0, 12.1, 0), 0.6, 12)
	end
end

-- One of three grave styles. `cframe` sits on the ground, facing along LookVector.
local function makeGrave(parent: Instance, cframe: CFrame)
	local kind = random:NextInteger(1, 3)
	if kind == 1 then
		-- Rounded headstone
		makePart(parent, {
			Name = "Headstone",
			Size = Vector3.new(2.6, 3, 0.7),
			CFrame = cframe * CFrame.new(0, 1.5, 0),
			Color = STONE,
			Material = Enum.Material.Slate,
		})
		makePart(parent, {
			Name = "HeadstoneTop",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.7, 2.6, 2.6),
			CFrame = cframe * CFrame.new(0, 3, 0) * CFrame.Angles(0, math.pi / 2, 0),
			Color = STONE,
			Material = Enum.Material.Slate,
		})
	elseif kind == 2 then
		-- Cross
		makePart(parent, {
			Name = "Cross",
			Size = Vector3.new(0.6, 4.5, 0.6),
			CFrame = cframe * CFrame.new(0, 2.25, 0),
			Color = STONE,
			Material = Enum.Material.Slate,
		})
		makePart(parent, {
			Name = "CrossBar",
			Size = Vector3.new(2.4, 0.6, 0.6),
			CFrame = cframe * CFrame.new(0, 3.2, 0),
			Color = STONE,
			Material = Enum.Material.Slate,
		})
	else
		-- Flat slab with a small headstone
		makePart(parent, {
			Name = "GraveSlab",
			Size = Vector3.new(3, 0.5, 6),
			CFrame = cframe * CFrame.new(0, 0.25, 3),
			Color = Color3.fromRGB(75, 70, 82),
			Material = Enum.Material.Slate,
		})
		makePart(parent, {
			Name = "Headstone",
			Size = Vector3.new(3, 2.4, 0.6),
			CFrame = cframe * CFrame.new(0, 1.2, 0),
			Color = STONE,
			Material = Enum.Material.Slate,
		})
	end
end

-- A leafless tree: a trunk with crooked branches.
local function makeDeadTree(parent: Instance, position: Vector3, height: number)
	local trunk = CFrame.new(position) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
	local thickness = height / 8
	makePart(parent, {
		Name = "TreeTrunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, thickness, thickness),
		CFrame = trunk * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = DEAD_WOOD,
		Material = Enum.Material.Wood,
	})
	for index = 1, 4 do
		local around = index * math.pi / 2 + random:NextNumber(-0.4, 0.4)
		local tilt = math.rad(random:NextNumber(35, 65))
		local length = height * random:NextNumber(0.3, 0.5)
		-- Start at a point on the trunk, turn to face outward, lean over, then go up the branch.
		local branchBase = trunk
			* CFrame.new(0, height * random:NextNumber(0.55, 0.9), 0)
			* CFrame.Angles(0, around, 0)
			* CFrame.Angles(0, 0, -tilt)
		makePart(parent, {
			Name = "TreeBranch",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(length, thickness * 0.45, thickness * 0.45),
			CFrame = branchBase * CFrame.new(0, length / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = DEAD_WOOD,
			Material = Enum.Material.Wood,
		})
		-- A small twig bending back upward from the branch tip.
		local twigLength = length * 0.5
		makePart(parent, {
			Name = "TreeTwig",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(twigLength, thickness * 0.25, thickness * 0.25),
			CFrame = branchBase * CFrame.new(0, length, 0) * CFrame.Angles(0, 0, tilt * 0.8) * CFrame.new(
				0,
				twigLength / 2,
				0
			) * CFrame.Angles(0, 0, math.pi / 2),
			Color = DEAD_WOOD,
			Material = Enum.Material.Wood,
		})
	end
end

-- A floating green spirit light.
local function makeSpirit(parent: Instance, position: Vector3)
	local orb = makePart(parent, {
		Name = "Spirit",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.9,
		Position = position,
		Color = SPIRIT_GREEN,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	})
	addLight(orb, SPIRIT_GREEN, 14, 2)
end

-- Rows of graves, dead trees, pumpkins and spirits between the back of the bases and the fence.
-- `side` is 1 for the +Z half of the map and -1 for the -Z half.
local function makeGraveyard(parent: Instance, side: number, halfX: number)
	for row = 0, 3 do
		local z = side * (72 + row * 10)
		for x = -halfX + 15, halfX - 15, 13 do
			if random:NextNumber() < 0.65 then
				local position = Vector3.new(x + random:NextNumber(-3, 3), -0.2, z + random:NextNumber(-2, 2))
				local facing = CFrame.lookAt(position, Vector3.new(position.X, position.Y, 0))
				local tilt = CFrame.Angles(
					math.rad(random:NextNumber(-8, 8)),
					math.rad(random:NextNumber(-15, 15)),
					math.rad(random:NextNumber(-6, 6))
				)
				makeGrave(parent, facing * tilt)
			end
		end
	end

	-- A line of big trees near the fence, plus a few among the graves.
	for x = -halfX + 20, halfX - 20, 45 do
		makeDeadTree(parent, Vector3.new(x + random:NextNumber(-8, 8), 0, side * 115), random:NextNumber(14, 20))
	end
	for _ = 1, 3 do
		local position = Vector3.new(random:NextNumber(-halfX + 20, halfX - 20), 0, side * random:NextNumber(77, 97))
		makeDeadTree(parent, position, random:NextNumber(10, 14))
	end

	for _ = 1, 8 do
		local scale = random:NextNumber(0.6, 1.1)
		local position =
			Vector3.new(random:NextNumber(-halfX + 10, halfX - 10), 1.3 * scale, side * random:NextNumber(68, 110))
		makePumpkin(parent, CFrame.lookAt(position, Vector3.new(position.X, position.Y, 0)), scale)
	end

	for _ = 1, 4 do
		makeSpirit(
			parent,
			Vector3.new(
				random:NextNumber(-halfX + 20, halfX - 20),
				random:NextNumber(3, 6),
				side * random:NextNumber(70, 105)
			)
		)
	end
end

-- Iron fence (rails, posts and spikes) around the whole map.
local function makeFence(parent: Instance, halfX: number, halfZ: number)
	local corners = {
		Vector3.new(-halfX, 0, -halfZ),
		Vector3.new(halfX, 0, -halfZ),
		Vector3.new(halfX, 0, halfZ),
		Vector3.new(-halfX, 0, halfZ),
	}
	for index, startPoint in corners do
		local endPoint = corners[index % #corners + 1]
		local direction = (endPoint - startPoint).Unit
		local length = (endPoint - startPoint).Magnitude
		local middle = (startPoint + endPoint) / 2

		for _, y in { 2, 5.5 } do
			local center = middle + Vector3.new(0, y, 0)
			makePart(parent, {
				Name = "FenceRail",
				Size = Vector3.new(0.3, 0.3, length),
				CFrame = CFrame.lookAt(center, center + direction),
				Color = IRON,
				Material = Enum.Material.Metal,
			})
		end
		for distance = 0, length - 1, 5 do
			local position = startPoint + direction * distance
			makePart(parent, {
				Name = "FencePost",
				Size = Vector3.new(0.4, 7, 0.4),
				CFrame = CFrame.new(position + Vector3.new(0, 3.5, 0)),
				Color = IRON,
				Material = Enum.Material.Metal,
			})
			makePart(parent, {
				Name = "FenceSpike",
				Size = Vector3.new(0.5, 0.5, 0.5),
				CFrame = CFrame.lookAt(
					position + Vector3.new(0, 7.2, 0),
					position + Vector3.new(0, 7.2, 0) + direction
				) * CFrame.Angles(0, 0, math.pi / 4),
				Color = IRON,
				Material = Enum.Material.Metal,
			})
		end
	end
end

-- A stone arch with a swirling purple portal across the walkway. Ghosts appear from (or vanish into) it.
local function makePortal(parent: Instance, position: Vector3, label: string?)
	local towardMap = Vector3.new(-math.sign(position.X), 0, 0)
	for _, side in { -1, 1 } do
		makePart(parent, {
			Name = "PortalPillar",
			Size = Vector3.new(2.5, 15, 2.5),
			Position = position + Vector3.new(0, 7.5, side * 8.5),
			Color = STONE,
			Material = Enum.Material.Slate,
		})
		local top = position + Vector3.new(0, 18.6, side * 8.5)
		makePumpkin(parent, CFrame.lookAt(top, top + towardMap), 0.8)
	end
	local beam = makePart(parent, {
		Name = "PortalBeam",
		Size = Vector3.new(3, 2.5, 19.5),
		Position = position + Vector3.new(0, 16.25, 0),
		Color = STONE,
		Material = Enum.Material.Slate,
	})

	-- A Cylinder's round faces point along X, which is the walkway direction.
	local disc = makePart(parent, {
		Name = "PortalDisc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 13, 13),
		Position = position + Vector3.new(0, 7.5, 0),
		Color = PURPLE,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	addLight(disc, PURPLE, 30, 3)

	local swirl = Instance.new("ParticleEmitter")
	swirl.Color = ColorSequence.new(PURPLE, SPIRIT_GREEN)
	swirl.LightEmission = 1
	swirl.Size = NumberSequence.new(1.2, 0)
	swirl.Transparency = NumberSequence.new(0.2, 1)
	swirl.Lifetime = NumberRange.new(1.5, 2.5)
	swirl.Rate = 25
	swirl.Speed = NumberRange.new(1, 3)
	swirl.SpreadAngle = Vector2.new(180, 180)
	swirl.RotSpeed = NumberRange.new(-90, 90)
	swirl.Parent = disc

	if label then
		Billboard.create(beam, {
			size = UDim2.fromOffset(360, 70),
			offset = Vector3.new(0, 6, 0),
			maxDistance = 400,
			font = Enum.Font.Creepster,
			lines = { { text = label, color = GLOW_ORANGE } },
		})
	end
end

-- A haunted mansion outside the fence, as scenery. `facing` points toward the map.
local function makeMansion(parent: Instance, origin: Vector3, facing: Vector3)
	local frame = CFrame.lookAt(origin, origin + facing)
	local wallColor = Color3.fromRGB(45, 38, 55)
	local roofColor = Color3.fromRGB(30, 25, 35)

	makePart(parent, {
		Name = "MansionBody",
		Size = Vector3.new(50, 22, 22),
		CFrame = frame * CFrame.new(0, 11, 0),
		Color = wallColor,
		Material = Enum.Material.WoodPlanks,
	})
	-- Two slanted slabs meeting at the top make the roof.
	for _, side in { -1, 1 } do
		makePart(parent, {
			Name = "MansionRoof",
			Size = Vector3.new(52, 1, 15),
			CFrame = frame * CFrame.new(0, 26.3, side * 6.1) * CFrame.Angles(side * math.rad(35), 0, 0),
			Color = roofColor,
			Material = Enum.Material.Slate,
		})
	end
	-- Towers on both ends with pointed (stacked) roofs and a lit window.
	for _, side in { -1, 1 } do
		local tower = frame * CFrame.new(side * 27, 0, 0)
		makePart(parent, {
			Name = "MansionTower",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(34, 9, 9),
			CFrame = tower * CFrame.new(0, 17, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = wallColor,
			Material = Enum.Material.Brick,
		})
		local roofY = 34
		for step, diameter in { 11, 7.5, 4, 1.5 } do
			local height = 1.5 + step
			makePart(parent, {
				Name = "MansionTowerRoof",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(height, diameter, diameter),
				CFrame = tower * CFrame.new(0, roofY + height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
				Color = roofColor,
				Material = Enum.Material.Slate,
			})
			roofY += height
		end
		makePart(parent, {
			Name = "MansionWindow",
			Size = Vector3.new(2.5, 4, 0.4),
			CFrame = tower * CFrame.new(0, 26, -4.4),
			Color = PURPLE,
			Material = Enum.Material.Neon,
			CastShadow = false,
		})
	end
	-- Glowing windows and a dark door on the front.
	for _, x in { -18, -9, 9, 18 } do
		for _, y in { 7, 16 } do
			makePart(parent, {
				Name = "MansionWindow",
				Size = Vector3.new(4, 5, 0.4),
				CFrame = frame * CFrame.new(x, y, -11.1),
				Color = if random:NextNumber() < 0.7 then CANDLE else PURPLE,
				Material = Enum.Material.Neon,
				CastShadow = false,
			})
		end
	end
	makePart(parent, {
		Name = "MansionDoor",
		Size = Vector3.new(6, 9, 0.4),
		CFrame = frame * CFrame.new(0, 4.5, -11.1),
		Color = Color3.fromRGB(25, 15, 15),
		Material = Enum.Material.Wood,
	})
end

-- A ring of tall rock cliffs (made of Terrain) around the whole map, so players can't see
-- the flat ground beyond it. `halfX`/`halfZ` are the distances from the map center to the
-- cliffs' inner faces.
local function makeCliffs(halfX: number, halfZ: number)
	local terrain = workspace.Terrain
	-- Dark purple-grey rock. This recolors these materials for all terrain in the place.
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(70, 62, 82))
	terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(58, 52, 70))
	terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(45, 40, 55))
	local materials = { Enum.Material.Rock, Enum.Material.Slate, Enum.Material.Basalt }

	-- Its own seed, so the cliffs don't change the layout of the graveyard and trees.
	local cliffRandom = Random.new(666)

	-- One entry per side: where its inner face is, which way is "outward", and how long it is.
	local sides = {
		{ face = Vector3.new(0, 0, halfZ), outward = Vector3.zAxis, length = halfX * 2 },
		{ face = Vector3.new(0, 0, -halfZ), outward = -Vector3.zAxis, length = halfX * 2 },
		{ face = Vector3.new(halfX, 0, 0), outward = Vector3.xAxis, length = halfZ * 2 },
		{ face = Vector3.new(-halfX, 0, 0), outward = -Vector3.xAxis, length = halfZ * 2 },
	}
	for _, side in sides do
		local along = side.outward:Cross(Vector3.yAxis)
		-- Run a bit past each end so the corners are closed.
		local reach = side.length / 2 + 40
		for distance = -reach, reach, 18 do
			local edge = side.face + along * (distance + cliffRandom:NextNumber(-4, 4))

			-- A big tilted rock slab. Lots of these overlapping make a jagged cliff wall.
			local height = cliffRandom:NextNumber(CLIFF_HEIGHT.Min, CLIFF_HEIGHT.Max)
			local depth = cliffRandom:NextNumber(CLIFF_DEPTH.Min, CLIFF_DEPTH.Max)
			local center = edge + side.outward * (depth / 2 + cliffRandom:NextNumber(0, 8))
			local slab = CFrame.lookAt(center, center + side.outward)
				* CFrame.Angles(
					math.rad(cliffRandom:NextNumber(-8, 8)),
					math.rad(cliffRandom:NextNumber(-15, 15)),
					math.rad(cliffRandom:NextNumber(-6, 6))
				)
			terrain:FillBlock(
				slab + Vector3.new(0, height / 2 - 6, 0),
				Vector3.new(cliffRandom:NextNumber(26, 40), height, depth),
				materials[cliffRandom:NextInteger(1, #materials)]
			)

			-- A lower ledge sticking out in front, so the wall looks stepped instead of flat.
			if cliffRandom:NextNumber() < 0.6 then
				local ledgeHeight = cliffRandom:NextNumber(20, 45)
				local ledgeCenter = edge + side.outward * cliffRandom:NextNumber(0, 6)
				terrain:FillBlock(
					CFrame.lookAt(ledgeCenter, ledgeCenter + side.outward)
							* CFrame.Angles(0, math.rad(cliffRandom:NextNumber(-15, 15)), 0)
						+ Vector3.new(0, ledgeHeight / 2 - 4, 0),
					Vector3.new(cliffRandom:NextNumber(18, 30), ledgeHeight, cliffRandom:NextNumber(14, 22)),
					Enum.Material.Rock
				)
			end

			-- Fallen boulders at the foot of the cliff.
			if cliffRandom:NextNumber() < 0.5 then
				local boulder = edge - side.outward * cliffRandom:NextNumber(2, 6)
				terrain:FillBall(boulder, cliffRandom:NextNumber(4, 8), Enum.Material.Slate)
			end
		end
	end
end

function HalloweenDecor.build(mapFolder: Folder, plots: { any }, walkwayLength: number)
	setupLighting()

	-- Build everything in a folder outside the game first, then add it in one go (faster).
	local decor = Instance.new("Folder")
	decor.Name = "HalloweenDecor"

	restyleGround(mapFolder, decor, walkwayLength)

	local walkwayEnd = walkwayLength / 2
	makePortal(decor, Vector3.new(-walkwayEnd, 0, 0), "Ghost Portal")
	makePortal(decor, Vector3.new(walkwayEnd, 0, 0))

	-- Pumpkin lamps along both sides of the walkway, in the gaps between bases.
	for x = -walkwayEnd + 30, walkwayEnd - 30, 50 do
		for _, side in { -1, 1 } do
			makeLampPost(decor, Vector3.new(x, 0, side * 9), Vector3.new(0, 0, -side))
		end
	end

	for _, plot in plots do
		decoratePlot(decor, plot)
	end

	local fenceHalfX = walkwayEnd + FENCE_MARGIN_X
	makeGraveyard(decor, 1, fenceHalfX)
	makeGraveyard(decor, -1, fenceHalfX)
	makeFence(decor, fenceHalfX, FENCE_HALF_Z)

	-- Scenery outside the fence: a mansion on one side, giant dead trees on the other.
	makeMansion(decor, Vector3.new(0, 0, FENCE_HALF_Z + 30), Vector3.new(0, 0, -1))
	for x = -120, 120, 60 do
		makeDeadTree(
			decor,
			Vector3.new(x + random:NextNumber(-10, 10), 0, -(FENCE_HALF_Z + 25)),
			random:NextNumber(28, 36)
		)
	end

	makeCliffs(fenceHalfX + CLIFF_GAP_X, FENCE_HALF_Z + CLIFF_GAP_Z)

	decor.Parent = mapFolder
end

return HalloweenDecor
