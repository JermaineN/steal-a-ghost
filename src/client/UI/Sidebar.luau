-- The side menu: press M (or tap the tab on the middle of the left edge) to slide out four
-- buttons (Shop, Rebirth, Index, Inventory), one after another; press again to tuck them away.
-- Index opens the Ghost Index (IndexPanel) and Rebirth the Rebirth window (RebirthPanel); the
-- other menus aren't built yet, so for now they say they're coming soon.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Hud = require(script.Parent.Hud)
local IndexPanel = require(script.Parent.IndexPanel)
local RebirthPanel = require(script.Parent.RebirthPanel)

local Sidebar = {}

local PANEL_DARK = Color3.fromRGB(28, 16, 44)
local PUMPKIN = Color3.fromRGB(255, 140, 30)
local TEXT_OUTLINE = Color3.fromRGB(20, 8, 30)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.FredokaOne

local TOGGLE_KEY = Enum.KeyCode.M
local TAB_SIZE = 56 -- pixels, before scaling to the screen
local BUTTON_SIZE = 96
local GAP = 16 -- between buttons (room for the name tags that hang off their bottom edge)
-- Space around each button inside its fading group, which hides anything outside its edges
-- (the name tag and the hover growth need the room).
local PAD = 16
local STAGGER = 0.06 -- seconds between each button appearing
local SLIDE_IN = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SLIDE_AWAY = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local QUICK = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Top to bottom. Each button has its own accent colour.
local OPTIONS = {
	{ name = "Shop", accent = Color3.fromRGB(70, 220, 90) },
	{ name = "Rebirth", accent = Color3.fromRGB(175, 95, 255) },
	{ name = "Index", accent = Color3.fromRGB(255, 190, 40) },
	{ name = "Inventory", accent = Color3.fromRGB(255, 140, 30) },
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

-- A colour mixed toward black (amount 0..1).
local function darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

-- The windows the buttons open. Opening one closes the others.
local PANELS = {
	Index = IndexPanel,
	Rebirth = RebirthPanel,
}

-- What each button does: open (or close) its window; menus without one aren't built yet.
local function select(name: string)
	local panel = PANELS[name]
	if not panel then
		Hud.showToast(name .. " coming soon!", "info")
		return
	end
	if not panel.isOpen() then
		for otherName, other in PANELS do
			if otherName ~= name then
				other.close()
			end
		end
	end
	panel.toggle()
end

-- One button: a card with a dark accent-tinted gradient, a glowing two-tone outline, the icon on a
-- soft halo, and a name tag hanging off the bottom edge. It grows and tilts when hovered and
-- squishes when pressed.
local function buildOption(option, parent: GuiObject): (TextButton, ImageLabel)
	local accent = option.accent
	local button = new("TextButton", {
		Name = option.name .. "Button",
		Position = UDim2.fromOffset(PAD, PAD),
		Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
		BackgroundColor3 = WHITE, -- tinted by the gradient below
		Text = "",
		AutoButtonColor = false,
		Parent = parent,
	})
	local scale = new("UIScale", { Parent = button })
	new("UICorner", { CornerRadius = UDim.new(0.26, 0), Parent = button })
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(darken(accent, 0.55), PANEL_DARK),
		Parent = button,
	})
	local stroke = new("UIStroke", {
		Color = WHITE,
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = button,
	})
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(accent:Lerp(WHITE, 0.35), darken(accent, 0.2)),
		Parent = stroke,
	})

	-- Soft halo behind the icon.
	local halo = new("Frame", {
		Name = "Halo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.44),
		Size = UDim2.fromScale(0.74, 0.74),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.78,
		Parent = button,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = halo })

	local icon = new("ImageLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.44),
		Size = UDim2.fromScale(0.76, 0.76),
		BackgroundTransparency = 1,
		Image = GameConfig.MenuIcons[option.name],
		Parent = button,
	})

	-- Name tag: an accent pill straddling the bottom edge.
	local tag = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.96),
		Size = UDim2.fromScale(0.98, 0.28),
		BackgroundColor3 = accent,
		Parent = button,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = tag })
	new("UIStroke", { Color = TEXT_OUTLINE, Thickness = 2.5, Parent = tag })
	local label = new("TextLabel", {
		Size = UDim2.fromScale(0.9, 0.8),
		Position = UDim2.fromScale(0.05, 0.1),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = option.name,
		Parent = tag,
	})
	new("UIStroke", { Color = TEXT_OUTLINE, Thickness = 2, Parent = label })

	-- Hover, press and click.
	local hovering = false
	local function settle()
		TweenService:Create(scale, QUICK, { Scale = if hovering then 1.08 else 1 }):Play()
		TweenService:Create(icon, QUICK, { Rotation = if hovering then -8 else 0 }):Play()
		TweenService:Create(stroke, QUICK, { Thickness = if hovering then 4.5 else 3 }):Play()
	end
	button.MouseEnter:Connect(function()
		hovering = true
		settle()
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		settle()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 0.93 }):Play()
	end)
	button.MouseButton1Up:Connect(settle)
	button.Activated:Connect(function()
		select(option.name)
	end)
	return button, icon
