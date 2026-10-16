-- "Are you sure?" pop-up before selling a rare ghost (GameConfig.SellConfirmMinRarity or higher).
-- The server asks (SellConfirm remote) instead of selling; pressing Sell answers yes
-- (SellConfirmed remote) and the server sells it. Keep it, or waiting too long, sells nothing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local GhostConfig = require(ReplicatedStorage.Shared.Config.GhostConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)

local SellConfirmPopup = {}

local FONT = Enum.Font.FredokaOne
local PANEL = Color3.fromRGB(32, 20, 48)
local PANEL_EDGE = Color3.fromRGB(150, 90, 220)
local SELL_RED = Color3.fromRGB(220, 60, 70)
local KEEP_GREEN = Color3.fromRGB(60, 190, 90)
local TEXT_OUTLINE = Color3.fromRGB(20, 8, 30)

local function new(className: string, props: { [string]: any }): Instance
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
	local label = new("TextLabel", props) :: TextLabel
	new("UIStroke", { Color = TEXT_OUTLINE, Thickness = 2, Parent = label })
	return label
end

local function button(name: string, label: string, color: Color3, position: UDim2, parent: Instance): TextButton
	local b = new("TextButton", {
		Name = name,
		Size = UDim2.fromScale(0.42, 0.22),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = color,
		Text = label,
		Font = FONT,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = true,
		Parent = parent,
	}) :: TextButton
	new("UICorner", { CornerRadius = UDim.new(0.25, 0), Parent = b })
	new("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0), Parent = b })
	new(
		"UIStroke",
		{ Color = TEXT_OUTLINE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = b }
	)
	return b
end

local current: Frame? = nil

local function close()
	if current then
		current:Destroy()
		current = nil
	end
end

local function show(gui: ScreenGui, slot: number, ghostId: string, refund: number)
	close()
	local def = GhostConfig.byId[ghostId]
	if not def then
		return
	end

	local panel = new("Frame", {
		Name = "SellConfirm",
		Size = UDim2.fromScale(0.34, 0.3),
		Position = UDim2.fromScale(0.5, 0.45),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = PANEL,
		Parent = gui,
	}) :: Frame
	-- Keep a sensible shape on wide and narrow screens alike.
	new("UIAspectRatioConstraint", { AspectRatio = 1.7, Parent = panel })
	new("UISizeConstraint", { MinSize = Vector2.new(300, 0), Parent = panel })
	new("UICorner", { CornerRadius = UDim.new(0.08, 0), Parent = panel })
	new("UIStroke", { Color = PANEL_EDGE, Thickness = 3, Parent = panel })
	current = panel

	text({
		Text = "Sell your " .. def.name .. "?",
		Size = UDim2.fromScale(0.9, 0.2),
		Position = UDim2.fromScale(0.05, 0.08),
		TextColor3 = Color3.new(1, 1, 1),
		Parent = panel,
	})
	-- The rarity in its colours: gradient text for the top rarities, like the ghost labels.
	local gradient = Theme.RarityGradients[def.rarity]
	local rarityLabel = text({
		Text = string.upper(def.rarity) .. " GHOST",
		Size = UDim2.fromScale(0.9, 0.15),
		Position = UDim2.fromScale(0.05, 0.3),
		TextColor3 = if gradient then Color3.new(1, 1, 1) else GhostConfig.Rarities[def.rarity].color,
		Parent = panel,
	})
	if gradient then
		new("UIGradient", { Color = gradient, Parent = rarityLabel })
	end
	text({
		Text = "You'll get $" .. Format.cash(refund) .. " back.",
		Size = UDim2.fromScale(0.9, 0.13),
		Position = UDim2.fromScale(0.05, 0.48),
		TextColor3 = Theme.MoneyGreen,
		Parent = panel,
	})

	local sell = button("SellButton", "Sell", SELL_RED, UDim2.fromScale(0.27, 0.7), panel)
	local keep = button("KeepButton", "Keep it", KEEP_GREEN, UDim2.fromScale(0.73, 0.7), panel)
	sell.Activated:Connect(function()
		Remotes.SellConfirmed:FireServer(slot)
		close()
	end)
	keep.Activated:Connect(close)

	-- Pop in.
	local scale = new("UIScale", { Scale = 0.6, Parent = panel }) :: UIScale
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()

	-- The server stops waiting after SellConfirmSeconds, so close it then too.
	task.delay(GameConfig.SellConfirmSeconds, function()
		if current == panel then
			close()
		end
	end)
end

function SellConfirmPopup.start()
	local gui = new("ScreenGui", {
		Name = "SellConfirmPopup",
		ResetOnSpawn = false,
		DisplayOrder = 10, -- above the HUD
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	}) :: ScreenGui
	Remotes.SellConfirm.OnClientEvent:Connect(function(slot: number, ghostId: string, refund: number)
		show(gui, slot, ghostId, refund)
	end)
end

return SellConfirmPopup
