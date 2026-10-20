-- Timers for the server-wide boosters (Shop → Boosters: Server Luck, Server Mutations), shown to
-- everyone in the server: one small pill per running booster at the top right, e.g.
-- "🍀 Server Luck 12:34", stacked under each other. A booster shows while its `serverAttribute`
-- on ReplicatedStorage (set by StoreService, in server time) is in the future.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HauntedHour = require(ReplicatedStorage.Shared.HauntedHour)
local StoreConfig = require(ReplicatedStorage.Shared.Config.StoreConfig)
local Mobile = require(script.Parent.Mobile)

local ServerBoostHud = {}

local PANEL_DARK = Color3.fromRGB(28, 16, 44)
local TEXT_OUTLINE = Color3.fromRGB(20, 8, 30)
local FONT = Enum.Font.FredokaOne
local PILL_WIDTH = 210
local PILL_HEIGHT = 30

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

-- One pill, in the booster's colour. Hidden until its booster runs.
local function buildPill(booster, order: number, parent: Instance): TextLabel
	local pill = new("Frame", {
		Name = booster.id,
		LayoutOrder = order,
		Size = UDim2.fromOffset(PILL_WIDTH, PILL_HEIGHT),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pill })
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(booster.color:Lerp(PANEL_DARK, 0.55), PANEL_DARK),
		Parent = pill,
	})
	new("UIStroke", {
		Color = booster.color,
		Thickness = 2.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = pill,
	})
	local label = new("TextLabel", {
		Name = "Time",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -18, 1, -8),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = pill,
	})
	new("UIStroke", {
		Color = TEXT_OUTLINE,
		Thickness = 1.5,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = label,
	})
	return label
end

function ServerBoostHud.start()
	local gui = new("ScreenGui", {
		Name = "ServerBoosts",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 4,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- Top right, under Roblox's own buttons in that corner.
	local stack = new("Frame", {
		Name = "Stack",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, if Mobile.isMobile then 58 else 62),
		Size = UDim2.fromOffset(PILL_WIDTH, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Parent = stack,
	})
	if Mobile.isMobile then
		new("UIScale", { Scale = 0.8, Parent = stack })
	end

	local pills = {}
	for order, booster in StoreConfig.Boosters do
		if booster.serverAttribute then
			table.insert(pills, { booster = booster, label = buildPill(booster, order, stack) })
		end
	end

	task.spawn(function()
		while true do
			local now = workspace:GetServerTimeNow()
			for _, pill in pills do
				local untilTime = ReplicatedStorage:GetAttribute(pill.booster.serverAttribute)
				local running = typeof(untilTime) == "number" and untilTime > now
				pill.label.Parent.Visible = running
				if running then
					pill.label.Text =
						`{pill.booster.icon} {pill.booster.name} {HauntedHour.formatTime(untilTime - now)}`
				end
			end
			task.wait(0.25)
		end
	end)
end

return ServerBoostHud
