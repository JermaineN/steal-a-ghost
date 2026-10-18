-- The Ghost Index: every ghost in the game, from the most common to the rarest, showing which
-- ones you've found (owned at least once). Found ghosts show their spinning model, name, rarity
-- and income; the rest are dark silhouettes named "???", so you can see what's left to hunt.
-- Each found ghost has a one-time gem reward to claim from its card (or "Claim all"); the
-- server checks claims (IndexService) and marks them with "IndexClaimed_<ghostId>".
--
-- Clicking a found ghost opens its page: the model big on the left, and its four mutations on the
-- right, greyed out until you've owned this ghost with that mutation, then in their colours. Each
-- found mutation has its own one-time gem reward (MutationConfig indexGems), per ghost; claim
-- them one by one or with the page's "Claim all". Cards with mutation gems waiting show a red "!".
-- The main "Claim all" claims every reward, mutation ones included. The server marks mutation
-- finds and claims with "IndexMut_<ghostId>_<mutationId>" / "IndexMutClaimed_<ghostId>_<mutationId>".
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
local MutationConfig = require(ReplicatedStorage.Shared.Config.MutationConfig)
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
local BADGE_RED = Color3.fromRGB(235, 50, 60)
local UNFOUND_GREY = Color3.fromRGB(70, 64, 84)

-- The mutations in the order a ghost page lists them: most common first.
local MUTATIONS = table.clone(MutationConfig.Mutations)
table.sort(MUTATIONS, function(a, b)
	return a.chance < b.chance
end)

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

local function isMutationFound(ghostId: string, mutationId: string): boolean
	return player:GetAttribute("IndexMut_" .. ghostId .. "_" .. mutationId) == true
end

local function canClaimMutation(ghostId: string, mutationId: string): boolean
	return isMutationFound(ghostId, mutationId)
		and player:GetAttribute("IndexMutClaimed_" .. ghostId .. "_" .. mutationId) ~= true
end

-- How many of a ghost's mutation rewards are waiting.
local function mutationClaimableCount(ghostId: string): number
	local count = 0
	for _, mutation in MUTATIONS do
		if canClaimMutation(ghostId, mutation.id) then
			count += 1
		end
	end
	return count
end

-- How many gem rewards are waiting to be claimed (ghosts and their mutations).
function IndexPanel.claimableCount(): number
	local count = 0
	for _, def in GhostConfig.Ghosts do
		if canClaim(def.id) then
			count += 1
		end
		count += mutationClaimableCount(def.id)
	end
	return count
end

-- The green "Claim all" pill: thick outline, gently pulsing so it stands out. Used in the header
-- and on ghost pages.
local function claimAllButton(props: { [string]: any }): TextButton
	props.BackgroundColor3 = WHITE -- tinted by the gradient below
	props.Font = FONT
	props.TextScaled = true
	props.TextColor3 = WHITE
	props.Text = "Claim all"
	props.Visible = false
	local button = new("TextButton", props)
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = button })
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Theme.MoneyGreen, Theme.MoneyGreen:Lerp(Color3.new(0, 0, 0), 0.35)),
		Parent = button,
	})
	new("UIStroke", {
		Color = TEXT_OUTLINE,
		Thickness = 3.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = button,
	})
	-- Outline on the words too, so the white text reads on the bright green.
	new("UIStroke", { Color = TEXT_OUTLINE, Thickness = 1.25, Parent = button })
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = button })
	local pulse = new("UIScale", { Parent = button })
	TweenService:Create(
		pulse,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), -- forever, back and forth
		{ Scale = 1.07 }
	):Play()
	return button
end

