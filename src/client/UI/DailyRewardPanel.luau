-- The Daily Reward window, in gem blue, styled like the other windows. It pops up by itself
-- when you join and today's reward is waiting: a row of seven day cards (days already claimed
-- this streak are ticked, today's glows), and a Claim button. If you close it without claiming,
-- a "Daily reward" button above the Invite button brings it back. The server decides everything
-- (DailyRewardService) and tells this device through the "DailyAvailable" and
-- "DailyStreakDay" attributes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DailyReward = require(ReplicatedStorage.Shared.DailyReward)
local Format = require(ReplicatedStorage.Shared.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Window = require(script.Parent.Window)

local DailyRewardPanel = {}

local GEM_BLUE = Theme.GemBlue
local GOLD = Color3.fromRGB(255, 190, 40)
local LOCKED_GREY = Color3.fromRGB(90, 84, 104)
local WHITE = Color3.new(1, 1, 1)
local DAYS_SHOWN = #GameConfig.DailyRewardGems
local CARD_WIDTH, CARD_GAP = 66, 8
local POPUP_DELAY = 3 -- seconds after joining before it pops up
local new = Window.new

local player = Players.LocalPlayer

local panel: Window.Window

local function available(): boolean
	return player:GetAttribute("DailyAvailable") == true
end

local function streakDay(): number
	return player:GetAttribute("DailyStreakDay") or 1
end

type DayCard = { frame: Frame, stroke: UIStroke, tick: TextLabel, scale: UIScale, dayLabel: TextLabel }

local function buildDayCard(parent: Instance, index: number): DayCard
	local frame = new("Frame", {
		Position = UDim2.fromOffset((index - 1) * (CARD_WIDTH + CARD_GAP), 0),
		Size = UDim2.fromOffset(CARD_WIDTH, 96),
		BackgroundColor3 = WHITE,
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(0.14, 0), Parent = frame })
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(GEM_BLUE:Lerp(Window.PANEL_DARK, 0.6), Window.PANEL_DARK),
		Parent = frame,
	})
	local stroke = new("UIStroke", { Color = GEM_BLUE, Thickness = 2, Parent = frame })
	local scale = new("UIScale", { Parent = frame })
	local dayLabel = Window.text({
		Position = UDim2.fromOffset(4, 6),
		Size = UDim2.new(1, -8, 0, 18),
		TextColor3 = WHITE,
		Text = "Day " .. index,
		Parent = frame,
	})
	new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 28),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		Image = GameConfig.GemIcon,
		Parent = frame,
	})
	Window.text({
		Position = UDim2.fromOffset(4, 66),
		Size = UDim2.new(1, -8, 0, 22),
		TextColor3 = GEM_BLUE,
		Text = "+" .. Format.cash(GameConfig.DailyRewardGems[index]),
		Parent = frame,
	}, 2)
	-- A big green tick over days already claimed this streak.
	local tick = Window.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(50, 50),
		TextColor3 = Theme.MoneyGreen,
		Text = "✓",
		ZIndex = 2,
		Visible = false,
		Parent = frame,
	}, 3)
	return { frame = frame, stroke = stroke, tick = tick, scale = scale, dayLabel = dayLabel }
end

function DailyRewardPanel.isOpen(): boolean
	return panel ~= nil and panel.isOpen()
end
function DailyRewardPanel.open()
	panel.open()
end
function DailyRewardPanel.close()
	panel.close()
end
function DailyRewardPanel.toggle()
	panel.toggle()
end

