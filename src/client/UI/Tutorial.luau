-- The first-time tutorial, for players the server marks with TutorialDone = false. Three steps,
-- each shown on a card at the bottom of the screen, with a glowing line from you to the thing to do
-- and a bouncing arrow above it:
--   1. Buy a ghost:  points at the nearest walkway ghost you can afford.
--   2. Collect:      points at your new ghost's green collect pad (at the ghost while it flies in).
--   3. Lock:         points at your base's lock button.
-- Finishing tells the server (TutorialComplete), which pays the reward. Everything here is drawn
-- only on this device.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GhostConfig = require(ReplicatedStorage.Shared.Config.GhostConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)

local Tutorial = {}

local PANEL_DARK = Color3.fromRGB(28, 16, 44)
local PUMPKIN = Color3.fromRGB(255, 140, 30)
local TEXT_OUTLINE = Color3.fromRGB(20, 8, 30)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.FredokaOne
local HOTBAR_CLEARANCE = 92 -- pixels from the bottom of the screen, clear of Roblox's hotbar

local STEPS = {
	{ title = "Buy a ghost from the walkway!", hint = "Walk up to one you can afford and press E" },
	{ title = "Collect your cash!", hint = "When your ghost lands, step on the green pad in front of it" },
	{ title = "Lock your base!", hint = "Step on the lock button to keep thieves out for a while" },
}

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

local function outlinedText(props: { [string]: any }, thickness: number): TextLabel
	props.BackgroundTransparency = 1
	props.Font = FONT
	props.TextScaled = true
	local label = new("TextLabel", props)
	new("UIStroke", { Color = TEXT_OUTLINE, Thickness = thickness, Parent = label })
	return label
end

local function myPlot(): Model?
	local index = player:GetAttribute("PlotIndex")
	local map = workspace:FindFirstChild("GeneratedMap")
	return if index and map then map:FindFirstChild("Plot" .. index) :: Model? else nil
end

-- Your ghosts (in your base, or flying to it).
local function myGhosts(): { Model }
	local plot = myPlot()
	local folder = plot and plot:FindFirstChild("Ghosts")
	local list = {}
	for _, model in if folder then folder:GetChildren() else {} do
		if model:IsA("Model") and model:GetAttribute("OwnerUserId") == player.UserId then
			table.insert(list, model)
		end
	end
	return list
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

local function cash(): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Cash")
	return if value then (value :: any).Value else 0
end

-- Step 1's target: the nearest walkway ghost you can afford (or the cheapest one if none).
local function walkwayTarget(): BasePart?
	local folder = workspace:FindFirstChild("WalkwayGhosts")
	local position = rootPosition()
	if not folder or not position then
		return nil
	end
	local best, bestDistance, cheapest, cheapestPrice = nil, math.huge, nil, math.huge
	for _, model in folder:GetChildren() do
		local def = GhostConfig.byId[model:GetAttribute("GhostId") or ""]
		local body = model:IsA("Model") and model.PrimaryPart
		if not def or not body or model:GetAttribute("Sold") then
			continue
		end
		local distance = (body.Position - position).Magnitude
		if def.price <= cash() and distance < bestDistance then
			best, bestDistance = body, distance
		end
		if def.price < cheapestPrice then
			cheapest, cheapestPrice = body, def.price
		end
	end
	return best or cheapest
end