-- A 3D view of a ghost's preview model, framed by its own camera. Returns the viewport and a
-- function that turns the model by `dt` seconds' worth.
local function ghostView(def, props: { [string]: any }, distanceScale: number): (ViewportFrame, (number) -> ())
	props.BackgroundTransparency = 1
	props.Ambient = Color3.fromRGB(200, 200, 210)
	props.LightColor = WHITE
	props.LightDirection = Vector3.new(-1, -1, -1)
	local viewport = new("ViewportFrame", props)
	local camera = new("Camera", { FieldOfView = 40, Parent = viewport })
	viewport.CurrentCamera = camera
	local preview = ReplicatedStorage:WaitForChild("GhostPreviews", 10)
	local template = preview and preview:FindFirstChild(def.id)
	if not template then
		return viewport, function() end
	end
	local model = template:Clone()
	model.Parent = viewport
	local box, size = model:GetBoundingBox()
	local center = box.Position
	local distance = math.max(size.X, size.Y, size.Z) * distanceScale
	-- The ghosts face -Z, so look at them from that side.
	camera.CFrame = CFrame.lookAt(center + Vector3.new(0, size.Y * 0.1, -distance), center)
	local spin = 0
	return viewport,
		function(dt: number)
			spin += dt * SPIN_SPEED
			model:PivotTo(CFrame.new(center) * CFrame.Angles(0, spin, 0) * CFrame.new(-center))
		end
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
	local viewport, turn = ghostView(def, { Size = UDim2.fromScale(1, 0.62), Parent = card }, 1.7)

	-- Clicking a found ghost opens its page (mutations). Under the Claim pill.
	local open = new("TextButton", {
		Name = "Open",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Parent = card,
	})
	open.Activated:Connect(function()
		if isFound(def.id) then
			IndexPanel.openGhost(def.id)
		end
	end)
	-- A red "!" in the corner while this ghost has mutation gems to claim.
	local badge = new("Frame", {
		Name = "MutationBadge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = BADGE_RED,
		Visible = false,
		ZIndex = 3,
		Parent = card,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
	new(
		"UIStroke",
		{ Color = TEXT_OUTLINE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = badge }
	)
	text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.75),
		TextColor3 = WHITE,
		Text = "!",
		ZIndex = 3,
		Parent = badge,
	})

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
		badge.Visible = mutationClaimableCount(def.id) > 0
		claim.Visible = canClaim(def.id)
		claim.Active = true
		claim.Text = "Claim 💎" .. gems
	end
	refresh()

	return {
		refresh = refresh,
		-- Found ghosts turn slowly so you can see them all round.
		spin = function(dt: number)
			if isFound(def.id) then
				turn(dt)
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
local grid: ScrollingFrame

-- The ghost page (one at a time): built when a ghost is opened, cleared on Back.
local page: Frame
local pageContent: Frame? = nil
local pageGhostId: string? = nil
local pageRefresh: (() -> ())? = nil
local pageTurn: ((number) -> ())? = nil

local function closeGhost()
	if pageContent then
		pageContent:Destroy()
	end
	pageContent, pageGhostId, pageRefresh, pageTurn = nil, nil, nil, nil
	page.Visible = false
	grid.Visible = true
end

-- One mutation's row on a ghost page: its name (greyed out until found, then in its colours and
-- shimmering), its income boost, and a claim pill for its gems.
local function buildMutationRow(ghostId: string, mutation, order: number, parent: Instance): () -> ()
	local row = new("TextButton", {
		Name = mutation.id,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = WHITE,
		AutoButtonColor = false,
		Text = "",
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 14), Parent = row })
	local rowGradient = new("UIGradient", { Rotation = 90, Parent = row })
	local rowStroke = new("UIStroke", { Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = row })

	local name = text({
		Position = UDim2.fromOffset(14, 5),
		Size = UDim2.new(0.55, -14, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.upper(mutation.name),
		Parent = row,
	})
	local nameGradient = new("UIGradient", { Color = mutation.gradient, Parent = name })
	CollectionService:AddTag(nameGradient, "AnimatedGradient") -- shimmers (client GradientAnimator)
	local boost = text({
		Position = UDim2.fromOffset(14, 33),
		Size = UDim2.new(0.55, -14, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local status = new("TextLabel", {
		Name = "Status",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0.42, 0, 0, 32),
		BackgroundColor3 = GEM_BLUE,
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		Parent = row,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = status })
	local statusStroke = new("UIStroke", {
		Color = TEXT_OUTLINE,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = status,
	})
	new("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7), Parent = status })

	row.Activated:Connect(function()
		if row.Active and canClaimMutation(ghostId, mutation.id) then
			row.Active = false -- until the server answers (the row refreshes then)
			status.Text = "..."
			Remotes.IndexClaimMutation:FireServer(ghostId, mutation.id)
		end
	end)

	return function()
		local found = isMutationFound(ghostId, mutation.id)
		local claimable = canClaimMutation(ghostId, mutation.id)
		-- Found: the mutation's colours. Not found: a dark, greyed-out row.
		nameGradient.Enabled = found
		name.TextColor3 = if found then WHITE else UNFOUND_GREY
		rowGradient.Color = if found
			then ColorSequence.new(mutation.color:Lerp(PANEL_DARK, 0.65), PANEL_DARK)
			else ColorSequence.new(Color3.fromRGB(40, 36, 50), Color3.fromRGB(18, 14, 26))
		rowStroke.Color = if found then mutation.color else UNFOUND_GREY
		boost.Text = "x" .. mutation.multiplier .. " income"
		boost.TextColor3 = if found then Theme.MoneyGreen else UNFOUND_GREY
		row.Active = true
		status.BackgroundTransparency = if claimable then 0 else 1
		statusStroke.Enabled = claimable
		status.TextColor3 = if claimable then WHITE elseif found then Theme.MoneyGreen else UNFOUND_GREY
		status.Text = if claimable
			then "Claim 💎" .. mutation.indexGems
			elseif found then "Claimed ✓"
			else "Not found"
	end
end

-- Opens a found ghost's page in place of the grid.
function IndexPanel.openGhost(ghostId: string)
	local def = GhostConfig.byId[ghostId]
	if not def or not isFound(ghostId) then
		return
	end
	if pageContent then
		pageContent:Destroy()
	end
	local rarity = GhostConfig.Rarities[def.rarity]
	local content = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = page })

	-- Left: the model, big, turning; its name and rarity under it.
	local viewport, turn = ghostView(def, {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(0.45, 0, 1, -110),
		Parent = content,
	}, 1.35)
	viewport.Name = "Model"
	text({
		Position = UDim2.new(0, 0, 1, -64),
		Size = UDim2.new(0.45, 0, 0, 32),
		TextColor3 = WHITE,
		Text = def.name,
		Parent = content,
	})
	local gradientText = Theme.RarityGradients[def.rarity]
	local rarityLabel = text({
		Position = UDim2.new(0, 0, 1, -30),
		Size = UDim2.new(0.45, 0, 0, 24),
		TextColor3 = if gradientText then WHITE else rarity.color,
		Text = string.upper(def.rarity),
		Parent = content,
	})
	if gradientText then
		local gradient = new("UIGradient", { Color = gradientText, Parent = rarityLabel })
		CollectionService:AddTag(gradient, "AnimatedGradient")
	end

	-- Right: the four mutations, then "Claim all" for this ghost's mutation gems.
	text({
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.new(0.5, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = WHITE,
		Text = "Mutations",
		Parent = content,
	})
	local list = new("Frame", {
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.new(0.5, -6, 1, -100),
		BackgroundTransparency = 1,
		Parent = content,
	})
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local rows = {}
	for order, mutation in MUTATIONS do
		table.insert(rows, buildMutationRow(ghostId, mutation, order, list))
	end
	local pageClaimAll = claimAllButton({
		Name = "ClaimAll",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -8),
		Size = UDim2.fromOffset(180, 44),
		Parent = content,
	})
	pageClaimAll.Activated:Connect(function()
		if pageClaimAll.Active then
			pageClaimAll.Active = false
			pageClaimAll.Text = "..."
			Remotes.IndexClaimMutation:FireServer(ghostId, "all")
		end
	end)

	pageContent, pageGhostId, pageTurn = content, ghostId, turn
	pageRefresh = function()
		for _, refreshRow in rows do
			refreshRow()
		end
		local claimable = mutationClaimableCount(ghostId)
		pageClaimAll.Visible = claimable >= 1
		pageClaimAll.Active = true
		pageClaimAll.Text = "Claim all (" .. claimable .. ")"
	end
	pageRefresh()
	grid.Visible = false
	page.Visible = true
end

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
	closeGhost() -- always opens on the grid
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
		if pageTurn then
			pageTurn(dt)
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

	-- "Claim all" (every ghost and mutation reward).
	claimAll = claimAllButton({
		Name = "ClaimAll",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -62, 0, 10),
		Size = UDim2.fromOffset(180, 44),
		Parent = window,
	})
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
	grid = new("ScrollingFrame", {
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

	-- The ghost page sits where the grid is, with a Back button in its top left.
	page = new("Frame", {
		Name = "GhostPage",
		Position = grid.Position,
		Size = grid.Size,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = window,
	})
	local back = new("TextButton", {
		Name = "Back",
		Size = UDim2.fromOffset(110, 36),
		BackgroundColor3 = PANEL_EDGE,
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = "< Back",
		ZIndex = 2,
		Parent = page,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = back })
	new(
		"UIStroke",
		{ Color = TEXT_OUTLINE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = back }
	)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = back })
	back.Activated:Connect(closeGhost)

	-- Finding a ghost, or claiming its reward, updates its card (and the counter) straight away.
	player.AttributeChanged:Connect(function(attribute)
		local ghostId = string.match(attribute, "^Index_(.+)$")
			or string.match(attribute, "^IndexClaimed_(.+)$")
			or string.match(attribute, "^IndexMut_(.+)_%a+$")
			or string.match(attribute, "^IndexMutClaimed_(.+)_%a+$")
		if ghostId and cards[ghostId] then
			cards[ghostId].refresh()
			updateCounter()
			if ghostId == pageGhostId and pageRefresh then
				pageRefresh()
			end
		end
	end)
	updateCounter()
end

return IndexPanel
