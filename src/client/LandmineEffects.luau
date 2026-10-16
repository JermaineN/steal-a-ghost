-- Landmine visuals, all made on this device only.
-- - Your own mines: the server tells only the owner where they are (Landmine remote), so only the
--   owner's device draws them: an olive disc with a blinking red light, plus a faint red circle
--   showing the trigger radius.
-- - Explosions (LandmineExploded remote, everyone): a stylised blast. A bright flash and fireball
--   that swell and fade, a shockwave ring along the ground, sparks, puffs of smoke and a boom.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local LandmineEffects = {}

local MINE_OLIVE = Color3.fromRGB(88, 94, 74)
local LIGHT_RED = Color3.fromRGB(255, 50, 35)
local FLASH_YELLOW = Color3.fromRGB(255, 225, 140)
local FIRE_ORANGE = Color3.fromRGB(255, 120, 30)
local SMOKE_GREY = Color3.fromRGB(105, 100, 108) -- light enough to show against the night sky
local EMBER_RED = Color3.fromRGB(120, 30, 15)

local folder: Folder
local mines: { [number]: Model } = {}

-- A see-through, non-colliding, anchored part for effects.
local function effectPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = folder
	return part
end

-- A flat disc lying on the ground (cylinders are round along their X axis, so tip them up).
local FLAT = CFrame.Angles(0, 0, math.rad(90))

local function drawMine(id: number, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "Landmine"
	local function part(props)
		local p = effectPart(props)
		p.Parent = model
		return p
	end
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.35, 1.9, 1.9),
		CFrame = CFrame.new(position + Vector3.new(0, 0.17, 0)) * FLAT,
		Color = MINE_OLIVE,
		Material = Enum.Material.Metal,
	})
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 0.9, 0.9),
		CFrame = CFrame.new(position + Vector3.new(0, 0.4, 0)) * FLAT,
		Color = Color3.fromRGB(120, 126, 104),
		Material = Enum.Material.Metal,
	})
	local light = part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.3, 0.3, 0.3),
		CFrame = CFrame.new(position + Vector3.new(0, 0.55, 0)),
		Color = LIGHT_RED,
		Material = Enum.Material.Neon,
	})
	-- The trigger radius: a faint red fill on the ground and a thin glowing outline floating just
	-- above it (so a raised path or step doesn't hide it).
	local radius = GameConfig.LandmineTriggerRadius
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, radius * 2, radius * 2),
		CFrame = CFrame.new(position + Vector3.new(0, 0.05, 0)) * FLAT,
		Color = LIGHT_RED,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.85,
	})
	local SEGMENTS = 40
	local segmentLength = 2 * math.pi * radius / SEGMENTS + 0.05
	for i = 1, SEGMENTS do
		local angle = (i / SEGMENTS) * 2 * math.pi
		local point = position + Vector3.new(math.cos(angle) * radius, 0.6, math.sin(angle) * radius)
		part({
			Size = Vector3.new(0.12, 0.12, segmentLength),
			-- Each segment lies along the circle (pointing sideways from the centre).
			CFrame = CFrame.lookAt(point, point + Vector3.new(-math.sin(angle), 0, math.cos(angle))),
			Color = LIGHT_RED,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
		})
	end
	model.Parent = folder
	mines[id] = model

	-- Blink the light until the mine is removed.
	task.spawn(function()
		while model.Parent do
			light.Transparency = if light.Transparency == 0 then 0.85 else 0
			task.wait(0.5)
		end
	end)
end

local function removeMine(id: number)
	if mines[id] then
		mines[id]:Destroy()
		mines[id] = nil
	end
end

