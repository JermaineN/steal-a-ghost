-- The Inventory window (side menu → Inventory), in the Inventory button's orange. One card per
-- item you own (bought in the Shop), with how many you have, and an Equip button that puts it
-- in the hotbar (max GameConfig.MaxEquippedItems; equipped cards get an "EQUIPPED" ribbon). The
-- server marks owned items with "Item_<itemId>" = count and the equipped ones with "Equipped".
-- Two tabs under the header: Items, and Titles (TitleConfig, owned ones are "Title_<id>"
-- attributes): Wear shows that title above your head (one at a time, the "Title" attribute),
-- Take off removes it. Rebirth titles (TitleConfig `rebirths`) show even before you own them:
-- locked, with a bar for how close you are (rebirths done plus your cash toward the next one).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local TitleConfig = require(ReplicatedStorage.Shared.Config.TitleConfig)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TitleText = require(ReplicatedStorage.Shared.TitleText)
local Hud = require(script.Parent.Hud)
local Window = require(script.Parent.Window)

local InventoryPanel = {}

local INVENTORY_ORANGE = Color3.fromRGB(255, 140, 30)
local LOCKED_GREY = Color3.fromRGB(90, 84, 104)
local WHITE = Color3.new(1, 1, 1)
local new = Window.new

local player = Players.LocalPlayer

local panel: Window.Window
type Card = {
	card: Frame,
	count: TextLabel,
	stroke: UIStroke,
	ribbon: Frame,
	equip: TextButton,
	equipLabel: TextLabel,
}
local cards: { [string]: Card } = {}
type TitleCard = {
	card: Frame,
	stroke: UIStroke,
	ribbon: Frame,
	wear: TextButton,
	wearLabel: TextLabel,
	heading: TextLabel,
	dim: Frame,
	bar: Frame,
	barFill: Frame,
	barText: TextLabel,
}
local titleCards: { [string]: TitleCard } = {}
local emptyLabel: TextLabel
local slotsLabel: TextLabel

local TAB_HEIGHT = 36
local TABS = { "Items", "Titles" }
local currentTab = "Items"
local tabButtons: { [string]: TextButton } = {}

local function owned(itemId: string): number
	return player:GetAttribute("Item_" .. itemId) or 0
end

local function stat(name: string): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(name)
	return if value then (value :: any).Value else 0
end

-- How close you are to a rebirth title, 0 to 1: rebirths done, plus your cash toward the next one.
local function rebirthProgress(needed: number): number
	local rebirths = stat("Rebirths")
	local towardNext = math.clamp(stat("Cash") / Rebirth.cost(rebirths), 0, 1)
	return math.clamp((rebirths + towardNext) / needed, 0, 1)
end

-- The equipped items (in the hotbar), from the server's "Equipped" attribute ("smoke_bomb,gravity").
local function equippedIds(): { string }
	local ids = {}
	for id in string.gmatch(player:GetAttribute("Equipped") or "", "[^,]+") do
		table.insert(ids, id)
	end
	return ids
end

