-- What the Shop's Boosters, Currency and Gamepasses tabs sell (the Items tab is ItemConfig).
-- What each one does is tuned in GameConfig (LuckBoostMultiplier, PassMoneyMultiplier, ...).
--
-- Robux purchases need a product made on the Creator Hub (Creator Hub → your experience →
-- Monetization → Developer Products for gem packs, Passes for game passes). Paste its ID below;
-- while an ID is 0 the card says "Coming soon" and can't be bought. The Robux price shown on a
-- card is read from Roblox, so set prices on the Creator Hub only.
--
-- Every id is saved in players' data or used as an attribute name: never change one once live.
-- `icon` is an emoji shown until the card gets a drawn picture.
local Theme = require(script.Parent.Parent.Theme)

local StoreConfig = {}

-- Bought with gems; each one adds its time (stacks). Money and Speed are yours and pause while
-- you're offline; Server Luck is for everyone in the server and ends when the server does.
--   money: income × GameConfig.SpinBoostMultiplier (the same boost as the Spin Wheel's prize)
--   luck:  rarer walkway ghosts (GameConfig.LuckBoostMultiplier / LuckBoostMinRarity)
--   speed: + GameConfig.SpeedBoostBonus walk speed
-- Rows with `spins` instead of `seconds` give that many Spin Wheel spins straight away.
-- stylua: ignore
StoreConfig.Boosters = {
	{ id = "money",   name = "2x Money",     description = "Double income for 15 min",       price = 150, seconds = 15 * 60, icon = "💰", color = Theme.MoneyGreen },
	{ id = "luck",    name = "Server Luck",  description = "Rarer ghosts for all, 15 min",   price = 250, seconds = 15 * 60, icon = "🍀", color = Color3.fromRGB(120, 230, 90) },
	{ id = "speed",   name = "Speed Boost",  description = "+30% walk speed for 10 min",     price = 75,  seconds = 10 * 60, icon = "⚡", color = Color3.fromRGB(255, 200, 40) },
	{ id = "spins_1", name = "1 Spin",       description = "One spin of the Spin Wheel",     price = 60,  spins = 1,         icon = "🎡", color = Color3.fromRGB(170, 90, 255) },
	{ id = "spins_2", name = "2 Spins",      description = "Two spins of the Spin Wheel",    price = 110, spins = 2,         icon = "🎡", color = Color3.fromRGB(170, 90, 255) },
	{ id = "spins_3", name = "3 Spins",      description = "Three spins of the Spin Wheel",  price = 150, spins = 3,         icon = "🎡", color = Color3.fromRGB(170, 90, 255) },
}

-- Gem packs, bought with Robux (Developer Products). `bonus` is just the label on the card.
-- stylua: ignore
StoreConfig.GemPacks = {
	{ id = "gems_500",  gems = 500,  productId = 0 },
	{ id = "gems_1200", gems = 1200, productId = 0, bonus = "+20% bonus" },
	{ id = "gems_3000", gems = 3000, productId = 0, bonus = "+50% bonus" },
	{ id = "gems_8000", gems = 8000, productId = 0, bonus = "BEST VALUE" },
}

-- Game passes, bought once with Robux. Owning one sets the "Pass_<id>" player attribute.
-- stylua: ignore
StoreConfig.Passes = {
	{ id = "double_money", name = "2x Money",          description = "Double income forever",         passId = 0, icon = "💵", color = Theme.MoneyGreen },
	{ id = "vip",          name = "VIP",               description = "VIP title and +10% income",     passId = 0, icon = "👑", color = Color3.fromRGB(255, 200, 40) },
	{ id = "extra_slot",   name = "Extra Hotbar Slot", description = "Equip one more item",           passId = 0, icon = "🎒", color = Color3.fromRGB(255, 140, 30) },
	{ id = "fast_flight",  name = "Fast Flight",       description = "Ghosts fly home 2x faster", passId = 0, icon = "🚀", color = Color3.fromRGB(90, 170, 255) },
	{ id = "auto_collect", name = "Auto Collect",      description = "Income goes right to cash", passId = 0, icon = "🧲", color = Color3.fromRGB(230, 70, 90) },
}

StoreConfig.boosterById = {}
for _, booster in StoreConfig.Boosters do
	StoreConfig.boosterById[booster.id] = booster
end
StoreConfig.packByProductId = {}
for _, pack in StoreConfig.GemPacks do
	if pack.productId ~= 0 then
		StoreConfig.packByProductId[pack.productId] = pack
	end
end
StoreConfig.passById = {}
StoreConfig.passByPassId = {}
for _, pass in StoreConfig.Passes do
	StoreConfig.passById[pass.id] = pass
	if pass.passId ~= 0 then
		StoreConfig.passByPassId[pass.passId] = pass
	end
end

-- Does the player own this game pass? Works on both sides (reads the "Pass_<id>" attribute).
function StoreConfig.ownsPass(player: Player, passId: string): boolean
	return player:GetAttribute("Pass_" .. passId) == true
end

return StoreConfig
