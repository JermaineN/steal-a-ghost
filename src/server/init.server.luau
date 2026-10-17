-- Server entry point: builds the map, starts every service, and handles players joining/leaving.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local Services = script.Services
local MapBuilder = require(Services.MapBuilder)
local DataService = require(Services.DataService)
local PlotService = require(Services.PlotService)
local GhostService = require(Services.GhostService)
local StealService = require(Services.StealService)
local LockService = require(Services.LockService)
local EconomyService = require(Services.EconomyService)
local RagdollService = require(Services.RagdollService)
local CageService = require(Services.CageService)
local LandmineService = require(Services.LandmineService)
local IndexService = require(Services.IndexService)
local ItemService = require(Services.ItemService)
local RebirthService = require(Services.RebirthService)
local HauntedHourService = require(Services.HauntedHourService)
local FriendBoostService = require(Services.FriendBoostService)
local ShopService = require(Services.ShopService)
local DailyRewardService = require(Services.DailyRewardService)
local TutorialService = require(Services.TutorialService)
local LeaderboardService = require(Services.LeaderboardService)
local UpgradeService = require(Services.UpgradeService)
local OfflineService = require(Services.OfflineService)
local SmokeBombService = require(Services.SmokeBombService)
local GravityService = require(Services.GravityService)

local map = MapBuilder.build()
PlotService.start(map.plots)
DataService.start()
GhostService.start(map)
StealService.start()
LockService.start(map.plots)
EconomyService.start(map.plots)
RagdollService.start()
CageService.start()
LandmineService.start()
IndexService.start()
ItemService.start()
RebirthService.start()
HauntedHourService.start()
FriendBoostService.start()
ShopService.start()
DailyRewardService.start()
TutorialService.start()
LeaderboardService.start(map.plots)
UpgradeService.start(map.plots)
SmokeBombService.start()
GravityService.start()

-- Every new character walks at GameConfig.WalkSpeed (StealService slows thieves down).
local function applyWalkSpeed(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.WalkSpeed = GameConfig.WalkSpeed
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(applyWalkSpeed)
	if player.Character then
		task.spawn(applyWalkSpeed, player.Character)
	end
	PlotService.playerAdded(player)
	LockService.playerAdded(player)
	if DataService.playerAdded(player) then
		TutorialService.playerLoaded(player)
		UpgradeService.playerLoaded(player)
		GhostService.loadGhosts(player)
		OfflineService.playerLoaded(player)
		DailyRewardService.playerLoaded(player)
		LeaderboardService.playerLoaded(player)
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