-- Shows the cards of the items you own, with their counts and whether they're equipped.
local function refresh()
	local equipped = equippedIds()
	local full = #equipped >= GameConfig.MaxEquippedItems
	local showItems = currentTab == "Items"
	local any = false
	for _, item in ItemConfig.Items do
		local count = owned(item.id)
		local entry = cards[item.id]
		local isEquipped = table.find(equipped, item.id) ~= nil
		entry.card.Visible = showItems and count > 0
		entry.count.Text = "x" .. count
		entry.ribbon.Visible = isEquipped
		entry.stroke.Thickness = if isEquipped then 4 else 2.5
		entry.stroke.Color = if isEquipped then INVENTORY_ORANGE else item.color
		entry.equipLabel.Text = if isEquipped then "Unequip" elseif full then "Hotbar full" else "Equip"
		Window.paintButton(entry.equip, if isEquipped or full then LOCKED_GREY else INVENTORY_ORANGE)
		entry.equip.Visible = item.tool == true -- only tools go in the hotbar
		any = any or (showItems and count > 0)
	end
	local wearing = player:GetAttribute("Title")
	for order, title in TitleConfig.Titles do
		local entry = titleCards[title.id]
		local isOwned = player:GetAttribute("Title_" .. title.id) == true
		local isWorn = wearing == title.id
		local locked = not isOwned and title.rebirths ~= nil
		entry.card.Visible = not showItems and (isOwned or locked)
		-- Owned titles first, then the locked ones.
		entry.card.LayoutOrder = #ItemConfig.Items + order + (if locked then 100 else 0)
		entry.ribbon.Visible = isWorn
		entry.stroke.Thickness = if isWorn then 4 else 2.5
		entry.stroke.Color = if locked then LOCKED_GREY else title.color
		entry.dim.Visible = locked
		entry.wear.Visible = not locked
		entry.bar.Visible = locked
		entry.wearLabel.Text = if isWorn then "Take off" else "Wear"
		Window.paintButton(entry.wear, if isWorn then LOCKED_GREY else title.color)
		if title.rebirths then
			local plural = if title.rebirths == 1 then "" else "s"
			entry.heading.Text = if locked then `Locked: {title.rebirths} rebirth{plural}` else `Rebirth title`
		end
		if locked then
			entry.barFill.Size = UDim2.fromScale(rebirthProgress(title.rebirths), 1)
			entry.barText.Text = `{math.min(stat("Rebirths"), title.rebirths)}/{title.rebirths} rebirths`
		end
		any = any or (not showItems and (isOwned or locked))
	end
	emptyLabel.Visible = not any
	emptyLabel.Text = if showItems then "Nothing here yet. Visit the Shop!" else "No titles yet."
	slotsLabel.Visible = showItems
	for name, button in tabButtons do
		Window.paintButton(button, if name == currentTab then INVENTORY_ORANGE else LOCKED_GREY)
	end
	slotsLabel.Text = `Hotbar: {#equipped}/{GameConfig.MaxEquippedItems} equipped`
end

local function buildCard(item, order: number, parent: Instance)
	local card = new("Frame", {
		Name = item.id,
		LayoutOrder = order,
		BackgroundColor3 = WHITE,
		Visible = false,
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(0.1, 0), Parent = card })
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(item.color:Lerp(Window.PANEL_DARK, 0.6), Window.PANEL_DARK),
		Parent = card,
	})
	new("UIStroke", { Color = item.color, Thickness = 2.5, Parent = card })

	local picture = Window.itemPicture(card, item, UDim2.fromOffset(96, 96), UDim2.fromOffset(27, 10))
	Window.rarityLabel(picture, item)
	-- How many you own, in a pill on the picture's corner.
	local countPill = new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 8, 1, 6),
		Size = UDim2.fromOffset(44, 26),
		BackgroundColor3 = INVENTORY_ORANGE,
		ZIndex = 2,
		Parent = picture,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = countPill })
	new("UIStroke", {
		Color = Window.TEXT_OUTLINE,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = countPill,
	})
	local count = Window.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 1, -6),
		TextColor3 = WHITE,
		ZIndex = 2,
		Parent = countPill,
	})

	Window.text({
		Position = UDim2.fromOffset(8, 110),
		Size = UDim2.new(1, -16, 0, 22),
		TextColor3 = WHITE,
		Text = item.name,
		Parent = card,
	})
	Window.text({
		Position = UDim2.fromOffset(8, 133),
		Size = UDim2.new(1, -16, 0, 16),
		TextColor3 = Color3.fromRGB(205, 190, 230),
		Text = item.description,
		Parent = card,
	})
	-- "EQUIPPED" ribbon across the top of the picture while it's in the hotbar.
	local ribbon = new("Frame", {
		Name = "Equipped",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(110, 24),
		BackgroundColor3 = INVENTORY_ORANGE,
		Rotation = -6,
		ZIndex = 3,
		Visible = false,
		Parent = card,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ribbon })
	new("UIStroke", {
		Color = Window.TEXT_OUTLINE,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = ribbon,
	})
	Window.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -12, 1, -6),
		TextColor3 = WHITE,
		Text = "EQUIPPED",
		ZIndex = 3,
		Parent = ribbon,
	})

	-- Equip puts it in the hotbar (max GameConfig.MaxEquippedItems); Unequip takes it out.
	local equip, equipLabel = Window.button({
		Name = "Equip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 160),
		Size = UDim2.new(1, -24, 0, 34),
		Parent = card,
	}, INVENTORY_ORANGE)
	equip.Activated:Connect(function()
		local isEquipped = table.find(equippedIds(), item.id) ~= nil
		if not isEquipped and #equippedIds() >= GameConfig.MaxEquippedItems then
			Hud.showToast(`Your hotbar is full! Unequip an item first (max {GameConfig.MaxEquippedItems}).`, "error")
			return
		end
		Remotes.EquipItem:FireServer(item.id, not isEquipped)
	end)

	cards[item.id] = {
		card = card,
		count = count,
		stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke,
		ribbon = ribbon,
		equip = equip,
		equipLabel = equipLabel,
	}
