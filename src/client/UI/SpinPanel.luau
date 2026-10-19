-- The Spin Wheel window, in money green, styled like the other windows. A wheel of six prizes
-- (GameConfig.SpinPrizes, clockwise from the top: gems on blue, money boosts on green, items on
-- their rarity's colour), each slice showing its odds, and a Spin button. A "Spin!" button above
-- the Daily reward button opens it and shows how many spins you have, or the time until the
-- next one. The server picks the prize (SpinService); this only turns the wheel to it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Mobile = require(script.Parent.Mobile)
local ShopPanel = require(script.Parent.ShopPanel)
local Window = require(script.Parent.Window)

local SpinPanel = {}

local GREEN = Theme.MoneyGreen
local GOLD = Color3.fromRGB(255, 200, 60)
local LOCKED_GREY = Color3.fromRGB(90, 84, 104)
local WHITE = Color3.new(1, 1, 1)
local WHEEL_SIZE = 340
local SLICE_DEGREES = 60
-- The wheel's motion (degrees per second / seconds).
local IDLE_SPEED = 18 -- the slow drift while nobody is spinning
local FAST_SPEED = 900 -- full speed after pressing Spin
local SPIN_UP_SECONDS = 0.5 -- from the drift to full speed
local MIN_SLOW_DOWN_TURNS = 3 -- at least this many turns while slowing down
-- The slow-down ends this long before the server pays out (GameConfig.SpinSeconds after the
-- press), covering the spin-up and the trip to the server.
local SLOW_DOWN_MARGIN = 0.7
local PRIZE_SHOW_SECONDS = 3 -- how long the wheel stays still on the prize before drifting again
local new = Window.new

local player = Players.LocalPlayer

local panel: Window.Window

local function spins(): number
	return player:GetAttribute("Spins") or 0
end

-- "7:32" until the next online spin.
local function nextSpinClock(): string
	local seconds = math.max(0, math.ceil((player:GetAttribute("NextSpinAt") or 0) - workspace:GetServerTimeNow()))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- A prize's slice colour: gems blue, money boosts green, items their rarity's colour.
local function prizeColor(prize): Color3
	if prize.kind == "gems" then
		return Theme.GemBlue
	elseif prize.kind == "boost" then
		return GREEN
	end
	local item = ItemConfig.byId[prize.itemId]
	return if item then item.color else WHITE
end

-- The prize's picture and words, drawn inside its slice.
local function buildPrizeContent(prize, parent: Frame)
	if prize.kind == "gems" then
		new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = GameConfig.GemIcon,
			Parent = parent,
		})
		Window.text({
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromScale(1, 0.3),
			TextColor3 = WHITE,
			Text = tostring(prize.amount),
			Parent = parent,
		}, 2)
	elseif prize.kind == "boost" then
		Window.text({
			Size = UDim2.fromScale(1, 0.48),
			TextColor3 = WHITE,
			Text = "x" .. GameConfig.SpinBoostMultiplier,
			Parent = parent,
		}, 2.5)
		Window.text({
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromScale(1, 0.3),
			TextColor3 = WHITE,
			Text = math.floor(prize.seconds / 60 + 0.5) .. " min",
			Parent = parent,
		}, 2)
	else
		local item = ItemConfig.byId[prize.itemId]
		if item then
			local picture = Window.itemPicture(parent, item, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.25, 0))
			picture.BackgroundTransparency = 1
			local stroke = picture:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke:Destroy()
			end
		end
		Window.text({
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromScale(1, 0.3),
			TextColor3 = WHITE,
			Text = string.upper(if item then item.rarity else "Item"),
			Parent = parent,
		}, 2)
	end
end

function SpinPanel.isOpen(): boolean
	return panel ~= nil and panel.isOpen()
end
function SpinPanel.open()
	panel.open()
end
function SpinPanel.close()
	panel.close()
end
function SpinPanel.toggle()
	panel.toggle()
end

