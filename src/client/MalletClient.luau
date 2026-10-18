-- Everything you see of a Mega Mallet swing (the server's MalletService decides who gets hit).
-- When the server sends MalletSwing (character, slamAt, origin), every device plays, timed to the
-- same slam moment (slamAt, in server time):
--   * The animation, made in code like BatSwing: lean far back with the mallet raised behind the
--     head, slowly loading up during the wind-up, then a fast slam forward with the head driven
--     into the ground in front, a short hold, and back to normal.
--   * The warning: a red cone on the ground (a picture on a flat part) that grows from the swinger
--     to the full hit range over MegaMalletTelegraphSeconds, pulsing until the slam.
--   * The slam: a flash, a dust cloud and flying rocks where the head lands, glowing shockwave
--     rings racing out through the cone, and rows of rock spikes bursting out of the ground as the
--     wave passes (at MegaMalletWaveSpeed, the same speed the server uses to launch players).
--     Cameras near the slam shake.
-- A cancel (character, false) stops the animation and removes the cone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local MalletClient = {}

local RANGE = GameConfig.MegaMalletRange
local HALF_ANGLE = GameConfig.MegaMalletHalfAngle
local WAVE_SPEED = GameConfig.MegaMalletWaveSpeed
local WINDUP = GameConfig.MegaMalletWindupSeconds
local TELEGRAPH = GameConfig.MegaMalletTelegraphSeconds

local ROCK = Color3.fromRGB(70, 62, 82)
local ROCK_LIGHT = Color3.fromRGB(105, 95, 120)
local GLOW = Color3.fromRGB(255, 80, 50)
local DUST = Color3.fromRGB(120, 105, 95)
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

----------------------------------------------------------------------------------------------
-- The animation
----------------------------------------------------------------------------------------------

-- Joint rotations in degrees, forward/back pitch, on top of the normal pose that holds the
-- mallet up in front. For the body (root, waist, neck), + leans back and - leans forward. The
-- arms (rs, ls) turn with the upper body, so their angles are relative to it: the same number
-- points them somewhere else once the body leans.
type Pose = {
	root: number, -- whole upper body, at the hips
	waist: number,
	neck: number,
	rs: number, -- right shoulder
	ls: number, -- left shoulder
	rw: number, -- right wrist (tips the mallet)
	rh: number, -- right hip
	lh: number,
	rk: number, -- right knee
	lk: number,
}
local NEUTRAL: Pose = { root = 0, waist = 0, neck = 0, rs = 0, ls = 0, rw = 0, rh = 0, lh = 0, rk = 0, lk = 0 }
-- Wind-up: leaning far back, the mallet raised behind the head in both hands, knees braced.
local WINDUP_POSE: Pose =
	{ root = 18, waist = 34, neck = -22, rs = 46, ls = 126, rw = 0, rh = -8, lh = 30, rk = 25, lk = 22 }
-- The end of the wind-up: pulled back a little further, loaded.
local LOADED_POSE: Pose =
	{ root = 24, waist = 42, neck = -26, rs = 33, ls = 116, rw = 10, rh = -12, lh = 36, rk = 32, lk = 26 }
-- Slammed: leaning forward over the mallet, its head driven into the ground in front.
local SLAM_POSE: Pose =
	{ root = -20, waist = -38, neck = 30, rs = 76, ls = 161, rw = -112, rh = -50, lh = 15, rk = 45, lk = 20 }

local JOINTS = {
	root = { "LowerTorso", "Root" },
	waist = { "UpperTorso", "Waist" },
	neck = { "Head", "Neck" },
	rs = { "RightUpperArm", "RightShoulder" },
	ls = { "LeftUpperArm", "LeftShoulder" },
	rw = { "RightHand", "RightWrist" },
	rh = { "RightUpperLeg", "RightHip" },
	lh = { "LeftUpperLeg", "LeftHip" },
	rk = { "RightLowerLeg", "RightKnee" },
	lk = { "LeftLowerLeg", "LeftKnee" },
}

-- Key moments, in seconds from the click (the slam is at WINDUP). `ease` shapes the move into
-- that pose: "smooth" eases in and out, "slam" starts slow and hits hard.
type Key = { time: number, pose: Pose, ease: string }
local KEYS: { Key } = {
	{ time = 0, pose = NEUTRAL, ease = "smooth" },
	{ time = 0.45, pose = WINDUP_POSE, ease = "smooth" },
	{ time = WINDUP - 0.1, pose = LOADED_POSE, ease = "smooth" },
	{ time = WINDUP, pose = SLAM_POSE, ease = "slam" },
	{ time = WINDUP + 0.5, pose = SLAM_POSE, ease = "smooth" },
	{ time = WINDUP + 0.95, pose = NEUTRAL, ease = "smooth" },
}

local function easeAlpha(alpha: number, kind: string): number
	if kind == "slam" then
		return alpha * alpha * alpha
	end
	return alpha * alpha * (3 - 2 * alpha)
end

local function poseAt(elapsed: number): Pose
	for index = 2, #KEYS do
		local from, to = KEYS[index - 1], KEYS[index]
		if elapsed <= to.time then
			local alpha = easeAlpha(math.clamp((elapsed - from.time) / (to.time - from.time), 0, 1), to.ease)
			local mixed = {}
			for key, value in from.pose do
				mixed[key] = value + ((to.pose :: any)[key] - value) * alpha
			end
			return mixed :: any
		end
	end
	return NEUTRAL
end

local animations: { [Model]: RBXScriptConnection } = {}

local function stopAnimation(character: Model)
	if animations[character] then
		animations[character]:Disconnect()
		animations[character] = nil
	end
end

-- Plays the swing on `character`, with `startedAt` (server time) as the click.
local function playAnimation(character: Model, startedAt: number)
	stopAnimation(character)
	local joints = {}
	for key, path in JOINTS do
		local part = character:FindFirstChild(path[1])
		joints[key] = part and part:FindFirstChild(path[2])
	end
	if not joints.waist then
		return -- not an R15 character
	end
	local rad = math.rad
	animations[character] = RunService.Stepped:Connect(function()
		local elapsed = workspace:GetServerTimeNow() - startedAt
		if elapsed >= KEYS[#KEYS].time or not character.Parent then
			stopAnimation(character)
			return
		end
		local pose = poseAt(elapsed)
		-- A little tremble while loading up.
		local shake = if elapsed > 0.45 and elapsed < WINDUP then math.sin(elapsed * 55) * 1.2 else 0
		for key, joint in joints do
			local angle = (pose :: any)[key] + (if key == "waist" then shake else 0)
			if angle ~= 0 then
				-- Rotating before the animated pose turns the joint in its parent part's frame.
				(joint :: any).Transform = CFrame.Angles(rad(angle), 0, 0) * (joint :: any).Transform
			end
		end
	end)
end

----------------------------------------------------------------------------------------------
-- Effects
----------------------------------------------------------------------------------------------

local effectsFolder: Folder

local function effectPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = effectsFolder
	return part
end

-- A flat, invisible part lying on the ground at `origin` with `image` on its top face. The
-- pictures are drawn with the swinger at the centre, pointing the way they face.
local function groundPicture(origin: CFrame, image: string, height: number): (Part, Decal)
	local part = effectPart({
		Name = "MalletGround",
		Size = Vector3.new(0.2, 0.05, 0.2),
		Transparency = 1,
		-- Turned round: a top-face decal's "up" points along the part's back (+Z).
		CFrame = origin * CFrame.new(0, height, 0) * CFrame.Angles(0, math.pi, 0),
	})
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Top
	decal.Texture = image
	decal.Parent = part
	return part, decal
end

local function playSound(at: Vector3, sound, maxDistance: number)
	local holder = effectPart({ Size = Vector3.one, Transparency = 1, Position = at })
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. sound.soundId
	s.Volume = sound.volume
	s.RollOffMaxDistance = maxDistance
	s.Parent = holder
	s:Play()
	task.delay(6, function()
		holder:Destroy()
	end)
end

-- A one-off burst of particles at `at`.
local function burst(at: Vector3, props: { [string]: any }, count: number, lifetime: number)
	local holder = effectPart({ Size = Vector3.one, Transparency = 1, Position = at })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	for key, value in props do
		(emitter :: any)[key] = value
	end
	emitter.Parent = holder
	emitter:Emit(count)
	task.delay(lifetime + 0.5, function()
		holder:Destroy()
	end)
end

local function dustProps(size: number)
	return {
		Texture = SMOKE_TEXTURE,
		Color = ColorSequence.new(DUST),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 2.5) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(6, 14),
		SpreadAngle = Vector2.new(80, 80),
		Acceleration = Vector3.new(0, 4, 0),
		Drag = 3,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
	}
end

-- The red warning cone: grows over TELEGRAPH seconds, then pulses until the slam.
local function telegraph(origin: CFrame, startedAt: number): () -> ()
	local part, decal = groundPicture(origin, GameConfig.MegaMalletConeImage, 0.12)
	local connection = RunService.Heartbeat:Connect(function()
		local elapsed = workspace:GetServerTimeNow() - startedAt
		local grow = math.clamp(elapsed / TELEGRAPH, 0, 1)
		grow = 1 - (1 - grow) ^ 3 -- fast at first, settling at full size
		local diameter = math.max(RANGE * 2 * grow, 0.2)
		part.Size = Vector3.new(diameter, 0.05, diameter)
		decal.Transparency = if elapsed < TELEGRAPH then 0.15 else 0.15 + 0.25 * (0.5 + 0.5 * math.sin(elapsed * 18))
	end)
	return function()
		connection:Disconnect()
		TweenService:Create(decal, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		task.delay(0.3, function()
			part:Destroy()
		end)
	end
end

-- One rock spike bursting out of the ground at `at`, then sinking back.
local function spike(at: Vector3, outward: Vector3, scale: number)
	local height = (3 + math.random() * 3) * scale
	local width = (1.4 + math.random() * 1.2) * scale
	local turn = CFrame.Angles(0, math.random() * math.pi * 2, 0)
	-- Tipped outward, away from the slam.
	local tilt = CFrame.fromAxisAngle(Vector3.yAxis:Cross(outward).Unit, math.rad(12 + math.random() * 14))
	local up = CFrame.new(at) * tilt * turn
	local rock = Instance.new("CornerWedgePart")
	rock.Anchored = true
	rock.CanCollide = false
	rock.CanQuery = false
	rock.CanTouch = false
	rock.Size = Vector3.new(width, height, width)
	rock.Color = if math.random() < 0.5 then ROCK else ROCK_LIGHT
	rock.Material = Enum.Material.Slate
	rock.CFrame = up * CFrame.new(0, -height / 2 - 0.5, 0)
	rock.Parent = effectsFolder
	-- A red-hot sliver at its base.
	local ember = effectPart({
		Size = Vector3.new(width * 0.9, 0.15, width * 0.9),
		Color = GLOW,
		Material = Enum.Material.Neon,
		CFrame = CFrame.new(at + Vector3.new(0, 0.06, 0)) * turn,
		Transparency = 0.2,
	})
	TweenService:Create(rock, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = up * CFrame.new(0, height * 0.32, 0),
	}):Play()
	task.delay(0.75 + math.random() * 0.25, function()
		TweenService:Create(rock, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = up * CFrame.new(0, -height / 2 - 0.5, 0),
		}):Play()
		TweenService:Create(ember, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		task.delay(0.45, function()
			rock:Destroy()
			ember:Destroy()
		end)
	end)
end

-- Rocks thrown up from the impact (loose, falling, then gone).
local function debris(at: Vector3, facing: Vector3)
	for _ = 1, 10 do
		local size = 0.5 + math.random() * 0.9
		local chunk = Instance.new("Part")
		chunk.Size = Vector3.new(size, size * 0.8, size)
		chunk.Color = if math.random() < 0.5 then ROCK else ROCK_LIGHT
		chunk.Material = Enum.Material.Slate
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.CanTouch = false
		chunk.CFrame = CFrame.new(at + Vector3.new(0, 0.6, 0))
			* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		local sideways = (facing * (0.6 + math.random()) + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)).Unit
		chunk.AssemblyLinearVelocity = sideways * (12 + math.random() * 14) + Vector3.new(0, 30 + math.random() * 22, 0)
		chunk.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 20
		chunk.Parent = effectsFolder
		task.delay(1.6, function()
			chunk:Destroy()
		end)
	end
