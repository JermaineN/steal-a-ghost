-- When you collect one of your pads: a "cha-ching" from the pad and a small burst of bills and
-- coins that pop up out of it, spin, fall and fade. The pieces exist only on this device
-- (purely visual), so they cost the server nothing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)

local CollectEffect = {}

local BILL_GREEN = Color3.fromRGB(90, 190, 90)
local BILL_INK = Color3.fromRGB(30, 100, 40)
local COIN_GOLD = Color3.fromRGB(255, 200, 50)
local LIFETIME = 1.1 -- seconds each piece lives
local FADE_TIME = 0.35 -- fades out over the last part of its life
local GRAVITY = 55 -- studs per second squared

local effectsFolder: Folder

-- A flat green bill with a "$" printed on both sides.
local function makeBill(): Part
	local bill = Instance.new("Part")
	bill.Size = Vector3.new(0.9, 0.05, 0.45)
	bill.Color = BILL_GREEN
	bill.Material = Enum.Material.SmoothPlastic
	for _, face in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
		local stamp = Instance.new("SurfaceGui")
		stamp.Face = face
		stamp.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		stamp.PixelsPerStud = 60
		local symbol = Instance.new("TextLabel")
		symbol.BackgroundTransparency = 1
		symbol.Size = UDim2.fromScale(1, 1)
		symbol.Font = Enum.Font.FredokaOne
		symbol.TextScaled = true
		symbol.TextColor3 = BILL_INK
		symbol.Text = "$"
		symbol.Parent = stamp
		stamp.Parent = bill
	end
	return bill
end

local function makeCoin(): Part
	local coin = Instance.new("Part")
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.1, 0.5, 0.5)
	coin.Color = COIN_GOLD
	coin.Material = Enum.Material.Metal
	return coin
end

-- A quick white flash of the pad's painted faces (only on this device).
local function flashPad(pad: BasePart)
	for _, glow in pad:GetDescendants() do
		if glow:IsA("Frame") and glow.Name == "Glow" then
			glow.BackgroundColor3 = Color3.new(1, 1, 1)
			TweenService:Create(glow, TweenInfo.new(0.4), { BackgroundColor3 = Theme.MoneyGreen }):Play()
		end
	end
end

local function playChaChing(pad: BasePart)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. GameConfig.CollectSoundId
	sound.Volume = GameConfig.CollectSoundVolume
	-- Played from the pad (the owner is standing on it). Only the owner's device gets this.
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 60
	sound.Parent = pad
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
end

local function burstCash(pad: BasePart)
	local origin = pad.Position + Vector3.new(0, pad.Size.Y / 2 + 0.3, 0)
	for _ = 1, GameConfig.CollectCashPieces do
		local piece = if math.random() < 0.7 then makeBill() else makeCoin()
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.CastShadow = false

		-- Each piece flies up and out in a random direction, spinning as it goes.
		local angle = math.random() * math.pi * 2
		local spread = 3 + math.random() * 5
		local velocity = Vector3.new(math.cos(angle) * spread, 14 + math.random() * 8, math.sin(angle) * spread)
		local spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 20
		local rotation = CFrame.Angles(math.random() * 6.3, math.random() * 6.3, math.random() * 6.3)
		piece.CFrame = CFrame.new(origin) * rotation
		piece.Parent = effectsFolder

		local position = origin
		local age = 0
		local connection
		connection = RunService.RenderStepped:Connect(function(dt)
			age += dt
			if age >= LIFETIME then
				connection:Disconnect()
				piece:Destroy()
				return
			end
			velocity -= Vector3.new(0, GRAVITY * dt, 0)
			position += velocity * dt
			rotation *= CFrame.Angles(spin.X * dt, spin.Y * dt, spin.Z * dt)
			piece.CFrame = CFrame.new(position) * rotation
			local fade = math.clamp((age - (LIFETIME - FADE_TIME)) / FADE_TIME, 0, 1)
			if fade > 0 then
				piece.Transparency = fade
				for _, symbol in piece:GetDescendants() do
					if symbol:IsA("TextLabel") then
						symbol.TextTransparency = fade
					end
				end
			end
		end)
	end
end

function CollectEffect.start()
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "CollectEffects"
	effectsFolder.Parent = workspace

	-- `withBurst` is true on the step onto the pad; later collects while standing just flash.
	Remotes.CashCollected.OnClientEvent:Connect(function(pad: BasePart, withBurst: boolean)
		-- Just in case the pad hasn't streamed in on this device yet.
		if not pad or not pad:IsDescendantOf(workspace) then
			return
		end
		flashPad(pad)
		if withBurst then
			playChaChing(pad)
			burstCash(pad)
		end
	end)
end

return CollectEffect
