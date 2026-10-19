-- The Shop window (side menu → Shop), in the Shop button's green, with four tabs:
--   Items       one card per item in ItemConfig (gems or cash); ShopBuy remote → ShopService
--   Boosters    timed boosts for gems (StoreConfig.Boosters); BuyBooster remote → StoreService
--   Cosmetics   titles, auras, pets and base decor (CosmeticConfig), for gems (BuyCosmetic remote →
--               CosmeticService) or Robux (game passes); worn from the Inventory
--   Currency    gem packs for Robux (StoreConfig.GemPacks, Developer Products)
--   Gamepasses  permanent perks for Robux (StoreConfig.Passes)
-- The window only asks: the server checks every price. Robux purchases open Roblox's own
-- purchase prompt, and the server pays out (StoreService). A Robux card whose ID is still 0 in
-- StoreConfig says "Coming soon".
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local CosmeticConfig = require(ReplicatedStorage.Shared.Config.CosmeticConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local StoreConfig = require(ReplicatedStorage.Shared.Config.StoreConfig)
local Theme = require(ReplicatedStorage.Shared.Theme)
local TitleConfig = require(ReplicatedStorage.Shared.Config.TitleConfig)
local Window = require(script.Parent.Window)

local ShopPanel = {}

local SHOP_GREEN = Color3.fromRGB(70, 220, 90)
local LOCKED_GREY = Color3.fromRGB(90, 84, 104)
local WHITE = Color3.new(1, 1, 1)
local PALE = Color3.fromRGB(205, 190, 230)
local TABS = { "Items", "Boosters", "Cosmetics", "Currency", "Gamepasses" }
local TAB_HEIGHT = 40
local CARD_SIZE = Vector2.new(150, 224)
local new = Window.new

local player = Players.LocalPlayer

local function balance(currency: string): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(if currency == "gems" then "Gems" else "Cash")
	return if value then (value :: any).Value else 0
end

local panel: Window.Window
local refreshers: { () -> () } = {}
local currentTab = "Items"
local tabButtons: { [string]: TextButton } = {}
local grids: { [string]: ScrollingFrame } = {}

local function refreshAll()
	for name, button in tabButtons do
		Window.paintButton(button, if name == currentTab then SHOP_GREEN else LOCKED_GREY)
		grids[name].Visible = name == currentTab
	end
	for _, refresh in refreshers do
		refresh()
	end
end

-- An empty card in `color`: dark gradient, outline, name and description.
local function cardShell(name: string, description: string, color: Color3, order: number, parent: Instance): Frame
	local card = new("Frame", {
		Name = name,
		LayoutOrder = order,
		BackgroundColor3 = WHITE,
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(0.1, 0), Parent = card })
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(color:Lerp(Window.PANEL_DARK, 0.6), Window.PANEL_DARK),
		Parent = card,
	})
	new("UIStroke", { Color = color, Thickness = 2.5, Parent = card })
	Window.text({
		Position = UDim2.fromOffset(8, 110),
		Size = UDim2.new(1, -16, 0, 22),
		TextColor3 = WHITE,
		Text = name,
		Parent = card,
	})
	Window.text({
		Position = UDim2.fromOffset(8, 133),
		Size = UDim2.new(1, -16, 0, 16),
		TextColor3 = PALE,
		Text = description,
		Parent = card,
	})
	return card
end

-- A small banner across the top edge of a picture ("ACTIVE 12:34", "+20% BONUS"), like an item's
-- rarity word.
local function pictureBanner(picture: Frame, color: Color3): TextLabel
	return Window.text({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1.3, 0, 0, 18),
		TextColor3 = color,
		Text = "",
		ZIndex = 2,
		Parent = picture,
	}, 2)
end

