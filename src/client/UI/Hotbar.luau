-- The hotbar along the bottom of the screen, replacing Roblox's built-in one. Built like the
-- Inventory cards (dark gradient, rounded, outlined in the item's colour, a number badge):
--   Slot 1:     the Bat (everyone always has it).
--   Slots 2+:   the items you've equipped from the Inventory (GameConfig.MaxEquippedItems).
--               Empty ones show a dashed "+" that opens the Inventory.
--   After that: any other tools in your Backpack (the Cage and Landmine, for allow-listed players).
-- Number keys (or clicking a slot) select it; selecting the selected slot again puts it away.
-- Tool slots hold the real Roblox tool. An item that's a tool (the Smoke Bomb) does the same with
-- its tool; other items are just highlighted. A cooldown shows as a shade with seconds left.
-- While you carry a ghost or are caged, the hotbar hides (CarryControls handles jumping).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local Hud = require(script.Parent.Hud)
local InventoryPanel = require(script.Parent.InventoryPanel)
local Window = require(script.Parent.Window)

local Hotbar = {}

local SLOT_SIZE = 66
local GAP = 10
local BOTTOM_MARGIN = 12
local INVENTORY_ORANGE = Color3.fromRGB(255, 140, 30)
local BAT_BROWN = Color3.fromRGB(190, 130, 80)
local EMPTY_GREY = Color3.fromRGB(90, 84, 104)
local WHITE = Color3.new(1, 1, 1)
local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local NUMBER_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}
local TOOL_COLORS = {
	Bat = BAT_BROWN,
}
-- The Cage and Landmine are coloured by their rarity, like the Shop items.
for name, rarity in ItemConfig.ToolRarities do
	TOOL_COLORS[name] = ItemConfig.rarityColor(rarity)
end
local TOOL_ICONS = {
	Bat = GameConfig.BatIcon,
	Cage = GameConfig.CageIcon,
	Landmine = GameConfig.LandmineIcon,
}
local new = Window.new

local player = Players.LocalPlayer

-- What a slot holds: a tool (by name), an equipped item (by id), or nothing (an empty item slot).
type Contents = { kind: "tool", name: string } | { kind: "item", id: string } | { kind: "empty" }

local function equippedIds(): { string }
	local text = player:GetAttribute("Equipped") or ""
	local ids = {}
	for id in string.gmatch(text, "[^,]+") do
		if ItemConfig.byId[id] then
			table.insert(ids, id)
		end
	end
	return ids
end

local function backpackTools(): { [string]: Tool }
	local tools = {}
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		for _, child in if container then container:GetChildren() else {} do
			if child:IsA("Tool") then
				tools[child.Name] = child
			end
		end
	end
	return tools
end

-- The slots in order: Bat, the equipped-item slots, then any other tools.
local function layout(): { Contents }
	local slots: { Contents } = { { kind = "tool", name = "Bat" } }
	local ids = equippedIds()
	for index = 1, GameConfig.MaxEquippedItems do
		local id = ids[index]
		table.insert(slots, if id then { kind = "item", id = id } else { kind = "empty" })
	end
	local extras = {}
	for name in backpackTools() do
		-- Item tools (named by item id) already sit in their item's slot.
		if name ~= "Bat" and not ItemConfig.byId[name] then
			table.insert(extras, name)
		end
	end
	table.sort(extras)
	for _, name in extras do
		table.insert(slots, { kind = "tool", name = name })
	end
	return slots
end

local function heldTool(): Tool?
	return player.Character and player.Character:FindFirstChildOfClass("Tool")
end

