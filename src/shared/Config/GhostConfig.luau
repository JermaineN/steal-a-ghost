-- Every ghost in the game. To add a ghost, add a row to Ghosts below.
--   price       cost on the walkway
--   income      cash per second while it sits in your base
--   spawnWeight how often it appears on the walkway (higher = more common)
local GhostConfig = {}

-- indexGems: the one-time gem reward for finding a ghost of that rarity (claimed in the Index).
GhostConfig.Rarities = {
	Common = { order = 1, color = Color3.fromRGB(210, 210, 210), indexGems = 5 },
	Uncommon = { order = 2, color = Color3.fromRGB(90, 220, 110), indexGems = 10 },
	Rare = { order = 3, color = Color3.fromRGB(80, 150, 255), indexGems = 20 },
	Epic = { order = 4, color = Color3.fromRGB(180, 90, 255), indexGems = 40 },
	Legendary = { order = 5, color = Color3.fromRGB(255, 190, 40), indexGems = 75 },
	Mythic = { order = 6, color = Color3.fromRGB(255, 60, 90), indexGems = 150 },
	Divine = { order = 7, color = Color3.fromRGB(150, 205, 255), indexGems = 300 },
	Secret = { order = 8, color = Color3.fromRGB(230, 230, 240), indexGems = 600 },
}

-- stylua: ignore
GhostConfig.Ghosts = {
	{ id = "wisp",           name = "Wisp",           rarity = "Common",    price = 25,     income = 1,    spawnWeight = 40,  size = 2.5, color = Color3.fromRGB(230, 240, 255) },
	{ id = "boo",            name = "Boo",            rarity = "Common",    price = 100,    income = 3,    spawnWeight = 30,  size = 3,   color = Color3.fromRGB(255, 255, 255) },
	{ id = "sheet_ghost",    name = "Sheet Ghost",    rarity = "Uncommon",  price = 400,    income = 10,   spawnWeight = 18,  size = 3.2, color = Color3.fromRGB(245, 235, 220) },
	{ id = "poltergeist",    name = "Poltergeist",    rarity = "Rare",      price = 1500,   income = 30,   spawnWeight = 10,  size = 3.5, color = Color3.fromRGB(110, 230, 120) },
	{ id = "banshee",        name = "Banshee",        rarity = "Epic",      price = 6000,   income = 100,  spawnWeight = 5,   size = 3.8, color = Color3.fromRGB(190, 140, 255) },
	{ id = "phantom_knight", name = "Phantom Knight", rarity = "Legendary", price = 25000,  income = 350,  spawnWeight = 2.5, size = 4.2, color = Color3.fromRGB(120, 255, 200) },
	{ id = "wraith",         name = "Wraith",         rarity = "Legendary", price = 100000, income = 1200, spawnWeight = 1.2, size = 4.6, color = Color3.fromRGB(70, 70, 100) },
	{ id = "spectre_king",   name = "Spectre King",   rarity = "Mythic",    price = 500000, income = 5000, spawnWeight = 0.4, size = 5.2, color = Color3.fromRGB(255, 215, 90) },
	-- PLACEHOLDERS: rename these and give them a mesh (ServerStorage.GhostMeshes.<id> plus a
	-- GhostModels.<id> look). Until then they use the simple ball look. Keep the ids: players'
	-- saves store ghosts by id, so changing one would delete it from everyone who owns it.
	{ id = "divine_1",       name = "Divine Ghost",   rarity = "Divine",    price = 2500000,  income = 20000, spawnWeight = 0.15, size = 5.5, color = Color3.fromRGB(225, 240, 255) },
	{ id = "secret_1",       name = "Secret Ghost",   rarity = "Secret",    price = 15000000, income = 100000, spawnWeight = 0.05, size = 6,  color = Color3.fromRGB(30, 30, 38) },
}

GhostConfig.byId = {}
for _, ghost in GhostConfig.Ghosts do
	GhostConfig.byId[ghost.id] = ghost
end

return GhostConfig
