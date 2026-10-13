-- Building blocks for the graveyard-style player bases: stone pillars, low stone walls with a
-- rusty iron fence on top, and tombstones with a grave in front where a ghost floats.
-- All positions are plot-local (relative to the plot's center, local -Z = the entrance side).
local Parts = require(script.Parent.Parent.Util.Parts)

local GraveyardBase = {}

local STONE = Color3.fromRGB(118, 112, 106)
local STONE_DARK = Color3.fromRGB(92, 87, 84)
local STONE_CAP = Color3.fromRGB(142, 136, 128)
local IRON = Color3.fromRGB(70, 48, 38)
local TOMBSTONE = Color3.fromRGB(128, 134, 140)
local SOIL = Color3.fromRGB(48, 38, 32)

local CURB_HEIGHT = 3.3 -- the low stone wall the fence stands on
local CURB_THICKNESS = 1.4
local FENCE_TOP = 15 -- height of the fence bars (arches go higher)
local BAR_SPACING = 1.25

local makePart = Parts.make

-- A stacked-stone pillar with a stone band, a cap, and (optionally) a ball finial on top.
-- Returns the CFrame of the top of its cap, so things can be placed on it.
function GraveyardBase.makePillar(
	model: Instance,
	plotCFrame: CFrame,
	position: Vector3,
	height: number,
	width: number,
	finial: boolean
): CFrame
	local base = plotCFrame * CFrame.new(position)
	makePart(model, {
		Name = "Pillar",
		Size = Vector3.new(width, height, width),
		CFrame = base * CFrame.new(0, height / 2, 0),
		Color = STONE_DARK,
		Material = Enum.Material.Cobblestone,
	})
	makePart(model, {
		Name = "PillarBand",
		Size = Vector3.new(width + 0.3, 0.4, width + 0.3),
		CFrame = base * CFrame.new(0, CURB_HEIGHT, 0),
		Color = STONE_CAP,
		Material = Enum.Material.Concrete,
	})
	makePart(model, {
		Name = "PillarCap",
		Size = Vector3.new(width + 0.6, 0.5, width + 0.6),
		CFrame = base * CFrame.new(0, height + 0.25, 0),
		Color = STONE_CAP,
		Material = Enum.Material.Concrete,
	})
	if finial then
		makePart(model, {
			Name = "PillarFinialBase",
			Size = Vector3.new(width * 0.45, 0.6, width * 0.45),
			CFrame = base * CFrame.new(0, height + 0.8, 0),
			Color = STONE_CAP,
			Material = Enum.Material.Concrete,
		})
		makePart(model, {
			Name = "PillarFinial",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * width * 0.4,
			CFrame = base * CFrame.new(0, height + 1.4, 0),
			Color = STONE_CAP,
			Material = Enum.Material.Concrete,
		})
	end
	return base * CFrame.new(0, height + 0.5, 0)
end

-- A low stone wall with a rusty spiked iron fence on top, running from `a` to `b` (on the ground).
-- `arch` raises the middle of the fence into a curve; 0 keeps it straight.
function GraveyardBase.makeFenceWall(model: Instance, plotCFrame: CFrame, a: Vector3, b: Vector3, arch: number)
	local length = (b - a).Magnitude
	local middle = (a + b) / 2
	-- In this frame, -Z runs along the wall from `a` toward `b`.
	local frame = plotCFrame * CFrame.lookAt(middle, b)
	local function along(distance: number, y: number): CFrame
		return frame * CFrame.new(0, y, -distance)
	end

	makePart(model, {
		Name = "WallCurb",
		Size = Vector3.new(CURB_THICKNESS, CURB_HEIGHT, length),
		CFrame = along(0, CURB_HEIGHT / 2),
		Color = STONE,
		Material = Enum.Material.Slate,
	})
	makePart(model, {
		Name = "WallCurbCap",
		Size = Vector3.new(CURB_THICKNESS + 0.4, 0.3, length),
		CFrame = along(0, CURB_HEIGHT + 0.15),
		Color = STONE_CAP,
		Material = Enum.Material.Concrete,
	})

	local barBottom = CURB_HEIGHT + 0.3
	local function barTop(distance: number): number
		local t = distance / (length / 2) -- -1 at one end, 1 at the other
		return FENCE_TOP + arch * (1 - t * t)
	end

	-- Vertical bars with a diamond spike on each.
	local barCount = math.max(2, math.round(length / BAR_SPACING))
	local topRailPoints = {}
	for index = 1, barCount - 1 do
		local distance = -length / 2 + index * (length / barCount)
		local top = barTop(distance)
		makePart(model, {
			Name = "FenceBar",
			Size = Vector3.new(0.18, top - barBottom, 0.18),
			CFrame = along(distance, (barBottom + top) / 2),
			Color = IRON,
			Material = Enum.Material.CorrodedMetal,
		})
		makePart(model, {
			Name = "FenceSpike",
			Size = Vector3.new(0.32, 0.32, 0.32),
			CFrame = along(distance, top + 0.1) * CFrame.Angles(math.pi / 4, 0, 0),
			Color = IRON,
			Material = Enum.Material.CorrodedMetal,
		})
		table.insert(topRailPoints, (along(distance, top - 0.5)).Position)
	end

	-- Bottom rail is straight; the top rail follows the bars (so it curves along an arch).
	makePart(model, {
		Name = "FenceRail",
		Size = Vector3.new(0.15, 0.2, length),
		CFrame = along(0, barBottom + 0.5),
		Color = IRON,
		Material = Enum.Material.CorrodedMetal,
	})
	for index = 1, #topRailPoints - 1 do
		local from, to = topRailPoints[index], topRailPoints[index + 1]
		makePart(model, {
			Name = "FenceRail",
			Size = Vector3.new(0.15, 0.2, (to - from).Magnitude + 0.1),
			CFrame = CFrame.lookAt((from + to) / 2, to),
			Color = IRON,
			Material = Enum.Material.CorrodedMetal,
		})
	end
end

-- A weathered tombstone with a rounded top, and a grave in front of it where a ghost floats.
-- `slotPosition` is the center of the grave on the floor. `random` adds a slight tilt per stone.
function GraveyardBase.makeGrave(
	model: Instance,
	plotCFrame: CFrame,
	slotPosition: Vector3,
	index: number,
	random: Random
)
	-- The stone stands behind the grave (toward the back wall) and faces the entrance.
	local stoneBase = plotCFrame
		* CFrame.new(slotPosition + Vector3.new(0, 0, 3.6))
		* CFrame.Angles(
			math.rad(random:NextNumber(-4, 2)),
			math.rad(random:NextNumber(-6, 6)),
			math.rad(random:NextNumber(-3, 3))
		)
	local shade = random:NextNumber(0.9, 1.05)
	local stoneColor = Color3.new(TOMBSTONE.R * shade, TOMBSTONE.G * shade, TOMBSTONE.B * shade)

	makePart(model, {
		Name = "TombstonePlinth",
		Size = Vector3.new(4.2, 0.6, 1.6),
		CFrame = stoneBase * CFrame.new(0, 0.3, 0),
		Color = STONE,
		Material = Enum.Material.Slate,
	})
	local slab = makePart(model, {
		Name = "Tombstone",
		Size = Vector3.new(3.4, 4, 0.7),
		CFrame = stoneBase * CFrame.new(0, 0.6 + 2, 0),
		Color = stoneColor,
		Material = Enum.Material.Granite,
	})
	-- A cylinder lying front-to-back, mostly hidden in the slab, gives the rounded top.
	makePart(model, {
		Name = "TombstoneTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.7, 3.4, 3.4),
		CFrame = stoneBase * CFrame.new(0, 0.6 + 4 - 0.9, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Color = stoneColor,
		Material = Enum.Material.Granite,
	})

	-- A faint carving on the front.
	local carving = Instance.new("SurfaceGui")
	carving.Face = Enum.NormalId.Front
	carving.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	carving.PixelsPerStud = 50
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(0.8, 0.3)
	text.Position = UDim2.fromScale(0.1, 0.12)
	text.Font = Enum.Font.Antique
	text.Text = "R.I.P."
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(70, 72, 78)
	text.TextTransparency = 0.25
	text.Parent = carving
	carving.Parent = slab

	-- The grave: a stone border with dark soil inside. The ghost floats above it.
	local graveCFrame = plotCFrame * CFrame.new(slotPosition)
	makePart(model, {
		Name = "Slot" .. index,
		Size = Vector3.new(5, 0.25, 5),
		CFrame = graveCFrame * CFrame.new(0, 0.125, 0),
		Color = STONE_CAP,
		Material = Enum.Material.Concrete,
	})
	makePart(model, {
		Name = "GraveSoil",
		Size = Vector3.new(4.2, 0.27, 4.2),
		CFrame = graveCFrame * CFrame.new(0, 0.135, 0),
		Color = SOIL,
		Material = Enum.Material.Ground,
	})
end

return GraveyardBase
