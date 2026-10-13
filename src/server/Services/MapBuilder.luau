-- Builds the map from code (walkway in the middle, player bases on both sides),
-- so the game works in an empty Baseplate place. Swap this for a hand-built map later.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Billboard = require(script.Parent.Parent.Util.Billboard)
local Parts = require(script.Parent.Parent.Util.Parts)
local HalloweenDecor = require(script.Parent.HalloweenDecor)
local GraveyardBase = require(script.Parent.GraveyardBase)

local MapBuilder = {}

local PLOT_SIZE = 40
local PLOT_SPACING = 80 -- center to center; bases are about 44 wide, so this leaves a ~36 stud gap
local PLOT_DISTANCE = 42 -- walkway center to plot center
local WALL_HEIGHT = 16.5 -- height of the lock barrier
local PILLAR_HEIGHT = 18
local GATE_PILLAR_HEIGHT = 21 -- the two pillars at the entrance
local INVISIBLE_WALL_HEIGHT = 300 -- reaches high into the sky, so nobody can jump or climb over
local BOUNDARY_MARGIN_X = 30 -- studs from the walkway ends to the edge of the map
local BOUNDARY_HALF_Z = 125 -- distance from the walkway to the map's front and back edges
local WALKWAY_HEIGHT = 4 -- height ghosts float at on the walkway
local GRAVE_ROWS = { -1, 12 } -- plot-local Z of the two rows of graves (front row, back row)
local GRAVE_SPACING = 8 -- studs between graves in a row

-- Slightly different grass for each base.
local PLOT_COLORS = {
	Color3.fromRGB(58, 70, 52),
	Color3.fromRGB(52, 64, 62),
	Color3.fromRGB(66, 62, 50),
	Color3.fromRGB(58, 54, 66),
	Color3.fromRGB(64, 58, 56),
}

local makePart = Parts.make

