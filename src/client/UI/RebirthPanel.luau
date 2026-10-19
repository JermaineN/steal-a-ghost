-- The Rebirth window (side menu → Rebirth). Built like the Ghost Index window, in purple: your
-- income boost now and after the next rebirth side by side, what you lose and keep, a progress
-- bar toward the cash needed, and the Rebirth button (press twice to confirm). The server
-- checks everything (RebirthService); the maths is in Shared.Rebirth.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)

local RebirthPanel = {}

local PANEL_DARK = Color3.fromRGB(28, 16, 44)
local PURPLE = Theme.RebirthPurple
local TEXT_OUTLINE = Color3.fromRGB(20, 8, 30)
local WHITE = Color3.new(1, 1, 1)
local LOCKED_GREY = Color3.fromRGB(90, 84, 104)
local CONFIRM_ORANGE = Color3.fromRGB(255, 140, 30)
local FONT = Enum.Font.FredokaOne
local POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local WIDTH, HEIGHT = 560, 450
local CONFIRM_SECONDS = 3 -- the "press again" state lasts this long

local player = Players.LocalPlayer

local function new(className: string, props: { [string]: any }): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	instance.Parent = props.Parent
	return instance
end

local function text(props: { [string]: any }, thickness: number?): TextLabel
	props.BackgroundTransparency = 1
	props.Font = FONT
	props.TextScaled = true
	local label = new("TextLabel", props)
	new("UIStroke", { Color = TEXT_OUTLINE, Thickness = thickness or 1.5, Parent = label })
	return label
end

local function darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function stat(name: string): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(name)
	return if value then (value :: any).Value else 0
end

-- Fires (true/false) when whether you can afford a rebirth changes; the side menu shows a "!"
-- on the Rebirth button while you can.
RebirthPanel.availableChanged = Instance.new("BindableEvent")

function RebirthPanel.canAfford(): boolean
	return player:FindFirstChild("leaderstats") ~= nil and stat("Cash") >= Rebirth.cost(stat("Rebirths"))
end

-- A card like the Index's: "NOW" or "NEXT" on top, the big income multiplier, the rebirth number.
type Card = { multiplier: TextLabel, rebirth: TextLabel, extra: TextLabel? }
local function buildCard(parent: Instance, position: UDim2, heading: string, accent: Color3, withReward: boolean): Card
	local card = new("Frame", {
		Position = position,
		Size = UDim2.fromOffset(200, 170),
		BackgroundColor3 = WHITE,
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(0.1, 0), Parent = card })
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(accent:Lerp(PANEL_DARK, 0.6), PANEL_DARK),
		Parent = card,
	})
	new("UIStroke", { Color = accent, Thickness = 2.5, Parent = card })
	text({
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 24),
		TextColor3 = accent,
		Text = heading,
		Parent = card,
	})
	local multiplier = text({
		Position = UDim2.fromOffset(10, 36),
		Size = UDim2.new(1, -20, 0, 56),
		TextColor3 = Theme.MoneyGreen,
		Parent = card,
	}, 2.5)
	text({
		Position = UDim2.fromOffset(10, 92),
		Size = UDim2.new(1, -20, 0, 20),
		TextColor3 = WHITE,
		Text = "income",
		Parent = card,
	})
	local rebirth = text({
		Position = UDim2.fromOffset(10, 116),
		Size = UDim2.new(1, -20, 0, 20),
		TextColor3 = Color3.fromRGB(205, 190, 230),
		Parent = card,
	})
	local extra: TextLabel? = nil
	if withReward then
		-- "+150" with the gem picture after it.
		local row = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 138),
			Size = UDim2.fromOffset(150, 24),
			BackgroundTransparency = 1,
			Parent = card,
		})
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			Parent = row,
		})
		extra = text({
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 1,
			TextScaled = false,
			TextSize = 22,
			TextColor3 = Theme.GemBlue,
			Parent = row,
		}, 2)
		new("ImageLabel", {
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			Image = GameConfig.GemIcon,
			LayoutOrder = 2,
			Parent = row,
		})
	end
	return { multiplier = multiplier, rebirth = rebirth, extra = extra }
end

local window: Frame
local scale: UIScale
local refresh: () -> ()

function RebirthPanel.isOpen(): boolean
	return window ~= nil and window.Visible
end

