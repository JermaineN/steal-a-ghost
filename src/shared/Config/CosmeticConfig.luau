-- Cosmetics: looks with no effect on the game, sold in the Shop's Cosmetics tab and worn from the
-- Inventory's Cosmetics tab (titles from its Titles tab). One of each kind is worn at a time.
--   id          saved in players' data: never change an id once the cosmetic is live
--   kind        "title" (a TitleConfig row, `titleId`), "aura" (particles around you), "pet" (a
--               little companion that follows you), "tombstone" (your base's tombstones),
--               "flowers" (flowers by your base's graves). How each looks: CosmeticModels.
--   rarity      a GhostConfig.Rarities name: sets the card's colour
--   currency    "gems" (price) or "robux": a game pass made on the Creator Hub (Monetization →
--               Passes), its ID in `passId`; 0 = "Coming soon". Its Robux price is set there.
--   icon        an emoji shown on the card until it gets a drawn picture
local GhostConfig = require(script.Parent.GhostConfig)

local CosmeticConfig = {}

-- The kinds, in the order the Shop and Inventory list them, with the word shown on cards.
CosmeticConfig.Kinds = {
	{ id = "title", name = "Title" },
	{ id = "aura", name = "Aura" },
	{ id = "pet", name = "Pet" },
	{ id = "tombstone", name = "Tombstones" },
	{ id = "flowers", name = "Base flowers" },
}

-- stylua: ignore
CosmeticConfig.Cosmetics = {
	{ id = "title_phantom",   kind = "title",     titleId = "phantom",   name = "PHANTOM title",   description = "A ghostly title",           rarity = "Epic",      currency = "gems",  price = 500,  icon = "👻" },
	{ id = "title_nightmare", kind = "title",     titleId = "nightmare", name = "NIGHTMARE title", description = "A blood-red shiny title",   rarity = "Mythic",    currency = "robux", passId = 2038366859,   icon = "😈" },
	{ id = "aura_purple",     kind = "aura",      name = "Purple Flames",   description = "Spooky flames around you",  rarity = "Epic",      currency = "gems",  price = 750,  icon = "🔥" },
	{ id = "aura_golden",     kind = "aura",      name = "Golden Sparkles", description = "Glitter wherever you go",   rarity = "Legendary", currency = "robux", passId = 2039740559,   icon = "✨" },
	{ id = "pet_pumpkin",     kind = "pet",       name = "Mini Pumpkin",    description = "Follows you around", rarity = "Legendary", currency = "gems", price = 1000, icon = "🎃" },
	-- Looks like a ghost you've found, picked with "Equip as pet" in the Index (Wisp until then).
	{ id = "pet_ghost",       kind = "pet",       name = "Ghost Buddy",     description = "Any ghost you've found",    rarity = "Mythic",    currency = "robux", passId = 2038216814,   icon = "👻" },
	{ id = "tomb_gold",       kind = "tombstone", name = "Gold Tombstones", description = "Gold graves at your base", rarity = "Legendary", currency = "gems", price = 1500, icon = "🏆" },
	{ id = "flowers_lily",    kind = "flowers",   name = "Ghost Lilies",    description = "Glowing flowers at your base", rarity = "Rare", currency = "gems", price = 400,  icon = "🌸" },
}

CosmeticConfig.byId = {}
CosmeticConfig.byPassId = {}
CosmeticConfig.kindName = {}
for _, kind in CosmeticConfig.Kinds do
	CosmeticConfig.kindName[kind.id] = kind.name
end
for _, cosmetic in CosmeticConfig.Cosmetics do
	cosmetic.color = GhostConfig.Rarities[cosmetic.rarity].color
	CosmeticConfig.byId[cosmetic.id] = cosmetic
	if cosmetic.currency == "robux" and cosmetic.passId ~= 0 then
		CosmeticConfig.byPassId[cosmetic.passId] = cosmetic
	end
end

-- Does the player own this cosmetic? Works on both sides ("Cosmetic_<id>" attribute).
function CosmeticConfig.owns(player: Player, cosmeticId: string): boolean
	return player:GetAttribute("Cosmetic_" .. cosmeticId) == true
end

return CosmeticConfig