-- The price row: a gem picture and blue number, a green "$X", or Robux. Returns the text label
-- (Robux prices are filled in once Roblox tells us them).
local function priceRow(card: Frame, currency: "gems" | "cash" | "robux", price: number?): TextLabel
	local row = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 152),
		Size = UDim2.new(1, -16, 0, 22),
		BackgroundTransparency = 1,
		Parent = card,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
		Parent = row,
	})
	if currency == "gems" then
		new("ImageLabel", {
			Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 1,
			Image = GameConfig.GemIcon,
			LayoutOrder = 1,
			Parent = row,
		})
	end
	local text = if currency == "gems"
		then Format.cash(price or 0)
		elseif currency == "cash" then "$" .. Format.cash(price or 0)
		else ""
	return Window.text({
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		TextScaled = false,
		TextSize = 21,
		TextColor3 = if currency == "gems" then Theme.GemBlue elseif currency == "cash" then Theme.MoneyGreen else WHITE,
		Text = text,
		LayoutOrder = 2,
		Parent = row,
	}, 2)
end

local function buyButton(card: Frame): (TextButton, TextLabel)
	return Window.button({
		Name = "Buy",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 180),
		Size = UDim2.new(1, -24, 0, 34),
		Parent = card,
	}, SHOP_GREEN)
end

-- Fills in a Robux price from Roblox (the price is set on the Creator Hub, not in code).
local function showRobuxPrice(label: TextLabel, id: number, infoType: Enum.InfoType)
	if id == 0 then
		label.Text = "Coming soon"
		label.TextColor3 = PALE
		return
	end
	label.Text = "..."
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
		label.Text = if ok and info.PriceInRobux then `R$ {Format.cash(info.PriceInRobux)}` else "R$ ?"
	end)
end

-- "12:34" until a server time.
local function clock(untilTime: number): string
	local seconds = math.max(0, math.ceil(untilTime - workspace:GetServerTimeNow()))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------

local function buildItemCard(item, order: number, parent: Instance)
	local card = cardShell(item.name, item.description, item.color, order, parent)
	card.Name = item.id
	local picture = Window.itemPicture(card, item, UDim2.fromOffset(96, 96), UDim2.fromOffset(27, 10))
	Window.rarityLabel(picture, item)
	priceRow(card, item.currency, item.price)

	local buy, buyLabel = buyButton(card)
	local waiting = false
	-- One-time items (ItemConfig `once`) you already have just say "Owned".
	local function alreadyOwned(): boolean
		return item.once == true and (player:GetAttribute("Item_" .. item.id) or 0) > 0
	end
	local function refresh()
		if alreadyOwned() then
			buyLabel.Text = "Owned"
			Window.paintButton(buy, LOCKED_GREY)
			return
		end
		local affordable = balance(item.currency) >= item.price
		if not waiting then
			buyLabel.Text = if affordable then "Buy" else "Can't afford"
		end
		Window.paintButton(buy, if affordable then SHOP_GREEN else LOCKED_GREY)
	end
	table.insert(refreshers, refresh)
	buy.Activated:Connect(function()
		if waiting or alreadyOwned() or balance(item.currency) < item.price then
			return
		end
		waiting = true
		buyLabel.Text = "..."
		Remotes.ShopBuy:FireServer(item.id)
		task.delay(0.6, function()
			waiting = false
			refresh()
		end)
	end)
	refresh()
end

---------------------------------------------------------------------------
-- Boosters
---------------------------------------------------------------------------

-- When a booster you can see runs out (server time), or nil if it isn't running.
local function boosterEnds(booster): number?
	local untilTime = if booster.id == "money"
		then player:GetAttribute("MoneyBoostUntil")
		elseif booster.id == "speed" then player:GetAttribute("SpeedBoostUntil")
		elseif booster.id == "luck" then ReplicatedStorage:GetAttribute("LuckBoostUntil")
		else nil -- spins aren't timed
	if untilTime and untilTime > workspace:GetServerTimeNow() then
		return untilTime
	end
	return nil
end

