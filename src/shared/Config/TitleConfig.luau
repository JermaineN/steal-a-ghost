-- Titles: a word shown above a player's head (everyone sees it), picked in the Inventory. One
-- title at a time. To add a title, add a row below.
--   id             saved in players' data: never change an id once the title is live
--   text           what it says (shown in capitals)
--   rarity         a GhostConfig.Rarities name (Common ... Secret): sets its card's colour, like
--                  the items' (`color` is filled in from it)
--   gradient       its colours (white text tinted by this gradient, sliding back and forth)
--   shine          true = a white glint sweeps across it now and then (looks reflective)
--   allowedUserIds players who always have it (special titles). Titles can also be earned in
--                  game and saved (DataService.grantTitle).
--   rebirths       earned by reaching this many rebirths (TitleService). These titles show in
--                  the Inventory even before you own them, locked, with a progress bar.
--   gamePass       owned with this game pass (a StoreConfig.Passes id)
--   cosmetic       owned by buying this cosmetic in the Shop (a CosmeticConfig id)
--   milestone      { stat, goal }: earned once that stat reaches the goal. Stats (saved by
--                  DataService, "Stat_<stat>" attributes): ghostsBought (walkway buys and
--                  out-bids), steals (steals and captures), found (ghosts in the Index),
--                  mutations (mutated ghosts you got), shinies (Shiny ghosts you got).
--                  These show in the Inventory even before you own them, locked, with a bar.
local Theme = require(script.Parent.Parent.Theme)
local GhostConfig = require(script.Parent.GhostConfig)

local TitleConfig = {}

local function gradient(...: Color3): ColorSequence
	local colors = { ... }
	local keypoints = {}
	for index, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keypoints)
end

local OWNER_USER_ID = 5783726738 -- the game's creator (jerizaxe)
local WINTER_UNICORN_USER_ID = 701124691 -- Winter_Unicorn79

