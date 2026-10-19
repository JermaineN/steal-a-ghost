-- Titles: a word shown above a player's head (everyone sees it), picked in the Inventory. One
-- title at a time. To add a title, add a row below.
--   id             saved in players' data: never change an id once the title is live
--   text           what it says (shown in capitals)
--   color          its card's accent colour in the Inventory
--   gradient       its colours (white text tinted by this gradient, sliding back and forth)
--   shine          true = a white glint sweeps across it now and then (looks reflective)
--   allowedUserIds players who always have it (special titles). Titles can also be earned in
--                  game and saved (DataService.grantTitle).
--   rebirths       earned by reaching this many rebirths (TitleService). These titles show in
--                  the Inventory even before you own them, locked, with a progress bar.
--   gamePass       owned with this game pass (a StoreConfig.Passes id)
--   cosmetic       owned by buying this cosmetic in the Shop (a CosmeticConfig id)
local Theme = require(script.Parent.Parent.Theme)

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
		text = "THE GOAT",
		-- The Secret rarity's colours: shiny black and white.
		color = Color3.fromRGB(230, 230, 240),
		gradient = Theme.RarityGradients.Secret,
		shine = true,
		allowedUserIds = { OWNER_USER_ID },
	},
	{
		id = "supernova",
		text = "SUPERNOVA",
		color = Color3.fromRGB(170, 60, 255),
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
		text = "VIP",
		color = Color3.fromRGB(255, 200, 40),
		gradient = gradient(Color3.fromRGB(255, 170, 30), Color3.fromRGB(255, 240, 130), Color3.fromRGB(255, 170, 30)),
		shine = true,
		gamePass = "vip",
	},
	-- Bought in the Shop's Cosmetics tab (CosmeticConfig).
	{
		id = "phantom",
		text = "PHANTOM",
		color = Color3.fromRGB(150, 230, 255),
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
		text = "NIGHTMARE",
		color = Color3.fromRGB(220, 30, 50),
		-- Blood red into near-black, shiny.
		gradient = gradient(Color3.fromRGB(230, 30, 45), Color3.fromRGB(70, 0, 10), Color3.fromRGB(230, 30, 45)),
		shine = true,
		cosmetic = "title_nightmare",
	},
	-- Rebirth titles: the first two in one plain colour, the last in shiny silver (like Eerie).
	{
		id = "reborn",
		text = "REBORN",
		color = Color3.fromRGB(170, 110, 255),
		gradient = gradient(Color3.fromRGB(190, 140, 255), Color3.fromRGB(190, 140, 255)),
		rebirths = 1,
	},
	{
		id = "undying",
		text = "UNDYING",
		color = Color3.fromRGB(255, 120, 50),
		gradient = gradient(Color3.fromRGB(255, 130, 60), Color3.fromRGB(255, 130, 60)),
		rebirths = 5,
	},
	{
		id = "eternal",
		text = "ETERNAL",
		color = Color3.fromRGB(200, 200, 210),
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

TitleConfig.byId = {}
for _, title in TitleConfig.Titles do
	TitleConfig.byId[title.id] = title
end

return TitleConfig