end

-- A title's card: the title itself, animated, where an item's picture would be.
local function ribbonOn(card: Frame, text: string, color: Color3): Frame
	local ribbon = new("Frame", {
		Name = "Ribbon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(110, 24),
		BackgroundColor3 = color,
		Rotation = -6,
		ZIndex = 3,
		Visible = false,
		Parent = card,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ribbon })
	new("UIStroke", {
		Color = Window.TEXT_OUTLINE,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = ribbon,
	})
	Window.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -12, 1, -6),
		TextColor3 = WHITE,
		Text = text,
		ZIndex = 3,
		Parent = ribbon,
	})
	return ribbon
end

local function buildTitleCard(title, order: number, parent: Instance)
	local card = new("Frame", {
		Name = "Title_" .. title.id,
		LayoutOrder = order,
		BackgroundColor3 = WHITE,
		Visible = false,
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(0.1, 0), Parent = card })
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(title.color:Lerp(Window.PANEL_DARK, 0.6), Window.PANEL_DARK),
		Parent = card,
	})
	local stroke = new("UIStroke", { Color = title.color, Thickness = 2.5, Parent = card })

	local holder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.new(1, -14, 0, 40),
		BackgroundTransparency = 1,
		Parent = card,
	})
	TitleText.create(holder, title, 2.5)

	-- Darkens a locked title's word.
	local dim = new("Frame", {
		Name = "Dim",
		Position = UDim2.fromOffset(4, 34),
		Size = UDim2.new(1, -8, 0, 52),
		BackgroundColor3 = Window.PANEL_DARK,
		BackgroundTransparency = 0.45,
		ZIndex = 3,
		Visible = false,
		Parent = card,
	})
	new("UICorner", { CornerRadius = UDim.new(0.2, 0), Parent = dim })

	local heading = Window.text({
		Position = UDim2.fromOffset(8, 110),
		Size = UDim2.new(1, -16, 0, 22),
		TextColor3 = WHITE,
		Text = "Title",
		Parent = card,
	})
	Window.text({
		Position = UDim2.fromOffset(8, 133),
		Size = UDim2.new(1, -16, 0, 16),
		TextColor3 = Color3.fromRGB(205, 190, 230),
		Text = "Shown above your head",
		Parent = card,
	})
	local ribbon = ribbonOn(card, "WEARING", title.color)

	local wear, wearLabel = Window.button({
		Name = "Wear",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 160),
		Size = UDim2.new(1, -24, 0, 34),
		Parent = card,
	}, title.color)
	wear.Activated:Connect(function()
		local isWorn = player:GetAttribute("Title") == title.id
		Remotes.EquipTitle:FireServer(if isWorn then "" else title.id)
	end)

	-- In the Wear button's place while a rebirth title is locked: how close you are.
	local bar = new("Frame", {
		Name = "Progress",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 163),
		Size = UDim2.new(1, -24, 0, 28),
		BackgroundColor3 = Color3.fromRGB(30, 20, 45),
		Visible = false,
		Parent = card,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bar })
	new("UIStroke", { Color = Window.TEXT_OUTLINE, Thickness = 2, Parent = bar })
	local barFill = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = title.color,
		Parent = bar,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = barFill })
	local barText = Window.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -12, 1, -8),
		TextColor3 = WHITE,
		ZIndex = 2,
		Parent = bar,
	})

	titleCards[title.id] = {
		card = card,
		stroke = stroke,
		ribbon = ribbon,
		wear = wear,
		wearLabel = wearLabel,
		heading = heading,
		dim = dim,
		bar = bar,
		barFill = barFill,
		barText = barText,
	}
