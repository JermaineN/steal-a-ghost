-- The "you're being robbed" alarm. While someone is carrying one of your ghosts away (the server
-- sends StealAlarm true, then false when the last one is caught, dropped or delivered): a looping
-- siren, the background music dips, and a red border pulses around the screen. Only you see and
-- hear it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local StealAlarm = {}

local ALARM_RED = Color3.fromRGB(255, 40, 40)
local FADE = TweenInfo.new(0.4)
local BORDER = 18 -- how much of the border shows along each screen edge, in pixels
local INNER_RADIUS = 30 -- roundness of the border's inside corners, in pixels

local function buildBorder(): (ScreenGui, UIStroke)
	local gui = Instance.new("ScreenGui")
	gui.Name = "StealAlarm"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- cover the whole screen, top bar included
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- The border is the outline of an invisible frame inset BORDER pixels from the screen edges.
	-- The frame's rounded corners give the border rounded inside corners. The outline is drawn
	-- much thicker than BORDER, so its outer edge (rounded too) lies off-screen and the screen
	-- edge cuts it square: it has to reach the screen's corner points, which are
	-- sqrt(2) * (BORDER + INNER_RADIUS) from the centre of each rounded corner.
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.new(1, -BORDER * 2, 1, -BORDER * 2)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, INNER_RADIUS)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = ALARM_RED
	stroke.Thickness = math.ceil(math.sqrt(2) * (BORDER + INNER_RADIUS) - INNER_RADIUS) + 2
	stroke.Transparency = 1
	stroke.Parent = frame
	return gui, stroke
end

function StealAlarm.start()
	local siren = Instance.new("Sound")
	siren.Name = "StealAlarm"
	siren.SoundId = "rbxassetid://" .. GameConfig.StealAlarmSound.soundId
	siren.Looped = true
	siren.Volume = 0
	siren.Parent = SoundService

	local gui, stroke = buildBorder()
	local pulse = TweenService:Create(
		stroke,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), -- forever, back and forth
		{ Transparency = 0.2 }
	)

	Remotes.StealAlarm.OnClientEvent:Connect(function(on: boolean)
		-- MusicPlayer puts the music in this group; dipping the group leaves its mute button alone.
		local music = SoundService:FindFirstChild("Music")
		if on then
			siren.TimePosition = 0
			siren:Play()
			TweenService:Create(siren, FADE, { Volume = GameConfig.StealAlarmSound.volume }):Play()
			if music then
				TweenService:Create(music, FADE, { Volume = GameConfig.StealAlarmMusicDuck }):Play()
			end
			gui.Enabled = true
			stroke.Transparency = 0.9
			pulse:Play()
		else
			local fadeOut = TweenService:Create(siren, FADE, { Volume = 0 })
			fadeOut.Completed:Once(function()
				if siren.Volume == 0 then
					siren:Stop()
				end
			end)
			fadeOut:Play()
			if music then
				TweenService:Create(music, FADE, { Volume = 1 }):Play()
			end
			pulse:Cancel()
			gui.Enabled = false
		end
	end)
end

return StealAlarm
