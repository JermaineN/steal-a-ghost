-- The Inventory window (side menu → Inventory), in the Inventory button's orange. One card per
-- item you own (bought in the Shop), with how many you have, and an Equip button that puts it
-- in the hotbar (max GameConfig.MaxEquippedItems; equipped cards get an "EQUIPPED" ribbon). The
-- server marks owned items with "Item_<itemId>" = count and the equipped ones with "Equipped".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
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
local emptyLabel: TextLabel
local slotsLabel: TextLabel

local function owned(itemId: string): number
	return player:GetAttribute("Item_" .. itemId) or 0
end

-- The equipped items (in the hotbar), from the server's "Equipped" attribute ("item_1,item_3").
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
	local any = false
	for _, item in ItemConfig.Items do
		local count = owned(item.id)
		local entry = cards[item.id]
		local isEquipped = table.find(equipped, item.id) ~= nil
		entry.card.Visible = count > 0
		entry.count.Text = "x" .. count
		entry.ribbon.Visible = isEquipped
		entry.stroke.Thickness = if isEquipped then 4 else 2.5
		entry.stroke.Color = if isEquipped then INVENTORY_ORANGE else item.color
		entry.equipLabel.Text = if isEquipped then "Unequip" elseif full then "Hotbar full" else "Equip"
		Window.paintButton(entry.equip, if isEquipped or full then LOCKED_GREY else INVENTORY_ORANGE)
		any = any or count > 0
	end
	emptyLabel.Visible = not any
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
		height = 480,
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
	local grid = Window.grid(panel.window, Vector2.new(150, 206))
	for order, item in ItemConfig.Items do
		buildCard(item, order, grid)
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
		if string.match(attribute, "^Item_") or attribute == "Equipped" then
			refresh()
		end
	end)
	refresh()
end

return InventoryPanel
