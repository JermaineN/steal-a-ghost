-- A pop-up window in the same style as the Ghost Index and Rebirth windows: dark purple
-- gradient, an outline in the menu button's accent colour, the menu icon and title in the top
-- left, a red X in the top right, and a little pop when it opens. Used by the Shop and
-- Inventory windows. Put the window's content inside `window` below the header (y = 70).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.Theme)

local Window = {}

local PANEL_DARK = Color3.fromRGB(28, 16, 44)
local TEXT_OUTLINE = Color3.fromRGB(20, 8, 30)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.FredokaOne
local POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

Window.HEADER_HEIGHT = 70
Window.PANEL_DARK = PANEL_DARK
Window.TEXT_OUTLINE = TEXT_OUTLINE

export type Window = {
	window: Frame,
	isOpen: () -> boolean,
	open: () -> (),
	close: () -> (),
	toggle: () -> (),
}

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
Window.new = new

-- Outlined text, like every other window's.
function Window.text(props: { [string]: any }, thickness: number?): TextLabel
	props.BackgroundTransparency = 1
	props.Font = FONT
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	local label = new("TextLabel", props)
	new("UIStroke", { Color = TEXT_OUTLINE, Thickness = thickness or 1.5, Parent = label })
	return label
end

-- A rounded button whose colour is a top-to-bottom gradient. The words are their own label
-- (a gradient on the button would tint its text too). Returns the button and its label.
function Window.button(props: { [string]: any }, color: Color3): (TextButton, TextLabel)
	props.BackgroundColor3 = WHITE
	props.Text = ""
	props.AutoButtonColor = false
	local button = new("TextButton", props)
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = button })
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(color, color:Lerp(Color3.new(0, 0, 0), 0.35)),
		Parent = button,
	})
	new("UIStroke", {
		Color = TEXT_OUTLINE,
		Thickness = 2.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = button,
	})
	local label = Window.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -16, 1, -12),
		TextColor3 = WHITE,
		Parent = button,
	})
	return button, label
end

-- Recolours a button made by Window.button.
function Window.paintButton(button: TextButton, color: Color3)
	local gradient = button:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(color, color:Lerp(Color3.new(0, 0, 0), 0.35))
	end
end

-- `options`: name (ScreenGui name), title, icon (image id), accent (outline colour), and the
-- window's size in pixels (it shrinks to fit small screens). `onOpen` runs every time it opens.
function Window.create(options: {
	name: string,
	title: string,
	icon: string,
	accent: Color3,
	width: number,
	height: number,
	onOpen: (() -> ())?,
}): Window
	local gui = new("ScreenGui", {
		Name = options.name,
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	-- The holder scales the window to the screen; the window's own scale pops it open.
	local holder = new("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(options.width, options.height),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local screenScale = new("UIScale", { Parent = holder })
	local function fitScreen()
		local camera = workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(1200, 900)
		screenScale.Scale = math.clamp(math.min((size.Y - 40) / options.height, (size.X - 40) / options.width), 0.5, 1)
	end
	fitScreen()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScreen)
	end

	local window = new("Frame", {
		Name = "Window",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		Visible = false,
		Parent = holder,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 18), Parent = window })
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(52, 30, 80), PANEL_DARK),
		Parent = window,
	})
	new("UIStroke", { Color = options.accent, Thickness = 3, Parent = window })
	local scale = new("UIScale", { Parent = window })

	new("ImageLabel", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.fromOffset(52, 52),
		BackgroundTransparency = 1,
		Image = options.icon,
		Parent = window,
	})
	Window.text({
		Position = UDim2.fromOffset(74, 12),
		Size = UDim2.new(0.5, 0, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = WHITE,
		Text = options.title,
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
	new("UIStroke", {
		Color = TEXT_OUTLINE,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = close,
	})
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = close })

	local self: Window
	self = {
		window = window,
		isOpen = function()
			return window.Visible
		end,
		open = function()
			if window.Visible then
				return
			end
			if options.onOpen then
				options.onOpen()
			end
			window.Visible = true
			scale.Scale = 0.8
			TweenService:Create(scale, POP, { Scale = 1 }):Play()
		end,
		close = function()
			if not window.Visible then
				return
			end
			local shrink = TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 0.8 })
			shrink.Completed:Once(function()
				if scale.Scale <= 0.81 then
					window.Visible = false
				end
			end)
			shrink:Play()
		end,
		toggle = function()
			if window.Visible then
				self.close()
			else
				self.open()
			end
		end,
	}
	close.Activated:Connect(self.close)
	return self
end

-- A scrolling grid of cards below the header, like the Index's.
function Window.grid(window: Frame, cellSize: Vector2): ScrollingFrame
	local grid = new("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(14, Window.HEADER_HEIGHT + 6),
		Size = UDim2.new(1, -28, 1, -(Window.HEADER_HEIGHT + 20)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
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
		CellSize = UDim2.fromOffset(cellSize.X, cellSize.Y),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = grid,
	})
	return grid
end

-- An item card's picture: the item's image, or a big "?" until it has one.
function Window.itemPicture(parent: GuiObject, item, size: UDim2, position: UDim2): Frame
	local frame = new("Frame", {
		Position = position,
		Size = size,
		BackgroundColor3 = item.color:Lerp(PANEL_DARK, 0.45),
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(0.18, 0), Parent = frame })
	new("UIStroke", { Color = item.color, Thickness = 2, Parent = frame })
	if item.image ~= "" then
		new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.85, 0.85),
			BackgroundTransparency = 1,
			Image = item.image,
			ScaleType = Enum.ScaleType.Fit,
			Parent = frame,
		})
	else
		Window.text({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.6, 0.6),
			TextColor3 = item.color:Lerp(WHITE, 0.4),
			Text = "?",
			Parent = frame,
		}, 2.5)
	end
	return frame
end

-- The item's rarity word across the top edge of its picture, in the rarity's colour (Legendary
-- and rarer shimmer, like the ghosts' rarity words).
function Window.rarityLabel(picture: GuiObject, item): TextLabel
	local gradientColors = Theme.RarityGradients[item.rarity]
	local label = Window.text({
		Name = "Rarity",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1.3, 0, 0, 18),
		TextColor3 = if gradientColors then WHITE else item.color,
		Text = string.upper(item.rarity),
		ZIndex = 2,
		Parent = picture,
	}, 2)
	if gradientColors then
		local gradient = new("UIGradient", { Color = gradientColors, Parent = label })
		CollectionService:AddTag(gradient, "AnimatedGradient") -- slides (client GradientAnimator)
	end
	return label
end

return Window