local function buildBoosterCard(booster, order: number, parent: Instance)
	local card = cardShell(booster.name, booster.description, booster.color, order, parent)
	card.Name = booster.id
	local picture = Window.iconPicture(card, booster.color, booster.icon)
	local banner = pictureBanner(picture, booster.color)
	priceRow(card, "gems", booster.price)

	local buy, buyLabel = buyButton(card)
	local waiting = false
	local function refresh()
		-- Running boosters show their time left; buying another adds more time.
		local ends = boosterEnds(booster)
		banner.Text = if ends then "ACTIVE " .. clock(ends) else ""
		local affordable = balance("gems") >= booster.price
		if not waiting then
			buyLabel.Text = if not affordable then "Can't afford" elseif ends then "Add time" else "Buy"
		end
		Window.paintButton(buy, if affordable then SHOP_GREEN else LOCKED_GREY)
	end
	table.insert(refreshers, refresh)
	buy.Activated:Connect(function()
		if waiting or balance("gems") < booster.price then
			return
		end
		waiting = true
		buyLabel.Text = "..."
		Remotes.BuyBooster:FireServer(booster.id)
		task.delay(0.6, function()
			waiting = false
			refresh()
		end)
	end)
	refresh()
end

---------------------------------------------------------------------------
-- Cosmetics
---------------------------------------------------------------------------

local function buildCosmeticCard(cosmetic, order: number, parent: Instance)
	local card = cardShell(cosmetic.name, cosmetic.description, cosmetic.color, order, parent)
	card.Name = cosmetic.id
	if cosmetic.kind == "title" then
		-- A title shows itself, animated, where the picture would be.
		Window.titlePicture(card, TitleConfig.byId[cosmetic.titleId])
	else
		local picture = Window.iconPicture(card, cosmetic.color, cosmetic.icon, cosmetic.image)
		Window.rarityLabel(picture, cosmetic)
	end
	local robux = cosmetic.currency == "robux"
	local price = priceRow(card, if robux then "robux" else "gems", cosmetic.price)
	if robux then
		showRobuxPrice(price, cosmetic.passId, Enum.InfoType.GamePass)
	end

	local buy, buyLabel = buyButton(card)
	local waiting = false
	local function refresh()
		local owned = CosmeticConfig.owns(player, cosmetic.id)
		if owned then
			buyLabel.Text = "Owned"
			Window.paintButton(buy, LOCKED_GREY)
		elseif robux then
			buyLabel.Text = if cosmetic.passId == 0 then "Soon" else "Buy"
			Window.paintButton(buy, if cosmetic.passId == 0 then LOCKED_GREY else SHOP_GREEN)
		else
			local affordable = balance("gems") >= cosmetic.price
			if not waiting then
				buyLabel.Text = if affordable then "Buy" else "Can't afford"
			end
			Window.paintButton(buy, if affordable then SHOP_GREEN else LOCKED_GREY)
		end
	end
	table.insert(refreshers, refresh)
	buy.Activated:Connect(function()
		if waiting or CosmeticConfig.owns(player, cosmetic.id) then
			return
		end
		if robux then
			if cosmetic.passId ~= 0 then
				MarketplaceService:PromptGamePassPurchase(player, cosmetic.passId)
			end
			return
		end
		if balance("gems") < cosmetic.price then
			return
		end
		waiting = true
		buyLabel.Text = "..."
		Remotes.BuyCosmetic:FireServer(cosmetic.id)
		task.delay(0.6, function()
			waiting = false
			refresh()
		end)
	end)
	refresh()
end

---------------------------------------------------------------------------
-- Currency (Robux gem packs)
---------------------------------------------------------------------------

local function buildGemPackCard(pack, order: number, parent: Instance)
	local card = cardShell(`{Format.cash(pack.gems)} Gems`, "", Theme.GemBlue, order, parent)
	card.Name = pack.id
	local picture = Window.iconPicture(card, Theme.GemBlue, nil, GameConfig.GemIcon)
	pictureBanner(picture, Theme.GemBlue).Text = if pack.bonus then string.upper(pack.bonus) else ""
	showRobuxPrice(priceRow(card, "robux"), pack.productId, Enum.InfoType.Product)

	local buy, buyLabel = buyButton(card)
	local available = pack.productId ~= 0
	buyLabel.Text = if available then "Buy" else "Soon"
	Window.paintButton(buy, if available then SHOP_GREEN else LOCKED_GREY)
	buy.Activated:Connect(function()
		if available then
			MarketplaceService:PromptProductPurchase(player, pack.productId)
		end
	end)
end

---------------------------------------------------------------------------
-- Gamepasses
---------------------------------------------------------------------------

