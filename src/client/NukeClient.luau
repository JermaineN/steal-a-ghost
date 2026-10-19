-- Everything you see and hear of a nuke (the server's NukeService decides who gets launched).
-- When the server sends NukeLaunched (launcher's name, cutsceneAt, explodeAt, target), every
-- device plays the same thing, timed to those server times:
--   * Warning, until cutsceneAt: "X HAS LAUNCHED A NUKE!" at the top, a big countdown in the
--     middle with a beep each second, a pulsing red screen, an air-raid siren and the music dipped.
--   * Cutscene, until explodeAt: black bars top and bottom, and the camera sits low on the ground
--     near the middle of the map, looking up and following the nuke as it falls (faster and
--     faster) with a whistle. Your character is frozen by the server meanwhile.
--   * Blast: a white flash, the camera goes back to normal, and a fireball, a shockwave ring and
--     a mushroom cloud grow in the middle of the map, with the camera shaking.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local NukeClient = {}

local FONT = Enum.Font.FredokaOne
local RED = Color3.fromRGB(255, 45, 35)
local HAZARD_YELLOW = Color3.fromRGB(255, 205, 40)
local BODY = Color3.fromRGB(62, 66, 78)
local FIRE = Color3.fromRGB(255, 140, 40)
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local MUSIC_DUCK = 0.2 -- the music's volume while the nuke is coming

-- How far from the middle (sideways, along the walkway) the cutscene camera sits, and how high.
local CAMERA_OFFSET = Vector3.new(-70, 0, 24)
local CAMERA_HEIGHT = 2.5
local CAMERA_FOV = 60

local NUKE_LENGTH = 22
local NUKE_WIDTH = 7

local effectsFolder: Folder
local gui: ScreenGui
local banner: TextLabel
local countdown: TextLabel
local countdownScale: UIScale
local tint: Frame
local topBar: Frame
local bottomBar: Frame
local flash: Frame

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

----------------------------------------------------------------------------------------------
-- Sounds and screen
----------------------------------------------------------------------------------------------

-- A sound heard the same everywhere (not from a spot in the world).
local function playSound(config, startAt: number?): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. config.soundId
	sound.Volume = config.volume
	sound.TimePosition = startAt or config.startAt or 0
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	return sound
end

local function fadeOutSound(sound: Sound, seconds: number)
	local fade = TweenService:Create(sound, TweenInfo.new(seconds), { Volume = 0 })
	fade.Completed:Once(function()
		sound:Destroy()
	end)
	fade:Play()
end

local function setMusicVolume(volume: number)
	-- MusicPlayer puts the music in this group (the steal alarm dips it the same way).
	local music = SoundService:FindFirstChild("Music")
	if music then
		TweenService:Create(music, TweenInfo.new(0.5), { Volume = volume }):Play()
	end
end

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

local function buildGui()
	gui = new("ScreenGui", {
		Name = "NukeHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 20, -- above the windows and the HUD
		Enabled = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	tint = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = RED,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = gui,
	})
	banner = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.16),
		Size = UDim2.fromScale(0.9, 0.08),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = HAZARD_YELLOW,
		Parent = gui,
	})
	new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(40, 0, 0), Parent = banner })
	new("UITextSizeConstraint", { MaxTextSize = 54, Parent = banner })
	countdown = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.3, 0.22),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = RED,
		Parent = gui,
	})
	new("UIStroke", { Thickness = 5, Color = Color3.fromRGB(255, 255, 255), Parent = countdown })
	countdownScale = new("UIScale", { Parent = countdown })
	-- Cutscene bars, slid in from off-screen.
	topBar = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 0.12),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Parent = gui,
	})
	bottomBar = new("Frame", {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.12),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Parent = gui,
	})
	flash = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = gui,
	})
end

local function showBars(on: boolean)
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(topBar, info, { AnchorPoint = Vector2.new(0, if on then 0 else 1) }):Play()
	TweenService:Create(bottomBar, info, { AnchorPoint = Vector2.new(0, if on then 1 else 0) }):Play()