-- Grows and fades a part, then removes it.
local function swellAndFade(part: BasePart, size: Vector3, growTime: number, fadeTime: number)
	TweenService:Create(part, TweenInfo.new(growTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = size })
		:Play()
	TweenService
		:Create(part, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
		:Play()
	Debris:AddItem(part, math.max(growTime, fadeTime) + 0.1)
end

local function explode(position: Vector3, radius: number)
	local center = position + Vector3.new(0, 1, 0)

	-- A short white-hot flash.
	local flash = effectPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2,
		CFrame = CFrame.new(center),
		Color = FLASH_YELLOW,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	})
	swellAndFade(flash, Vector3.one * radius * 0.9, 0.12, 0.22)

	-- The fireball: a lumpy cluster of orange and red puffs that swell, rise and burn out, so it
	-- doesn't look like one perfect ball.
	local fireball: BasePart? = nil
	for i = 1, 6 do
		local offset = Vector3.new(math.random(-10, 10), math.random(0, 8), math.random(-10, 10)) / 10 * radius * 0.25
		local puff = effectPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2,
			CFrame = CFrame.new(center + offset),
			Color = FIRE_ORANGE:Lerp(Color3.fromRGB(230, 50, 20), math.random()),
			Material = Enum.Material.Neon,
			Transparency = 0.1,
		})
		local size = Vector3.one * radius * math.random(55, 80) / 100
		local lifetime = math.random(35, 50) / 100
		TweenService
			:Create(
				puff,
				TweenInfo.new(lifetime * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = size }
			)
			:Play()
		-- Cools from orange to a dull ember red as it burns out.
		TweenService:Create(puff, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1,
			Color = EMBER_RED,
			CFrame = CFrame.new(center + offset + Vector3.new(0, radius * 0.3, 0)),
		}):Play()
		Debris:AddItem(puff, lifetime + 0.1)
		if i == 1 then
			fireball = puff
		end
	end

	-- Shockwave ring racing outward along the ground.
	local ring = effectPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 2, 2),
		CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * FLAT,
		Color = Color3.fromRGB(255, 235, 200),
		Material = Enum.Material.Neon,
		Transparency = 0.3,
	})
	swellAndFade(ring, Vector3.new(0.2, radius * 2.4, radius * 2.4), 0.4, 0.45)

	-- A quick burst of light on everything nearby.
	local light = Instance.new("PointLight")
	light.Color = FIRE_ORANGE
	light.Range = radius * 3
	light.Brightness = 6
	light.Parent = fireball or flash
	TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()

	-- Sparks flying out in every direction.
	local sparkHolder = effectPart({ Size = Vector3.one * 0.2, CFrame = CFrame.new(center), Transparency = 1 })
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(FLASH_YELLOW, FIRE_ORANGE)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.5, 0)
	sparks.Speed = NumberRange.new(30, 55)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Lifetime = NumberRange.new(0.4, 0.8)
	sparks.Drag = 3
	sparks.Acceleration = Vector3.new(0, -40, 0)
	sparks.Enabled = false
	sparks.Parent = sparkHolder
	sparks:Emit(45)
	Debris:AddItem(sparkHolder, 1.5)

	-- Smoke puffs that billow up and drift away.
	for _ = 1, 7 do
		local offset = Vector3.new(math.random(-10, 10) / 10, 0, math.random(-10, 10) / 10) * radius * 0.4
		local puff = effectPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * math.random(25, 40) / 10,
			CFrame = CFrame.new(center + offset),
			Color = SMOKE_GREY,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.2,
		})
		local rise = Vector3.new(offset.X * 0.6, math.random(55, 90) / 10, offset.Z * 0.6)
		local lifetime = math.random(12, 18) / 10
		TweenService:Create(puff, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(center + offset + rise),
			Size = puff.Size * 2.2,
			Transparency = 1,
		}):Play()
		Debris:AddItem(puff, lifetime + 0.1)
	end

	-- Boom.
	local soundHolder = effectPart({ Size = Vector3.one * 0.2, CFrame = CFrame.new(center), Transparency = 1 })
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. GameConfig.LandmineSound.soundId
	sound.Volume = GameConfig.LandmineSound.volume
	sound.RollOffMaxDistance = 300
	sound.Parent = soundHolder
	sound:Play()
	Debris:AddItem(soundHolder, 6)
end

function LandmineEffects.start()
	folder = Instance.new("Folder")
	folder.Name = "LandmineEffects"
	folder.Parent = workspace

	Remotes.Landmine.OnClientEvent:Connect(function(action: string, id: number, position: Vector3?)
		if action == "placed" and position then
			drawMine(id, position)
		elseif action == "removed" then
			removeMine(id)
		end
	end)
	Remotes.LandmineExploded.OnClientEvent:Connect(explode)
end

return LandmineEffects