end

-- Shakes this device's camera for `seconds`, starting at `strength` degrees and fading out.
local shakeUntil, shakeStrength, shakeLength = 0, 0, 1
local function shakeCamera(strength: number, seconds: number)
	if strength > shakeStrength * math.max(shakeUntil - os.clock(), 0) / shakeLength then
		shakeUntil, shakeStrength, shakeLength = os.clock() + seconds, strength, seconds
	end
end

-- The slam itself: flash, dust and rocks at the head, then the shockwave and spikes.
local function slam(origin: CFrame)
	local facing = origin.LookVector
	local impact = origin.Position + facing * 3

	playSound(impact, GameConfig.MegaMalletSlamSound, RANGE * 3)
	-- Flash: a glowing ball that swells and fades.
	local flash = effectPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2,
		Color = Color3.fromRGB(255, 200, 150),
		Material = Enum.Material.Neon,
		Position = impact,
		Transparency = 0.1,
	})
	TweenService:Create(flash, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = Vector3.one * 14, Transparency = 1 })
		:Play()
	task.delay(0.35, function()
		flash:Destroy()
	end)
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = 30
	light.Brightness = 6
	light.Parent = flash
	-- A crater ring of dust and sparks, and loose rocks.
	burst(impact, dustProps(3), 40, 1.4)
	burst(impact, {
		Texture = SPARK_TEXTURE,
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 120), GLOW),
		LightEmission = 1,
		Size = NumberSequence.new(0.6, 0),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(25, 45),
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, -40, 0),
	}, 35, 0.8)
	debris(impact, facing)

	-- Shockwave rings: glowing bands sweeping out through the cone, the first one exactly with
	-- the wave that launches players.
	local travel = RANGE / WAVE_SPEED
	for index, delay in { 0, 0.1, 0.22 } do
		task.delay(delay, function()
			local part, decal = groundPicture(origin, GameConfig.MegaMalletWaveImage, 0.18 + index * 0.02)
			decal.Color3 = if index == 1 then Color3.new(1, 1, 1) else Color3.fromRGB(255, 150, 110)
			local duration = travel * (1 + index * 0.15)
			part.Size = Vector3.new(1, 0.05, 1)
			TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
				Size = Vector3.new(RANGE * 2, 0.05, RANGE * 2),
			}):Play()
			TweenService:Create(decal, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
			}):Play()
			task.delay(duration + 0.1, function()
				part:Destroy()
			end)
		end)
	end

	-- Rows of spikes erupting as the wave passes, with dust along each row.
	local rowStep = 7.5
	local distance = 5
	local halfRad = math.rad(HALF_ANGLE - 4)
	while distance <= RANGE do
		local rowDistance = distance
		task.delay(rowDistance / WAVE_SPEED, function()
			local arc = rowDistance * halfRad * 2
			local count = math.clamp(math.floor(arc / 10), 2, 22)
			local scale = 1 + rowDistance / RANGE * 0.6 -- bigger further out
			for index = 1, count do
				local t = if count == 1 then 0.5 else (index - 1) / (count - 1)
				local angle = -halfRad + t * halfRad * 2 + (math.random() - 0.5) * 0.08
				local direction = (CFrame.fromAxisAngle(Vector3.yAxis, angle) * facing).Unit
				local at = origin.Position + direction * (rowDistance + (math.random() - 0.5) * 2.5)
				spike(at, direction, scale)
				if index % 4 == 1 then
					burst(at + Vector3.new(0, 0.5, 0), dustProps(2), 6, 1.4)
				end
			end
		end)
		distance += rowStep
	end

	-- Shake nearby cameras, harder the closer they are.
	local camera = workspace.CurrentCamera
	if camera then
		local away = (camera.Focus.Position - origin.Position).Magnitude
		if away < RANGE * 1.5 then
			shakeCamera(2.5 * (1 - away / (RANGE * 1.5)) + 0.4, 0.7)
		end
	end