function DailyRewardPanel.start()
	local width = DAYS_SHOWN * CARD_WIDTH + (DAYS_SHOWN - 1) * CARD_GAP + 60
	local refresh: () -> ()
	panel = Window.create({
		name = "DailyReward",
		title = "Daily Reward",
		icon = GameConfig.GemIcon,
		accent = GEM_BLUE,
		width = width,
		height = 330,
		onOpen = function()
			refresh()
		end,
	})
	local window = panel.window

	local subtitle = Window.text({
		Position = UDim2.fromOffset(20, 72),
		Size = UDim2.new(1, -40, 0, 22),
		TextColor3 = Color3.fromRGB(205, 190, 230),
		Text = "Come back every day for bigger rewards!",
		Parent = window,
	})
	local row = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 108),
		Size = UDim2.fromOffset(DAYS_SHOWN * CARD_WIDTH + (DAYS_SHOWN - 1) * CARD_GAP, 96),
		BackgroundTransparency = 1,
		Parent = window,
	})
	local dayCards = {}
	for index = 1, DAYS_SHOWN do
		dayCards[index] = buildDayCard(row, index)
	end

	local claim, claimLabel = Window.button({
		Name = "Claim",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 236),
		Size = UDim2.fromOffset(260, 52),
		Parent = window,
	}, Theme.MoneyGreen)
	local claimPulse = new("UIScale", { Parent = claim })
	local pulseTween = TweenService:Create(
		claimPulse,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.06 }
	)
	local todayPulse: Tween? = nil

	refresh = function()
		local day = streakDay()
		local canClaim = available()
		-- Which card is "today": past the last day, the last card stands for every later day.
		local todayIndex = math.min(day, DAYS_SHOWN)
		if todayPulse then
			todayPulse:Cancel()
			todayPulse = nil
		end
		for index, card in dayCards do
			card.scale.Scale = 1
			-- Ticked: days before today in this streak, plus today once it's claimed.
			local claimed = index < todayIndex or (index == todayIndex and not canClaim)
			card.tick.Visible = claimed
			card.frame.BackgroundTransparency = if claimed then 0.4 else 0
			card.stroke.Color = if index == todayIndex then GOLD else if claimed then LOCKED_GREY else GEM_BLUE
			card.stroke.Thickness = if index == todayIndex then 3.5 else 2
			card.dayLabel.Text = if index == DAYS_SHOWN and day > DAYS_SHOWN then "Day " .. day else "Day " .. index
			if index == todayIndex and canClaim then
				todayPulse = TweenService:Create(
					card.scale,
					TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Scale = 1.1 }
				)
				todayPulse:Play()
			end
		end
		if canClaim then
			claimLabel.Text = "Claim +" .. Format.cash(DailyReward.gems(day)) .. " gems"
			Window.paintButton(claim, Theme.MoneyGreen)
			subtitle.Text = if day == 1
				then "Come back every day for bigger rewards!"
				else `Day {day} streak! Don't break it!`
			pulseTween:Play()
		else
			claimLabel.Text = "Come back tomorrow!"
			Window.paintButton(claim, LOCKED_GREY)
			pulseTween:Cancel()
			claimPulse.Scale = 1
		end
	end

	claim.Activated:Connect(function()
		if available() then
			claimLabel.Text = "..."
			Remotes.DailyClaim:FireServer()
		end
	end)

	-- The "Daily reward" button above the Invite button, while today's reward is waiting.
	local reopenGui = new("ScreenGui", {
		Name = "DailyRewardButton",
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local reopen, reopenLabel = Window.button({
		Name = "Open",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -72, 1, -70),
		Size = UDim2.fromOffset(150, 40),
		Visible = false,
		Parent = reopenGui,
	}, GEM_BLUE)
	reopenLabel.Text = "Daily reward!"
	local reopenScale = new("UIScale", { Parent = reopen })
	TweenService:Create(
		reopenScale,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.08 }
	):Play()
	reopen.Activated:Connect(panel.open)

	local poppedUp = false
	local function onChanged()
		reopen.Visible = available()
		if panel.isOpen() then
			refresh()
		end
		-- Claimed: show the tick for a moment, then close.
		if not available() and panel.isOpen() then
			task.delay(1.5, panel.close)
		end
		-- Pop up once per session, the first time a reward is waiting.
		if available() and not poppedUp then
			poppedUp = true
			task.delay(POPUP_DELAY, function()
				if available() then
					panel.open()
				end
			end)
		end
	end
	player:GetAttributeChangedSignal("DailyAvailable"):Connect(onChanged)
	player:GetAttributeChangedSignal("DailyStreakDay"):Connect(onChanged)
	onChanged()
end

return DailyRewardPanel