local function buildPlot(mapFolder: Folder, index: number, plotCFrame: CFrame)
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model.Parent = mapFolder

	local half = PLOT_SIZE / 2
	local wallY = 1 + WALL_HEIGHT / 2
	-- Positions are relative to the plot. Local -Z is the front (the side facing the walkway).
	local function at(x: number, y: number, z: number): CFrame
		return plotCFrame * CFrame.new(x, y, z)
	end

	-- Grassy graveyard floor, with a cobblestone area inside the entrance.
	makePart(model, {
		Name = "Floor",
		Size = Vector3.new(PLOT_SIZE, 1, PLOT_SIZE),
		CFrame = at(0, 0.5, 0),
		Color = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1],
		Material = Enum.Material.Grass,
	})
	makePart(model, {
		Name = "EntrancePath",
		Size = Vector3.new(PLOT_SIZE - 2, 0.1, 11),
		CFrame = at(0, 1.05, -half + 5.5),
		Color = Color3.fromRGB(95, 90, 92),
		Material = Enum.Material.Cobblestone,
	})

	-- Invisible walls along the fence, stretching high into the sky. They stop players squeezing
	-- through the bars, and jumping or climbing over the walls in or out of a base.
	-- Only the entrance is open.
	local wallLine = half + 1 -- the fence stands just outside the floor
	local wallLength = PLOT_SIZE + 6 -- a bit longer than the fence, so the corners are sealed
	local invisibleWallY = INVISIBLE_WALL_HEIGHT / 2
	for _, wall in
		{
			{
				name = "WallLeft",
				size = Vector3.new(1.4, INVISIBLE_WALL_HEIGHT, wallLength),
				position = Vector3.new(-wallLine, invisibleWallY, 0),
			},
			{
				name = "WallRight",
				size = Vector3.new(1.4, INVISIBLE_WALL_HEIGHT, wallLength),
				position = Vector3.new(wallLine, invisibleWallY, 0),
			},
			{
				name = "WallBack",
				size = Vector3.new(wallLength, INVISIBLE_WALL_HEIGHT, 1.4),
				position = Vector3.new(0, invisibleWallY, wallLine),
			},
		}
	do
		makePart(model, {
			Name = wall.name,
			Size = wall.size,
			CFrame = at(wall.position.X, wall.position.Y, wall.position.Z),
			Transparency = 1,
			CastShadow = false,
		})
	end

	-- Stone pillars joined by low stone walls with an iron fence: down both sides and across
	-- the back, with an arch in the middle of the back. The entrance pillars are taller.
	local gateTops = {}
	for _, side in { -1, 1 } do
		local x = side * wallLine
		table.insert(
			gateTops,
			GraveyardBase.makePillar(model, plotCFrame, Vector3.new(x, 0, -wallLine), GATE_PILLAR_HEIGHT, 3.2, false)
		)
		local sidePoints = { -wallLine, -wallLine / 2, 0, wallLine / 2, wallLine }
		for point = 2, #sidePoints do
			GraveyardBase.makePillar(model, plotCFrame, Vector3.new(x, 0, sidePoints[point]), PILLAR_HEIGHT, 2.6, true)
			local inset = if point == 2 then 1.6 else 1.3
			GraveyardBase.makeFenceWall(
				model,
				plotCFrame,
				Vector3.new(x, 0, sidePoints[point - 1] + inset),
				Vector3.new(x, 0, sidePoints[point] - 1.3),
				0
			)
		end
	end
	local backPoints = { -wallLine, -wallLine / 2, wallLine / 2, wallLine }
	for point = 2, #backPoints do
		if point < #backPoints then
			GraveyardBase.makePillar(
				model,
				plotCFrame,
				Vector3.new(backPoints[point], 0, wallLine),
				PILLAR_HEIGHT,
				2.6,
				true
			)
		end
		GraveyardBase.makeFenceWall(
			model,
			plotCFrame,
			Vector3.new(backPoints[point - 1] + 1.3, 0, wallLine),
			Vector3.new(backPoints[point] - 1.3, 0, wallLine),
			if point == 3 then 3.75 else 0 -- the middle section gets the arch
		)
	end

	-- Red laser across the entrance; visible only while the base is locked.
	local barrier = makePart(model, {
		Name = "LockBarrier",
		Size = Vector3.new(PLOT_SIZE, WALL_HEIGHT, 0.4),
		CFrame = at(0, wallY, -half),
		Color = Color3.fromRGB(255, 40, 60),
		Material = Enum.Material.Neon,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})

	local lockButton = makePart(model, {
		Name = "LockButton",
		Size = Vector3.new(4, 0.4, 4),
		CFrame = at(half - 5, 1.2, -half + 5),
		Color = Color3.fromRGB(80, 255, 120),
		Material = Enum.Material.Neon,
	})
	local lockLabel = Billboard.create(lockButton, {
		size = UDim2.fromOffset(180, 32),
		offset = Vector3.new(0, 3, 0),
		lines = { { text = "" } },
	})[1]

	-- 10 graves in two well-spaced rows. Each has a tombstone behind it; the ghost floats above the grave.
	local slots = {}
	local graveRandom = Random.new(index)
	for _, z in GRAVE_ROWS do
		for column = -2, 2 do
			local x = column * GRAVE_SPACING
			GraveyardBase.makeGrave(model, plotCFrame, Vector3.new(x, 1, z), #slots + 1, graveRandom)
			table.insert(slots, at(x, 4, z))
		end
	end

	local signAnchor = makePart(model, {
		Name = "Sign",
		Size = Vector3.one,
		CFrame = at(0, 1 + WALL_HEIGHT + 3.5, wallLine),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local signLabel = Billboard.create(signAnchor, {
		size = UDim2.fromOffset(320, 50),
		maxDistance = 250,
		lines = { { text = "Empty Base" } },
	})[1]

	local ghostFolder = Instance.new("Folder")
	ghostFolder.Name = "Ghosts"
	ghostFolder.Parent = model

	return {
		index = index,
		cframe = plotCFrame,
		size = PLOT_SIZE,
		model = model,
		ghostFolder = ghostFolder,
		barrier = barrier,
		lockButton = lockButton,
		lockLabel = lockLabel,
		signLabel = signLabel,
		slots = slots,
		gateTops = gateTops, -- tops of the two entrance pillars (for decorations)
		spawnCFrame = at(0, 4, -10),
		ejectCFrame = at(0, 4, -half - 8),
		owner = nil :: Player?,
		lockedUntil = 0,
		lockCooldownUntil = 0,
	}
end

function MapBuilder.build()
	local old = workspace:FindFirstChild("GeneratedMap")
	if old then
		old:Destroy()
	end

	local mapFolder = Instance.new("Folder")
	mapFolder.Name = "GeneratedMap"
	mapFolder.Parent = workspace

	if not workspace:FindFirstChild("Baseplate") then
		makePart(mapFolder, {
			Name = "Ground",
			Size = Vector3.new(1024, 2, 1024),
			Position = Vector3.new(0, -1, 0),
			Color = Color3.fromRGB(40, 36, 52),
			Material = Enum.Material.Slate,
		})
	end

	-- Hide the place's spawn pad. Roblox still spawns players there, but PlotService moves
	-- them to their own base straight away, so it only needs to exist, not be seen.
	for _, spawnLocation in workspace:GetDescendants() do
		if spawnLocation:IsA("SpawnLocation") then
			spawnLocation.Transparency = 1
			spawnLocation.CanCollide = false
			spawnLocation.CastShadow = false
			for _, child in spawnLocation:GetChildren() do
				if child:IsA("Decal") then
					child.Transparency = 1
				end
			end
		end
	end

	local perSide = math.ceil(GameConfig.PlotCount / 2)
	local walkwayLength = perSide * PLOT_SPACING + 60

	makePart(mapFolder, {
		Name = "Walkway",
		Size = Vector3.new(walkwayLength, 0.6, 12),
		Position = Vector3.new(0, 0.3, 0),
		Color = Color3.fromRGB(130, 30, 45),
		Material = Enum.Material.Fabric,
	})

	local plots = {}
	for index = 1, GameConfig.PlotCount do
		local side = if index <= perSide then 1 else -1
		local column = (index - 1) % perSide
		local x = (column - (perSide - 1) / 2) * PLOT_SPACING
		local center = Vector3.new(x, 0, side * PLOT_DISTANCE)
		-- Face the plot toward the walkway.
		local plotCFrame = CFrame.lookAt(center, Vector3.new(x, 0, 0))
		table.insert(plots, buildPlot(mapFolder, index, plotCFrame))
	end

	-- Invisible walls around the whole map, stretching high into the sky, so players can't
	-- leave the play area (or climb the cliffs behind the fence).
	local boundaryHalfX = walkwayLength / 2 + BOUNDARY_MARGIN_X
	for _, wall in
		{
			{
				size = Vector3.new(boundaryHalfX * 2, INVISIBLE_WALL_HEIGHT, 2),
				position = Vector3.new(0, 0, BOUNDARY_HALF_Z),
			},
			{
				size = Vector3.new(boundaryHalfX * 2, INVISIBLE_WALL_HEIGHT, 2),
				position = Vector3.new(0, 0, -BOUNDARY_HALF_Z),
			},
			{
				size = Vector3.new(2, INVISIBLE_WALL_HEIGHT, BOUNDARY_HALF_Z * 2),
				position = Vector3.new(boundaryHalfX, 0, 0),
			},
			{
				size = Vector3.new(2, INVISIBLE_WALL_HEIGHT, BOUNDARY_HALF_Z * 2),
				position = Vector3.new(-boundaryHalfX, 0, 0),
			},
		}
	do
		makePart(mapFolder, {
			Name = "BoundaryWall",
			Size = wall.size + Vector3.new(2, 0, 2), -- a little extra so the corners overlap
			Position = wall.position + Vector3.new(0, INVISIBLE_WALL_HEIGHT / 2, 0),
			Transparency = 1,
			CastShadow = false,
		})
	end

	if GameConfig.HalloweenMap then
		HalloweenDecor.build(mapFolder, plots, walkwayLength, boundaryHalfX, BOUNDARY_HALF_Z)
	end

	local startPosition = Vector3.new(-walkwayLength / 2, WALKWAY_HEIGHT, 0)
	local endPosition = Vector3.new(walkwayLength / 2, WALKWAY_HEIGHT, 0)

	return {
		plots = plots,
		walkwayStart = CFrame.lookAt(startPosition, endPosition),
		walkwayEnd = CFrame.lookAt(endPosition, endPosition + Vector3.xAxis),
	}
end

return MapBuilder