function Hotbar.start()
	-- Turn off Roblox's own hotbar; this one replaces it. (Can fail for a moment after joining.)
	task.spawn(function()
		for _ = 1, 20 do
			if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then
				return
			end
			task.wait(0.5)
		end
	end)

	local gui = new("ScreenGui", {
		Name = "Hotbar",
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local bar = new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM_MARGIN),
		Size = UDim2.fromOffset(0, SLOT_SIZE),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = gui,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, GAP),
		Parent = bar,
	})

	local slots: { Contents } = {}
	local selectedItem: string? = nil -- an item slot that's selected (items have no tool yet)

	-- Selects slot `index`: equips its tool, or selects its item; again puts it away.
	local function select(index: number)
		local contents = slots[index]
		if not contents or player:GetAttribute("Carrying") or player:GetAttribute("Caged") then
			return
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		-- An item that's a tool (e.g. the Smoke Bomb) works like any other tool slot.
		local toolName = if contents.kind == "tool"
			then contents.name
			elseif contents.kind == "item" and backpackTools()[contents.id] then contents.id
			else nil
		-- While invisible, only the Smoke Bomb itself can be picked: taking it out again ends the
		-- invisibility early (the server watches for it, SmokeBombService).
		if toolName and toolName ~= "smoke_bomb" and player:GetAttribute("Invisible") then
			Hud.showToast("You can't use items while invisible!", "error")
			return
		end
		if toolName then
			selectedItem = nil
			local held = heldTool()
			if held and held.Name == toolName then
				humanoid:UnequipTools()
			else
				local tool = backpackTools()[toolName]
				if tool then
					humanoid:EquipTool(tool)
				end
			end
		elseif contents.kind == "item" then
			humanoid:UnequipTools()
			selectedItem = if selectedItem == contents.id then nil else contents.id
		else
			-- An empty slot opens the Inventory to equip something.
			InventoryPanel.open()
		end
		Hotbar.refresh()
	end

	-- Builds one slot card.
	local function buildSlot(index: number, contents: Contents)
		local accent = EMPTY_GREY
		local item = contents.kind == "item" and ItemConfig.byId[contents.id] or nil
		if contents.kind == "tool" then
			accent = TOOL_COLORS[contents.name] or INVENTORY_ORANGE
		elseif item then
			accent = item.color
		end

		local button = new("TextButton", {
			Name = "Slot" .. index,
			LayoutOrder = index,
			Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = if contents.kind == "empty" then 0.2 else 0,
			Text = "",
			AutoButtonColor = false,
			Parent = bar,
		})
		new("UICorner", { CornerRadius = UDim.new(0.2, 0), Parent = button })
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(accent:Lerp(Window.PANEL_DARK, 0.6), Window.PANEL_DARK),
			Parent = button,
		})
		local stroke = new("UIStroke", {
			Name = "Outline",
			Color = accent,
			Thickness = 2.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = button,
		})
		local scale = new("UIScale", { Name = "Pop", Parent = button })

		-- The picture: the tool's icon, the item's picture, or a "+" for an empty slot.
		if contents.kind == "tool" then
			local tool = backpackTools()[contents.name]
			new("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.8, 0.8),
				BackgroundTransparency = 1,
				-- The tool can be missing for a moment (respawning, carrying a ghost), so the built-in
				-- items have their icons here too.
				Image = if tool and tool.TextureId ~= "" then tool.TextureId else TOOL_ICONS[contents.name] or "",
				Parent = button,
			})
		elseif item then
			local picture = Window.itemPicture(button, item, UDim2.fromScale(0.78, 0.78), UDim2.fromScale(0.11, 0.11))
			picture.BackgroundTransparency = 1
			local pictureStroke = picture:FindFirstChildOfClass("UIStroke")
			if pictureStroke then
				pictureStroke:Destroy()
			end
		else
			Window.text({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.5, 0.5),
				TextColor3 = Color3.fromRGB(170, 160, 190),
				Text = "+",
				Parent = button,
			}, 2)
		end

		-- The key number in the top-left corner, like the side menu's "M" badge.
		local badge = new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = accent,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextColor3 = Window.PANEL_DARK,
			Text = tostring(index),
			ZIndex = 3,
			Visible = UserInputService.KeyboardEnabled and index <= #NUMBER_KEYS,
			Parent = button,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
		new("UIStroke", {
			Color = Window.TEXT_OUTLINE,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = badge,
		})
		new("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3), Parent = badge })

		-- Cooldown: a dark shade that shrinks downward as the item gets ready, with the seconds left.
		local cooldown = new("Frame", {
			Name = "Cooldown",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			ZIndex = 2,
			Visible = false,
			Parent = button,
		})
		new("UICorner", { CornerRadius = UDim.new(0.2, 0), Parent = cooldown })
		local cooldownText = Window.text({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.7, 0.45),
			TextColor3 = WHITE,
			ZIndex = 2,
			Visible = false,
			Parent = button,
		}, 2)

		button.MouseEnter:Connect(function()
			TweenService:Create(scale, QUICK, { Scale = if scale:GetAttribute("Selected") then 1.12 else 1.06 }):Play()
		end)
		button.MouseLeave:Connect(function()
			TweenService:Create(scale, QUICK, { Scale = if scale:GetAttribute("Selected") then 1.1 else 1 }):Play()
		end)
		button.Activated:Connect(function()
			select(index)
		end)
		return button, stroke, scale, cooldown, cooldownText
	end

	type Built = {
		contents: Contents,
		stroke: UIStroke,
		scale: UIScale,
		cooldown: Frame,
		cooldownText: TextLabel,
	}
	local built: { Built } = {}

	-- The tool a slot uses, if any (a tool slot, or an item that's a tool).
	local function slotToolName(contents: Contents): string?
		if contents.kind == "tool" then
			return contents.name
		elseif contents.kind == "item" then
			return contents.id
		end
		return nil
	end
	local lastLayout = ""

	-- Rebuilds the slots when what's in them changes, and shows which one is selected.
	function Hotbar.refresh()
		local newSlots = layout()
		local key = {}
		for _, contents in newSlots do
			table.insert(key, contents.kind .. ":" .. ((contents :: any).name or (contents :: any).id or ""))
		end
		local layoutKey = table.concat(key, "|")
		if layoutKey ~= lastLayout then
			lastLayout = layoutKey
			slots = newSlots
			for _, child in bar:GetChildren() do
				if child:IsA("GuiButton") then
					child:Destroy()
				end
			end
			table.clear(built)
			for index, contents in slots do
				local _, stroke, scale, cooldown, cooldownText = buildSlot(index, contents)
				built[index] = {
					contents = contents,
					stroke = stroke,
					scale = scale,
					cooldown = cooldown,
					cooldownText = cooldownText,
				}
			end
			-- An unequipped item can't stay selected.
			if selectedItem and not table.find(equippedIds(), selectedItem) then
				selectedItem = nil
			end
		end

		-- Selected: bigger, with a thick white outline.
		local held = heldTool()
		for _, slot in built do
			local contents = slot.contents
			local toolName = slotToolName(contents)
			local selected = (held ~= nil and toolName ~= nil and held.Name == toolName)
				or (contents.kind == "item" and selectedItem == contents.id)
			if slot.scale:GetAttribute("Selected") ~= selected then
				slot.scale:SetAttribute("Selected", selected)
				TweenService:Create(slot.scale, QUICK, { Scale = if selected then 1.1 else 1 }):Play()
				TweenService:Create(slot.stroke, QUICK, { Thickness = if selected then 4 else 2.5 }):Play()
				slot.stroke:SetAttribute("BaseColor", slot.stroke:GetAttribute("BaseColor") or slot.stroke.Color)
				slot.stroke.Color = if selected then WHITE else slot.stroke:GetAttribute("BaseColor")
			end
		end
	end

	-- Cooldowns: any slot whose tool has a "ReadyAt" time (server clock) in the future.
	local COOLDOWN_LENGTHS = {
		Cage = GameConfig.CageCooldownSeconds,
		smoke_bomb = GameConfig.SmokeBombCooldownSeconds,
		gravity = GameConfig.GravityCooldownSeconds,
		universal_key = GameConfig.UniversalKeyCooldownSeconds,
		shield = GameConfig.ShieldCooldownSeconds,
		mega_mallet = GameConfig.MegaMalletCooldownSeconds,
		nuke = GameConfig.NukeCooldownSeconds,
	}
	task.spawn(function()
		while true do
			local tools = backpackTools()
			local now = workspace:GetServerTimeNow()
			for _, slot in built do
				local toolName = slotToolName(slot.contents)
				local tool = toolName and tools[toolName]
				local readyAt = tool and tool:GetAttribute("ReadyAt")
				local left = if readyAt then readyAt - now else 0
				local active = left > 0
				slot.cooldown.Visible = active
				slot.cooldownText.Visible = active
				if active then
					-- Items whose cooldown varies (the PolterPuller) put its length on the tool.
					local total = (tool :: Tool):GetAttribute("CooldownTotal")
						or COOLDOWN_LENGTHS[toolName :: string]
						or left
					slot.cooldown.Size = UDim2.fromScale(1, math.clamp(left / total, 0, 1))
					slot.cooldownText.Text = tostring(math.ceil(left))
				end
			end
			task.wait(0.1)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return -- typing in chat
		end
		local index = table.find(NUMBER_KEYS, input.KeyCode)
		if index then
			select(index)
		end
	end)

	-- Hide while carrying a ghost or caged (no items then).
	local function updateVisible()
		bar.Visible = not (player:GetAttribute("Carrying") or player:GetAttribute("Caged"))
		if not bar.Visible then
			selectedItem = nil
		end
	end
	player:GetAttributeChangedSignal("Carrying"):Connect(updateVisible)
	player:GetAttributeChangedSignal("Caged"):Connect(updateVisible)
	updateVisible()
	-- Going invisible puts your item away (the server does too); show that straight away.
	player:GetAttributeChangedSignal("Invisible"):Connect(function()
		selectedItem = nil
		Hotbar.refresh()
	end)

	-- Refresh when items are equipped or tools come and go (each spawn brings a new Backpack).
	player:GetAttributeChangedSignal("Equipped"):Connect(Hotbar.refresh)
	local function watch(container: Instance?)
		if container then
			container.ChildAdded:Connect(Hotbar.refresh)
			container.ChildRemoved:Connect(Hotbar.refresh)
		end
	end
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watch(child)
			Hotbar.refresh()
		end
	end)
	watch(player:FindFirstChildOfClass("Backpack"))
	player.CharacterAdded:Connect(function(character)
		selectedItem = nil
		watch(character)
		Hotbar.refresh()
	end)
	watch(player.Character)
	Hotbar.refresh()
end

return Hotbar
