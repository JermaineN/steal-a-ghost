-- Banner across the top of the screen when a top-rarity ghost spawns on the walkway.
--   Legendary: slides down in shimmering gold with the ghost's name and price, with a chime.
--   Mythic:    the screen flashes, a dark strip drops in, and a huge rainbow title lands with a
--              bigger sound; its colours drift slowly and it stays longer.
-- The server only says which ghost spawned (Remotes.RareSpawn); everything here is visual.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local GhostConfig = require(ReplicatedStorage.Shared.Config.GhostConfig)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)

local player = Players.LocalPlayer

local RareSpawnBanner = {}

local FONT = Enum.Font.FredokaOne
local TOP_MARGIN = 58 -- clear of Roblox's own buttons in the top corners

local gui: ScreenGui
local current: { destroy: () -> () }? -- the banner on screen, if any

local function new(className: string, props: { [string]: any }): any
	local instance = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	instance.Parent = parent
	return instance
end

-- Text with a thick dark outline.
local function outlinedText(props: { [string]: any }, thickness: number): (TextLabel, UIStroke)
	props.BackgroundTransparency = 1
	props.Font = FONT
	props.TextScaled = false
	local label = new("TextLabel", props)
	local stroke = new("UIStroke", {
		Color = Color3.new(0, 0, 0),
		Thickness = thickness,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = label,
	})
	return label, stroke
end

-- "Phantom Knight · $25K", with the price in money green.
local function nameAndPrice(def): string
	local hex = Theme.MoneyGreen:ToHex()
	return `{def.name}  ·  <font color="#{hex}">${Format.cash(def.price)}</font>`
end

local function playSound(announcement)
	local sound = new("Sound", {
		SoundId = "rbxassetid://" .. announcement.soundId,
		Volume = announcement.volume,
		Parent = SoundService,
	})
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
end

-- Shrinks banners on small (phone) screens.
local function screenScale(): number
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 800
	return math.clamp(height / 800, 0.6, 1)
end

local function showLegendary(def, announcement)
	local banner = new("Frame", {
		Name = "LegendaryBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -120),
		Size = UDim2.new(0.95, 0, 0, 72),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	new("UIScale", { Scale = screenScale(), Parent = banner })

	local title = outlinedText({
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 36,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "LEGENDARY GHOST SPAWNED!",
		Parent = banner,
	}, 3)
	-- A gold gradient that slides along, so the title shimmers.
	local shimmer = new("UIGradient", {
		Color = Theme.RarityGradients.Legendary,
		Rotation = 15,
		Parent = title,
	})
	outlinedText({
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 25,
		RichText = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = nameAndPrice(def),
		Parent = banner,
	}, 2.5)

	local started = os.clock()
	local animation = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		shimmer.Offset = Vector2.new(math.sin(t * 3) * 0.5, 0)
	end)

	playSound(announcement)
	TweenService:Create(banner, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, TOP_MARGIN),
	}):Play()

	local function destroy()
		animation:Disconnect()
		banner:Destroy()
	end
	task.delay(announcement.seconds, function()
		if not banner.Parent then
			return
		end
		local leave = TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -120),
		})
		leave.Completed:Connect(destroy)
		leave:Play()
	end)
	return { destroy = destroy }
end

local function showMythic(def, announcement)
	local scale = screenScale()

	-- A quick white flash over the whole screen.
	local flash = new("Frame", {
		Name = "MythicFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = gui,
	})
	local fade = TweenService:Create(flash, TweenInfo.new(0.7), { BackgroundTransparency = 1 })
	fade.Completed:Connect(function()
		flash:Destroy()
	end)
	fade:Play()

	-- A dark strip across the top.
	local stripHeight = 170 * scale
	local strip = new("Frame", {
		Name = "MythicBanner",
		Position = UDim2.new(0, 0, 0, -stripHeight - 10),
		Size = UDim2.new(1, 0, 0, stripHeight),
		BackgroundColor3 = Color3.fromRGB(10, 5, 20),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Parent = gui,
	})
	local content = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12 * scale),
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundTransparency = 1,
		Parent = strip,
	})
	new("UIScale", { Scale = scale, Parent = content })

	-- Anchored at its centre so it grows in from the middle.
	local title = outlinedText({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 0, 0, 72),
		TextSize = 66,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "MYTHIC GHOST SPAWNED!",
		Parent = content,
	}, 5)
	local rainbow = new("UIGradient", { Color = Theme.RarityGradients.Mythic, Parent = title })
	local titleScale = new("UIScale", { Scale = 2.5, Parent = title })
	outlinedText({
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 38,
		RichText = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = nameAndPrice(def),
		Parent = content,
	}, 3.5)

	-- The rainbow drifts slowly back and forth; the title itself stays still once it lands.
	local started = os.clock()
	local animation = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		rainbow.Offset = Vector2.new(math.sin(t * 0.8) * 0.5, 0)
	end)

	playSound(announcement)
	TweenService:Create(strip, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0),
	}):Play()
	-- Shrinks smoothly into place (no bounce).
	TweenService:Create(titleScale, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()

	local function destroy()
		animation:Disconnect()
		strip:Destroy()
		if flash.Parent then
			flash:Destroy()
		end
	end
	task.delay(announcement.seconds, function()
		if not strip.Parent then
			return
		end
		local leave = TweenService:Create(strip, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0, 0, 0, -stripHeight - 10),
		})
		leave.Completed:Connect(destroy)
		leave:Play()
	end)
	return { destroy = destroy }
end

function RareSpawnBanner.start()
	gui = new("ScreenGui", {
		Name = "RareSpawnBanner",
		ResetOnSpawn = false,
		IgnoreGuiInset = true, -- lets the Mythic strip and flash cover the very top of the screen
		DisplayOrder = 5, -- above the HUD
		Parent = player:WaitForChild("PlayerGui"),
	})

	Remotes.RareSpawn.OnClientEvent:Connect(function(ghostId: string)
		local def = GhostConfig.byId[ghostId]
		local announcement = def and GameConfig.RareSpawnAnnouncements[def.rarity]
		if not announcement then
			return
		end
		-- A new banner replaces whatever is showing.
		if current then
			current.destroy()
		end
		current = if def.rarity == "Mythic" then showMythic(def, announcement) else showLegendary(def, announcement)
	end)
end

return RareSpawnBanner
