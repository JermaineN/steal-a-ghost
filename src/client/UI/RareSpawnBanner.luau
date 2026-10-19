-- Banner across the top of the screen when a top-rarity ghost spawns on the walkway.
--   Legendary: slides down in shimmering gold with the ghost's name and price, with a chime.
--   Mythic:    the screen flashes, a dark strip drops in, and a huge shiny red title lands with a
--              bigger sound; its colours drift slowly and it stays longer.
--   Divine / Secret: the same big banner in their own colours (Secret flashes the screen dark).
--   Shiny mutation: the big banner in Shiny's colours, on any rarity ("SHINY GHOST SPAWNED!",
--              or "SHINY MYTHIC GHOST SPAWNED!" on a rare one).
--   Undead mutation: the smaller (Legendary-style) banner in Undead's colours, or the big one
--              when the ghost is Mythic or rarer ("UNDEAD MYTHIC GHOST SPAWNED!").
-- The server only says which ghost spawned (Remotes.RareSpawn); everything here is visual.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local GhostConfig = require(ReplicatedStorage.Shared.Config.GhostConfig)
local MutationConfig = require(ReplicatedStorage.Shared.Config.MutationConfig)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local GradientAnimator = require(script.Parent.Parent.GradientAnimator)

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

-- "Spooky Phantom Knight · $25K", with the price in money green.
local function nameAndPrice(def, mutation): string
	local hex = Theme.MoneyGreen:ToHex()
	local name = if mutation then mutation.name .. " " .. def.name else def.name
	return `{name}  ·  <font color="#{hex}">${Format.cash(def.price)}</font>`
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

-- The smaller banner (Legendary, and Undead on anything below Mythic), in `gradient`'s colours.
local function showSmall(announcement, nameText: string, titleText: string, gradient: ColorSequence)
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
		Text = titleText,
		Parent = banner,
	}, 3)
	-- A gradient that slides along, so the title shimmers.
	local shimmer = new("UIGradient", {
		Color = gradient,
		Rotation = 15,
		Parent = title,
	})
	outlinedText({
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 25,
		RichText = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = nameText,
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

-- The big banner, used for Mythic and every rarity above it, and for the mutations that
-- announce (Undead, Shiny), each in its own colours. `flashColor` is the quick screen flash:
-- Secret flashes dark, Undead a sickly green.
local BIG_BANNERS = {
	Mythic = { flashColor = Color3.new(1, 1, 1) },
	Divine = { flashColor = Color3.fromRGB(215, 235, 255) },
	Secret = { flashColor = Color3.new(0, 0, 0) },
}
local MUTATION_FLASH = {
	undead = Color3.fromRGB(60, 120, 50),
	shiny = Color3.new(1, 1, 1),
}

type BigStyle = { title: string, gradient: ColorSequence, flashColor: Color3, nameText: string }

local function showBig(style: BigStyle, announcement)
	local scale = screenScale()

	-- A quick flash over the whole screen.
	local flash = new("Frame", {
		Name = "MythicFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = style.flashColor,
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
		-- Long titles ("SHINY LEGENDARY GHOST SPAWNED!") get a bit smaller so they fit.
		TextSize = if #style.title > 24 then 52 else 66,
		TextColor3 = Color3.new(1, 1, 1),
		Text = style.title,
		Parent = content,
	}, 5)
	local shimmer = new("UIGradient", { Color = style.gradient, Parent = title })
	local titleScale = new("UIScale", { Scale = 2.5, Parent = title })
	outlinedText({
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 38,
		RichText = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = style.nameText,
		Parent = content,
	}, 3.5)

	-- The colours drift slowly back and forth (looping colours, like Secret's, scroll one way
	-- through GradientAnimator instead); the title itself stays still once it lands.
	local started = os.clock()
	local animation = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		shimmer.Offset = Vector2.new(math.sin(t * 0.8) * 0.5, 0)
	end)
	if GradientAnimator.loops(style.gradient) then
		animation:Disconnect()
		CollectionService:AddTag(shimmer, GradientAnimator.TAG)
	end

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

	Remotes.RareSpawn.OnClientEvent:Connect(function(ghostId: string, mutationId: string?)
		local def = GhostConfig.byId[ghostId]
		if not def then
			return
		end
		local mutation = mutationId and MutationConfig.byId[mutationId]
		-- A mutation that announces (Undead, Shiny) gets the big banner in its own colours.
		local bigMutation = if mutation and mutation.announce then mutation else nil
		local rarityAnnouncement = GameConfig.RareSpawnAnnouncements[def.rarity]
		local mutationAnnouncement = bigMutation and GameConfig.MutationAnnouncements[bigMutation.id]
		if not rarityAnnouncement and not mutationAnnouncement then
			return
		end
		-- A new banner replaces whatever is showing.
		if current then
			current.destroy()
		end
		local nameText = nameAndPrice(def, mutation)
		-- "SHINY GHOST SPAWNED!", "MYTHIC GHOST SPAWNED!", "UNDEAD LEGENDARY GHOST SPAWNED!" ...
		local words = {}
		if bigMutation then
			table.insert(words, string.upper(bigMutation.name))
		end
		if rarityAnnouncement then
			table.insert(words, string.upper(def.rarity))
		end
		table.insert(words, "GHOST SPAWNED!")
		local title = table.concat(words, " ")
		-- An announced mutation colours the banner; otherwise the rarity does.
		local gradient = if bigMutation then bigMutation.gradient else Theme.RarityGradients[def.rarity]
		-- Whichever announcement lasts longer (and its sound) wins.
		local announcement = mutationAnnouncement or rarityAnnouncement
		if
			rarityAnnouncement
			and mutationAnnouncement
			and rarityAnnouncement.seconds > mutationAnnouncement.seconds
		then
			announcement = rarityAnnouncement
		end

		-- The big banner for Mythic and rarer, and for mutations marked bigBanner (Shiny); the
		-- smaller one otherwise (Legendary, and Undead on anything below Mythic).
		if BIG_BANNERS[def.rarity] or (bigMutation and bigMutation.bigBanner) then
			current = showBig({
				title = title,
				gradient = gradient,
				flashColor = if bigMutation then MUTATION_FLASH[bigMutation.id] else BIG_BANNERS[def.rarity].flashColor,
				nameText = nameText,
			}, announcement)
		else
			current = showSmall(announcement, nameText, title, gradient)
		end
	end)
end

return RareSpawnBanner