local function buildPassCard(pass, order: number, parent: Instance)
	local card = cardShell(pass.name, pass.description, pass.color, order, parent)
	card.Name = pass.id
	Window.iconPicture(card, pass.color, pass.icon, pass.image)
	showRobuxPrice(priceRow(card, "robux"), pass.passId, Enum.InfoType.GamePass)

	local buy, buyLabel = buyButton(card)
	local function refresh()
		local owned = StoreConfig.ownsPass(player, pass.id)
		buyLabel.Text = if owned then "Owned" elseif pass.passId == 0 then "Soon" else "Buy"
		Window.paintButton(buy, if owned or pass.passId == 0 then LOCKED_GREY else SHOP_GREEN)
	end
	table.insert(refreshers, refresh)
	buy.Activated:Connect(function()
		if pass.passId ~= 0 and not StoreConfig.ownsPass(player, pass.id) then
			MarketplaceService:PromptGamePassPurchase(player, pass.passId)
		end
	end)
	refresh()
end

function ShopPanel.isOpen(): boolean
	return panel ~= nil and panel.isOpen()
end
function ShopPanel.open()
	panel.open()
end
function ShopPanel.close()
	panel.close()
end
function ShopPanel.toggle()
	panel.toggle()
end

function ShopPanel.start()
	panel = Window.create({
		name = "Shop",
		title = "Shop",
		icon = GameConfig.MenuIcons.Shop,
		accent = SHOP_GREEN,
		width = 560,
		height = 520 + TAB_HEIGHT + 8,
		onOpen = refreshAll,
	})
	-- The tabs, under the header, each with its own grid of cards below.
	for index, name in TABS do
		local button, label = Window.button({
			Name = name .. "Tab",
			Position = UDim2.fromOffset(20 + (index - 1) * 104, Window.HEADER_HEIGHT),
			Size = UDim2.fromOffset(98, TAB_HEIGHT),
			Parent = panel.window,
		}, LOCKED_GREY)
		label.Text = name
		button.Activated:Connect(function()
			currentTab = name
			refreshAll()
		end)
		tabButtons[name] = button
		local grid = Window.grid(panel.window, CARD_SIZE)
		grid.Name = name .. "Grid"
		grid.Position += UDim2.fromOffset(0, TAB_HEIGHT + 8)
		grid.Size -= UDim2.fromOffset(0, TAB_HEIGHT + 8)
		grids[name] = grid
	end

	-- Items and cosmetics: rarest first; within a rarity, gem items before cash items (the two
	-- currencies can't be compared), then the priciest first.
	local items = {}
	for _, item in ItemConfig.Items do
		if item.shop ~= false then
			table.insert(items, item)
		end
	end
	table.sort(items, function(a, b)
		if a.currency ~= b.currency then
			return a.currency == "gems"
		end
		return a.price > b.price
	end)
	for order, item in ItemConfig.sortByRarity(items) do
		buildItemCard(item, order, grids.Items)
	end
	for order, booster in StoreConfig.Boosters do
		buildBoosterCard(booster, order, grids.Boosters)
	end
	for order, cosmetic in ItemConfig.sortByRarity(CosmeticConfig.Cosmetics) do
		buildCosmeticCard(cosmetic, order, grids.Cosmetics)
	end
	for order, pack in StoreConfig.GemPacks do
		buildGemPackCard(pack, order, grids.Currency)
	end
	for order, pass in StoreConfig.Passes do
		buildPassCard(pass, order, grids.Gamepasses)
	end
	refreshAll()

	-- Buttons grey out and come back as your gems and cash change, booster timers tick, and
	-- passes and cosmetics say "Owned" once bought.
	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats")
		for _, name in { "Cash", "Gems" } do
			(leaderstats:WaitForChild(name) :: any).Changed:Connect(function()
				if panel.isOpen() then
					refreshAll()
				end
			end)
		end
		refreshAll()
	end)
	player.AttributeChanged:Connect(function(attribute)
		if panel.isOpen() and (string.match(attribute, "^Pass_") or string.match(attribute, "^Cosmetic_")) then
			refreshAll()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if panel.isOpen() and currentTab == "Boosters" then
				refreshAll()
			end
		end
	end)
end

return ShopPanel