function RebirthPanel.close()
	if not RebirthPanel.isOpen() then
		return
	end
	local shrink = TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 0.8 })
	shrink.Completed:Once(function()
		if scale.Scale <= 0.81 then
			window.Visible = false
		end
	end)
	shrink:Play()
end

function RebirthPanel.open()
	if RebirthPanel.isOpen() then
		return
	end
	refresh()
	window.Visible = true
	scale.Scale = 0.8
	TweenService:Create(scale, POP, { Scale = 1 }):Play()
end

function RebirthPanel.toggle()
	if RebirthPanel.isOpen() then
		RebirthPanel.close()
	else
		RebirthPanel.open()
	end
end

-- Shrinks the window on small (phone) screens.
local function scaleToScreen(screenScale: UIScale)
	local function update()
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 900
		screenScale.Scale = math.clamp((height - 40) / HEIGHT, 0.55, 1)
	end
	update()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
end

function RebirthPanel.start()
	local gui = new("ScreenGui", {
		Name = "Rebirth",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- The holder scales the window to the screen; the window's own scale pops it open.
	local holder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	scaleToScreen(new("UIScale", { Parent = holder }))
	window = new("Frame", {
		Name = "Window",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		Visible = false,
		Parent = holder,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 18), Parent = window })
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(52, 30, 80), PANEL_DARK),
		Parent = window,
	})
	new("UIStroke", { Color = PURPLE, Thickness = 3, Parent = window })
	scale = new("UIScale", { Parent = window })

	-- Header: icon, title, close button (same as the Index), then how many rebirths you have.
	new("ImageLabel", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.fromOffset(52, 52),
		BackgroundTransparency = 1,
		Image = GameConfig.MenuIcons.Rebirth,
		Parent = window,
	})
	text({
		Position = UDim2.fromOffset(74, 12),
		Size = UDim2.new(0.5, 0, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = WHITE,
		Text = "Rebirth",
		Parent = window,
	})
	local close = new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Color3.fromRGB(220, 60, 70),
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = "X",
		Parent = window,
	})
	new("UICorner", { CornerRadius = UDim.new(0.3, 0), Parent = close })
	new("UIStroke", {
		Color = TEXT_OUTLINE,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = close,
	})
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = close })
	close.Activated:Connect(RebirthPanel.close)

	local count = text({
		Position = UDim2.fromOffset(18, 64),
		Size = UDim2.new(1, -36, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = WHITE,
		Parent = window,
	})

	-- Now → next.
	local now = buildCard(window, UDim2.fromOffset(40, 100), "NOW", Color3.fromRGB(150, 140, 175), false)
	local nextCard = buildCard(window, UDim2.fromOffset(WIDTH - 240, 100), "NEXT", PURPLE, true)
	local arrow = text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(WIDTH / 2, 185),
		Size = UDim2.fromOffset(60, 50),
		TextColor3 = PURPLE,
		Text = "➜",
		Parent = window,
	}, 2)
	TweenService:Create(
		arrow,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.fromOffset(WIDTH / 2 + 6, 185) }
	):Play()

	-- What happens to your stuff.
	text({
		Position = UDim2.fromOffset(18, 282),
		Size = UDim2.new(1, -36, 0, 22),
		TextColor3 = Theme.SpendRed,
		Text = "You lose: your cash, your base's ghosts and upgrades (not graves)",
		Parent = window,
	})
	-- Filled in by refresh with the cash you'd restart with.
	local keepLabel = text({
		Position = UDim2.fromOffset(18, 306),
		Size = UDim2.new(1, -36, 0, 22),
		TextColor3 = Theme.MoneyGreen,
		Parent = window,
	})

	-- Progress toward the cash needed, with "$X / $Y" over it.
	local bar = new("Frame", {
		Position = UDim2.fromOffset(40, 340),
		Size = UDim2.new(1, -80, 0, 24),
		BackgroundColor3 = Color3.fromRGB(18, 10, 28),
		Parent = window,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bar })
	new("UIStroke", { Color = TEXT_OUTLINE, Thickness = 2, Parent = bar })
	local barFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = PURPLE, Parent = bar })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = barFill })
	local barText = text({
		Size = UDim2.fromScale(1, 1),
		TextColor3 = WHITE,
		ZIndex = 2,
		Parent = bar,
	})
	new("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3), Parent = barText })

	-- The Rebirth button: grey until you can afford it, then purple and pulsing. The first press
	-- turns it orange ("Press again to confirm"); a second press within a few seconds rebirths.
	local button = new("TextButton", {
		Name = "RebirthButton",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 380),
		Size = UDim2.fromOffset(260, 52),
		BackgroundColor3 = WHITE,
		Text = "",
		AutoButtonColor = false,
		Parent = window,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = button })
	-- The gradient would tint the button's own text too, so the words are a separate label.
	local buttonGradient = new("UIGradient", { Rotation = 90, Parent = button })
	new("UIStroke", {
		Color = TEXT_OUTLINE,
		Thickness = 3.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = button,
	})
	local buttonText = text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -24, 1, -18),
		TextColor3 = WHITE,
		Parent = button,
	}, 1.5)
	local pulse = new("UIScale", { Parent = button })
	local pulseTween = TweenService:Create(
		pulse,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.06 }
	)

	local confirmUntil = 0
	local waiting = false -- sent the request, waiting for the server
	local lastAvailable: boolean? = nil
	local pulsing = false

	local function paintButton(color: Color3)
		buttonGradient.Color = ColorSequence.new(color, darken(color, 0.35))
	end

	refresh = function()
		local rebirths = stat("Rebirths")
		local cash = stat("Cash")
		local cost = Rebirth.cost(rebirths)
		local affordable = player:FindFirstChild("leaderstats") ~= nil and cash >= cost
		keepLabel.Text = `You keep: gems, the Index, items and graves, and restart with ${Format.cash(
			Rebirth.startingCash(rebirths)
		)}`

		count.Text = if rebirths == 0
			then "You haven't rebirthed yet"
			else "Rebirths: " .. rebirths .. "   (income " .. Rebirth.formatMultiplier(
				Rebirth.multiplier(rebirths)
			) .. ")"
		now.multiplier.Text = Rebirth.formatMultiplier(Rebirth.multiplier(rebirths))
		now.rebirth.Text = if rebirths == 0 then "no rebirths" else "Rebirth " .. rebirths
		nextCard.multiplier.Text = Rebirth.formatMultiplier(Rebirth.multiplier(rebirths + 1))
		nextCard.rebirth.Text = "Rebirth " .. (rebirths + 1)
		if nextCard.extra then
			nextCard.extra.Text = "+" .. Format.cash(Rebirth.gems(rebirths + 1))
		end

		barText.Text = "$" .. Format.cash(math.min(cash, cost)) .. " / $" .. Format.cash(cost)
		TweenService:Create(barFill, TweenInfo.new(0.3), {
			Size = UDim2.fromScale(math.clamp(cash / cost, 0, 1), 1),
		}):Play()

		if waiting then
			buttonText.Text = "..."
		elseif not affordable then
			confirmUntil = 0
			buttonText.Text = "Need $" .. Format.cash(cost)
			paintButton(LOCKED_GREY)
		elseif os.clock() < confirmUntil then
			buttonText.Text = "Press again to confirm!"
			paintButton(CONFIRM_ORANGE)
		else
			buttonText.Text = "REBIRTH!"
			paintButton(PURPLE)
		end
		local shouldPulse = affordable and not waiting
		if shouldPulse ~= pulsing then
			pulsing = shouldPulse
			if shouldPulse then
				pulseTween:Play()
			else
				pulseTween:Cancel()
				pulse.Scale = 1
			end
		end

		if affordable ~= lastAvailable then
			lastAvailable = affordable
			RebirthPanel.availableChanged:Fire(affordable)
		end
	end

	button.Activated:Connect(function()
		if waiting or not RebirthPanel.canAfford() then
			return
		end
		if os.clock() < confirmUntil then
			waiting = true
			confirmUntil = 0
			Remotes.Rebirth:FireServer()
			-- If the server says no (e.g. someone is robbing you), the button comes back.
			task.delay(3, function()
				waiting = false
				refresh()
			end)
		else
			confirmUntil = os.clock() + CONFIRM_SECONDS
			task.delay(CONFIRM_SECONDS, refresh)
		end
		refresh()
	end)

	-- Keep the numbers live (the HUD's leaderstats appear once our data has loaded).
	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats")
		for _, name in { "Cash", "Rebirths" } do
			(leaderstats:WaitForChild(name) :: any).Changed:Connect(refresh)
		end
		refresh()
	end)

	-- Our own rebirth went through: close the window (the celebration takes over the screen).
	Remotes.Rebirthed.OnClientEvent:Connect(function(who: Player)
		if who == player then
			waiting = false
			RebirthPanel.close()
		end
	end)
	refresh()
end

return RebirthPanel
