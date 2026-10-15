-- The floating text above each ghost (no card or border): its name, its rarity in the rarity's
-- colour (gold for Legendary, rainbow for Mythic), and lines of info (price and income on the
-- walkway, income in a base). Text has a thick black outline so it reads over anything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Theme = require(ReplicatedStorage.Shared.Theme)

local GhostLabel = {}

local RARITY_TEXT_SIZE = 21

local function textLabel(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 1
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

-- A thick black outline around a label's text.
local function outline(label: TextLabel, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = thickness
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
end

export type InfoLine = { text: string, color: Color3 }

local INFO_LINE_HEIGHT = 22

-- `rarity` is the entry from GhostConfig.Rarities; `infoLines` are shown under the badge.
function GhostLabel.create(adornee: BasePart, def, rarity, infoLines: { InfoLine }, height: number): BillboardGui
	local cardHeight = 60 + #infoLines * INFO_LINE_HEIGHT + 4
	local gui = Instance.new("BillboardGui")
	gui.Name = "GhostLabel"
	gui.Size = UDim2.fromOffset(190, cardHeight)
	gui.StudsOffset = Vector3.new(0, height, 0)
	-- Extra lines make the card grow upward instead of down over the ghost: shift it up by
	-- half its extra height compared to a one-line card (86px).
	gui.SizeOffset = Vector2.new(0, (cardHeight - 86) / 2 / cardHeight)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.Adornee = adornee

	local card = gui -- everything floats directly in the billboard; no background or border

	local nameLabel = textLabel(card, {
		Name = "GhostName",
		Position = UDim2.new(0, 8, 0, 4),
		Size = UDim2.new(1, -16, 0, 26),
		TextColor3 = Color3.new(1, 1, 1),
		Text = def.name,
	})
	outline(nameLabel, 2.5)

	-- Rarity: the word itself in the rarity's colour, with a black outline.
	-- A UIGradient on a TextLabel tints the text, so gradient rarities start from white text.
	-- The label is sized to the word so a gradient spans exactly the letters.
	local gradientColors = Theme.RarityGradients[def.rarity]
	local rarityText = string.upper(def.rarity)
	local textWidth =
		TextService:GetTextSize(rarityText, RARITY_TEXT_SIZE, Enum.Font.FredokaOne, Vector2.new(1000, 100)).X
	local rarityLabel = textLabel(card, {
		Name = "Rarity",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 31),
		Size = UDim2.fromOffset(textWidth + 2, 24),
		TextScaled = false,
		TextSize = RARITY_TEXT_SIZE,
		TextColor3 = if gradientColors then Color3.new(1, 1, 1) else rarity.color,
		Text = rarityText,
	})
	outline(rarityLabel, 2.5)
	if gradientColors then
		local gradient = Instance.new("UIGradient")
		gradient.Color = gradientColors
		gradient.Parent = rarityLabel
	end

	for index, line in infoLines do
		local infoLabel = textLabel(card, {
			Name = "Info" .. index,
			Position = UDim2.new(0, 8, 0, 58 + (index - 1) * INFO_LINE_HEIGHT),
			Size = UDim2.new(1, -16, 0, INFO_LINE_HEIGHT),
			TextColor3 = line.color,
			Text = line.text,
		})
		outline(infoLabel, 2.5)
	end

	gui.Parent = adornee
	return gui
end

return GhostLabel
