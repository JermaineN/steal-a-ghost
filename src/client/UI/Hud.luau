-- On-screen HUD: a big outlined cash number in the bottom-left (it counts up, pops, and big
-- gains/spends float a "+$X" / "-$X" off to its right) with the income under it, gems above it
-- (they count up too, with a floating "+N"), and pop-up messages.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local StoreConfig = require(ReplicatedStorage.Shared.Config.StoreConfig)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Mobile = require(script.Parent.Mobile)

local player = Players.LocalPlayer

local Hud = {}

local CASH_GREEN = Theme.MoneyGreen
local SPEND_RED = Theme.SpendRed
local GEM_BLUE = Theme.GemBlue
local FRIEND_PINK = Theme.FriendPink
local BOOST_GOLD = Color3.fromRGB(255, 210, 60)
local GEMS_ROW_HEIGHT = 42 -- pixels: the gem icon and number above the cash

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
-- The optional smaller line above a message (e.g. "Don't leave!" while being robbed).
local TOAST_NOTE_SIZE = 24
local TOAST_NOTE_COLOR = Color3.fromRGB(255, 240, 200)
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

-- Big outlined cash number in the bottom-left corner, with the income line under it and the
-- gems line above it.
local function buildCashDisplay(gui: ScreenGui)
	local display = new("Frame", {
		Name = "CashDisplay",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 18, 1, -14),
		Size = UDim2.fromOffset(340, 96),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	-- Used to "pop" the number when cash jumps. Starts at Mobile.scale (smaller on phones).
	local pop = new("UIScale", { Scale = Mobile.scale, Parent = display })

	local cashLabel = text({
		Name = "Cash",
		Size = UDim2.new(1, 0, 0, 64),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = CASH_GREEN,
		Text = "$0",
		Parent = display,
	})
	outline(cashLabel, 4)

	-- "x2" sticker just right of the cash number while you own the 2x Money pass.
	local passBadge = text({
		Name = "PassBadge",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(56, 40),
		TextColor3 = BOOST_GOLD,
		Text = "x" .. GameConfig.PassMoneyMultiplier,
		Rotation = -10,
		Visible = false,
		Parent = display,
	})
	outline(passBadge, 3.5)

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

	-- Gems: the gem icon and the amount, in their own row above the cash.
	local gemsRow = new("Frame", {
		Name = "Gems",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromOffset(2, 0),
		Size = UDim2.new(1, -2, 0, GEMS_ROW_HEIGHT),
		BackgroundTransparency = 1,
		Parent = display,
	})
	new("ImageLabel", {
		Name = "Icon",
		Size = UDim2.fromOffset(GEMS_ROW_HEIGHT, GEMS_ROW_HEIGHT),
		BackgroundTransparency = 1,
		Image = GameConfig.GemIcon,
		Parent = gemsRow,
	})
	local gemsLabel = text({
		Name = "Amount",
		Position = UDim2.fromOffset(GEMS_ROW_HEIGHT + 6, 0),
		Size = UDim2.new(1, -(GEMS_ROW_HEIGHT + 6), 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GEM_BLUE,
		Text = "0",
		Parent = gemsRow,
	})
	outline(gemsLabel, 3)
	-- Used to "pop" the row when gems come in.
	local gemsPop = new("UIScale", { Parent = gemsRow })

	-- Keeps the badge beside the number as it grows, and shows it only with the pass.
	-- (TextBounds is in on-screen pixels, so undo the display's phone scale.)
	local function updateBadge()
		passBadge.Visible = StoreConfig.ownsPass(player, "double_money")
		passBadge.Position = UDim2.fromOffset(cashLabel.TextBounds.X / Mobile.scale + 10, 32)
	end
	cashLabel:GetPropertyChangedSignal("TextBounds"):Connect(updateBadge)
	player:GetAttributeChangedSignal("Pass_double_money"):Connect(updateBadge)
	updateBadge()

	return display, pop, cashLabel, incomeLabel, gemsRow, gemsLabel, gemsPop, passBadge
end

-- A "+$X" / "-$X" that floats up off the cash number and fades away.
local function floatAmount(display: Frame, cashLabel: TextLabel, passBadge: TextLabel, amount: number)
	local gain = amount > 0
	-- Starts just to the right of the cash number (and the "x2" badge, if shown), clear of the
	-- gems above it, and drifts upward.
	local badgeWidth = if passBadge.Visible then passBadge.Size.X.Offset + 4 else 0
	local label = text({
		AnchorPoint = Vector2.new(0, 0.5),
		-- TextBounds and AbsoluteSize are on-screen pixels, so undo the display's phone scale.
		Position = UDim2.fromOffset(
			cashLabel.TextBounds.X / Mobile.scale + 14 + badgeWidth,
			cashLabel.AbsoluteSize.Y / Mobile.scale / 2
		),
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

-- A "+N" with a little gem that floats up off the gems number and fades away.
local function floatGems(gemsRow: Frame, gemsLabel: TextLabel, amount: number)
	local holder = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(
			gemsLabel.Position.X.Offset + gemsLabel.TextBounds.X / Mobile.scale + 12,
			GEMS_ROW_HEIGHT / 2
		),
		Size = UDim2.fromOffset(160, 30),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = gemsRow,
	})
	local label = text({
		Size = UDim2.fromOffset(90, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GEM_BLUE,
		Text = "+" .. Format.cash(amount),
		ZIndex = 5,
		Parent = holder,
	})
	local labelOutline = outline(label, 3)
	local labelWidth = label.TextBounds.X / Mobile.scale
	label.Size = UDim2.fromOffset(labelWidth + 4, 30)
	local icon = new("ImageLabel", {
		Position = UDim2.fromOffset(labelWidth + 6, 1),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Image = GameConfig.GemIcon,
		ZIndex = 5,
		Parent = holder,
	})
	local fade = TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(labelOutline, fade, { Transparency = 1 }):Play()
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(icon, fade, { ImageTransparency = 1 }):Play()
	local rise = TweenService:Create(holder, fade, { Position = holder.Position + UDim2.fromOffset(8, -40) })
	rise.Completed:Connect(function()
		holder:Destroy()
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
	-- device (like the sidebar) can call Hud.showToast directly. `options.note` adds a smaller
	-- line above the message (e.g. a warning), and `options.seconds` keeps it up longer.
	local function showToast(message: string, kind: string, options: { note: string?, seconds: number? }?)
		local style = TOAST_STYLES[kind] or TOAST_STYLES.info
		local note = options and options.note
		local seconds = options and options.seconds or TOAST_SECONDS
		toastCount += 1

		-- The list layout positions this holder; the text inside it pops in and floats away.
		local holder = new("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = toastCount,
			BackgroundTransparency = 1,
			Parent = toasts,
		})
		-- The note (if any) sits above the message; both move together.
		local content = new("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = holder,
		})
		new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Parent = content,
		})
		local tilt = if math.random() < 0.5 then -6 else 6
		local labels: { TextLabel } = {}
		local outlines: { UIStroke } = {}
		local function addLine(lineText: string, size: number, color: Color3, order: number): TextLabel
			local line = new("TextLabel", {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Font = TOAST_FONT,
				TextSize = size,
				TextWrapped = true,
				RichText = true,
				TextColor3 = color,
				Text = lineText,
				Rotation = tilt,
				LayoutOrder = order,
				Parent = content,
			})
			table.insert(labels, line)
			table.insert(outlines, outline(line, if size < TOAST_TEXT_SIZE then 2.5 else 3.5))
			return line
		end
		if note then
			addLine(toastRichText(note, style.money), TOAST_NOTE_SIZE, TOAST_NOTE_COLOR, 1)
		end
		addLine(toastRichText(message, style.money), TOAST_TEXT_SIZE, style.color, 2)
		local pop = new("UIScale", { Scale = 0.2, Parent = content })

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
		for _, line in labels do
			TweenService:Create(line, bounce, { Rotation = 0 }):Play()
		end

		-- Then float up and fade away.
		task.delay(seconds, function()
			if not content.Parent then
				return
			end
			local away = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			for _, lineOutline in outlines do
				TweenService:Create(lineOutline, away, { Transparency = 1 }):Play()
			end
			for _, line in labels do
				TweenService:Create(line, away, { TextTransparency = 1 }):Play()
			end
			local fade = TweenService:Create(content, away, { Position = UDim2.fromOffset(0, -24) })
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
		-- Above the menu windows (5), so messages like "You bought ..." show over the Shop.
		DisplayOrder = 6,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local display, pop, cashLabel, incomeLabel, gemsRow, gemsLabel, gemsPop, passBadge = buildCashDisplay(gui)
	buildToasts(gui)

	-- "Income: +$150/s", plus the friend boost in its own colour while friends are here.
	incomeLabel.RichText = true
	local function updateIncome()
		local line = "Income: +$" .. Format.cash(player:GetAttribute("IncomePerSecond") or 0) .. "/s"
		local friendBoost = player:GetAttribute("FriendBoost") or 0
		if friendBoost > 0 then
			line ..= `  <font color="#{FRIEND_PINK:ToHex()}">+{math.floor(friendBoost * 100 + 0.5)}% friends</font>`
		end
		-- A Spin Wheel money boost, with the time it has left.
		local boostLeft = (player:GetAttribute("MoneyBoostUntil") or 0) - workspace:GetServerTimeNow()
		if boostLeft > 0 then
			local seconds = math.ceil(boostLeft)
			local clock = string.format("%d:%02d", seconds // 60, seconds % 60)
			line ..= `  <font color="#{BOOST_GOLD:ToHex()}">x{GameConfig.SpinBoostMultiplier} {clock}</font>`
		end
		incomeLabel.Text = line
	end
	player:GetAttributeChangedSignal("IncomePerSecond"):Connect(updateIncome)
	player:GetAttributeChangedSignal("FriendBoost"):Connect(updateIncome)
	player:GetAttributeChangedSignal("MoneyBoostUntil"):Connect(updateIncome)
	updateIncome()
	-- The boost's clock ticks down.
	task.spawn(function()
		while true do
			task.wait(1)
			if player:GetAttribute("MoneyBoostUntil") then
				updateIncome()
			end
		end
	end)

	-- leaderstats appears once the server has loaded our data.
	task.spawn(function()
		local gems = player:WaitForChild("leaderstats"):WaitForChild("Gems") :: IntValue
		-- Like the cash, the shown number counts toward the real one.
		local shown = Instance.new("NumberValue")
		shown.Value = gems.Value
		shown.Changed:Connect(function(value)
			gemsLabel.Text = Format.cash(value)
		end)
		gemsLabel.Text = Format.cash(gems.Value)

		local lastValue = gems.Value
		gems.Changed:Connect(function(value)
			local change = value - lastValue
			lastValue = value
			TweenService:Create(shown, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Value = value }):Play()
			if change > 0 then
				floatGems(gemsRow, gemsLabel, change)
				gemsPop.Scale = 1.25
				TweenService:Create(gemsPop, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end
		end)
	end)
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
				floatAmount(display, cashLabel, passBadge, change)
				-- A quick pop of the number.
				pop.Scale = 1.12 * Mobile.scale
				TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = Mobile.scale }):Play()
			end
		end)
	end)
end

return Hud