end

-- The always-visible tab: three bars that turn into an X while the menu is open, and a little
-- "M" badge so keyboard players learn the shortcut.
local function buildTab(parent: GuiObject): (TextButton, (boolean) -> ())
	local tab = new("TextButton", {
		Name = "Toggle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(TAB_SIZE, TAB_SIZE),
		BackgroundColor3 = WHITE,
		Text = "",
		AutoButtonColor = false,
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(0.3, 0), Parent = tab })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(darken(PUMPKIN, 0.6), PANEL_DARK), Parent = tab })
	local stroke = new("UIStroke", { Color = PUMPKIN, Thickness = 3, Parent = tab })
	local scale = new("UIScale", { Parent = tab })

	local bars = {}
	for i = 1, 3 do
		local bar = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, (i - 2) * 10),
			Size = UDim2.fromOffset(28, 5),
			BackgroundColor3 = PUMPKIN,
			Parent = tab,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bar })
		bars[i] = bar
	end

	local badge = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 1, -4),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = PUMPKIN,
		Font = FONT,
		TextScaled = true,
		TextColor3 = PANEL_DARK,
		Text = "M",
		Visible = UserInputService.KeyboardEnabled,
		Parent = tab,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
	-- Outline the circle, not the letter (a dark outline on such small text makes it unreadable).
	new("UIStroke", {
		Color = TEXT_OUTLINE,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = badge,
	})
	new("UIPadding", {
		PaddingTop = UDim.new(0, 3),
		PaddingBottom = UDim.new(0, 3),
		Parent = badge,
	})

	tab.MouseEnter:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 1.08 }):Play()
	end)
	tab.MouseLeave:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 1 }):Play()
	end)

	local morph = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local function showOpen(open: boolean)
		local color = if open then WHITE else PUMPKIN
		TweenService:Create(stroke, QUICK, { Color = color }):Play()
		for _, bar in bars do
			TweenService:Create(bar, QUICK, { BackgroundColor3 = color }):Play()
		end
		-- Top and bottom bars swing into an X; the middle one shrinks away.
		TweenService:Create(bars[1], morph, {
			Position = UDim2.fromScale(0.5, 0.5) + (if open then UDim2.new() else UDim2.fromOffset(0, -10)),
			Rotation = if open then 45 else 0,
		}):Play()
		TweenService:Create(bars[3], morph, {
			Position = UDim2.fromScale(0.5, 0.5) + (if open then UDim2.new() else UDim2.fromOffset(0, 10)),
			Rotation = if open then -45 else 0,
		}):Play()
		TweenService:Create(bars[2], QUICK, { Size = UDim2.fromOffset(if open then 0 else 28, 5) }):Play()
	end
	return tab, showOpen
end

-- A red badge in a button's corner: the number of Index rewards waiting, or "!" on Rebirth
-- while you can afford one. `changed` fires with the new value; `show` turns it into the badge
-- text, or nil to hide it.
local function addBadge(button: GuiObject, changed: BindableEvent, initial: any, show: (any) -> string?)
	local badge = new("TextLabel", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Color3.fromRGB(230, 40, 60),
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		ZIndex = 3,
		Parent = button,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
	new("UIStroke", {
		Color = TEXT_OUTLINE,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = badge,
	})
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = badge })
	local function update(value: any)
		local badgeText = show(value)
		badge.Visible = badgeText ~= nil
		badge.Text = badgeText or ""
	end
	changed.Event:Connect(update)
	update(initial)
