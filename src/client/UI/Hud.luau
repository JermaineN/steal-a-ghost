-- On-screen HUD: a big outlined cash number in the bottom-left (it counts up, pops, and big
-- gains/spends float a "+$X" / "-$X" off it) with the income under it, and pop-up messages.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)

local player = Players.LocalPlayer

local Hud = {}

local CASH_GREEN = Theme.MoneyGreen
local SPEND_RED = Theme.SpendRed

-- Pop-up messages ("You bought Boo!", "Outbid!"): big rounded text with a dark outline,
-- no box, in the lower middle of the screen. Colour shows the kind of message, and dollar
-- amounts stand out in their own colour.
local TOAST_STYLES = {
	success = { color = Color3.fromRGB(130, 255, 100), money = Color3.fromRGB(255, 225, 60) },
	error = { color = Color3.fromRGB(255, 95, 95), money = Color3.fromRGB(130, 255, 100) },
	info = { color = Color3.fromRGB(255, 225, 90), money = Color3.fromRGB(130, 255, 100) },
}
local TOAST_FONT = Enum.Font.FredokaOne -- rounded and bold
local TOAST_TEXT_SIZE = 40
local MAX_TOASTS = 4
local TOAST_SECONDS = 3

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

-- Text with a dark outline so it stays readable over any background.
local function text(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextScaled = true
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0.4
	props.TextStrokeColor3 = Color3.fromRGB(20, 8, 30)
	return new("TextLabel", props)
end

-- A thick black outline around a label's text (chunkier than the built-in text stroke).
local function outline(label: TextLabel, thickness: number): UIStroke
	label.TextStrokeTransparency = 1
	return new("UIStroke", {
		Color = Color3.new(0, 0, 0),
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = label,
	})
end

-- Big outlined cash number in the bottom-left corner, with the income line under it.
local function buildCashDisplay(gui: ScreenGui)
	local display = new("Frame", {
		Name = "CashDisplay",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 18, 1, -14),
		Size = UDim2.fromOffset(340, 96),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	-- Used to "pop" the number when cash jumps.
	local pop = new("UIScale", { Parent = display })

	local cashLabel = text({
		Name = "Cash",
		Size = UDim2.new(1, 0, 0, 64),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = CASH_GREEN,
		Text = "$0",
		Parent = display,
	})
	outline(cashLabel, 4)

	local incomeLabel = text({
		Name = "Income",
		Position = UDim2.fromOffset(2, 66),
		Size = UDim2.new(1, -2, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = CASH_GREEN,
		Text = "Income: +$0/s",
		Parent = display,
	})
	outline(incomeLabel, 2.5)

	return display, pop, cashLabel, incomeLabel
end

-- A "+$X" / "-$X" that floats up off the cash number and fades away.
local function floatAmount(display: Frame, amount: number)
	local gain = amount > 0
	-- Starts just above the cash number and drifts upward.
	local label = text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromOffset(6, -2),
		Size = UDim2.fromOffset(200, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if gain then CASH_GREEN else SPEND_RED,
		Text = (if gain then "+$" else "-$") .. Format.cash(math.abs(amount)),
		ZIndex = 5,
		Parent = display,
	})
	local labelOutline = outline(label, 3)
	TweenService:Create(labelOutline, TweenInfo.new(1.2), { Transparency = 1 }):Play()
	local rise = TweenService:Create(
		label,
		TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = label.Position + UDim2.fromOffset(0, -36), TextTransparency = 1 }
	)
	rise.Completed:Connect(function()
		label:Destroy()
	end)
	rise:Play()
end

-- Makes a message safe for rich text (so a "<" in a name can't break it), then colours every
-- dollar amount ("$37", "$1.50K"). A full stop right after an amount stays uncoloured.
local function toastRichText(message: string, moneyColor: Color3): string
	local escaped = message:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	local hex = moneyColor:ToHex()
	return (
		escaped:gsub("%$%d[%d%.]*%a*", function(amount)
			local body, fullStop = amount:match("^(.-)(%.?)$")
			return `<font color="#{hex}">{body}</font>{fullStop}`
		end)
	)
end

-- Shrinks the messages on small (phone) screens.
local function scaleToScreen(scale: UIScale)
	local function update()
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 900
		scale.Scale = math.clamp(height / 800, 0.6, 1)
	end
	update()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
end

local function buildToasts(gui: ScreenGui)
	local toasts = new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.76, 0),
		Size = UDim2.new(0.9, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	})
	new("UISizeConstraint", { MaxSize = Vector2.new(760, math.huge), Parent = toasts })
	scaleToScreen(new("UIScale", { Parent = toasts }))
	-- Newest message at the bottom; older ones move up.
	new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 2),
		Parent = toasts,
	})

	local toastCount = 0
	-- Shows a pop-up message. Messages from the server arrive through Notify; scripts on this
	-- device (like the sidebar) can call Hud.showToast directly.
	local function showToast(message: string, kind: string)
		local style = TOAST_STYLES[kind] or TOAST_STYLES.info
		toastCount += 1

		-- The list layout positions this holder; the text inside it pops in and floats away.
		local holder = new("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = toastCount,
			BackgroundTransparency = 1,
			Parent = toasts,
		})
		local label = new("TextLabel", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = TOAST_FONT,
			TextSize = TOAST_TEXT_SIZE,
			TextWrapped = true,
			RichText = true,
			TextColor3 = style.color,
			Text = toastRichText(message, style.money),
			Rotation = if math.random() < 0.5 then -6 else 6,
			Parent = holder,
		})
		local labelOutline = outline(label, 3.5)
		local pop = new("UIScale", { Scale = 0.2, Parent = label })

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

		-- Pop in: grow past full size with a bounce, straightening out the tilt.
		local bounce = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(pop, bounce, { Scale = 1 }):Play()
		TweenService:Create(label, bounce, { Rotation = 0 }):Play()

		-- Then float up and fade away.
		task.delay(TOAST_SECONDS, function()
			if not label.Parent then
				return
			end
			local away = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(labelOutline, away, { Transparency = 1 }):Play()
			local fade = TweenService:Create(label, away, {
				Position = UDim2.fromOffset(0, -24),
				TextTransparency = 1,
			})
			fade.Completed:Connect(function()
				holder:Destroy()
			end)
			fade:Play()
		end)
	end
	Hud.showToast = showToast
	Remotes.Notify.OnClientEvent:Connect(showToast)
end

function Hud.start()
	local gui = new("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local display, pop, cashLabel, incomeLabel = buildCashDisplay(gui)
	buildToasts(gui)

	local function updateIncome()
		incomeLabel.Text = "Income: +$" .. Format.cash(player:GetAttribute("IncomePerSecond") or 0) .. "/s"
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
				floatAmount(display, change)
				-- A quick pop of the number.
				pop.Scale = 1.12
				TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end
		end)
	end)
end

return Hud
