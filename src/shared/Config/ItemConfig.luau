-- Everything sold in the Shop (side menu → Shop). Bought items are saved and listed in the
-- Inventory (side menu → Inventory). To add an item, add a row below.
--   id          saved in players' data: never change an id once the item is live
--   name        shown on its card
--   description one short line under the name
--   price       how much it costs
--   currency    "gems" or "cash"
--   rarity      one of GhostConfig.Rarities (Rare, Epic, Legendary, Mythic, ...): sets the item's
--               colour (card background and outline in the Shop, Inventory and hotbar)
--   image       the card's picture (an rbxassetid://); "" shows a "?" until there is one
--   once        true = can only be bought once (a reusable item, not a stack)
--   shop        false = not sold in the Shop (won some other way, e.g. the Spin Wheel)
--   tool        true = equipping it puts a usable tool (named by its id) in the hotbar; what it
--               does is built in ItemService
--
-- Removing an item: take its row out and add it to RETIRED_ITEMS in DataService, so anyone who
-- bought it gets refunded.
local GhostConfig = require(script.Parent.GhostConfig)

local ItemConfig = {}

-- stylua: ignore
ItemConfig.Items = {
	{ id = "smoke_bomb", name = "Smoke Bomb", description = "Vanish in a puff of smoke", price = 250, currency = "gems", rarity = "Epic", image = "rbxassetid://109587585269112", once = true, tool = true },
	{ id = "universal_key", name = "Universal Key", description = "Unlock any locked base", price = 500, currency = "gems", rarity = "Legendary", image = "rbxassetid://86142974980494", once = true, tool = true },
	{ id = "mega_mallet", name = "Mega Mallet", description = "Slam the ground, launch everyone", price = 2000, currency = "gems", rarity = "Mythic", image = "rbxassetid://78467553699874", once = true, tool = true },
	{ id = "polterpuller", name = "PolterPuller 4000", description = "Capture ghosts straight home", price = 1100, currency = "gems", rarity = "Legendary", image = "rbxassetid://110348892274923", once = true, tool = true },
	{ id = "tennis_racket", name = "Tennis Racket", description = "A bat that knocks people further", price = 200, currency = "gems", rarity = "Rare", image = "rbxassetid://95075449356080", once = true, tool = true },
	{ id = "shield",     name = "Shield",     description = "Shrug off knockbacks and cages", price = 300, currency = "gems", rarity = "Epic", image = "rbxassetid://108221968843411", once = true, tool = true },
	{ id = "gravity",    name = "Gravity",    description = "Pull everyone toward you",  price = 700, currency = "gems", rarity = "Legendary", image = "rbxassetid://100121928705722", once = true, tool = true },
	-- The Spin Wheel's Mythic prize (GameConfig.SpinPrizes); not sold in the Shop. It replaced the
	-- old "mythic_placeholder" item (DataService renames it in saves).
	{ id = "nuke",       name = "Nuke",       description = "Launch everyone off the map", price = 0, currency = "gems", rarity = "Mythic", image = "rbxassetid://81602201807177", once = true, shop = false, tool = true },
}

-- Rarities of the hotbar tools that aren't Shop items (the Bat has none and stays brown).
ItemConfig.ToolRarities = {
	Cage = "Mythic",
	Landmine = "Mythic",
}

-- A rarity's colour (the same colours as the ghosts').
function ItemConfig.rarityColor(rarity: string): Color3
	return GhostConfig.Rarities[rarity].color
end

-- A copy of a list of rows with a `rarity` (Shop items, cosmetics), rarest first. Rows of the
-- same rarity keep their order in the list.
function ItemConfig.sortByRarity(list: { any }): { any }
	local position = {}
	local sorted = table.clone(list)
	for index, row in sorted do
		position[row] = index
	end
	table.sort(sorted, function(a, b)
		local rankA, rankB = GhostConfig.Rarities[a.rarity].order, GhostConfig.Rarities[b.rarity].order
		if rankA ~= rankB then
			return rankA > rankB
		end
		return position[a] < position[b]
	end)
	return sorted
end

ItemConfig.byId = {}
for _, item in ItemConfig.Items do
	item.color = ItemConfig.rarityColor(item.rarity)
	ItemConfig.byId[item.id] = item
end

return ItemConfig
