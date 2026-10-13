-- Server entry point: builds the map, starts every service, and handles players joining/leaving.
local Players = game:GetService("Players")

local Services = script.Services
local MapBuilder = require(Services.MapBuilder)
local DataService = require(Services.DataService)
local PlotService = require(Services.PlotService)
local GhostService = require(Services.GhostService)
local StealService = require(Services.StealService)
local LockService = require(Services.LockService)
local EconomyService = require(Services.EconomyService)

local map = MapBuilder.build()
PlotService.start(map.plots)
DataService.start()
GhostService.start(map)
StealService.start()
LockService.start(map.plots)
EconomyService.start()

local function onPlayerAdded(player: Player)
	PlotService.playerAdded(player)
	if DataService.playerAdded(player) then
		GhostService.loadGhosts(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	-- Order matters: cancel any steals first, then clear the base, then save.
	StealService.playerRemoving(player)
	GhostService.playerRemoving(player)
	PlotService.playerRemoving(player)
	DataService.playerRemoving(player)
end)

game:BindToClose(DataService.saveAll)