TitleConfig.Titles = {
	{
		id = "the_goat",
		rarity = "Secret",
		text = "THE GOAT",
		-- The Secret rarity's colours: shiny black and white.
		gradient = Theme.RarityGradients.Secret,
		shine = true,
		allowedUserIds = { OWNER_USER_ID },
	},
	{
		id = "supernova",
		rarity = "Secret",
		text = "SUPERNOVA",
		-- Red and purple, with a hot pink flash between them.
		gradient = gradient(
			Color3.fromRGB(255, 45, 60),
			Color3.fromRGB(255, 90, 170),
			Color3.fromRGB(150, 50, 255),
			Color3.fromRGB(255, 90, 170),
			Color3.fromRGB(255, 45, 60)
		),
		shine = true,
		allowedUserIds = { WINTER_UNICORN_USER_ID },
	},
	-- The VIP game pass's title, in gold.
	{
		id = "vip",
		rarity = "Mythic",
		text = "VIP",
		gradient = gradient(Color3.fromRGB(255, 170, 30), Color3.fromRGB(255, 240, 130), Color3.fromRGB(255, 170, 30)),
		shine = true,
		gamePass = "vip",
	},
	-- Bought in the Shop's Cosmetics tab (CosmeticConfig).
	{
		id = "phantom",
		rarity = "Legendary",
		text = "PHANTOM",
		-- Pale ghostly blue fading to white and back.
		gradient = gradient(
			Color3.fromRGB(120, 210, 255),
			Color3.fromRGB(235, 250, 255),
			Color3.fromRGB(120, 210, 255)
		),
		cosmetic = "title_phantom",
	},
	{
		id = "nightmare",
		rarity = "Mythic",
		text = "NIGHTMARE",
		-- Blood red into near-black, shiny.
		gradient = gradient(Color3.fromRGB(230, 30, 45), Color3.fromRGB(70, 0, 10), Color3.fromRGB(230, 30, 45)),
		shine = true,
		cosmetic = "title_nightmare",
	},
	-- Milestone titles, Common up to Legendary: earned by doing something enough times (see
	-- `milestone` above). Common ones are one plain colour, rarer ones get gradients, Legendary
	-- ones shine.
	{
		id = "ghost_hunter",
		rarity = "Common",
		text = "GHOST HUNTER",
		gradient = gradient(Color3.fromRGB(255, 140, 40), Color3.fromRGB(255, 140, 40)),
		milestone = { stat = "ghostsBought", goal = 20 },
	},
	{
		id = "pickpocket",
		rarity = "Common",
		text = "PICKPOCKET",
		gradient = gradient(Color3.fromRGB(235, 228, 205), Color3.fromRGB(235, 228, 205)),
		milestone = { stat = "steals", goal = 3 },
	},
	{
		id = "collector",
		rarity = "Uncommon",
		text = "COLLECTOR",
		gradient = gradient(Color3.fromRGB(140, 230, 90), Color3.fromRGB(140, 230, 90)),
		milestone = { stat = "found", goal = 5 },
	},
	{
		id = "ghost_hoarder",
		rarity = "Uncommon",
		text = "GHOST HOARDER",
		-- Sickly green into a dull purple and back.
		gradient = gradient(
			Color3.fromRGB(120, 220, 100),
			Color3.fromRGB(170, 110, 200),
			Color3.fromRGB(120, 220, 100)
		),
		milestone = { stat = "ghostsBought", goal = 100 },
	},
	{
		id = "oddball",
		rarity = "Rare",
		text = "ODDBALL",
		-- Ghostly teal into a deep blue.
		gradient = gradient(Color3.fromRGB(80, 230, 220), Color3.fromRGB(70, 120, 255), Color3.fromRGB(80, 230, 220)),
		milestone = { stat = "mutations", goal = 5 },
	},
	{
		id = "cat_burglar",
		rarity = "Rare",
		text = "CAT BURGLAR",
		-- Shadowy grey into a sneaky blue.
		gradient = gradient(Color3.fromRGB(150, 160, 185), Color3.fromRGB(90, 140, 255), Color3.fromRGB(150, 160, 185)),
		milestone = { stat = "steals", goal = 25 },
	},
	{
		id = "mutated",
		rarity = "Epic",
		text = "MUTATED",
		-- Toxic green into purple.
		gradient = gradient(Color3.fromRGB(130, 255, 80), Color3.fromRGB(170, 80, 255), Color3.fromRGB(130, 255, 80)),
		milestone = { stat = "mutations", goal = 20 },
	},
	{
		id = "master_thief",
		rarity = "Epic",
		text = "MASTER THIEF",
		-- Purple and hot pink.
		gradient = gradient(Color3.fromRGB(170, 80, 255), Color3.fromRGB(255, 100, 210), Color3.fromRGB(170, 80, 255)),
		milestone = { stat = "steals", goal = 100 },
	},
	{
		id = "shiny_hunter",
		rarity = "Legendary",
		text = "SHINY HUNTER",
		-- Gold and white, shiny (like the Shiny mutation).
		gradient = gradient(Color3.fromRGB(255, 200, 50), Color3.fromRGB(255, 250, 220), Color3.fromRGB(255, 200, 50)),
		shine = true,
		milestone = { stat = "shinies", goal = 5 },
	},
	{
		id = "gravekeeper",
		rarity = "Legendary",
		text = "GRAVEKEEPER",
		-- Pale wailing green into white, shiny.
		gradient = gradient(
			Color3.fromRGB(160, 255, 190),
			Color3.fromRGB(250, 255, 250),
			Color3.fromRGB(160, 255, 190)
		),
		shine = true,
		milestone = { stat = "found", goal = #GhostConfig.Ghosts },
	},
	-- Rebirth titles: the first two in one plain colour, the last in shiny silver (like Eerie).
	{
		id = "reborn",
		rarity = "Rare",
		text = "REBORN",
		gradient = gradient(Color3.fromRGB(190, 140, 255), Color3.fromRGB(190, 140, 255)),
		rebirths = 1,
	},
	{
		id = "undying",
		rarity = "Epic",
		text = "UNDYING",
		gradient = gradient(Color3.fromRGB(255, 130, 60), Color3.fromRGB(255, 130, 60)),
		rebirths = 5,
	},
	{
		id = "eternal",
		rarity = "Legendary",
		text = "ETERNAL",
		gradient = gradient(
			Color3.fromRGB(150, 150, 160),
			Color3.fromRGB(235, 238, 245),
			Color3.fromRGB(150, 150, 160),
			Color3.fromRGB(235, 238, 245)
		),
		shine = true,
		rebirths = 10,
	},
}

-- What each milestone stat means, for the Inventory ("Steal 25 ghosts") and the unlock message.
TitleConfig.MilestoneText = {
	ghostsBought = "Buy %d ghosts",
	steals = "Steal %d ghosts",
	found = "Find %d ghosts",
	mutations = "Get %d mutated ghosts",
	shinies = "Get %d Shiny ghosts",
}

function TitleConfig.milestoneText(title): string
	return string.format(TitleConfig.MilestoneText[title.milestone.stat], title.milestone.goal)
end

TitleConfig.byId = {}
for _, title in TitleConfig.Titles do
	title.color = GhostConfig.Rarities[title.rarity].color
	TitleConfig.byId[title.id] = title
end

return TitleConfig