end

----------------------------------------------------------------------------------------------
-- Camera shake
----------------------------------------------------------------------------------------------

local shakeUntil, shakeStrength, shakeLength = 0, 0, 1
local function shakeCamera(strength: number, seconds: number)
	shakeUntil, shakeStrength, shakeLength = os.clock() + seconds, strength, seconds
end

----------------------------------------------------------------------------------------------
-- The nuke and the blast (local parts, only on this device)
----------------------------------------------------------------------------------------------

local function effectPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = effectsFolder
	return part
end

-- The bomb, nose down, as a Model whose pivot is the tip of the nose. A dark body with a hazard
-- band, a rounded nose, four tail fins and fire pouring out of the tail.
local function buildNuke(): Model
	local model = Instance.new("Model")
	model.Name = "Nuke"
	-- Built standing up around the origin, nose at y = 0.
	local function add(props): Part
		local part = effectPart(props)
		part.Parent = model
		return part
	end
	local bodyHeight = NUKE_LENGTH * 0.6
	local bodyY = NUKE_WIDTH / 2 + bodyHeight / 2
	-- Cylinders run along their X axis, so turn them upright.
	local upright = CFrame.Angles(0, 0, math.rad(90))
	add({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(bodyHeight, NUKE_WIDTH, NUKE_WIDTH),
		Color = BODY,
		CFrame = CFrame.new(0, bodyY, 0) * upright,
	})
	for _, y in { bodyY - bodyHeight * 0.18, bodyY + bodyHeight * 0.18 } do
		add({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, NUKE_WIDTH + 0.2, NUKE_WIDTH + 0.2),
			Color = HAZARD_YELLOW,
			Material = Enum.Material.Neon,
			CFrame = CFrame.new(0, y, 0) * upright,
		})
	end
	local nose = add({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * NUKE_WIDTH,
		Color = RED,
		CFrame = CFrame.new(0, NUKE_WIDTH / 2, 0),
	})
	local tailY = bodyY + bodyHeight / 2
	local tail = add({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(NUKE_LENGTH * 0.25, NUKE_WIDTH * 0.6, NUKE_WIDTH * 0.6),
		Color = Color3.fromRGB(40, 42, 50),
		CFrame = CFrame.new(0, tailY + NUKE_LENGTH * 0.12, 0) * upright,
	})
	for index = 0, 3 do
		add({
			Size = Vector3.new(0.5, NUKE_LENGTH * 0.28, NUKE_WIDTH * 0.7),
			Color = RED,
			CFrame = CFrame.Angles(0, index * math.pi / 2, 0)
				* CFrame.new(0, tailY + NUKE_LENGTH * 0.06, NUKE_WIDTH * 0.55),
		})
	end
	model.PrimaryPart = nose
	model.WorldPivot = CFrame.new(0, 0, 0)

	local exhaust = Instance.new("Attachment")
	exhaust.Position = Vector3.new(NUKE_LENGTH * 0.12, 0, 0) -- the tail turned upright: its X points up
	exhaust.Parent = tail
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = FIRE_TEXTURE
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), FIRE)
	fire.LightEmission = 1
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 1) })
	fire.Lifetime = NumberRange.new(0.3, 0.5)
	fire.Rate = 80
	fire.Speed = NumberRange.new(20, 30)
	fire.EmissionDirection = Enum.NormalId.Right -- up, out of the tail
	fire.Parent = exhaust
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = SMOKE_TEXTURE
	trail.Color = ColorSequence.new(Color3.fromRGB(90, 85, 95))
	trail.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 14) })
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = NumberRange.new(1.5, 2.5)
	trail.Rate = 40
	trail.Speed = NumberRange.new(2, 5)
	trail.LockedToPart = false
	trail.Parent = exhaust
	local light = Instance.new("PointLight")
	light.Color = FIRE
	light.Range = 30
	light.Brightness = 3
	light.Parent = tail

	model.Parent = effectsFolder
	return model
