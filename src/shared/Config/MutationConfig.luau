-- Mutations: a walkway ghost can spawn with (at most) one mutation, which multiplies its income
-- and puts the mutation's name, in its own animated colours, above the ghost's rarity.
--   chance     1 in this many spawns
--   multiplier income multiplier
--   gradient   text colours (white text tinted by this gradient)
--   announce   true = everyone gets a spawn banner, like a rare ghost
--   bigBanner  true = always the big banner (like Mythic); otherwise the smaller one (like
--              Legendary), unless the ghost itself is Mythic or rarer
--
-- Listed rarest first. Each spawn rolls them in this order and the first one that hits wins,
-- so a rarer mutation always takes precedence.
local MutationConfig = {}

local function gradient(...: Color3): ColorSequence
	local colors = { ... }
	local keypoints = {}
	for index, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keypoints)
end

local WHITE = Color3.fromRGB(255, 255, 255)

MutationConfig.Mutations = {
	{
		id = "shiny",
		name = "Shiny",
		chance = 500,
		multiplier = 3,
		-- Mostly white with a touch of gold (so it doesn't look like Legendary).
		gradient = gradient(WHITE, Color3.fromRGB(255, 250, 225), Color3.fromRGB(255, 215, 110), WHITE, WHITE),
		color = Color3.fromRGB(255, 245, 210),
		announce = true,
		bigBanner = true,
	},
	{
		id = "undead",
		name = "Undead",
		chance = 115,
		multiplier = 2,
		gradient = gradient(
			Color3.fromRGB(120, 255, 110),
			Color3.fromRGB(70, 75, 70),
			Color3.fromRGB(120, 255, 110),
			Color3.fromRGB(70, 75, 70)
		),
		color = Color3.fromRGB(120, 255, 110),
		announce = true,
	},
	{
		id = "spooky",
		name = "Spooky",
		chance = 50,
		multiplier = 1.5,
		-- Orange and black (the black is a very dark grey, so it still reads on the outline).
		gradient = gradient(
			Color3.fromRGB(255, 140, 30),
			Color3.fromRGB(45, 40, 45),
			Color3.fromRGB(255, 140, 30),
			Color3.fromRGB(45, 40, 45)
		),
		color = Color3.fromRGB(255, 140, 30),
		announce = false,
	},
	{
		id = "eerie",
		name = "Eerie",
		chance = 20,
		multiplier = 1.2,
		gradient = gradient(
			Color3.fromRGB(150, 150, 160),
			Color3.fromRGB(235, 238, 245),
			Color3.fromRGB(150, 150, 160),
			Color3.fromRGB(235, 238, 245)
		),
		color = Color3.fromRGB(200, 200, 210),
		announce = false,
	},
}

MutationConfig.byId = {}
for _, mutation in MutationConfig.Mutations do
	MutationConfig.byId[mutation.id] = mutation
end

-- Income multiplier for a mutation id (or nil for none).
function MutationConfig.multiplier(mutationId: string?): number
	local mutation = mutationId and MutationConfig.byId[mutationId]
	return if mutation then mutation.multiplier else 1
end

return MutationConfig
