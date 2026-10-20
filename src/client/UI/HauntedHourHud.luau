-- Haunted Hour on screen (the event itself is run by the server, see HauntedHourService):
--   Before it:  a small pill at the top of the screen counting down ("Haunted Hour in 12:34"),
--               and a "starting soon" message shortly before.
--   It starts:  a lightning flash, thunder, a big blood-red "HAUNTED HOUR!" title, and the
--               world turns red. The pill turns red and counts down the time left, with what's
--               boosted under it.
--   It ends:    the red fades away and a message says it's over.
-- Each of these (starting soon, begun, over) also puts a line in chat (SystemChat).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local HauntedHour = require(ReplicatedStorage.Shared.HauntedHour)
local Hud = require(script.Parent.Hud)
local Mobile = require(script.Parent.Mobile)
local SystemChat = require(script.Parent.Parent.SystemChat)

local HauntedHourHud = {}

local PANEL_DARK = Color3.fromRGB(28, 16, 44)
local PUMPKIN = Color3.fromRGB(255, 140, 30)
local BLOOD = Color3.fromRGB(255, 40, 50)
local TEXT_OUTLINE = Color3.fromRGB(20, 8, 30)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.FredokaOne
local BLOOD_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 120)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 30, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 0, 15)),
})

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

local function outlinedText(props: { [string]: any }, thickness: number): (TextLabel, UIStroke)
	props.BackgroundTransparency = 1
	props.Font = FONT
	local label = new("TextLabel", props)
	local stroke = new("UIStroke", {
		Color = TEXT_OUTLINE,
		Thickness = thickness,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = label,
	})
	return label, stroke
end

-- The big title when it starts, with a lightning flash and thunder.
local function announce(gui: ScreenGui)
	local flash = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = gui,
	})
	-- Lightning flickers: bright, dim, bright again, then gone.
	task.spawn(function()
		task.wait(0.08)
		flash.BackgroundTransparency = 0.7
		task.wait(0.08)
		flash.BackgroundTransparency = 0.25
		TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		task.wait(0.7)
		flash:Destroy()
	end)

	local sound = new("Sound", {
		SoundId = "rbxassetid://" .. GameConfig.HauntedHourSound.soundId,
		Volume = GameConfig.HauntedHourSound.volume,
		Parent = SoundService,
	})
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()

	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 800
	local width = if camera then camera.ViewportSize.X else 1200
	local title, titleStroke = outlinedText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.33),
		Size = UDim2.fromOffset(900, 110),
		TextSize = 100,
		TextColor3 = WHITE,
		Text = "HAUNTED HOUR!",
		ZIndex = 5,
		Parent = gui,
	}, 6)
	new("UIGradient", { Color = BLOOD_GRADIENT, Rotation = 90, Parent = title })
	local titleScale = new("UIScale", {
		Scale = 2.5 * math.clamp(math.min(height / 800, width / 950), 0.4, 1),
		Parent = title,
	})
	local finalScale = titleScale.Scale / 2.5
	TweenService:Create(titleScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = finalScale,
	}):Play()
	local subtitle, subtitleStroke = outlinedText({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.33, 60 * finalScale),
		Size = UDim2.fromOffset(900, 44),
		TextSize = 36,
		TextColor3 = WHITE,
		Text = `Rare ghosts x{GameConfig.HauntedHourLuck}  ·  Ghosts spawn {GameConfig.HauntedHourSpawnSpeed}x faster`,
		ZIndex = 5,
		Parent = gui,
	}, 3.5)
	new("UIScale", { Scale = finalScale, Parent = subtitle })

	task.delay(3.5, function()
		local away = TweenInfo.new(0.6)
		for _, item in { title, subtitle } do
			TweenService:Create(item, away, { TextTransparency = 1 }):Play()
		end
		for _, item in { titleStroke, subtitleStroke } do
			TweenService:Create(item, away, { Transparency = 1 }):Play()
		end
		task.wait(0.7)
		title:Destroy()
		subtitle:Destroy()
	end)
end

