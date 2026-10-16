-- The Ghost Index: every ghost in the game, from the most common to the rarest, showing which
-- ones you've found (owned at least once). Found ghosts show their spinning model, name, rarity
-- and income; the rest are dark silhouettes named "???", so you can see what's left to hunt.
-- Each found ghost has a one-time gem reward to claim from its card (or "Claim all"); the
-- server checks claims (IndexService) and marks them with "IndexClaimed_<ghostId>".
--
-- It's built from GhostConfig.Ghosts, so new ghosts appear here automatically. The server saves
-- what you've found and marks each one with an "Index_<ghostId>" attribute on your player, and
-- puts a preview copy of every ghost in ReplicatedStorage.GhostPreviews.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local GhostConfig = require(ReplicatedStorage.Shared.Config.GhostConfig)
local Theme = require(ReplicatedStorage.Shared.Theme)

local IndexPanel = {}

local PANEL_DARK = Color3.fromRGB(28, 16, 44)
local PANEL_EDGE = Color3.fromRGB(255, 140, 30)
local TEXT_OUTLINE = Color3.fromRGB(20, 8, 30)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.FredokaOne
local SPIN_SPEED = math.rad(40) -- degrees per second the found ghosts turn
local POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local GEM_BLUE = Theme.GemBlue

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

local function text(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.Font = FONT
	props.TextScaled = true
	local label = new("TextLabel", props)
	new("UIStroke", { Color = TEXT_OUTLINE, Thickness = 1.5, Parent = label })
	return label
end

local function isFound(ghostId: string): boolean
	return player:GetAttribute("Index_" .. ghostId) == true
end

local function canClaim(ghostId: string): boolean
	return isFound(ghostId) and player:GetAttribute("IndexClaimed_" .. ghostId) ~= true
end

-- How many gem rewards are waiting to be claimed.
function IndexPanel.claimableCount(): number
	local count = 0
	for _, def in GhostConfig.Ghosts do
		if canClaim(def.id) then
			count += 1
		end
	end
	return count
end

-- Fires (with the new count) whenever the number of waiting rewards changes; the side menu
-- shows it as a badge on the Index button.
IndexPanel.claimableChanged = Instance.new("BindableEvent")

-- Every ghost, most common first; within a rarity, cheapest first.
local function sortedGhosts()
	local list = table.clone(GhostConfig.Ghosts)
	table.sort(list, function(a, b)
		local orderA, orderB = GhostConfig.Rarities[a.rarity].order, GhostConfig.Rarities[b.rarity].order
		if orderA ~= orderB then
			return orderA < orderB
		end
		return a.price < b.price
	end)
	return list
end

type Card = { refresh: () -> (), spin: (number) -> () }

-- One ghost's card: a 3D view of the model on top, then name, rarity and income.
local function buildCard(def, order: number, parent: Instance): Card
	local rarity = GhostConfig.Rarities[def.rarity]
	local card = new("Frame", {
		Name = def.id,
		LayoutOrder = order,
		BackgroundColor3 = WHITE,
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(0.1, 0), Parent = card })
	local gradient = new("UIGradient", { Rotation = 90, Parent = card })
	local stroke = new("UIStroke", { Thickness = 2.5, Parent = card })

	-- The 3D view: a copy of the preview model, framed by its own little camera.
	local viewport = new("ViewportFrame", {
		Size = UDim2.fromScale(1, 0.62),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 200, 210),
		LightColor = WHITE,
		LightDirection = Vector3.new(-1, -1, -1),
		Parent = card,
	})
	local camera = new("Camera", { FieldOfView = 40, Parent = viewport })
	viewport.CurrentCamera = camera
	local model: Model? = nil
	local preview = ReplicatedStorage:WaitForChild("GhostPreviews", 10)
	local template = preview and preview:FindFirstChild(def.id)
	local center, distance = Vector3.zero, 10
	if template then
		model = template:Clone()
		model.Parent = viewport
		local box, size = model:GetBoundingBox()
		center = box.Position
		distance = math.max(size.X, size.Y, size.Z) * 1.7
		-- The ghosts face -Z, so look at them from that side.
		camera.CFrame = CFrame.lookAt(center + Vector3.new(0, size.Y * 0.1, -distance), center)
	end

	local name = text({
		Size = UDim2.fromScale(0.9, 0.13),
		Position = UDim2.fromScale(0.05, 0.62),
		TextColor3 = WHITE,
		Parent = card,
	})
	local gradientText = Theme.RarityGradients[def.rarity]
	local rarityLabel = text({
		Size = UDim2.fromScale(0.9, 0.1),
		Position = UDim2.fromScale(0.05, 0.76),
		Text = string.upper(def.rarity),
		TextColor3 = if gradientText then WHITE else rarity.color,
		Parent = card,
	})
	if gradientText then
		local gradient = new("UIGradient", { Color = gradientText, Parent = rarityLabel })
		CollectionService:AddTag(gradient, "AnimatedGradient") -- shimmers (client GradientAnimator)
	end
	local income = text({
		Size = UDim2.fromScale(0.9, 0.1),
		Position = UDim2.fromScale(0.05, 0.87),
		TextColor3 = Theme.MoneyGreen,
		Parent = card,
	})

	-- The gem reward: a blue "Claim" pill over the bottom of the 3D view, until it's claimed.
	local gems = GhostConfig.Rarities[def.rarity].indexGems
	local claim = new("TextButton", {
		Name = "Claim",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromScale(0.84, 0.15),
		BackgroundColor3 = GEM_BLUE,
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = "Claim 💎" .. gems,
		Visible = false,
		ZIndex = 2,
		Parent = card,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = claim })
	new(
		"UIStroke",
		{ Color = TEXT_OUTLINE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = claim }
	)
	new("UIPadding", { PaddingTop = UDim.new(0.14, 0), PaddingBottom = UDim.new(0.14, 0), Parent = claim })
	claim.Activated:Connect(function()
		if claim.Active then
			claim.Active = false -- until the server answers (the card refreshes then)
			claim.Text = "..."
			Remotes.IndexClaim:FireServer(def.id)
		end
	end)

	local spin = 0
	local function refresh()
		local found = isFound(def.id)
		name.Text = if found then def.name else "???"
		income.Text = if found then "+$" .. Format.cash(def.income) .. "/s" else ""
		-- Found: tinted by the rarity colour. Not found: dark, with a black silhouette.
		gradient.Color = if found
			then ColorSequence.new(rarity.color:Lerp(PANEL_DARK, 0.6), PANEL_DARK)
			else ColorSequence.new(Color3.fromRGB(40, 36, 50), Color3.fromRGB(18, 14, 26))
		stroke.Color = if found then rarity.color else Color3.fromRGB(70, 64, 84)
		viewport.ImageColor3 = if found then WHITE else Color3.new(0, 0, 0)
		viewport.ImageTransparency = if found then 0 else 0.35
		claim.Visible = canClaim(def.id)
		claim.Active = true
		claim.Text = "Claim 💎" .. gems
	end
	refresh()

	return {
		refresh = refresh,
		-- Found ghosts turn slowly so you can see them all round.
		spin = function(dt: number)
			if model and isFound(def.id) then
				spin += dt * SPIN_SPEED
				model:PivotTo(CFrame.new(center) * CFrame.Angles(0, spin, 0) * CFrame.new(-center))
			end
		end,
	}
