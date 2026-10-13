-- Builds the map from code (walkway in the middle, player bases on both sides),
-- so the game works in an empty Baseplate place. Swap this for a hand-built map later.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Billboard = require(script.Parent.Parent.Util.Billboard)
local Parts = require(script.Parent.Parent.Util.Parts)
local HalloweenDecor = require(script.Parent.HalloweenDecor)

local MapBuilder = {}

local PLOT_SIZE = 40
local PLOT_SPACING = 50
local PLOT_DISTANCE = 42 -- walkway center to plot center
local WALL_HEIGHT = 8
local WALKWAY_HEIGHT = 4 -- height ghosts float at on the walkway

local PLOT_COLORS = {
	Color3.fromRGB(70, 60, 90),
	Color3.fromRGB(60, 80, 90),
	Color3.fromRGB(80, 70, 60),
	Color3.fromRGB(60, 85, 70),
	Color3.fromRGB(90, 60, 70),
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

	local wallColor = Color3.fromRGB(45, 40, 60)
	makePart(model, {
		Name = "Floor",
		Size = Vector3.new(PLOT_SIZE, 1, PLOT_SIZE),
		CFrame = at(0, 0.5, 0),
		Color = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1],
		Material = Enum.Material.WoodPlanks,
	})
	makePart(model, {
		Name = "WallLeft",
		Size = Vector3.new(1, WALL_HEIGHT, PLOT_SIZE),
		CFrame = at(-half - 0.5, wallY, 0),
		Color = wallColor,
		Material = Enum.Material.Brick,
	})
	makePart(model, {
		Name = "WallRight",
		Size = Vector3.new(1, WALL_HEIGHT, PLOT_SIZE),
		CFrame = at(half + 0.5, wallY, 0),
		Color = wallColor,
		Material = Enum.Material.Brick,
	})
	makePart(model, {
		Name = "WallBack",
		Size = Vector3.new(PLOT_SIZE + 2, WALL_HEIGHT, 1),
		CFrame = at(0, wallY, half + 0.5),
		Color = wallColor,
		Material = Enum.Material.Brick,
	})

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

	-- 10 slots in two rows at the back of the base.
	local slots = {}
	for row = 0, 1 do
		for column = -2, 2 do
			local x, z = column * 8, 7 + row * 7
			makePart(model, {
				Name = "Slot" .. (#slots + 1),
				Size = Vector3.new(5, 0.2, 5),
				CFrame = at(x, 1.1, z),
				Color = Color3.fromRGB(110, 100, 140),
				Material = Enum.Material.SmoothPlastic,
			})
			table.insert(slots, at(x, 4, z))
		end
	end

	local signAnchor = makePart(model, {
		Name = "Sign",
		Size = Vector3.one,
		CFrame = at(0, 1 + WALL_HEIGHT + 3, half),
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
		spawnCFrame = at(0, 4, -5),
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
			Size = Vector3.new(512, 2, 512),
			Position = Vector3.new(0, -1, 0),
			Color = Color3.fromRGB(40, 36, 52),
			Material = Enum.Material.Slate,
		})
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

	if GameConfig.HalloweenMap then
		HalloweenDecor.build(mapFolder, plots, walkwayLength)
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
