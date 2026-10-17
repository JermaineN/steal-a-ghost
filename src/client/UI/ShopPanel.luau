-- The Shop window (side menu → Shop), in the Shop button's green. One card per item in
-- ItemConfig: its picture, name, description, price (gems or cash) and a Buy button. Buying
-- asks the server (ShopService), which checks the price; the item then shows in the Inventory.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Window = require(script.Parent.Window)

local ShopPanel = {}

local SHOP_GREEN = Color3.fromRGB(70, 220, 90)
local LOCKED_GREY = Color3.fromRGB(90, 84, 104)
local WHITE = Color3.new(1, 1, 1)
local new = Window.new

local player = Players.LocalPlayer

local function balance(currency: string): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(if currency == "gems" then "Gems" else "Cash")
	return if value then (value :: any).Value else 0
end

local panel: Window.Window
local refreshers: { () -> () } = {}

local function refreshAll()
	for _, refresh in refreshers do
		refresh()
	end
end

-- One item's card.
local function buildCard(item, order: number, parent: Instance)
	local card = new("Frame", {
		Name = item.id,
		LayoutOrder = order,
		BackgroundColor3 = WHITE,
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(0.1, 0), Parent = card })
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(item.color:Lerp(Window.PANEL_DARK, 0.6), Window.PANEL_DARK),
		Parent = card,
	})
	new("UIStroke", { Color = item.color, Thickness = 2.5, Parent = card })

	Window.itemPicture(card, item, UDim2.fromOffset(96, 96), UDim2.fromOffset(27, 10))
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

	-- The price: a gem picture and blue number, or a green "$X".
	local priceRow = new("Frame", {
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
		Parent = priceRow,
	})
	if item.currency == "gems" then
		new("ImageLabel", {
			Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 1,
			Image = GameConfig.GemIcon,
			LayoutOrder = 1,
			Parent = priceRow,
		})
	end
	Window.text({
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		TextScaled = false,
		TextSize = 21,
		TextColor3 = if item.currency == "gems" then Theme.GemBlue else Theme.MoneyGreen,
		Text = if item.currency == "gems" then Format.cash(item.price) else "$" .. Format.cash(item.price),
		LayoutOrder = 2,
		Parent = priceRow,
	}, 2)

	local buy, buyLabel = Window.button({
		Name = "Buy",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 180),
		Size = UDim2.new(1, -24, 0, 34),
		Parent = card,
	}, SHOP_GREEN)
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
		height = 520,
		onOpen = refreshAll,
	})
	local grid = Window.grid(panel.window, Vector2.new(150, 224))
	-- Cheapest first: gem items, then cash items (the two currencies can't be compared directly).
	local sorted = table.clone(ItemConfig.Items)
	table.sort(sorted, function(a, b)
		if a.currency ~= b.currency then
			return a.currency == "gems"
		end
		return a.price < b.price
	end)
	for order, item in sorted do
		buildCard(item, order, grid)
	end

	-- Buttons grey out and come back as your gems and cash change.
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
end

return ShopPanel
