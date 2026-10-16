-- The Shop: buying items (ItemConfig) with gems or cash. The Shop window only asks (ShopBuy
-- remote); the price and currency always come from ItemConfig here, never from the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notify = require(script.Parent.Parent.Util.Notify)
local DataService = require(script.Parent.DataService)

local ShopService = {}

local function tryBuy(player: Player, itemId: unknown)
	local item = typeof(itemId) == "string" and ItemConfig.byId[itemId]
	if not item or not DataService.isLoaded(player) then
		return
	end
	local paid = if item.currency == "gems"
		then DataService.spendGems(player, item.price)
		else DataService.spendCash(player, item.price)
	if not paid then
		local cost = if item.currency == "gems"
			then Format.cash(item.price) .. " gems"
			else "$" .. Format.cash(item.price)
		Notify.send(player, "Not enough for " .. item.name .. " (" .. cost .. ").", "error")
		return
	end
	DataService.addItem(player, item.id, 1)
	Notify.send(player, "You bought " .. item.name .. "! It's in your Inventory.", "success")
end

function ShopService.start()
	Remotes.ShopBuy.OnServerEvent:Connect(tryBuy)
end

return ShopService