end

local window: Frame
local scale: UIScale
local cards: { [string]: Card } = {}
local counter: TextLabel
local barFill: Frame
local claimAll: TextButton
local spinConnection: RBXScriptConnection? = nil

local function updateCounter()
	local found = 0
	for _, def in GhostConfig.Ghosts do
		if isFound(def.id) then
			found += 1
		end
	end
	counter.Text = "Found " .. found .. " / " .. #GhostConfig.Ghosts
	TweenService:Create(barFill, TweenInfo.new(0.3), {
		Size = UDim2.fromScale(found / math.max(#GhostConfig.Ghosts, 1), 1),
	}):Play()

	-- "Claim all" shows when there's more than one reward waiting.
	local claimable = IndexPanel.claimableCount()
	claimAll.Visible = claimable >= 2
	claimAll.Active = true
	claimAll.Text = "Claim all (" .. claimable .. ")"
	IndexPanel.claimableChanged:Fire(claimable)
end

function IndexPanel.isOpen(): boolean
	return window ~= nil and window.Visible
end

function IndexPanel.close()
	if not IndexPanel.isOpen() then
		return
	end
	if spinConnection then
		spinConnection:Disconnect()
		spinConnection = nil
	end
	local shrink = TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 0.8 })
	shrink.Completed:Once(function()
		if scale.Scale <= 0.81 then
			window.Visible = false
		end
	end)
	shrink:Play()
end