end

local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

-- A ball that grows to `size` and then fades away.
local function growingBall(at: Vector3, color: Color3, fromSize: number, toSize: number, grow: number, fade: number)
	local ball = effectPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * fromSize,
		Position = at,
		Color = color,
		Material = Enum.Material.Neon,
	})
	tween(ball, grow, { Size = Vector3.one * toSize })
	task.delay(grow * 0.6, function()
		tween(ball, fade, { Transparency = 1 }, Enum.EasingStyle.Sine)
	end)
	task.delay(grow * 0.6 + fade + 0.1, function()
		ball:Destroy()
	end)
	return ball
end

local function blast(target: Vector3)
	playSound(GameConfig.NukeBlastSound)
	playSound(GameConfig.NukeBoomSound)
	shakeCamera(3, 2)

	-- Fireball: a white-hot core inside an orange ball, both growing fast.
	growingBall(target, Color3.fromRGB(255, 250, 220), 6, 70, 0.3, 0.8)
	local fireball = growingBall(target, FIRE, 10, 130, 0.7, 2.5)
	local light = Instance.new("PointLight")
	light.Color = FIRE
	light.Range = 60
	light.Brightness = 8
	light.Parent = fireball

	-- Shockwave: a thin glowing ring racing out along the ground.
	local ring = effectPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.5, 20, 20),
		CFrame = CFrame.new(target + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 230, 180),
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	})
	tween(ring, 1.6, { Size = Vector3.new(1.5, 700, 700), Transparency = 1 })
	task.delay(1.7, function()
		ring:Destroy()
	end)

	-- Mushroom cloud: a stem rising out of the blast with a wide, flattened cap on top.
	local stem = effectPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(10, 26, 26),
		CFrame = CFrame.new(target + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(200, 110, 50),
	})
	tween(stem, 2.2, {
		Size = Vector3.new(150, 34, 34),
		CFrame = CFrame.new(target + Vector3.new(0, 75, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(110, 95, 90),
	})
	local cap = effectPart({
		Size = Vector3.one,
		Position = target + Vector3.new(0, 20, 0),
		Color = Color3.fromRGB(255, 150, 60),
	})
	local capMesh = Instance.new("SpecialMesh")
	capMesh.MeshType = Enum.MeshType.Sphere
	capMesh.Scale = Vector3.new(40, 25, 40)
	capMesh.Parent = cap
	tween(cap, 2.2, { Position = target + Vector3.new(0, 160, 0), Color = Color3.fromRGB(120, 100, 95) })
	tween(capMesh, 2.2, { Scale = Vector3.new(150, 70, 150) })
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = SMOKE_TEXTURE
	smoke.Color = ColorSequence.new(Color3.fromRGB(110, 95, 90))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 30), NumberSequenceKeypoint.new(1, 60) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(3, 5)
	smoke.Rate = 25
	smoke.Speed = NumberRange.new(5, 15)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Parent = cap
	task.delay(4, function()
		smoke.Enabled = false
		tween(stem, 3, { Transparency = 1 }, Enum.EasingStyle.Sine)
		tween(cap, 3, { Transparency = 1 }, Enum.EasingStyle.Sine)
	end)
	task.delay(9, function()
		stem:Destroy()
		cap:Destroy()
	end)
end

----------------------------------------------------------------------------------------------
-- The whole sequence
----------------------------------------------------------------------------------------------

local playing = false

local function onLaunched(launcherName: string, cutsceneAt: number, explodeAt: number, target: Vector3)
	if playing then
		return
	end
	playing = true
	gui.Enabled = true
	banner.Text = "☢ " .. string.upper(launcherName) .. " HAS LAUNCHED A NUKE! ☢"
	banner.Visible = true
	countdown.Visible = true
	setMusicVolume(MUSIC_DUCK)
	local siren = playSound(GameConfig.NukeSirenSound)
	siren.Looped = true

	-- The red screen pulses with the siren.
	local pulse = TweenService:Create(
		tint,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ BackgroundTransparency = 0.75 }
	)
	tint.BackgroundTransparency = 1
	pulse:Play()

	-- Countdown: one beep and a pop each second.
	local shown = -1
	while serverNow() < cutsceneAt do
		local left = math.ceil(cutsceneAt - serverNow())
		if left ~= shown then
			shown = left
			countdown.Text = tostring(left)
			countdownScale.Scale = 1.6
			tween(countdownScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			playSound(GameConfig.NukeBeepSound)
		end
		RunService.RenderStepped:Wait()
	end
	pulse:Cancel()
	tint.BackgroundTransparency = 1
	banner.Visible = false
	countdown.Visible = false

	-- Cutscene: the camera low on the ground near the middle, following the nuke down.
	local camera = workspace.CurrentCamera
	local oldType, oldFov = camera.CameraType, camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = CAMERA_FOV
	showBars(true)
	local fall = playSound(GameConfig.NukeFallSound)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { effectsFolder }
	local cameraSpot = target + CAMERA_OFFSET
	local ground = workspace:Raycast(cameraSpot + Vector3.new(0, 100, 0), Vector3.new(0, -200, 0), params)
	local cameraStart =
		Vector3.new(cameraSpot.X, (if ground then ground.Position.Y else target.Y) + CAMERA_HEIGHT, cameraSpot.Z)
	-- The camera creeps a little towards the middle as the nuke comes down.
	local creep = (Vector3.new(target.X, cameraStart.Y, target.Z) - cameraStart).Unit * 12

	local nuke = buildNuke()
	local fallSeconds = explodeAt - cutsceneAt
	while true do
		local alpha = math.clamp((serverNow() - cutsceneAt) / fallSeconds, 0, 1)
		-- Falls faster and faster, turning slowly.
		local height = GameConfig.NukeDropHeight * (1 - alpha * alpha)
		local nosePosition = target + Vector3.new(0, height, 0)
		nuke:PivotTo(CFrame.new(nosePosition) * CFrame.Angles(0, alpha * math.pi * 2, 0))
		local cameraAt = cameraStart + creep * alpha
		-- Look at the middle of the bomb, or just above the ground once it's nearly down.
		local lookAt = nosePosition + Vector3.new(0, math.max(NUKE_LENGTH / 2, 6), 0)
		camera.CFrame = CFrame.lookAt(cameraAt, lookAt)
		if alpha >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end

	-- Blast: flash white, back to the normal camera underneath it, then the explosion.
	nuke:Destroy()
	fadeOutSound(siren, 1.5)
	fadeOutSound(fall, 0.2)
	flash.BackgroundTransparency = 0
	tween(flash, 1.5, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
	showBars(false)
	camera.CameraType = if oldType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else oldType
	camera.FieldOfView = oldFov
	local humanoid = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	blast(target)
	task.delay(3, function()
		setMusicVolume(1)
	end)
	task.delay(1.6, function()
		if not playing then
			gui.Enabled = false
		end
	end)
	playing = false
end

function NukeClient.start()
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "NukeEffects"
	effectsFolder.Parent = workspace
	buildGui()

	Remotes.NukeLaunched.OnClientEvent:Connect(function(...)
		task.spawn(onLaunched, ...)
	end)

	-- The camera shake, applied after the camera has moved each frame.
	RunService:BindToRenderStep("NukeShake", Enum.RenderPriority.Camera.Value + 2, function()
		local left = shakeUntil - os.clock()
		local camera = workspace.CurrentCamera
		if left <= 0 or not camera then
			return
		end
		local strength = math.rad(shakeStrength * left / shakeLength)
		camera.CFrame = camera.CFrame
			* CFrame.Angles(
				(math.random() - 0.5) * strength,
				(math.random() - 0.5) * strength,
				(math.random() - 0.5) * strength * 0.5
			)
	end)
end

return NukeClient
