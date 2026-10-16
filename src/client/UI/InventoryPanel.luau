-- The Inventory window (side menu → Inventory), in the Inventory button's orange. One card per
-- item you own (bought in the Shop), with how many you have. The server marks owned items with
-- "Item_<itemId>" = count on your player. Items don't do anything yet (they're placeholders),
-- so each card's button says so.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local Window = require(script.Parent.Window)

local InventoryPanel = {}

local INVENTORY_ORANGE = Color3.fromRGB(255, 140, 30)
local LOCKED_GREY = Color3.fromRGB(90, 84, 104)
local WHITE = Color3.new(1, 1, 1)
local new = Window.new

local player = Players.LocalPlayer

local panel: Window.Window
local cards: { [string]: { card: Frame, count: TextLabel } } = {}
local emptyLabel: TextLabel

local function owned(itemId: string): number
	return player:GetAttribute("Item_" .. itemId) or 0
end

-- Shows the cards of the items you own, with their counts.
local function refresh()
	local any = false
	for _, item in ItemConfig.Items do
		local count = owned(item.id)
		local entry = cards[item.id]
		entry.card.Visible = count > 0
		entry.count.Text = "x" .. count
		any = any or count > 0
	end
	emptyLabel.Visible = not any
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
	-- Placeholder items can't be used yet.
	local _, useLabel = Window.button({
		Name = "Use",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 160),
		Size = UDim2.new(1, -24, 0, 34),
		Parent = card,
	}, LOCKED_GREY)
	useLabel.Text = "Coming soon"

	cards[item.id] = { card = card, count = count }
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
		if string.match(attribute, "^Item_") then
			refresh()
		end
	end)
	refresh()
end

return InventoryPanel