end

-- Shrinks everything on small (phone) screens, like the HUD does.
local function scaleToScreen(scale: UIScale)
	local function update()
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 900
		scale.Scale = math.clamp(height / 800, 0.6, 1)
	end
	update()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
end

function Sidebar.start()
	local gui = new("ScreenGui", {
		Name = "Sidebar",
		ResetOnSpawn = false,
		IgnoreGuiInset = true, -- measure from the very top of the screen, so the tab is truly centred
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local stackHeight = #OPTIONS * BUTTON_SIZE + (#OPTIONS - 1) * GAP
	-- The tab and the button stack are both centred on this frame, which is centred on the left edge.
	local root = new("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(TAB_SIZE + GAP + BUTTON_SIZE, stackHeight),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	scaleToScreen(new("UIScale", { Parent = root }))
	local tab, showOpen = buildTab(root)

	-- Each button sits in a fixed slot; a see-through group inside slides in from the left and
	-- fades in, tilting into place.
	local holders, icons = {}, {}
	for index, option in OPTIONS do
		local slot = new("Frame", {
			Name = option.name,
			Position = UDim2.fromOffset(TAB_SIZE + GAP, (index - 1) * (BUTTON_SIZE + GAP)),
			Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
			BackgroundTransparency = 1,
			Parent = root,
		})
		local holder = new("CanvasGroup", {
			Name = "Holder",
			Size = UDim2.new(1, PAD * 2, 1, PAD * 2),
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			Visible = false,
			Parent = slot,
		})
		local button, icon = buildOption(option, holder)
		holders[index] = holder
		icons[index] = icon
		if option.name == "Index" then
			addBadge(button, IndexPanel.claimableChanged, IndexPanel.claimableCount(), function(count: number)
				return if count > 0 then tostring(count) else nil
			end)
		elseif option.name == "Rebirth" then
			addBadge(button, RebirthPanel.availableChanged, RebirthPanel.canAfford(), function(available: boolean)
				return if available then "!" else nil
			end)
		end
	end

	local SHOWN = UDim2.fromOffset(-PAD, -PAD)
	local HIDDEN = SHOWN + UDim2.fromOffset(-(TAB_SIZE + GAP + BUTTON_SIZE + PAD), 0)
	for _, holder in holders do
		holder.Position = HIDDEN
		holder.Rotation = -10
	end

	-- While open, the icons bob gently, each a little out of step with the others.
	local bobs = {}
	for index, icon in icons do
		bobs[index] = TweenService:Create(
			icon,
			TweenInfo.new(1.1 + index * 0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = UDim2.new(0.5, 0, 0.44, -3) }
		)
	end

	local open = false
	local generation = 0 -- so a quick re-press cancels the previous animation's leftovers
	local function setOpen(shouldOpen: boolean)
		open = shouldOpen
		generation += 1
		local thisGeneration = generation
		showOpen(open)
		for index, holder in holders do
			-- Opening: top button first. Closing: bottom button first.
			local order = if open then index else #holders - index + 1
			task.delay((order - 1) * STAGGER, function()
				if generation ~= thisGeneration then
					return
				end
				if open then
					holder.Visible = true
					TweenService:Create(holder, SLIDE_IN, { Position = SHOWN, Rotation = 0, GroupTransparency = 0 })
						:Play()
					bobs[index]:Play()
				else
					local away = TweenService:Create(
						holder,
						SLIDE_AWAY,
						{ Position = HIDDEN, Rotation = -10, GroupTransparency = 1 }
					)
					away.Completed:Once(function()
						if generation == thisGeneration then
							holder.Visible = false
							bobs[index]:Cancel()
							icons[index].Position = UDim2.fromScale(0.5, 0.44)
						end
					end)
					away:Play()
				end
			end)
		end
	end

	tab.Activated:Connect(function()
		setOpen(not open)
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		-- gameProcessed is true while typing in chat, so M there doesn't toggle the menu.
		if input.KeyCode == TOGGLE_KEY and not gameProcessed then
			setOpen(not open)
		end
	end)
end

return Sidebar
