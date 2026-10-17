-- The Shop: buying items (ItemConfig) with gems or cash. The Shop window only asks (ShopBuy
-- remote); the price and currency always come from ItemConfig here, never from the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
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
	-- Reusable items (once = true) can only be bought once.
	if item.once and DataService.getItemCount(player, item.id) > 0 then
		Notify.send(player, "You already own " .. item.name .. "!", "info")
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
	Notify.send(player, "You bought " .. item.name .. "! Equip it from your Inventory.", "success")
end

-- Equips (puts in the hotbar) or unequips an owned item. Max GameConfig.MaxEquippedItems.
local function setEquipped(player: Player, itemId: unknown, equip: unknown)
	local item = typeof(itemId) == "string" and ItemConfig.byId[itemId]
	if not item or typeof(equip) ~= "boolean" or not DataService.isLoaded(player) then
		return
	end
	local equipped = table.clone(DataService.getEquipped(player))
	local index = table.find(equipped, item.id)
	if equip then
		if index or DataService.getItemCount(player, item.id) <= 0 then
			return
		end
		if #equipped >= GameConfig.MaxEquippedItems then
			Notify.send(
				player,
				`Your hotbar is full! Unequip an item first (max {GameConfig.MaxEquippedItems}).`,
				"error"
			)
			return
		end
		table.insert(equipped, item.id)
	else
		if not index then
			return
		end
		table.remove(equipped, index)
	end
	DataService.setEquipped(player, equipped)
end

function ShopService.start()
	Remotes.ShopBuy.OnServerEvent:Connect(tryBuy)
	Remotes.EquipItem.OnServerEvent:Connect(setEquipped)
end

return ShopService
