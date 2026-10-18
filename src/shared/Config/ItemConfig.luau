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
-- Removing an item: take its row out and add it to RETIRED_ITEMS in DataService, so anyone who
-- bought it gets refunded.
local ItemConfig = {}

-- stylua: ignore
ItemConfig.Items = {
	{ id = "smoke_bomb", name = "Smoke Bomb", description = "Vanish in a puff of smoke", price = 125, currency = "gems", color = Color3.fromRGB(175, 95, 255), image = "rbxassetid://109587585269112", once = true, tool = true },
	{ id = "universal_key", name = "Universal Key", description = "Unlock any locked base", price = 250, currency = "gems", color = Color3.fromRGB(255, 190, 40), image = "rbxassetid://86142974980494", once = true, tool = true },
	{ id = "polterpuller", name = "PolterPuller 4000", description = "Capture ghosts straight home", price = 550, currency = "gems", color = Color3.fromRGB(120, 255, 130), image = "rbxassetid://110348892274923", once = true, tool = true },
	{ id = "shield",     name = "Shield",     description = "Shrug off knockbacks and cages", price = 150, currency = "gems", color = Color3.fromRGB(80, 200, 255), image = "rbxassetid://108221968843411", once = true, tool = true },
	{ id = "gravity",    name = "Gravity",    description = "Pull everyone toward you",  price = 350, currency = "gems", color = Color3.fromRGB(110, 60, 200),  image = "rbxassetid://100121928705722", once = true, tool = true },
}

ItemConfig.byId = {}
for _, item in ItemConfig.Items do
	ItemConfig.byId[item.id] = item
end

return ItemConfig