end

----------------------------------------------------------------------------------------------

type Swing = { startedAt: number, stopTelegraph: () -> (), cancelled: boolean }
local swings: { [Model]: Swing } = {}

local function onSwing(character: Model, slamAt: number | boolean, origin: CFrame?)
	if not character then
		return
	end
	local current = swings[character]
	if slamAt == false then
		-- Cancelled: knocked over, caged, died or put the mallet away.
		if current then
			current.cancelled = true
			current.stopTelegraph()
			swings[character] = nil
		end
		stopAnimation(character)
		return
	end
	if typeof(slamAt) ~= "number" or typeof(origin) ~= "CFrame" then
		return
	end
	local startedAt = slamAt - WINDUP
	local swing: Swing = { startedAt = startedAt, stopTelegraph = telegraph(origin, startedAt), cancelled = false }
	swings[character] = swing
	playAnimation(character, startedAt)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		playSound(root.Position, GameConfig.MegaMalletWindupSound, RANGE * 2)
	end
	task.delay(math.max(slamAt - workspace:GetServerTimeNow(), 0), function()
		if swing.cancelled then
			return
		end
		swing.stopTelegraph()
		if swings[character] == swing then
			swings[character] = nil
		end
		slam(origin)
	end)
end

function MalletClient.start()
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "MalletEffects"
	effectsFolder.Parent = workspace

	Remotes.MalletSwing.OnClientEvent:Connect(onSwing)

	-- The camera shake, applied after the camera has moved each frame.
	RunService:BindToRenderStep("MalletShake", Enum.RenderPriority.Camera.Value + 1, function()
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

return MalletClient
