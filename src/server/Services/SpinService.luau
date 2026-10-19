-- The Spin Wheel: players earn spins (one free each day, plus one for every
-- GameConfig.SpinOnlineSeconds played in a row) and use them in the Spin window. The server
-- picks the prize (GameConfig.SpinPrizes, by weight), tells the spinner's device where the wheel
-- lands (SpinResult), and pays out once the wheel has stopped.
-- Attributes for the player's device:
--   "Spins"           unused spins (set by DataService)
--   "NextSpinAt"      server time (workspace:GetServerTimeNow) the next online spin arrives
--   "MoneyBoostUntil" server time the income boost ends (missing = no boost)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyReward = require(ReplicatedStorage.Shared.DailyReward)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local StoreConfig = require(ReplicatedStorage.Shared.Config.StoreConfig)
local Notify = require(script.Parent.Parent.Util.Notify)
local DataService = require(script.Parent.DataService)

local SpinService = {}

-- The prize each player is waiting for while their wheel spins (paid out when it stops, or
-- straight away if they leave first).
local pending: { [Player]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

-- "10 mins", "30 mins", "1 min".
local function minutesText(seconds: number): string
	local minutes = math.floor(seconds / 60 + 0.5)
	return minutes .. (if minutes == 1 then " min" else " mins")
end

-- A prize's name, for messages.
function SpinService.prizeName(prize): string
	if prize.kind == "gems" then
		return prize.amount .. " gems"
	elseif prize.kind == "boost" then
		return `x{GameConfig.SpinBoostMultiplier} money for {minutesText(prize.seconds)}`
	else
		local item = ItemConfig.byId[prize.itemId]
		return if item then item.name else prize.itemId
	end
end

-- Picks a prize index at random, each one as likely as its weight.
local function rollPrize(): number
	local total = 0
	for _, prize in GameConfig.SpinPrizes do
		total += prize.weight
	end
	local roll = math.random() * total
	for index, prize in GameConfig.SpinPrizes do
		roll -= prize.weight
		if roll <= 0 then
			return index
		end
	end
	return #GameConfig.SpinPrizes
end

-- Starts (or lengthens) the income boost. Winning another adds its time on top. The Shop's 2x
-- Money booster (StoreService) uses this too.
function SpinService.addMoneyBoost(player: Player, seconds: number)
	local untilTime = math.max(now(), player:GetAttribute("MoneyBoostUntil") or 0) + seconds
	player:SetAttribute("MoneyBoostUntil", untilTime)
	DataService.setMoneyBoostLeft(player, untilTime - now())
end

-- Pays the prize and returns its name for the message (gems include any VIP bonus).
local function payOut(player: Player, index: number): string
	local prize = GameConfig.SpinPrizes[index]
	if prize.kind == "gems" then
		return DataService.earnGems(player, prize.amount) .. " gems"
	elseif prize.kind == "boost" then
		SpinService.addMoneyBoost(player, prize.seconds)
	else
		DataService.addItem(player, prize.itemId, 1)
	end
	return SpinService.prizeName(prize)
end

local function trySpin(player: Player)
	if pending[player] or not DataService.isLoaded(player) or DataService.getSpins(player) <= 0 then
		return
	end
	local index = rollPrize()
	DataService.addSpins(player, -1)
	pending[player] = index
	Remotes.SpinResult:FireClient(player, index)
	task.delay(GameConfig.SpinSeconds, function()
		if pending[player] ~= index or not DataService.isLoaded(player) then
			return
		end
		pending[player] = nil
		Notify.send(player, "You won " .. payOut(player, index) .. "!", "success")
	end)
end

-- Gives today's free spin if they haven't had it yet.
local function checkDaily(player: Player)
	local today = DailyReward.today()
	if DataService.getSpinDay(player) ~= today then
		DataService.setSpinDay(player, today)
		DataService.addSpins(player, 1)
		Notify.send(player, "Your free daily spin is ready! Press Spin.", "success")
	end
end

-- Every second: online spins, the daily spin at midnight, and the boost counting down.
local function tick()
	local time = now()
	for _, player in Players:GetPlayers() do
		if not DataService.isLoaded(player) then
			continue
		end
		local nextAt = player:GetAttribute("NextSpinAt")
		if nextAt and time >= nextAt then
			player:SetAttribute("NextSpinAt", nextAt + GameConfig.SpinOnlineSeconds)
			-- VIP pass owners get more each time.
			local count = if StoreConfig.ownsPass(player, "vip") then GameConfig.VipOnlineSpins else 1
			DataService.addSpins(player, count)
			local spinsText = if count == 1 then "a spin" else `{count} spins`
			Notify.send(
				player,
				`You earned {spinsText} for playing {minutesText(GameConfig.SpinOnlineSeconds)}!`,
				"success"
			)
		end
		checkDaily(player)

		local boostUntil = player:GetAttribute("MoneyBoostUntil")
		if boostUntil then
			-- Saved as time left, so it pauses while they're offline.
			DataService.setMoneyBoostLeft(player, boostUntil - time)
			if time >= boostUntil then
				player:SetAttribute("MoneyBoostUntil", nil)
				Notify.send(player, "Your money boost has ended.", "info")
			end
		end
	end
end

-- Called once the player's data has loaded.
function SpinService.playerLoaded(player: Player)
	-- The online timer starts over every time they join.
	player:SetAttribute("NextSpinAt", now() + GameConfig.SpinOnlineSeconds)
	local boostLeft = DataService.getMoneyBoostLeft(player)
	if boostLeft > 0 then
		player:SetAttribute("MoneyBoostUntil", now() + boostLeft)
	end
	checkDaily(player)
end

-- Called before their data saves: a prize still spinning is paid now.
function SpinService.playerRemoving(player: Player)
	local index = pending[player]
	pending[player] = nil
	if index then
		payOut(player, index)
	end
end

function SpinService.start()
	Remotes.Spin.OnServerEvent:Connect(trySpin)
	task.spawn(function()
		while true do
			task.wait(1)
			tick()
		end
	end)
end

return SpinService
