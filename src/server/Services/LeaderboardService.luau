-- Leaderboards: three glowing boards in the gaps between the middle bases, facing the walkway:
-- Richest (cash) and Most Rebirths on one side, Top Thieves (steals) on the other. Each shows
-- the top players worldwide, kept in an OrderedDataStore per stat (a DataStore that can list its
-- highest values). Every GameConfig.LeaderboardRefreshSeconds the server saves everyone's
-- current numbers and redraws the boards. If DataStores aren't available (Studio), a board shows
-- the players in this server instead.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Parts = require(script.Parent.Parent.Util.Parts)
local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local BOARD_WIDTH, BOARD_HEIGHT = 15, 19
local PIXELS_PER_STUD = 40
local STONE = Color3.fromRGB(38, 32, 48)
local TEXT_OUTLINE = Color3.fromRGB(20, 8, 30)
local RANK_COLORS = {
	Color3.fromRGB(255, 205, 60), -- gold
	Color3.fromRGB(215, 220, 235), -- silver
	Color3.fromRGB(225, 145, 85), -- bronze
}

type Stat = {
	key: string,
	title: string,
	color: Color3,
	value: (Player) -> number,
	format: (number) -> string,
}
local STATS: { Stat } = {
	{
		key = "Cash",
		title = "RICHEST",
		color = Theme.MoneyGreen,
		value = DataService.getCash,
		format = function(value)
			return "$" .. Format.cash(value)
		end,
	},
	{
		key = "Rebirths",
		title = "MOST REBIRTHS",
		color = Theme.RebirthPurple,
		value = DataService.getRebirths,
		format = function(value)
			return Format.cash(value)
		end,
	},
	{
		key = "Steals",
		title = "TOP THIEVES",
		color = Color3.fromRGB(255, 90, 90),
		value = DataService.getSteals,
		format = function(value)
			return Format.cash(value) .. " stolen"
		end,
	},
}

type Row = { rank: TextLabel, name: TextLabel, value: TextLabel }
type Board = { stat: Stat, store: OrderedDataStore?, rows: { Row }, footer: TextLabel }
local boards: { Board } = {}
local names: { [number]: string } = {} -- UserId -> username (looked up once)

local function label(parent: Instance, props: { [string]: any }, thickness: number): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	for key, value in props do
		(text :: any)[key] = value
	end
	text.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = TEXT_OUTLINE
	stroke.Thickness = thickness
	stroke.Parent = text
	return text
end

