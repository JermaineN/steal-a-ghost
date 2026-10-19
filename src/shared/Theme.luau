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
	-- The friend boost (HUD income line, Invite button).
	FriendPink = Color3.fromRGB(255, 120, 200),
	-- Rebirths (the side menu's Rebirth button, the Rebirth panel and the celebration).
	RebirthPurple = Color3.fromRGB(175, 95, 255),
	RebirthGradient = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(205, 150, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	}),

	-- Special text colours for the top rarities (gold, shiny red, heavenly, shiny black-and-white); the rest use their rarity's
	-- colour from GhostConfig. Applied with a UIGradient on white text.
	RarityGradients = {
		Legendary = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 150)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 190, 40)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 150)),
		}),
		-- Shiny red: deep red with bright highlights that catch the light as the gradient slides.
		Mythic = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 120)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(215, 10, 30)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 215, 215)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(215, 10, 30)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 120)),
		}),
		-- Heavenly white and blue.
		Divine = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.3, Color3.fromRGB(110, 180, 255)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(150, 205, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
		}),
		-- Shiny dark grey: mostly dark grey, with two thin white shines. It scrolls one way in a loop
		-- (client GradientAnimator), so it must start and end on the same colour.
		Secret = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.1, Color3.fromRGB(70, 70, 78)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(70, 70, 78)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 70, 78)),
			ColorSequenceKeypoint.new(0.9, Color3.fromRGB(70, 70, 78)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
		}),
	},
}
