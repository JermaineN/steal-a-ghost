-- Titles: a word shown above a player's head (everyone sees it), picked in the Inventory. One
-- title at a time. To add a title, add a row below.
--   id             saved in players' data: never change an id once the title is live
--   text           what it says (shown in capitals)
--   color          its card's accent colour in the Inventory
--   gradient       its colours (white text tinted by this gradient, sliding back and forth)
--   shine          true = a white glint sweeps across it now and then (looks reflective)
--   allowedUserIds players who always have it (special titles). Titles can also be earned in
--                  game and saved (DataService.grantTitle); nothing grants them yet.
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

TitleConfig.Titles = {
	{
		id = "the_goat",
		text = "THE GOAT",
		color = Color3.fromRGB(255, 70, 90),
		-- The Secret rarity's colours: silver stripes with a blood-red streak.
		gradient = gradient(
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(140, 140, 155),
			Color3.fromRGB(255, 50, 70),
			Color3.fromRGB(140, 140, 155),
			Color3.fromRGB(255, 255, 255)
		),
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
		-- Until there's a way to earn it in game.
		allowedUserIds = { OWNER_USER_ID },
	},
}

TitleConfig.byId = {}
for _, title in TitleConfig.Titles do
	TitleConfig.byId[title.id] = title
end

return TitleConfig
