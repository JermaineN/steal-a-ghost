-- Daily rewards: once per day (midnight UTC), a player can claim gems; claiming on consecutive
-- days grows the reward (GameConfig.DailyRewardGems, maths in Shared.DailyReward). Each player
-- gets attributes for their device: "DailyAvailable" (can claim now), "DailyStreakDay" (the
-- streak day they can claim, or last claimed). The window only asks (DailyClaim remote).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyReward = require(ReplicatedStorage.Shared.DailyReward)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notify = require(script.Parent.Parent.Util.Notify)
local DataService = require(script.Parent.DataService)

local DailyRewardService = {}

-- Works out whether the player can claim today and shows it to their device.
local function refresh(player: Player)
	local daily = DataService.getDaily(player)
	if not daily then
		return
	end
	local available, streakDay = DailyReward.check(daily.day, daily.streak, DailyReward.today())
	player:SetAttribute("DailyStreakDay", streakDay)
	player:SetAttribute("DailyAvailable", available)
end

local function claim(player: Player)
	local daily = DataService.getDaily(player)
	if not daily then
		return
	end
	local today = DailyReward.today()
	local available, streakDay = DailyReward.check(daily.day, daily.streak, today)
	if not available then
		return
	end
	DataService.setDaily(player, today, streakDay)
	local gems = DataService.earnGems(player, DailyReward.gems(streakDay))
	refresh(player)
	Notify.send(player, `Day {streakDay} reward: +{gems} gems! Come back tomorrow for more.`, "success")
end

-- Called once the player's data has loaded.
function DailyRewardService.playerLoaded(player: Player)
	refresh(player)
end

function DailyRewardService.start()
	Remotes.DailyClaim.OnServerEvent:Connect(claim)
	-- Someone still playing at midnight gets the next day's reward without rejoining.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("DailyAvailable") == false then
					refresh(player)
				end
			end
		end
	end)
end

return DailyRewardService
