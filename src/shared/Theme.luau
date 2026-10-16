-- Colours shared by the HUD, the ghost labels and the rare-spawn banners, so they look the same
-- everywhere.
return {
	-- All money: cash, prices, and the income of ghosts you own.
	MoneyGreen = Color3.fromRGB(60, 255, 60),
	-- Income of ghosts still on the walkway (not bought yet), so it stands apart from the price.
	PreviewIncomeYellow = Color3.fromRGB(255, 225, 40),
	-- Spending (the floating "-$X" on the HUD).
	SpendRed = Color3.fromRGB(255, 90, 90),
	-- Gems, the second currency.
	GemBlue = Color3.fromRGB(80, 190, 255),

	-- Special text colours for the top rarities (gold, rainbow, heavenly, silver-and-red); the rest use their rarity's
	-- colour from GhostConfig. Applied with a UIGradient on white text.
	RarityGradients = {
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
		-- Heavenly white, gold and sky blue.
		Divine = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 225, 120)),
			ColorSequenceKeypoint.new(0.65, Color3.fromRGB(160, 230, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
		}),
		-- Silver stripes with a blood-red streak.
		Secret = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.3, Color3.fromRGB(140, 140, 155)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 50, 70)),
			ColorSequenceKeypoint.new(0.7, Color3.fromRGB(140, 140, 155)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
		}),
	},
}