function SpinPanel.start()
	local refresh: () -> ()
	panel = Window.create({
		name = "SpinWheel",
		title = "Spin Wheel",
		icon = GameConfig.SpinIcon,
		accent = GREEN,
		width = 440,
		height = 580,
		onOpen = function()
			refresh()
		end,
	})
	local window = panel.window

	local subtitle = Window.text({
		Position = UDim2.fromOffset(20, 70),
		Size = UDim2.new(1, -40, 0, 22),
		TextColor3 = Color3.fromRGB(205, 190, 230),
		Text = "",
		Parent = window,
	})

	-- The wheel: a gold rim, the six slices (they turn together), a hub and a pointer on top.
	local holder = new("Frame", {
		Name = "WheelHolder",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 112),
		Size = UDim2.fromOffset(WHEEL_SIZE, WHEEL_SIZE),
		BackgroundTransparency = 1,
		Parent = window,
	})
	local rim = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.04, 1.04),
		BackgroundColor3 = Window.PANEL_DARK,
		Parent = holder,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = rim })
	new("UIStroke", { Color = GOLD, Thickness = 6, Parent = rim })
	local wheel = new("Frame", {
		Name = "Wheel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = holder,
	})
	local contents = {}
	for index, prize in GameConfig.SpinPrizes do
		local angle = (index - 1) * SLICE_DEGREES
		new("ImageLabel", {
			Name = "Slice" .. index,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = GameConfig.SpinWedgeImage,
			ImageColor3 = prizeColor(prize),
			Rotation = angle,
			Parent = wheel,
		})
		-- The prize sits two thirds of the way out along the middle of its slice, turned to match.
		local radians = math.rad(angle)
		local content = new("Frame", {
			Name = "Prize" .. index,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + 0.3 * math.sin(radians), 0.5 - 0.3 * math.cos(radians)),
			Size = UDim2.fromOffset(84, 84),
			BackgroundTransparency = 1,
			Rotation = angle,
			Parent = wheel,
		})
		buildPrizeContent(prize, content)
		Window.text({
			Position = UDim2.fromScale(0, 0.8),
			Size = UDim2.fromScale(1, 0.2),
			TextColor3 = Color3.fromRGB(235, 230, 245),
			Text = prize.weight .. "%",
			Parent = content,
		}, 1.5)
		contents[index] = { frame = content, scale = new("UIScale", { Parent = content }) }
	end
	local hub = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = GOLD,
		ZIndex = 3,
		Parent = holder,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = hub })
	new("UIStroke", { Color = Window.TEXT_OUTLINE, Thickness = 5, Parent = hub })
	Window.text({
		Name = "Pointer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, -4),
		Size = UDim2.fromOffset(52, 52),
		TextColor3 = GOLD,
		Text = "▼",
		ZIndex = 3,
		Parent = holder,
	}, 4)

	local spinButton, spinLabel = Window.button({
		Name = "SpinButton",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 500),
		Size = UDim2.fromOffset(260, 52),
		Parent = window,
	}, GREEN)

	local spinning = false
	refresh = function()
		local count = spins()
		subtitle.Text = if count > 0
			then `You have {count} spin{if count == 1 then "" else "s"}!`
			else `Next spin in {nextSpinClock()}`
		if spinning then
			spinLabel.Text = "Spinning..."
			Window.paintButton(spinButton, LOCKED_GREY)
		elseif count > 0 then
			spinLabel.Text = "SPIN!"
			Window.paintButton(spinButton, GREEN)
		else
			-- Out of spins: the subtitle shows the wait, and the button sends you to buy more.
			spinLabel.Text = "Get more"
			Window.paintButton(spinButton, GOLD)
		end
	end

	-- How the wheel moves (every frame, in RenderStepped):
	--   "idle"     drifts slowly round, easing back to IDLE_SPEED
	--   "spinUp"   speeds up to FAST_SPEED the moment you press Spin, while the server picks
	--   "slowDown" carries on from full speed and slows dramatically, stopping on the prize
	--   "stopped"  shows the prize for a few seconds, then goes back to idle
	local mode = "idle"
	local speed = IDLE_SPEED -- degrees per second
	local spinUpStarted = 0
	local result: number? = nil -- the prize the server picked, waiting for full speed
	-- The slow-down: from `startAngle` it turns `distance` degrees over `duration` seconds,
	-- following 1 - (1 - t)^power. `power` is picked so its starting speed matches the speed
	-- the wheel already has, so there's no jump.
	local slowDown = { startAngle = 0, distance = 0, duration = 0, power = 1, elapsed = 0, index = 1 }

	local function beginSlowDown(index: number)
		mode = "slowDown"
		local duration = GameConfig.SpinSeconds - SLOW_DOWN_MARGIN
		-- Where the wheel has to stop: the prize's slice under the pointer (not always dead centre).
		local stopAngle = -(index - 1) * SLICE_DEGREES + math.random(-20, 20)
		local startAngle = wheel.Rotation
		local minimum = 360 * MIN_SLOW_DOWN_TURNS
		local distance = minimum + (stopAngle - (startAngle + minimum)) % 360
		slowDown = {
			startAngle = startAngle,
			distance = distance,
			duration = duration,
			-- Speed at the start of 1 - (1 - t)^power is power × distance / duration.
			power = speed * duration / distance,
			elapsed = 0,
			index = index,
		}
	end

	local function landed(index: number)
		mode = "stopped"
		speed = 0
		spinning = false
		refresh()
		-- The winning prize bounces.
		TweenService:Create(
			contents[index].scale,
			TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true),
			{ Scale = 1.3 }
		):Play()
		task.delay(PRIZE_SHOW_SECONDS, function()
			if mode == "stopped" then
				mode = "idle"
			end
		end)
	end

	RunService.RenderStepped:Connect(function(dt: number)
		if mode == "idle" then
			speed += (IDLE_SPEED - speed) * math.min(1, dt * 1.5)
			wheel.Rotation = (wheel.Rotation + speed * dt) % 360
		elseif mode == "spinUp" then
			speed = math.min(FAST_SPEED, speed + FAST_SPEED / SPIN_UP_SECONDS * dt)
			wheel.Rotation += speed * dt
			if result and speed >= FAST_SPEED then
				local index = result
				result = nil
				beginSlowDown(index)
			elseif not result and os.clock() - spinUpStarted > 3 then
				-- The server said no (e.g. the spin was already used): drift again.
				mode = "idle"
				spinning = false
				refresh()
			end
		elseif mode == "slowDown" then
			slowDown.elapsed += dt
			local t = math.min(1, slowDown.elapsed / slowDown.duration)
			wheel.Rotation = slowDown.startAngle + slowDown.distance * (1 - (1 - t) ^ slowDown.power)
			if t >= 1 then
				wheel.Rotation %= 360
				landed(slowDown.index)
			end
		end
	end)

	local function startSpinUp()
		if mode ~= "spinUp" then
			mode = "spinUp"
			spinUpStarted = os.clock()
			speed = math.max(speed, IDLE_SPEED)
		end
	end

	spinButton.Activated:Connect(function()
		if not spinning and spins() == 0 then
			-- "Get more": spins are sold on the Shop's Boosters tab.
			panel.close()
			ShopPanel.openTab("Boosters", "spins_1")
		elseif not spinning and spins() > 0 and (mode == "idle" or mode == "stopped") then
			spinning = true
			refresh()
			for _, content in contents do
				content.scale.Scale = 1
			end
			startSpinUp()
			Remotes.Spin:FireServer()
		end
	end)

	-- The server picked a prize: once the wheel is at full speed, slow down onto it.
	Remotes.SpinResult.OnClientEvent:Connect(function(index: number)
		spinning = true
		panel.open()
		startSpinUp()
		result = index
		refresh()
	end)

	-- The "Spin!" button above the Daily reward button.
	local openGui = new("ScreenGui", {
		Name = "SpinButton",
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local opener, openerLabel = Window.button({
		Name = "Open",
		AnchorPoint = Vector2.new(1, 1),
		-- Stacked on the Daily reward and Invite buttons, which are smaller on phones.
		Position = UDim2.new(1, -72, 1, -14 - 104 * Mobile.scale),
		Size = UDim2.fromOffset(150, 40),
		Parent = openGui,
	}, GREEN)
	local openerScale = new("UIScale", { Scale = Mobile.scale, Parent = opener })
	local openerPulse = TweenService:Create(
		openerScale,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.08 * Mobile.scale }
	)
	opener.Activated:Connect(panel.toggle)

	local function refreshOpener()
		local count = spins()
		if count > 0 then
			openerLabel.Text = `Spin! ({count})`
			Window.paintButton(opener, GREEN)
			openerPulse:Play()
		else
			openerLabel.Text = "Spin " .. nextSpinClock()
			Window.paintButton(opener, LOCKED_GREY)
			openerPulse:Cancel()
			openerScale.Scale = Mobile.scale
		end
	end
	player:GetAttributeChangedSignal("Spins"):Connect(function()
		refreshOpener()
		if panel.isOpen() then
			refresh()
		end
	end)
	-- The countdowns tick.
	task.spawn(function()
		while true do
			refreshOpener()
			if panel.isOpen() then
				refresh()
			end
			task.wait(1)
		end
	end)
end

return SpinPanel
