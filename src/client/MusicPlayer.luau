-- Background music: plays GameConfig.MusicTracks in a shuffled loop, and adds a small round
-- button (bottom-right) that mutes/unmutes it. Music only plays on this player's device.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local player = Players.LocalPlayer

local MusicPlayer = {}

local PANEL_DARK = Color3.fromRGB(28, 16, 44)
local PUMPKIN = Color3.fromRGB(255, 140, 30)
local MUTED_GREY = Color3.fromRGB(140, 130, 150)

local function shuffled(list: { number }): { number }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = math.random(i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function buildButton(onClick: () -> ()): (TextButton, UIStroke)
	local gui = Instance.new("ScreenGui")
	gui.Name = "MusicToggle"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local button = Instance.new("TextButton")
	button.Name = "Toggle"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -14, 1, -14)
	button.Size = UDim2.fromOffset(48, 48)
	button.BackgroundColor3 = PANEL_DARK
	button.BackgroundTransparency = 0.1
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = PUMPKIN
	button.Text = "♪"
	button.AutoButtonColor = true
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = PUMPKIN
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = button

	button.Activated:Connect(onClick)
	return button, stroke
end

function MusicPlayer.start()
	local tracks = GameConfig.MusicTracks
	if not tracks or #tracks == 0 then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "BackgroundMusic"
	sound.Volume = GameConfig.MusicVolume
	sound.Parent = SoundService

	local muted = false
	local button, stroke
	button, stroke = buildButton(function()
		muted = not muted
		TweenService:Create(sound, TweenInfo.new(0.4), { Volume = if muted then 0 else GameConfig.MusicVolume }):Play()
		button.TextColor3 = if muted then MUTED_GREY else PUMPKIN
		stroke.Color = if muted then MUTED_GREY else PUMPKIN
		button.Text = if muted then "✕" else "♪"
	end)

	-- Play the shuffled playlist forever, reshuffling each time it runs out.
	task.spawn(function()
		while true do
			for _, id in shuffled(tracks) do
				sound.SoundId = "rbxassetid://" .. id
				sound.TimePosition = 0
				sound:Play()
				-- Wait for the track to end (or give up on one that never loads).
				local started = os.clock()
				while sound.Playing or (not sound.IsLoaded and os.clock() - started < 10) do
					task.wait(0.5)
				end
			end
		end
	end)
end

return MusicPlayer
