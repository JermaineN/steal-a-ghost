-- The Codes window (side menu → Codes): type a code (from a video, the description or the
-- Roblox group) and press Redeem. The server checks it (CodeService) and answers with
-- CodeResult, shown on the line under the box: green for a reward, red otherwise.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Window = require(script.Parent.Window)

local CodesPanel = {}

local WIDTH, HEIGHT = 460, 300
CodesPanel.ACCENT = Color3.fromRGB(60, 215, 200) -- the window's outline and its side menu button
local FAIL_RED = Color3.fromRGB(255, 90, 90)
local WAIT_SECONDS = 5 -- give up waiting for the server's answer after this long

local panel: Window.Window?

function CodesPanel.isOpen(): boolean
	return panel ~= nil and panel.isOpen()
end

function CodesPanel.open()
	if panel then
		panel.open()
	end
end

function CodesPanel.close()
	if panel then
		panel.close()
	end
end

function CodesPanel.toggle()
	if panel then
		panel.toggle()
	end
end

function CodesPanel.start()
	local result: TextLabel
	local box: TextBox
	local created = Window.create({
		name = "Codes",
		title = "Codes",
		icon = GameConfig.MenuIcons.Codes,
		accent = CodesPanel.ACCENT,
		width = WIDTH,
		height = HEIGHT,
		onOpen = function()
			result.Text = ""
			box.Text = ""
		end,
	})
	panel = created
	local window = created.window

	Window.text({
		Position = UDim2.fromOffset(20, Window.HEADER_HEIGHT + 2),
		Size = UDim2.new(1, -40, 0, 22),
		TextColor3 = Color3.fromRGB(205, 190, 230),
		Text = "Find codes in our videos and Roblox group!",
		Parent = window,
	}, 1.25)

	-- The text box: a dark rounded field with an accent outline.
	local field = Window.new("Frame", {
		Position = UDim2.fromOffset(20, Window.HEADER_HEIGHT + 36),
		Size = UDim2.new(1, -40, 0, 56),
		BackgroundColor3 = Color3.fromRGB(18, 10, 30),
		Parent = window,
	})
	Window.new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = field })
	local fieldStroke = Window.new("UIStroke", { Color = CodesPanel.ACCENT, Thickness = 2, Parent = field })
	box = Window.new("TextBox", {
		Name = "CodeBox",
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 1, -16),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		PlaceholderText = "Type a code...",
		PlaceholderColor3 = Color3.fromRGB(130, 115, 155),
		Text = "",
		ClearTextOnFocus = false,
		Parent = field,
	})
	box.Focused:Connect(function()
		fieldStroke.Thickness = 3
	end)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > GameConfig.CodeMaxLength then
			box.Text = string.sub(box.Text, 1, GameConfig.CodeMaxLength)
		end
	end)

	result = Window.text({
		Name = "Result",
		Position = UDim2.fromOffset(20, Window.HEADER_HEIGHT + 102),
		Size = UDim2.new(1, -40, 0, 30),
		TextColor3 = Theme.MoneyGreen,
		Text = "",
		Parent = window,
	}, 2)
	local resultScale = Window.new("UIScale", { Parent = result })

	local redeemButton, redeemLabel = Window.button({
		Name = "Redeem",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(220, 52),
		Parent = window,
	}, CodesPanel.ACCENT)
	redeemLabel.Text = "Redeem"

	local waiting = false
	local function show(success: boolean, message: string)
		result.TextColor3 = if success then Theme.MoneyGreen else FAIL_RED
		result.Text = message
		resultScale.Scale = 1.2
		TweenService:Create(resultScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	local function setWaiting(on: boolean)
		waiting = on
		redeemLabel.Text = if on then "..." else "Redeem"
	end

	local function redeem()
		if waiting then
			return
		end
		local text = string.match(box.Text, "^%s*(.-)%s*$") or ""
		if text == "" then
			show(false, "Type a code first")
			return
		end
		setWaiting(true)
		Remotes.RedeemCode:FireServer(text)
		local asked = os.clock()
		task.delay(WAIT_SECONDS, function()
			if waiting and os.clock() - asked >= WAIT_SECONDS - 0.1 then
				setWaiting(false)
				show(false, "No answer, try again")
			end
		end)
	end
	redeemButton.Activated:Connect(redeem)
	box.FocusLost:Connect(function(enterPressed: boolean)
		fieldStroke.Thickness = 2
		if enterPressed then
			redeem()
		end
	end)

	Remotes.CodeResult.OnClientEvent:Connect(function(success: boolean, message: string)
		setWaiting(false)
		show(success, message)
		if success then
			box.Text = ""
		end
	end)
end

return CodesPanel