-- One board: a dark stone slab on two posts, with glowing trim in the stat's colour and the
-- table on its front.
local function buildBoard(parent: Instance, stat: Stat, cframe: CFrame): Board
	local model = Instance.new("Model")
	model.Name = stat.key .. "Leaderboard"
	local slab = Parts.make(model, {
		Name = "Slab",
		Size = Vector3.new(BOARD_WIDTH, BOARD_HEIGHT, 1),
		CFrame = cframe * CFrame.new(0, 3 + BOARD_HEIGHT / 2, 0),
		Color = STONE,
		Material = Enum.Material.Slate,
	})
	for _, side in { -1, 1 } do
		Parts.make(model, {
			Name = "Post",
			Size = Vector3.new(1.2, 4, 1.2),
			CFrame = cframe * CFrame.new(side * (BOARD_WIDTH / 2 - 1.5), 2, 0),
			Color = STONE,
			Material = Enum.Material.Slate,
		})
	end
	-- Glowing trim along the top and bottom edges.
	for _, y in { 3, 3 + BOARD_HEIGHT } do
		local trim = Parts.make(model, {
			Name = "Trim",
			Size = Vector3.new(BOARD_WIDTH + 0.4, 0.5, 1.3),
			CFrame = cframe * CFrame.new(0, y, 0),
			Color = stat.color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		local light = Instance.new("PointLight")
		light.Color = stat.color
		light.Range = 14
		light.Brightness = 1.2
		light.Parent = trim
	end

	-- The table, drawn on the front face and not dimmed by the night lighting.
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.Parent = slab
	local width, height = BOARD_WIDTH * PIXELS_PER_STUD, BOARD_HEIGHT * PIXELS_PER_STUD

	local title = label(gui, {
		Position = UDim2.fromOffset(20, 18),
		Size = UDim2.fromOffset(width - 40, 70),
		Text = stat.title,
		TextColor3 = Color3.new(1, 1, 1),
	}, 4)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(stat.color:Lerp(Color3.new(1, 1, 1), 0.5), stat.color)
	gradient.Rotation = 90
	gradient.Parent = title
	label(gui, {
		Position = UDim2.fromOffset(20, 92),
		Size = UDim2.fromOffset(width - 40, 28),
		Text = "TOP PLAYERS",
		TextColor3 = Color3.fromRGB(205, 190, 230),
	}, 2)

	local rows: { Row } = {}
	local top, rowHeight = 136, (height - 136 - 50) / GameConfig.LeaderboardSize
	for index = 1, GameConfig.LeaderboardSize do
		local y = top + (index - 1) * rowHeight
		local rankColor = RANK_COLORS[index] or Color3.fromRGB(170, 160, 190)
		rows[index] = {
			rank = label(gui, {
				Position = UDim2.fromOffset(24, y + 4),
				Size = UDim2.fromOffset(70, rowHeight - 8),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = rankColor,
				Text = "#" .. index,
			}, 2.5),
			name = label(gui, {
				Position = UDim2.fromOffset(100, y + 4),
				Size = UDim2.fromOffset(width - 330, rowHeight - 8),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if index <= 3 then rankColor else Color3.new(1, 1, 1),
				Text = "",
			}, 2.5),
			value = label(gui, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromOffset(width - 24, y + 4),
				Size = UDim2.fromOffset(210, rowHeight - 8),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = stat.color,
				Text = "",
			}, 2.5),
		}
	end
	local footer = label(gui, {
		Position = UDim2.fromOffset(20, height - 44),
		Size = UDim2.fromOffset(width - 40, 26),
		TextColor3 = Color3.fromRGB(150, 140, 170),
		Text = "",
	}, 1.5)

	model.Parent = parent
	local ok, store =
		pcall(DataStoreService.GetOrderedDataStore, DataStoreService, GameConfig.LeaderboardStorePrefix .. stat.key)
	return { stat = stat, store = if ok then store else nil, rows = rows, footer = footer }
end

local function nameFor(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.Name
		return player.Name
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok then name else "Player"
	return names[userId]
end

-- Saves the players in this server, then returns the top entries worldwide, or nil if the
-- DataStore can't be reached.
local function fetchGlobal(board: Board): { { userId: number, value: number } }?
	local store = board.store
	if not store then
		return nil
	end
	for _, player in Players:GetPlayers() do
		if DataService.isLoaded(player) and player.UserId > 0 then
			local value = math.clamp(math.floor(board.stat.value(player)), 0, 2 ^ 53)
			pcall(store.SetAsync, store, tostring(player.UserId), value)
		end
	end
	local ok, pages = pcall(store.GetSortedAsync, store, false, GameConfig.LeaderboardSize)
	if not ok then
		return nil
	end
	local entries = {}
	for _, entry in pages:GetCurrentPage() do
		table.insert(entries, { userId = tonumber(entry.key) or 0, value = entry.value })
	end
	return entries
end

-- The players in this server, highest first (when DataStores aren't available).
local function serverEntries(board: Board): { { userId: number, value: number } }
	local entries = {}
	for _, player in Players:GetPlayers() do
		if DataService.isLoaded(player) then
			table.insert(entries, { userId = player.UserId, value = board.stat.value(player) })
		end
	end
	table.sort(entries, function(a, b)
		return a.value > b.value
	end)
	return entries
end

local function refresh(board: Board)
	local entries = fetchGlobal(board)
	local global = entries ~= nil
	entries = entries or serverEntries(board)
	for index, row in board.rows do
		local entry = entries[index]
		if entry then
			-- Players in this server are named straight away (Studio test players have no account).
			local player = Players:GetPlayerByUserId(entry.userId)
			row.name.Text = if player then player.Name else nameFor(entry.userId)
			row.value.Text = board.stat.format(entry.value)
		else
			row.name.Text = ""
			row.value.Text = ""
		end
	end
	board.footer.Text = if global then "Updates every minute" else "Players in this server"
end

-- Puts the boards in the gaps between the two middle bases on each side of the walkway.
function LeaderboardService.start(plots)
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = workspace:FindFirstChild("GeneratedMap") or workspace

	-- The x halfway between the two middle bases, and how far each row of bases is from the walkway.
	local xs, z = {}, 0
	for _, plot in plots do
		local position = plot.cframe.Position
		if not table.find(xs, position.X) then
			table.insert(xs, position.X)
		end
		z = math.max(z, math.abs(position.Z))
	end
	table.sort(xs)
	local middle = #xs // 2
	local gapX = if #xs >= 2 then (xs[middle] + xs[middle + 1]) / 2 else 0

	local function facingWalkway(x: number, side: number): CFrame
		local position = Vector3.new(x, 0, side * z)
		return CFrame.lookAt(position, Vector3.new(x, 0, 0))
	end
	local spacing = BOARD_WIDTH / 2 + 2
	-- Seen from the walkway, Richest is on the left and Most Rebirths on the right.
	table.insert(boards, buildBoard(folder, STATS[1], facingWalkway(gapX + spacing, 1)))
	table.insert(boards, buildBoard(folder, STATS[2], facingWalkway(gapX - spacing, 1)))
	table.insert(boards, buildBoard(folder, STATS[3], facingWalkway(gapX, -1)))

	task.spawn(function()
		while true do
			LeaderboardService.refreshAll()
			task.wait(GameConfig.LeaderboardRefreshSeconds)
		end
	end)
end

function LeaderboardService.refreshAll()
	for _, board in boards do
		refresh(board)
	end
end

-- Called once a player's data has loaded, so they show up without waiting for the next refresh.
-- Players joining close together share one extra refresh a few seconds later.
local refreshQueued = false
function LeaderboardService.playerLoaded(_player: Player)
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.delay(3, function()
		refreshQueued = false
		LeaderboardService.refreshAll()
	end)
end

return LeaderboardService