function IndexPanel.open()
	if IndexPanel.isOpen() then
		return
	end
	for _, card in cards do
		card.refresh()
	end
	updateCounter()
	window.Visible = true
	scale.Scale = 0.8
	TweenService:Create(scale, POP, { Scale = 1 }):Play()
	spinConnection = RunService.RenderStepped:Connect(function(dt)
		for _, card in cards do
			card.spin(dt)
		end
	end)
end

function IndexPanel.toggle()
	if IndexPanel.isOpen() then
		IndexPanel.close()
	else
		IndexPanel.open()
	end
end

function IndexPanel.start()
	local gui = new("ScreenGui", {
		Name = "GhostIndex",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	window = new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.72),
		BackgroundColor3 = WHITE,
		Visible = false,
		Parent = gui,
	})
	new("UISizeConstraint", { MaxSize = Vector2.new(860, 620), MinSize = Vector2.new(320, 300), Parent = window })
	new("UICorner", { CornerRadius = UDim.new(0, 18), Parent = window })
	new(
		"UIGradient",
		{ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(52, 30, 80), PANEL_DARK), Parent = window }
	)
	new("UIStroke", { Color = PANEL_EDGE, Thickness = 3, Parent = window })
	scale = new("UIScale", { Parent = window })

	-- Header: icon, title, close button, then the "Found X / Y" counter and progress bar.
	new("ImageLabel", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.fromOffset(52, 52),
		BackgroundTransparency = 1,
		Image = GameConfig.MenuIcons.Index,
		Parent = window,
	})
	text({
		Position = UDim2.fromOffset(74, 12),
		Size = UDim2.new(0.5, 0, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = WHITE,
		Text = "Ghost Index",
		Parent = window,
	})
	local close = new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Color3.fromRGB(220, 60, 70),
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = "X",
		Parent = window,
	})
	new("UICorner", { CornerRadius = UDim.new(0.3, 0), Parent = close })
	new(
		"UIStroke",
		{ Color = TEXT_OUTLINE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = close }
	)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = close })
	close.Activated:Connect(IndexPanel.close)

	-- "Claim all": a money-green pill with a thick outline that pulses gently, so it stands out.
	claimAll = new("TextButton", {
		Name = "ClaimAll",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -62, 0, 10),
		Size = UDim2.fromOffset(180, 44),
		BackgroundColor3 = WHITE, -- tinted by the gradient below
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = "Claim all",
		Visible = false,
		Parent = window,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = claimAll })
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Theme.MoneyGreen, Theme.MoneyGreen:Lerp(Color3.new(0, 0, 0), 0.35)),
		Parent = claimAll,
	})
	new("UIStroke", {
		Color = TEXT_OUTLINE,
		Thickness = 3.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = claimAll,
	})
	-- Outline on the words too, so the white text reads on the bright green.
	new("UIStroke", { Color = TEXT_OUTLINE, Thickness = 1.25, Parent = claimAll })
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = claimAll })
	local claimAllPulse = new("UIScale", { Parent = claimAll })
	TweenService:Create(
		claimAllPulse,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), -- forever, back and forth
		{ Scale = 1.07 }
	):Play()
	claimAll.Activated:Connect(function()
		if claimAll.Active then
			claimAll.Active = false
			claimAll.Text = "..."
			Remotes.IndexClaim:FireServer("all")
		end
	end)

	counter = text({
		Position = UDim2.fromOffset(18, 66),
		Size = UDim2.new(0.4, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = WHITE,
		Parent = window,
	})
	local bar = new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 70),
		Size = UDim2.new(0.5, 0, 0, 16),
		BackgroundColor3 = Color3.fromRGB(18, 10, 28),
		Parent = window,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bar })
	new("UIStroke", { Color = TEXT_OUTLINE, Thickness = 2, Parent = bar })
	barFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = PANEL_EDGE, Parent = bar })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = barFill })

	-- The cards, in a scrolling grid that grows as ghosts are added.
	local grid = new("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(14, 102),
		Size = UDim2.new(1, -28, 1, -116),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = PANEL_EDGE,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = window,
	})
	new("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 14),
		Parent = grid,
	})
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 196),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = grid,
	})
	for order, def in sortedGhosts() do
		cards[def.id] = buildCard(def, order, grid)
	end

	-- Finding a ghost, or claiming its reward, updates its card (and the counter) straight away.
	player.AttributeChanged:Connect(function(attribute)
		local ghostId = string.match(attribute, "^Index_(.+)$") or string.match(attribute, "^IndexClaimed_(.+)$")
		if ghostId and cards[ghostId] then
			cards[ghostId].refresh()
			updateCounter()
		end
	end)
	updateCounter()
end

return IndexPanel