end

function InventoryPanel.isOpen(): boolean
	return panel ~= nil and panel.isOpen()
end
function InventoryPanel.open()
	panel.open()
end
function InventoryPanel.close()
	panel.close()
end
function InventoryPanel.toggle()
	panel.toggle()
end

function InventoryPanel.start()
	panel = Window.create({
		name = "Inventory",
		title = "Inventory",
		icon = GameConfig.MenuIcons.Inventory,
		accent = INVENTORY_ORANGE,
		width = 560,
		height = 480 + TAB_HEIGHT + 8,
		onOpen = refresh,
	})
	-- "Hotbar: 2/3 equipped", in the header next to the title.
	slotsLabel = Window.text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -62, 0, 20),
		Size = UDim2.fromOffset(200, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = INVENTORY_ORANGE,
		Parent = panel.window,
	}, 1.5)
	-- The tabs, under the header.
	for index, name in TABS do
		local button, label = Window.button({
			Name = name .. "Tab",
			Position = UDim2.fromOffset(20 + (index - 1) * 130, Window.HEADER_HEIGHT),
			Size = UDim2.fromOffset(120, TAB_HEIGHT),
			Parent = panel.window,
		}, LOCKED_GREY)
		label.Text = name
		button.Activated:Connect(function()
			currentTab = name
			refresh()
		end)
		tabButtons[name] = button
	end
	-- The cards sit below the tabs.
	local grid = Window.grid(panel.window, Vector2.new(150, 206))
	grid.Position += UDim2.fromOffset(0, TAB_HEIGHT + 8)
	grid.Size -= UDim2.fromOffset(0, TAB_HEIGHT + 8)
	for order, item in ItemConfig.Items do
		buildCard(item, order, grid)
	end
	for order, title in TitleConfig.Titles do
		buildTitleCard(title, #ItemConfig.Items + order, grid)
	end
	emptyLabel = Window.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 20),
		Size = UDim2.new(1, -80, 0, 30),
		TextColor3 = Color3.fromRGB(205, 190, 230),
		Text = "Nothing here yet. Visit the Shop!",
		Parent = panel.window,
	})

	-- Buying something updates the window straight away.
	player.AttributeChanged:Connect(function(attribute)
		if string.match(attribute, "^Item_") or string.match(attribute, "^Title") or attribute == "Equipped" then
			refresh()
		end
	end)
	-- The rebirth titles' bars follow your rebirths and cash.
	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats")
		for _, name in { "Cash", "Rebirths" } do
			(leaderstats:WaitForChild(name) :: NumberValue).Changed:Connect(function()
				if panel.isOpen() and currentTab == "Titles" then
					refresh()
				end
			end)
		end
	end)
	refresh()
end

return InventoryPanel
