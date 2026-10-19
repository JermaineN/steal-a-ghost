-- Titles: a word shown above a player's head (everyone sees it), picked in the Inventory. One
-- title at a time. To add a title, add a row below.
--   id             saved in players' data: never change an id once the title is live
--   text           what it says (shown in capitals)
--   rarity         a GhostConfig.Rarities name (Common ... Secret): sets its card's colour, like
--                  the items' (`color` is filled in from it)
--   gradient       its colours (white text tinted by this gradient, sliding back and forth).
--                  Leave it out for one flat colour, the rarity's, with no animation (`flat`
--                  is set below): the look for Legendary and below (Phantom is the exception).
--   shine          true = a white glint sweeps across it now and then (looks reflective).
--                  Mythic and rarer only.
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
-- The players who tested the game before launch.
local EARLY_TESTER_USER_IDS = {
	129697926, -- AyoGamerOfficial
	280803878, -- Joespo
	659456331, -- wintrishere15
	WINTER_UNICORN_USER_ID,
	5282578235, -- Jessn350
}

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
	{
		id = "early_tester",
		rarity = "Divine",
		text = "EARLY TESTER",
		-- The Divine rarity's colours: heavenly white and blue.
		gradient = Theme.RarityGradients.Divine,
		shine = true,
		allowedUserIds = EARLY_TESTER_USER_IDS,
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
		-- Pale ghostly blue fading to white and back (the one Legendary title with a gradient).
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
	-- `milestone` above).
	{
		id = "ghost_hunter",
		rarity = "Common",
		text = "GHOST HUNTER",
		milestone = { stat = "ghostsBought", goal = 20 },
	},
	{
		id = "pickpocket",
		rarity = "Common",
		text = "PICKPOCKET",
		milestone = { stat = "steals", goal = 3 },
	},
	{
		id = "collector",
		rarity = "Uncommon",
		text = "COLLECTOR",
		milestone = { stat = "found", goal = 5 },
	},
	{
		id = "ghost_hoarder",
		rarity = "Uncommon",
		text = "GHOST HOARDER",
		milestone = { stat = "ghostsBought", goal = 100 },
	},
	{
		id = "oddball",
		rarity = "Rare",
		text = "ODDBALL",
		milestone = { stat = "mutations", goal = 5 },
	},
	{
		id = "cat_burglar",
		rarity = "Rare",
		text = "CAT BURGLAR",
		milestone = { stat = "steals", goal = 25 },
	},
	{
		id = "mutated",
		rarity = "Epic",
		text = "MUTATED",
		milestone = { stat = "mutations", goal = 20 },
	},
	{
		id = "master_thief",
		rarity = "Epic",
		text = "MASTER THIEF",
		milestone = { stat = "steals", goal = 100 },
	},
	{
		id = "shiny_hunter",
		rarity = "Legendary",
		text = "SHINY HUNTER",
		milestone = { stat = "shinies", goal = 5 },
	},
	{
		id = "gravekeeper",
		rarity = "Legendary",
		text = "GRAVEKEEPER",
		milestone = { stat = "found", goal = #GhostConfig.Ghosts },
	},
	-- Rebirth titles.
	{
		id = "reborn",
		rarity = "Rare",
		text = "REBORN",
		rebirths = 1,
	},
	{
		id = "undying",
		rarity = "Epic",
		text = "UNDYING",
		rebirths = 5,
	},
	{
		id = "eternal",
		rarity = "Legendary",
		text = "ETERNAL",
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
	if not title.gradient then
		title.flat = true
		title.gradient = ColorSequence.new(title.color)
		title.shine = nil
	end
	TitleConfig.byId[title.id] = title
end

return TitleConfig