function HauntedHourHud.start()
	local gui = new("ScreenGui", {
		Name = "HauntedHour",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 4,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- The pill at the top of the screen, just under Roblox's top bar. On phones it goes up into
	-- the top bar's row (its middle is empty; Roblox's buttons are in the corners).
	local pill = new("Frame", {
		Name = "Timer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, if Mobile.isMobile then 12 else 62),
		Size = UDim2.fromOffset(260, 34),
		BackgroundColor3 = WHITE,
		Visible = false,
		Parent = gui,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pill })
	local pillGradient = new("UIGradient", { Rotation = 90, Parent = pill })
	local pillStroke = new("UIStroke", {
		Thickness = 2.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = pill,
	})
	local pillScale = new("UIScale", { Parent = pill })
	local pillText = outlinedText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -20, 1, -10),
		TextScaled = true,
		TextColor3 = WHITE,
		Parent = pill,
	}, 1.5)
	local boostText = outlinedText({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.fromOffset(320, 20),
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 200, 200),
		Text = `Rare ghosts x{GameConfig.HauntedHourLuck} · spawning {GameConfig.HauntedHourSpawnSpeed}x faster`,
		Visible = false,
		Parent = pill,
	}, 1.5)
	local pulse = TweenService:Create(
		pillScale,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.08 }
	)

	-- The red world, drawn only on this device.
	local tint = new("ColorCorrectionEffect", { Name = "HauntedHourTint", Enabled = true, Parent = Lighting })
	local RED_WORLD = { TintColor = Color3.fromRGB(255, 165, 165), Saturation = 0.15, Contrast = 0.08 }
	local NORMAL_WORLD = { TintColor = WHITE, Saturation = 0, Contrast = 0 }

	local function paintPill(active: boolean)
		local accent = if active then BLOOD else PUMPKIN
		pillGradient.Color = ColorSequence.new(accent:Lerp(PANEL_DARK, 0.55), PANEL_DARK)
		pillStroke.Color = accent
		boostText.Visible = active
		if active then
			pulse:Play()
		else
			pulse:Cancel()
			pillScale.Scale = 1
		end
	end

	-- "waiting" (counting down), "active", or nil before the server has set a time.
	local phase: string? = nil
	local warnedFor: number? = nil
	local function update()
		local startAt, endAt = HauntedHour.times()
		if not startAt or not endAt then
			pill.Visible = false
			return
		end
		pill.Visible = true
		local now = workspace:GetServerTimeNow()
		local active = now >= startAt and now < endAt
		local newPhase = if active then "active" else "waiting"

		if active then
			pillText.Text = "HAUNTED HOUR  " .. HauntedHour.formatTime(endAt - now)
		else
			pillText.Text = "Haunted Hour in " .. HauntedHour.formatTime(startAt - now)
			-- (startAt > now: not the one that just ended, before the server writes the next time)
			if startAt > now and startAt - now <= GameConfig.HauntedHourWarnSeconds and warnedFor ~= startAt then
				warnedFor = startAt
				Hud.showToast(`Haunted Hour starts in {GameConfig.HauntedHourWarnSeconds} seconds!`, "info")
				SystemChat.post(
					"HAUNTED HOUR",
					PUMPKIN,
					`The Haunted Hour starts in {GameConfig.HauntedHourWarnSeconds} seconds! Get to the walkway!`
				)
			end
		end

		if newPhase ~= phase then
			local wasActive = phase == "active"
			phase = newPhase
			paintPill(active)
			TweenService:Create(tint, TweenInfo.new(2), if active then RED_WORLD else NORMAL_WORLD):Play()
			if active and now - startAt < 5 then
				announce(gui) -- only for a fresh start, not when joining mid-event
				SystemChat.post(
					"HAUNTED HOUR",
					BLOOD,
					`The Haunted Hour has begun! {GameConfig.HauntedHourLuckMinRarity}+ ghosts are `
						.. `{GameConfig.HauntedHourLuck}x as likely and spawn {GameConfig.HauntedHourSpawnSpeed}x `
						.. `faster for {HauntedHour.formatTime(endAt - startAt)}.`
				)
			elseif wasActive then
				Hud.showToast("Haunted Hour is over!", "info")
				SystemChat.post(
					"HAUNTED HOUR",
					BLOOD,
					-- From the config: the server may not have written the next start time yet.
					`The Haunted Hour is over. The next one is in {HauntedHour.formatTime(
						GameConfig.HauntedHourEverySeconds
					)}.`
				)
			end
		end
	end

	task.spawn(function()
		while true do
			update()
			task.wait(0.25)
		end
	end)
end

return HauntedHourHud
