-- The "Welcome back!" window: when you rejoin, the server pays your offline earnings
-- (OfflineService) and sends OfflineEarnings; this shows how long you were away and how much
-- your ghosts made, with the amount counting up. Built like the other windows, in money green.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Offline = require(ReplicatedStorage.Shared.Offline)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Window = require(script.Parent.Window)

local WelcomeBackPanel = {}

local WIDTH, HEIGHT = 440, 300

local panel: Window.Window

function WelcomeBackPanel.isOpen(): boolean
	return panel ~= nil and panel.isOpen()
end

function WelcomeBackPanel.start()
	panel = Window.create({
		name = "WelcomeBack",
		title = "Welcome back!",
		icon = GameConfig.MenuIcons.Shop,
		accent = Theme.MoneyGreen,
		width = WIDTH,
		height = HEIGHT,
	})
	local window = panel.window

	local away = Window.text({
		Position = UDim2.fromOffset(20, Window.HEADER_HEIGHT + 4),
		Size = UDim2.new(1, -40, 0, 26),
		TextColor3 = Color3.fromRGB(205, 190, 230),
		Parent = window,
	}, 1.5)
	local amount = Window.text({
		Position = UDim2.fromOffset(20, Window.HEADER_HEIGHT + 38),
		Size = UDim2.new(1, -40, 0, 70),
		TextColor3 = Theme.MoneyGreen,
		Parent = window,
	}, 4)
	local amountScale = Window.new("UIScale", { Parent = amount })
	Window.text({
		Position = UDim2.fromOffset(20, Window.HEADER_HEIGHT + 112),
		Size = UDim2.new(1, -40, 0, 18),
		TextColor3 = Color3.fromRGB(150, 140, 170),
		Text = `Your ghosts earn {math.floor(GameConfig.OfflineIncomeShare * 100 + 0.5)}% while you're away, for up to {GameConfig.OfflineMaxHours} hours`,
		Parent = window,
	}, 1.25)
	local nice, niceLabel = Window.button({
		Name = "Nice",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(200, 48),
		Parent = window,
	}, Theme.MoneyGreen)
	niceLabel.Text = "Nice!"
	nice.Activated:Connect(panel.close)

	Remotes.OfflineEarnings.OnClientEvent:Connect(function(earned: number, secondsAway: number)
		away.Text = `You were away for {Offline.formatDuration(secondsAway)}. Your ghosts earned:`
		panel.open()
		-- Count the amount up from zero, then give it a little pop.
		local shown = Instance.new("NumberValue")
		shown.Changed:Connect(function(value)
			amount.Text = "+$" .. Format.cash(value)
		end)
		amount.Text = "+$0"
		local count = TweenService:Create(
			shown,
			TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Value = earned }
		)
		count.Completed:Once(function()
			amountScale.Scale = 1.2
			TweenService:Create(amountScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			shown:Destroy()
		end)
		count:Play()
	end)
end

return WelcomeBackPanel
