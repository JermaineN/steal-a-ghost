-- Server entry point: builds the map, starts every service, and handles players joining/leaving.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Upgrades = require(ReplicatedStorage.Shared.Upgrades)

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
local UniversalKeyService = require(Services.UniversalKeyService)
local CaptureService = require(Services.CaptureService)
local ShieldService = require(Services.ShieldService)
local MalletService = require(Services.MalletService)
local TitleService = require(Services.TitleService)
local SpinService = require(Services.SpinService)

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
UniversalKeyService.start()
CaptureService.start()
ShieldService.start()
MalletService.start()
TitleService.start()
SpinService.start()

-- Every new character walks at GameConfig.WalkSpeed plus their Speed upgrade (StealService
-- slows thieves down; UpgradeService applies a newly bought level straight away).
local function applyWalkSpeed(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.WalkSpeed = Upgrades.walkSpeed(player)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		applyWalkSpeed(player, character)
	end)
	if player.Character then
		task.spawn(applyWalkSpeed, player, player.Character)
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
		TitleService.playerLoaded(player)
		SpinService.playerLoaded(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	-- Order matters: settle any steals and captures first, then clear the base, then save.
	StealService.playerRemoving(player)
	CaptureService.playerRemoving(player)
	GhostService.playerRemoving(player)
	PlotService.playerRemoving(player)
	SpinService.playerRemoving(player) -- pays a prize still spinning
	DataService.playerRemoving(player)
end)

game:BindToClose(DataService.saveAll)
