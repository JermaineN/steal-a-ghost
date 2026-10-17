-- Everything sold in the Shop (side menu → Shop). Bought items are saved and listed in the
-- Inventory (side menu → Inventory). To add an item, add a row below.
--   id          saved in players' data: never change an id once the item is live
--   name        shown on its card
--   description one short line under the name
--   price       how much it costs
--   currency    "gems" or "cash"
--   color       the card's accent colour
--   image       the card's picture (an rbxassetid://); "" shows a "?" until there is one
--   once        true = can only be bought once (a reusable item, not a stack)
--   tool        true = equipping it puts a usable tool (named by its id) in the hotbar; what it
--               does is built in ItemService
--
-- The "Placeholder Item" rows are stand-ins so the Shop and Inventory work end to end. They can
-- be bought and are saved, but don't do anything. Replace them with real items.
local ItemConfig = {}

-- stylua: ignore
ItemConfig.Items = {
	{ id = "smoke_bomb", name = "Smoke Bomb", description = "Vanish in a puff of smoke", price = 125, currency = "gems", color = Color3.fromRGB(175, 95, 255), image = "rbxassetid://109587585269112", once = true, tool = true },
	{ id = "item_1", name = "Placeholder Item 1", description = "Design me!", price = 25,     currency = "gems", color = Color3.fromRGB(80, 190, 255),  image = "" },
	{ id = "item_2", name = "Placeholder Item 2", description = "Design me!", price = 75,     currency = "gems", color = Color3.fromRGB(175, 95, 255),  image = "" },
	{ id = "item_3", name = "Placeholder Item 3", description = "Design me!", price = 200,    currency = "gems", color = Color3.fromRGB(255, 190, 40),  image = "" },
	{ id = "item_4", name = "Placeholder Item 4", description = "Design me!", price = 5000,   currency = "cash", color = Color3.fromRGB(60, 255, 60),   image = "" },
	{ id = "item_5", name = "Placeholder Item 5", description = "Design me!", price = 50000,  currency = "cash", color = Color3.fromRGB(255, 140, 30),  image = "" },
	{ id = "item_6", name = "Placeholder Item 6", description = "Design me!", price = 500000, currency = "cash", color = Color3.fromRGB(255, 60, 90),   image = "" },
}

ItemConfig.byId = {}
for _, item in ItemConfig.Items do
	ItemConfig.byId[item.id] = item
end

return ItemConfig
