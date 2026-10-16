-- What a rebirth looks like (the server sends Rebirthed to everyone):
--   Everyone:      a purple pillar of light shoots up from the player, with sparkles.
--   The player:    a purple flash, "REBIRTH 3!" slams onto the screen with the new income boost
--                  and gem reward, and the level-up sound plays.
--   Other players: a pop-up message saying who rebirthed.
-- All of it is drawn on each device; nothing here changes the game.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Hud = require(script.Parent.UI.Hud)

local RebirthEffects = {}

local player = Players.LocalPlayer
local PURPLE = Theme.RebirthPurple
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local PILLAR_HEIGHT = 60
local CELEBRATION_SECONDS = 3.5

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

-- A glowing column of light that grows up out of the player and fades, with sparkles.
local function pillar(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local base = root.Position - Vector3.new(0, 3, 0)
	local beam = new("Part", {
		Name = "RebirthPillar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, 6, 6),
		-- A cylinder runs along its X axis, so turn it upright.
		CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90)),
		Color = PURPLE,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = workspace,
	})
	local grow = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(beam, grow, {
		Size = Vector3.new(PILLAR_HEIGHT, 6, 6),
		CFrame = CFrame.new(base + Vector3.new(0, PILLAR_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	}):Play()
	task.delay(0.6, function()
		TweenService:Create(beam, TweenInfo.new(1.4), { Transparency = 1, Size = Vector3.new(PILLAR_HEIGHT, 1, 1) })
			:Play()
	end)

	local sparkles = new("ParticleEmitter", {
		Texture = SPARKLE_TEXTURE,
		Color = Theme.RebirthGradient,
		LightEmission = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 1.2),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(1, 1.8),
		Rate = 0,
		Speed = NumberRange.new(8, 18),
		SpreadAngle = Vector2.new(30, 30),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		Parent = beam,
	})
	-- The beam is lying on its side, so "up" for the sparkles is the beam's +X face.
	sparkles.EmissionDirection = Enum.NormalId.Right
	sparkles:Emit(60)
	Debris:AddItem(beam, 2.5)
end

-- The big on-screen moment for the player who rebirthed.
local function celebrate(reached: number)
	local gui = new("ScreenGui", {
		Name = "RebirthCelebration",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local flash = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = PURPLE,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Parent = gui,
	})
	TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()

	local content = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(900, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local camera = workspace.CurrentCamera
	local screenHeight = if camera then camera.ViewportSize.Y else 800
	local screenWidth = if camera then camera.ViewportSize.X else 1200
	new("UIScale", { Scale = math.clamp(math.min(screenHeight / 800, screenWidth / 950), 0.4, 1), Parent = content })

	local title = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 0, 0, 100),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextSize = 96,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "REBIRTH " .. reached .. "!",
		Parent = content,
	})
	local titleStroke = new("UIStroke", { Color = Color3.fromRGB(20, 8, 30), Thickness = 6, Parent = title })
	local shine = new("UIGradient", { Color = Theme.RebirthGradient, Rotation = 20, Parent = title })
	local titleScale = new("UIScale", { Scale = 3, Parent = title })
	TweenService:Create(titleScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	-- Light sweeps across the title.
	shine.Offset = Vector2.new(-1, 0)
	TweenService:Create(
		shine,
		TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1),
		{ Offset = Vector2.new(1, 0) }
	):Play()

	local multiplier = Rebirth.formatMultiplier(Rebirth.multiplier(reached))
	local moneyHex = Theme.MoneyGreen:ToHex()
	local gemHex = Theme.GemBlue:ToHex()
	local subtitle = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 108),
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextSize = 42,
		RichText = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 1,
		Text = `Income <font color="#{moneyHex}">{multiplier}</font> forever!  <font color="#{gemHex}">+{Format.cash(
			Rebirth.gems(reached)
		)} gems</font>`,
		Parent = content,
	})
	local subtitleStroke =
		new("UIStroke", { Color = Color3.fromRGB(20, 8, 30), Thickness = 4, Transparency = 1, Parent = subtitle })
	task.delay(0.35, function()
		TweenService:Create(subtitle, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		TweenService:Create(subtitleStroke, TweenInfo.new(0.3), { Transparency = 0 }):Play()
	end)

	local sound = new("Sound", {
		SoundId = "rbxassetid://" .. GameConfig.RebirthSound.soundId,
		Volume = GameConfig.RebirthSound.volume,
		Parent = SoundService,
	})
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()

	task.delay(CELEBRATION_SECONDS, function()
		local away = TweenInfo.new(0.5)
		TweenService:Create(title, away, { TextTransparency = 1 }):Play()
		TweenService:Create(titleStroke, away, { Transparency = 1 }):Play()
		TweenService:Create(subtitle, away, { TextTransparency = 1 }):Play()
		TweenService:Create(subtitleStroke, away, { Transparency = 1 }):Play()
		TweenService:Create(content, away, { Position = UDim2.fromScale(0.5, 0.34) }):Play()
		Debris:AddItem(gui, 0.6)
	end)
end

function RebirthEffects.start()
	Remotes.Rebirthed.OnClientEvent:Connect(function(who: Player, reached: number)
		if who.Character then
			pillar(who.Character)
		end
		if who == player then
			celebrate(reached)
		else
			Hud.showToast(who.DisplayName .. " reached Rebirth " .. reached .. "!", "info")
		end
	end)
end

return RebirthEffects
