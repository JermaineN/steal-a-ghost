-- The Upgrades window, opened from the Upgrades signpost at your base's entrance (the server
-- sends OpenUpgrades). Built like the other windows, in gold: one card per base upgrade (see
-- Shared.Upgrades) with pips for its level, what it does now and next, and a Buy button with the
-- price. The server checks every purchase (UpgradeService); levels arrive as "Upgrade_<id>"
-- attributes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Window = require(script.Parent.Window)

local UpgradePanel = {}

local GOLD = Color3.fromRGB(255, 190, 40)
local LOCKED_GREY = Color3.fromRGB(90, 84, 104)
local WHITE = Color3.new(1, 1, 1)
local CARD_WIDTH, CARD_HEIGHT = 230, 250
local new = Window.new

local player = Players.LocalPlayer

local panel: Window.Window
local refreshers: { () -> () } = {}

local function level(kindId: string): number
	return player:GetAttribute("Upgrade_" .. kindId) or 0
end

local function cash(): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Cash")
	return if value then (value :: any).Value else 0
end

local function refreshAll()
	for _, refresh in refreshers do
		refresh()
	end
end

local function buildCard(kind, order: number, parent: Instance)
	local card = new("Frame", {
		Name = kind.id,
		Position = UDim2.fromOffset(30 + (order - 1) * (CARD_WIDTH + 20), Window.HEADER_HEIGHT + 10),
		Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
		BackgroundColor3 = WHITE,
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(0.08, 0), Parent = card })
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(GOLD:Lerp(Window.PANEL_DARK, 0.65), Window.PANEL_DARK),
		Parent = card,
	})
	new("UIStroke", { Color = GOLD, Thickness = 2.5, Parent = card })

	Window.text({
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 30),
		TextColor3 = WHITE,
		Text = kind.name,
		Parent = card,
	}, 2)

	-- One pip per level: filled up to the current level.
	local maxLevel = #kind.costs
	local pipRow = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 48),
		Size = UDim2.fromOffset(maxLevel * 30, 20),
		BackgroundTransparency = 1,
		Parent = card,
	})
	local pips = {}
	for index = 1, maxLevel do
		local pip = new("Frame", {
			Position = UDim2.fromOffset((index - 1) * 30 + 4, 0),
			Size = UDim2.fromOffset(20, 20),
			BackgroundColor3 = LOCKED_GREY,
			Parent = pipRow,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pip })
		new("UIStroke", { Color = Window.TEXT_OUTLINE, Thickness = 2, Parent = pip })
		pips[index] = pip
	end

	local now = Window.text({
		Position = UDim2.fromOffset(10, 82),
		Size = UDim2.new(1, -20, 0, 26),
		TextColor3 = WHITE,
		Parent = card,
	}, 2)
	local nextLabel = Window.text({
		Position = UDim2.fromOffset(10, 112),
		Size = UDim2.new(1, -20, 0, 22),
		TextColor3 = GOLD,
		Parent = card,
	}, 1.75)
	local price = Window.text({
		Position = UDim2.fromOffset(10, 146),
		Size = UDim2.new(1, -20, 0, 28),
		TextColor3 = Theme.MoneyGreen,
		Parent = card,
	}, 2)

	local buy, buyLabel = Window.button({
		Name = "Buy",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(1, -40, 0, 44),
		Parent = card,
	}, GOLD)
	local waiting = false

	local function refresh()
		local current = level(kind.id)
		for index, pip in pips do
			pip.BackgroundColor3 = if index <= current then GOLD else LOCKED_GREY
		end
		now.Text = "Now: " .. Upgrades.describe(kind.id, current)
		local cost = Upgrades.nextCost(kind.id, current)
		if not cost then
			nextLabel.Text = "Fully upgraded!"
			price.Text = ""
			buyLabel.Text = "MAXED"
			Window.paintButton(buy, LOCKED_GREY)
			return
		end
		nextLabel.Text = "Next: " .. Upgrades.describe(kind.id, current + 1)
		price.Text = "$" .. Format.cash(cost)
		local affordable = cash() >= cost
		if not waiting then
			buyLabel.Text = if affordable then "Upgrade" else "Can't afford"
		end
		Window.paintButton(buy, if affordable then GOLD else LOCKED_GREY)
	end
	table.insert(refreshers, refresh)

	buy.Activated:Connect(function()
		local cost = Upgrades.nextCost(kind.id, level(kind.id))
		if waiting or not cost or cash() < cost then
			return
		end
		waiting = true
		buyLabel.Text = "..."
		Remotes.BuyUpgrade:FireServer(kind.id)
		task.delay(0.6, function()
			waiting = false
			refresh()
		end)
	end)
	refresh()
end

function UpgradePanel.isOpen(): boolean
	return panel ~= nil and panel.isOpen()
end
function UpgradePanel.open()
	panel.open()
end
function UpgradePanel.close()
	panel.close()
end

function UpgradePanel.start()
	panel = Window.create({
		name = "Upgrades",
		title = "Base Upgrades",
		icon = GameConfig.MenuIcons.Shop,
		accent = GOLD,
		width = 2 * CARD_WIDTH + 80,
		height = Window.HEADER_HEIGHT + CARD_HEIGHT + 30,
		onOpen = refreshAll,
	})
	for order, kind in Upgrades.Kinds do
		buildCard(kind, order, panel.window)
	end

	Remotes.OpenUpgrades.OnClientEvent:Connect(panel.open)
	player.AttributeChanged:Connect(function(attribute)
		if string.match(attribute, "^Upgrade_") and panel.isOpen() then
			refreshAll()
		end
	end)
	task.spawn(function()
		local cashValue = player:WaitForChild("leaderstats"):WaitForChild("Cash") :: NumberValue
		cashValue.Changed:Connect(function()
			if panel.isOpen() then
				refreshAll()
			end
		end)
	end)
end

return UpgradePanel
