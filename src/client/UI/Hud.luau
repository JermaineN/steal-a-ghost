-- On-screen HUD: a Halloween-styled cash panel (the number counts up, and big gains/spends
-- float a "+$X" / "-$X" off it), an income badge, and sliding message toasts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local Hud = {}

local PANEL_DARK = Color3.fromRGB(28, 16, 44)
local PANEL_LIGHT = Color3.fromRGB(62, 34, 92)
local PUMPKIN = Color3.fromRGB(255, 140, 30)
local GOLD = Color3.fromRGB(255, 205, 70)
local CASH_GREEN = Color3.fromRGB(140, 255, 150)
local SPEND_RED = Color3.fromRGB(255, 110, 110)

local TOAST_STYLES = {
	info = { color = Color3.fromRGB(190, 140, 255), icon = "i" },
	success = { color = Color3.fromRGB(110, 240, 140), icon = "+" },
	error = { color = Color3.fromRGB(255, 95, 95), icon = "!" },
}
local MAX_TOASTS = 4
local TOAST_SECONDS = 3.5

-- Builds an instance from a table of properties, e.g. new("Frame", { Size = ..., Parent = ... }).
local function new(className: string, props: { [string]: any }): any
	local instance = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	instance.Parent = parent
	return instance
end

local function corner(parent: Instance, radius: number)
	new("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function gradient(parent: Instance, top: Color3, bottom: Color3)
	new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90, Parent = parent })
end

-- Text with a dark outline so it stays readable over any background.
local function text(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextScaled = true
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0.4
	props.TextStrokeColor3 = Color3.fromRGB(20, 8, 30)
	return new("TextLabel", props)
end

local function buildCashPanel(gui: ScreenGui)
	local panel = new("Frame", {
		Name = "CashPanel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(280, 58),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = gui,
	})
	corner(panel, 16)
	gradient(panel, PANEL_LIGHT, PANEL_DARK)
	local panelStroke = stroke(panel, PUMPKIN, 2.5)

	-- Gold coin on the left.
	local coin = new("Frame", {
		Name = "Coin",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(42, 42),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = panel,
	})
	corner(coin, 21)
	gradient(coin, Color3.fromRGB(255, 235, 140), Color3.fromRGB(230, 150, 30))
	stroke(coin, Color3.fromRGB(150, 85, 10), 2)
	text({
		Text = "$",
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Color3.fromRGB(120, 60, 0),
		TextStrokeTransparency = 1,
		Parent = coin,
	})

	local cashLabel = text({
		Name = "Cash",
		Position = UDim2.fromOffset(58, 6),
		Size = UDim2.new(1, -68, 1, -12),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = CASH_GREEN,
		Text = "$0",
		Parent = panel,
	})

	-- Income badge hanging under the panel.
	local incomeBadge = new("Frame", {
		Name = "IncomeBadge",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(150, 26),
		BackgroundColor3 = PANEL_DARK,
		BackgroundTransparency = 0.15,
		Parent = gui,
	})
	corner(incomeBadge, 13)
	stroke(incomeBadge, CASH_GREEN, 1.5, 0.4)
	local incomeLabel = text({
		Name = "Income",
		Position = UDim2.fromOffset(8, 3),
		Size = UDim2.new(1, -16, 1, -6),
		TextColor3 = CASH_GREEN,
		Text = "+$0/s",
		Parent = incomeBadge,
	})

	return panel, panelStroke, cashLabel, incomeLabel
end

-- A "+$X" / "-$X" that floats up off the cash panel and fades away.
local function floatAmount(panel: Frame, amount: number)
	local gain = amount > 0
	-- Starts just right of the panel and drifts upward.
	local label = text({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 10, 0.5, 0),
		Size = UDim2.fromOffset(140, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if gain then CASH_GREEN else SPEND_RED,
		Text = (if gain then "+$" else "-$") .. Format.cash(math.abs(amount)),
		ZIndex = 5,
		Parent = panel,
	})
	local rise = TweenService:Create(
		label,
		TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = label.Position + UDim2.fromOffset(0, -30), TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	rise.Completed:Connect(function()
		label:Destroy()
	end)
	rise:Play()
end

local function buildToasts(gui: ScreenGui)
	local toasts = new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(420, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		Parent = toasts,
	})

	local toastCount = 0
	Remotes.Notify.OnClientEvent:Connect(function(message: string, kind: string)
		local style = TOAST_STYLES[kind] or TOAST_STYLES.info
		toastCount += 1

		-- The list layout positions this holder; the card inside it slides in from below.
		local holder = new("Frame", {
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = toastCount,
			BackgroundTransparency = 1,
			Parent = toasts,
		})
		local card = new("CanvasGroup", {
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			GroupTransparency = 1,
			Parent = holder,
		})
		corner(card, 12)
		gradient(card, PANEL_LIGHT, PANEL_DARK)
		stroke(card, style.color, 2)

		local badge = new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = style.color,
			Parent = card,
		})
		corner(badge, 14)
		text({
			Text = style.icon,
			Size = UDim2.fromScale(1, 1),
			TextColor3 = PANEL_DARK,
			TextStrokeTransparency = 1,
			Parent = badge,
		})
		text({
			Position = UDim2.fromOffset(42, 7),
			Size = UDim2.new(1, -52, 1, -14),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = message,
			Parent = card,
		})

		-- Keep only the newest few.
		local holders = {}
		for _, child in toasts:GetChildren() do
			if child:IsA("Frame") then
				table.insert(holders, child)
			end
		end
		table.sort(holders, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for index = 1, #holders - MAX_TOASTS do
			holders[index]:Destroy()
		end

		TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(0, 0),
			GroupTransparency = 0,
		}):Play()
		task.delay(TOAST_SECONDS, function()
			if not card.Parent then
				return
			end
			local fade = TweenService:Create(card, TweenInfo.new(0.4), { GroupTransparency = 1 })
			fade.Completed:Connect(function()
				holder:Destroy()
			end)
			fade:Play()
		end)
	end)
end

function Hud.start()
	local gui = new("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local panel, panelStroke, cashLabel, incomeLabel = buildCashPanel(gui)
	buildToasts(gui)

	local function updateIncome()
		incomeLabel.Text = "+$" .. Format.cash(player:GetAttribute("IncomePerSecond") or 0) .. "/s"
	end
	player:GetAttributeChangedSignal("IncomePerSecond"):Connect(updateIncome)
	updateIncome()

	-- leaderstats appears once the server has loaded our data.
	task.spawn(function()
		local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash") :: NumberValue

		-- The shown number tweens toward the real one, so it counts up instead of jumping.
		local shown = Instance.new("NumberValue")
		shown.Value = cash.Value
		shown.Changed:Connect(function(value)
			cashLabel.Text = "$" .. Format.cash(value)
		end)
		cashLabel.Text = "$" .. Format.cash(cash.Value)

		local lastValue = cash.Value
		cash.Changed:Connect(function(value)
			local change = value - lastValue
			lastValue = value
			TweenService:Create(shown, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Value = value }):Play()

			-- Ignore the steady income ticks; only call out purchases, sales and other big changes.
			local income = player:GetAttribute("IncomePerSecond") or 0
			if math.abs(change) > income * 1.5 then
				floatAmount(panel, change)
				-- Flash the border green for gains, red for spends.
				panelStroke.Color = if change > 0 then CASH_GREEN else SPEND_RED
				TweenService:Create(panelStroke, TweenInfo.new(0.6), { Color = PUMPKIN }):Play()
			end
		end)
	end)
end

return Hud