-- Step 2's target: the collect pad in front of your newest ghost, or the ghost itself while it's
-- still flying in.
local function padTarget(): BasePart?
	local ghosts = myGhosts()
	local ghost = ghosts[#ghosts]
	local body = ghost and ghost.PrimaryPart
	if not body then
		return nil
	end
	if ghost:GetAttribute("Arriving") then
		return body
	end
	local plot = myPlot()
	local nearest, nearestDistance = nil, math.huge
	for _, part in if plot then plot:GetChildren() else {} do
		if part:IsA("BasePart") and string.match(part.Name, "^CollectPad") then
			local distance = (part.Position - body.Position).Magnitude
			if distance < nearestDistance then
				nearest, nearestDistance = part, distance
			end
		end
	end
	return nearest
end

-- Runs the whole tutorial, so it doesn't return until it's finished: start it with task.spawn.
function Tutorial.start()
	-- Wait for the server to say whether we need it (set once our data has loaded).
	if player:GetAttribute("TutorialDone") == nil then
		player:GetAttributeChangedSignal("TutorialDone"):Wait()
	end
	if player:GetAttribute("TutorialDone") then
		return
	end

	-- The step card.
	local gui = new("ScreenGui", {
		Name = "Tutorial",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 4,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local card = new("Frame", {
		Name = "Card",
		-- Bottom centre, just above Roblox's hotbar (the item slots), between the cash display
		-- and the corner buttons, so it never covers the walkway, the timer or the banners.
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -HOTBAR_CLEARANCE),
		Size = UDim2.fromOffset(420, 74),
		BackgroundColor3 = WHITE,
		Parent = gui,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 14), Parent = card })
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(PUMPKIN:Lerp(PANEL_DARK, 0.6), PANEL_DARK),
		Parent = card,
	})
	new("UIStroke", { Color = PUMPKIN, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
	local cardScale = new("UIScale", { Parent = card })
	local stepLabel = outlinedText({
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = PUMPKIN,
		Parent = card,
	}, 1.25)
	local titleLabel = outlinedText({
		Position = UDim2.fromOffset(14, 22),
		Size = UDim2.new(1, -28, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = WHITE,
		Parent = card,
	}, 2)
	local hintLabel = outlinedText({
		Position = UDim2.fromOffset(14, 51),
		Size = UDim2.new(1, -28, 0, 17),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(205, 190, 230),
		Parent = card,
	}, 1.25)

	-- The pointer: an invisible part that sits on the target, with a bouncing arrow above it,
	-- and a glowing line from your character to it.
	local marker = new("Part", {
		Name = "TutorialTarget",
		Size = Vector3.one,
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = workspace,
	})
	local targetAttachment = new("Attachment", { Parent = marker })
	local arrowGui = new("BillboardGui", {
		Size = UDim2.fromOffset(60, 60),
		StudsOffset = Vector3.new(0, 6, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Parent = marker,
	})
	local arrow = outlinedText({
		Size = UDim2.fromScale(1, 1),
		TextColor3 = PUMPKIN,
		Text = "▼",
		Parent = arrowGui,
	}, 3)
	TweenService:Create(
		arrow,
		TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.fromOffset(0, 14) }
	):Play()
	local beam = new("Beam", {
		Attachment1 = targetAttachment,
		Color = ColorSequence.new(PUMPKIN, Theme.PreviewIncomeYellow),
		LightEmission = 1,
		Transparency = NumberSequence.new(0.2, 0.5),
		Width0 = 0.7,
		Width1 = 0.7,
		FaceCamera = true,
		Segments = 1,
		Parent = marker,
	})
	-- The line starts at your character (again after every respawn).
	local function attachToCharacter(character: Model)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root then
			beam.Attachment0 = new("Attachment", { Name = "TutorialFrom", Parent = root })
		end
	end
	player.CharacterAdded:Connect(attachToCharacter)
	if player.Character then
		task.spawn(attachToCharacter, player.Character)
	end

	local step = 1
	local function showStep()
		local info = STEPS[step]
		stepLabel.Text = `TUTORIAL · STEP {step}/{#STEPS}`
		titleLabel.Text = info.title
		hintLabel.Text = info.hint
		cardScale.Scale = 1.15
		TweenService:Create(cardScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	showStep()

	-- Step 2 finishes the first time cash is collected.
	local collected = false
	Remotes.CashCollected.OnClientEvent:Connect(function()
		collected = true
	end)

	-- Each step's target and whether it's done.
	local function update(): boolean
		local target: BasePart? = nil
		if step == 1 then
			if #myGhosts() > 0 then
				return true
			end
			target = walkwayTarget()
		elseif step == 2 then
			if collected then
				return true
			end
			target = padTarget()
		else
			local plot = myPlot()
			local wall = plot and plot:FindFirstChild("LockWall") :: BasePart?
			if wall and wall.CanCollide then
				return true -- the base is locked
			end
			target = plot and plot:FindFirstChild("LockButton") :: BasePart?
		end
		arrowGui.Enabled = target ~= nil
		beam.Enabled = target ~= nil
		if target then
			marker.CFrame = target.CFrame
			-- Over a ghost the arrow goes above its name label; over a pad or button, just above it.
			local isGhost = target.Name == "Body"
			arrowGui.StudsOffset = Vector3.new(0, if isGhost then 12 else 4, 0)
		end
		return false
	end

	while step <= #STEPS do
		if update() then
			step += 1
			if step <= #STEPS then
				showStep()
			end
		end
		task.wait(0.1)
	end

	-- All done: tell the server (it pays the reward and shows the message), and tidy up.
	Remotes.TutorialComplete:FireServer()
	marker:Destroy()
	local from = player.Character and player.Character:FindFirstChild("TutorialFrom", true)
	if from then
		from:Destroy()
	end
	local away = TweenService:Create(cardScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Scale = 0,
	})
	away.Completed:Connect(function()
		gui:Destroy()
	end)
	away:Play()
end

return Tutorial
