-- Builds the map from code (walkway in the middle, player bases on both sides),
-- so the game works in an empty Baseplate place. Swap this for a hand-built map later.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Billboard = require(script.Parent.Parent.Util.Billboard)
local Parts = require(script.Parent.Parent.Util.Parts)
local HalloweenDecor = require(script.Parent.HalloweenDecor)
local GraveyardBase = require(script.Parent.GraveyardBase)

local MapBuilder = {}

local PLOT_SIZE = 40
local PLOT_SPACING = 104 -- center to center; bases are about 44 wide, so this leaves a ~60 stud gap
local PLOT_DISTANCE = 58 -- walkway center to plot center: a 32-stud gap between the walkway edge and the base
local WALL_HEIGHT = 16.5 -- height of the lock bars
local LOCK_BAR_SPACING = 3 -- studs between lock bars (purely visual; an invisible wall blocks)
local LOCK_BAR_THICKNESS = 0.8
local LOCK_BAR_COLOR = Color3.fromRGB(255, 40, 60)
local LOCK_BAR_TRANSPARENCY = 0.4 -- 60% opaque; the bars are just a warning, the wall blocks
local PILLAR_HEIGHT = 18
local GATE_PILLAR_HEIGHT = 21 -- the two pillars at the entrance
local INVISIBLE_WALL_HEIGHT = 300 -- reaches high into the sky, so nobody can jump or climb over
local BOUNDARY_MARGIN_X = 30 -- studs from the walkway ends to the edge of the map
-- Distance from the walkway to the map's front and back edges; leaves room behind the bases
-- for the graveyard decorations.
local BOUNDARY_HALF_Z = PLOT_DISTANCE + 83
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

-- The green pad in front of a grave where that ghost's income piles up, drawn fullbright (see
-- Parts.paintFullbright) so it looks like neon in the dark without lighting up its surroundings.
-- EconomyService flashes its "Glow" fills when the pad is collected.
local PAD_BRIGHTNESS = 1.6 -- above 1 pushes the colour past normal, like neon

local function makeCollectPad(model: Model, slot: number, cframe: CFrame): Part
	local pad = makePart(model, {
		Name = "CollectPad" .. slot,
		Size = Vector3.new(4, 0.4, 2.5),
		CFrame = cframe,
		Color = Theme.MoneyGreen,
		Material = Enum.Material.SmoothPlastic,
		CastShadow = false,
	})
	Parts.paintFullbright(pad, Theme.MoneyGreen, PAD_BRIGHTNESS)
	return pad
end

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

	-- Chunky red jail bars across the entrance, with a rail along the top and along the ground
	-- (covering the bars' feet). They're drawn fullbright like the collect pads, slightly
	-- see-through, and never collide: they only show while the base is locked. What actually
	-- blocks the entrance is the invisible wall right behind them, which LockService makes solid
	-- for everyone but the owner while locked.
	local lockWall = makePart(model, {
		Name = "LockWall",
		Size = Vector3.new(PLOT_SIZE, WALL_HEIGHT, 0.4),
		CFrame = at(0, wallY, -half + 0.4),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	local lockBarSurfaces = {}
	local function lockBar(name: string, size: Vector3, cframe: CFrame)
		local bar = makePart(model, {
			Name = name,
			Size = size,
			CFrame = cframe,
			Color = LOCK_BAR_COLOR,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
		-- The bar part stays invisible; its fullbright paint is what you see.
		for _, surface in Parts.paintFullbright(bar, LOCK_BAR_COLOR, PAD_BRIGHTNESS) do
			surface.Enabled = false
			surface:FindFirstChild("Glow").BackgroundTransparency = LOCK_BAR_TRANSPARENCY
			table.insert(lockBarSurfaces, surface)
		end
	end
	local barCount = math.floor(PLOT_SIZE / LOCK_BAR_SPACING)
	local barGap = PLOT_SIZE / barCount
	for bar = 0, barCount do
		local x = -half + bar * barGap
		lockBar("LockBar", Vector3.new(LOCK_BAR_THICKNESS, WALL_HEIGHT, LOCK_BAR_THICKNESS), at(x, wallY, -half))
	end
	-- The bottom rail sits on the ground (y = 1) and is deeper than the bars, hiding their feet.
	local railHeight = LOCK_BAR_THICKNESS
	for _, y in { 1 + railHeight / 2, 1 + WALL_HEIGHT - railHeight / 2 } do
		lockBar("LockRail", Vector3.new(PLOT_SIZE, railHeight, LOCK_BAR_THICKNESS + 0.3), at(0, y, -half))
	end

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

	-- The Upgrades signpost, across the entrance from the lock button: a wooden post with a board
	-- that reads "UPGRADES" on both sides. Its prompt opens the owner's Upgrades window
	-- (UpgradeService).
	local signX = -(half - 5)
	-- The post stops at the board's bottom edge (y 5.3); it's thicker than the board, so going
	-- any higher would poke out through the sign's faces.
	makePart(model, {
		Name = "UpgradePost",
		Size = Vector3.new(0.6, 4.3, 0.6),
		CFrame = at(signX, 3.15, -half + 5),
		Color = Color3.fromRGB(70, 48, 34),
		Material = Enum.Material.Wood,
	})
	local upgradeBoard = makePart(model, {
		Name = "UpgradeSign",
		Size = Vector3.new(5, 2.2, 0.4),
		CFrame = at(signX, 6.4, -half + 5),
		Color = Color3.fromRGB(90, 62, 42),
		Material = Enum.Material.Wood,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local surface = Instance.new("SurfaceGui")
		surface.Face = face
		surface.LightInfluence = 0
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 50
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(255, 190, 40)
		text.Text = "UPGRADES"
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0.15, 0)
		padding.PaddingBottom = UDim.new(0.15, 0)
		padding.Parent = text
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(20, 8, 30)
		stroke.Thickness = 3
		stroke.Parent = text
		text.Parent = surface
		surface.Parent = upgradeBoard
	end
	local upgradePrompt = Instance.new("ProximityPrompt")
	upgradePrompt.Name = "UpgradePrompt"
	upgradePrompt.ActionText = "Upgrade"
	upgradePrompt.ObjectText = "Your base"
	upgradePrompt.HoldDuration = 0
	upgradePrompt.MaxActivationDistance = 9
	upgradePrompt.RequiresLineOfSight = false
	upgradePrompt.Parent = upgradeBoard

	-- 10 graves in two well-spaced rows. Each has a tombstone behind it; the ghost floats above the grave.
	-- A bright green collect pad sits in front of each grave, where that ghost's income piles up.
	local slots = {}
	local collectPads = {}
	local graveRandom = Random.new(index)
	for _, z in GRAVE_ROWS do
		for column = -2, 2 do
			local x = column * GRAVE_SPACING
			GraveyardBase.makeGrave(model, plotCFrame, Vector3.new(x, 1, z), #slots + 1, graveRandom)
			table.insert(slots, at(x, 4, z))
			table.insert(collectPads, makeCollectPad(model, #slots, at(x, 1.2, z - 4.5)))
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
		lockBarSurfaces = lockBarSurfaces, -- the jail bars' fullbright paint, shown only while locked
		lockWall = lockWall, -- invisible wall behind the bars that fills the gaps
		lockButton = lockButton,
		lockLabel = lockLabel,
		upgradePrompt = upgradePrompt, -- on the Upgrades signpost (UpgradeService)
		signLabel = signLabel,
		slots = slots,
		collectPads = collectPads, -- collectPads[slot] is the pad in front of that grave
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
