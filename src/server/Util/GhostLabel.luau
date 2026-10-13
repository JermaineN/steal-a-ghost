-- The floating card above each ghost: its name, a coloured rarity badge (gold for Legendary,
-- rainbow for Mythic), and lines of info (price and income on the walkway, income in a base).
local GhostLabel = {}

local CARD = Color3.fromRGB(28, 16, 44)
local OUTLINE = Color3.fromRGB(20, 8, 30)

-- Special badge colours for the top rarities; the rest use their rarity colour.
local BADGE_GRADIENTS = {
	Legendary = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 150)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 190, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 150)),
	}),
	Mythic = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 110)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 80)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 255, 150)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(110, 170, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 120, 255)),
	}),
}

local function textLabel(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeColor3 = OUTLINE
	label.TextStrokeTransparency = 0.3
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
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

	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = CARD
	card.BackgroundTransparency = 0.3
	card.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = rarity.color
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = card

	textLabel(card, {
		Name = "GhostName",
		Position = UDim2.new(0, 8, 0, 4),
		Size = UDim2.new(1, -16, 0, 26),
		TextColor3 = Color3.new(1, 1, 1),
		Text = def.name,
	})

	-- Rarity badge: a rounded pill in the rarity's colour.
	local badge = Instance.new("Frame")
	badge.Name = "RarityBadge"
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.new(0.5, 0, 0, 32)
	badge.Size = UDim2.fromOffset(104, 22)
	badge.BackgroundColor3 = if BADGE_GRADIENTS[def.rarity] then Color3.new(1, 1, 1) else rarity.color
	badge.Parent = card
	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 11)
	badgeCorner.Parent = badge
	if BADGE_GRADIENTS[def.rarity] then
		local gradient = Instance.new("UIGradient")
		gradient.Color = BADGE_GRADIENTS[def.rarity]
		gradient.Parent = badge
	end
	textLabel(badge, {
		Position = UDim2.fromOffset(6, 3),
		Size = UDim2.new(1, -12, 1, -6),
		TextColor3 = CARD,
		TextStrokeTransparency = 1,
		Text = string.upper(def.rarity),
	})

	for index, line in infoLines do
		textLabel(card, {
			Name = "Info" .. index,
			Position = UDim2.new(0, 8, 0, 58 + (index - 1) * INFO_LINE_HEIGHT),
			Size = UDim2.new(1, -16, 0, INFO_LINE_HEIGHT),
			TextColor3 = line.color,
			Text = line.text,
		})
	end

	gui.Parent = adornee
	return gui
end

return GhostLabel
