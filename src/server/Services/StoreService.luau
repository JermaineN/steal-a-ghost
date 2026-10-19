-- The Shop's Boosters, Currency and Gamepasses tabs (StoreConfig; the Items tab is ShopService).
--   Boosters (gems, BuyBooster remote): 2x Money adds to the Spin Wheel's money boost
--   (SpinService); Speed Boost sets the "SpeedBoostUntil" player attribute (Shared.Upgrades adds
--   the speed, UpgradeService applies it) and is saved as time left, so it pauses offline; Server
--   Luck sets "LuckBoostUntil" on ReplicatedStorage for the whole server (GhostService reads it).
--   Gem packs (Robux Developer Products): paid out in ProcessReceipt. Roblox keeps calling it
--   until we say PurchaseGranted, and each purchase id is remembered so none is paid twice.
--   Game passes (Robux): owned passes are "Pass_<id>" = true player attributes, checked on join
--   and set straight away when one is bought here.
-- The Robux prompts themselves are opened by the Shop window on the player's device.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local StoreConfig = require(ReplicatedStorage.Shared.Config.StoreConfig)
local Notify = require(script.Parent.Parent.Util.Notify)
local DataService = require(script.Parent.DataService)
local SpinService = require(script.Parent.SpinService)
local TitleService = require(script.Parent.TitleService)

local StoreService = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function minutesText(seconds: number): string
	return `{math.round(seconds / 60)} min`
end

-- Adds `seconds` to a boost that ends at the `attribute` on `holder` (stacks on any time left).
local function extend(holder: Instance, attribute: string, seconds: number): number
	local untilTime = math.max(now(), holder:GetAttribute(attribute) or 0) + seconds
	holder:SetAttribute(attribute, untilTime)
	return untilTime
end

local function buyBooster(player: Player, boosterId: unknown)
	local booster = typeof(boosterId) == "string" and StoreConfig.boosterById[boosterId]
	if not booster or not DataService.isLoaded(player) then
		return
	end
	if not DataService.spendGems(player, booster.price) then
		Notify.send(player, `Not enough gems for {booster.name} ({Format.cash(booster.price)} gems).`, "error")
		return
	end
	if booster.spins then
		DataService.addSpins(player, booster.spins)
		Notify.send(player, `+{booster.spins} {if booster.spins == 1 then "spin" else "spins"}!`, "success", {
			note = "Open the Spin Wheel to use them",
		})
	elseif booster.id == "money" then
		SpinService.addMoneyBoost(player, booster.seconds)
		Notify.send(player, `2x Money for {minutesText(booster.seconds)}!`, "success")
	elseif booster.id == "speed" then
		local untilTime = extend(player, "SpeedBoostUntil", booster.seconds)
		DataService.setBoostLeft(player, "speed", untilTime - now())
		Notify.send(player, `Speed Boost for {minutesText(booster.seconds)}!`, "success")
	elseif booster.id == "luck" then
		extend(ReplicatedStorage, "LuckBoostUntil", booster.seconds)
		for _, other in Players:GetPlayers() do
			Notify.send(
				other,
				`{player.DisplayName} started Server Luck!`,
				"success",
				{ note = `Rarer ghosts for everyone, {minutesText(booster.seconds)}` }
			)
		end
	end
end

-- Every second: boosters counting down and ending.
local function tick()
	local time = now()
	for _, player in Players:GetPlayers() do
		local speedUntil = player:GetAttribute("SpeedBoostUntil")
		if speedUntil and DataService.isLoaded(player) then
			-- Saved as time left, so it pauses while they're offline.
			DataService.setBoostLeft(player, "speed", speedUntil - time)
			if time >= speedUntil then
				player:SetAttribute("SpeedBoostUntil", nil)
				Notify.send(player, "Your Speed Boost has ended.", "info")
			end
		end
	end
	local luckUntil = ReplicatedStorage:GetAttribute("LuckBoostUntil")
	if luckUntil and time >= luckUntil then
		ReplicatedStorage:SetAttribute("LuckBoostUntil", nil)
		for _, player in Players:GetPlayers() do
			Notify.send(player, "Server Luck has ended.", "info")
		end
	end
end

-- Robux gem packs. Roblox calls this for every purchase (again later if we don't grant it).
local function processReceipt(receipt): Enum.ProductPurchaseDecision
	local pack = StoreConfig.packByProductId[receipt.ProductId]
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not pack or not player or not DataService.isLoaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if DataService.hasReceipt(player, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	-- If this session won't save (their data failed to load), wait: Roblox offers it again when
	-- they next join. (Studio test purchases are paid out anyway.)
	if not DataService.canSave(player) and not RunService:IsStudio() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService.addGems(player, pack.gems)
	DataService.addReceipt(player, purchaseId)
	DataService.saveNow(player)
	Notify.send(player, `+{Format.cash(pack.gems)} gems! Thank you!`, "success")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function givePass(player: Player, pass)
	player:SetAttribute("Pass_" .. pass.id, true)
end

-- Called once the player's data has loaded (before TitleService, so the VIP title counts).
function StoreService.playerLoaded(player: Player)
	for _, pass in StoreConfig.Passes do
		if pass.passId ~= 0 then
			local ok, owns =
				pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.passId)
			if ok and owns then
				givePass(player, pass)
			elseif not ok then
				warn(`[StoreService] Couldn't check {player.Name}'s {pass.name} pass: {owns}`)
			end
		end
	end
	local speedLeft = DataService.getBoostLeft(player, "speed")
	if speedLeft > 0 then
		player:SetAttribute("SpeedBoostUntil", now() + speedLeft)
	end
end

function StoreService.start()
	Remotes.BuyBooster.OnServerEvent:Connect(buyBooster)
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		local pass = StoreConfig.passByPassId[gamePassId]
		if not purchased or not pass or not player.Parent then
			return
		end
		givePass(player, pass)
		Notify.send(player, `You got {pass.name}! Thank you!`, "success")
		TitleService.unlockBought(player)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			tick()
		end
	end)
end

return StoreService
