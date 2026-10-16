-- Income: every tick, each ghost in a base adds its earnings to the green collect pad in front of
-- its grave. The owner steps on a pad to move that money into their balance.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local GhostConfig = require(ReplicatedStorage.Shared.Config.GhostConfig)
local Format = require(ReplicatedStorage.Shared.Format)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local DataService = require(script.Parent.DataService)
local GhostService = require(script.Parent.GhostService)
local PlotService = require(script.Parent.PlotService)

local EconomyService = {}

-- padLabels[plot][slot] is the floating text above that slot's collect pad: the "$X" amount,
-- and a "COLLECT" line above it that only shows while there's money to pick up.
type PadLabel = { amount: TextLabel, collect: TextLabel }
local padLabels: { [any]: { PadLabel } } = {}
-- Whether the owner was standing on each pad last update (to spot the step onto it).
local ownerWasOn: { [BasePart]: boolean } = {}

-- Text with a thick black outline.
local function outlinedText(gui: BillboardGui, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = ""
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 2.5
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return label
end

-- Floating "COLLECT" and green "$X" above a collect pad.
local function makePadLabel(pad: BasePart): PadLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "StoredCash"
	gui.Size = UDim2.fromOffset(120, 56)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	gui.Adornee = pad

	local collect = outlinedText(gui, {
		Name = "Collect",
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = Color3.new(1, 1, 1),
	})
	local amount = outlinedText(gui, {
		Name = "Amount",
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 32),
		TextColor3 = Theme.MoneyGreen,
	})

	gui.Parent = pad
	return { amount = amount, collect = collect }
end

-- True if the player is alive and standing on (or right above) the pad.
local function isStandingOn(player: Player, pad: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local offset = pad.CFrame:PointToObjectSpace(root.Position)
	local margin = GameConfig.CollectPadMargin
	return math.abs(offset.X) <= pad.Size.X / 2 + margin
		and math.abs(offset.Z) <= pad.Size.Z / 2 + margin
		and offset.Y > 0
		and offset.Y < 6
end

-- Every income tick: each ghost in a base (not being carried off) adds to its pad, boosted by
-- the owner's rebirths and their friends in the server.
local function incomeTick()
	for _, player in Players:GetPlayers() do
		if not DataService.isLoaded(player) then
			continue
		end
		local plot = PlotService.getPlot(player)
		local rebirths = DataService.getRebirths(player)
		-- Friends in the server add their bonus on top (FriendBoostService).
		local friendBoost = 1 + (player:GetAttribute("FriendBoost") or 0)
		local income = 0
		for slot = 1, if plot then #plot.slots else 0 do
			local entry = GhostService.getEntry(player, slot)
			if entry and GhostService.isInBase(entry) then
				local baseIncome = Rebirth.income(GhostConfig.byId[entry.id].income, rebirths)
				local slotIncome = math.floor(baseIncome * friendBoost + 0.5)
				income += slotIncome
				DataService.addStored(player, slot, slotIncome * GameConfig.IncomeTickSeconds)
			end
		end
		player:SetAttribute("IncomePerSecond", income)
	end
end

-- Collects pads the owner is standing on and refreshes every pad's "$X" text.
local function updatePads(plots)
	for _, plot in plots do
		local owner = plot.owner
		local loaded = owner and DataService.isLoaded(owner)
		for slot, pad in plot.collectPads do
			local label = padLabels[plot][slot]
			if not loaded then
				label.amount.Text = ""
				label.collect.Text = ""
				continue
			end
			-- Only the owner is checked, so nobody else can collect this pad. The owner's device
			-- shows the collect (CollectEffect): a flash every time, plus the cha-ching and cash
			-- burst on the step onto the pad, so they don't repeat every second while standing.
			-- Other players get nothing.
			local onPad = isStandingOn(owner, pad)
			local justStepped = onPad and not ownerWasOn[pad]
			ownerWasOn[pad] = onPad
			if onPad and DataService.collectStored(owner, slot) > 0 then
				Remotes.CashCollected:FireClient(owner, pad, justStepped)
			end
			local stored = DataService.getStored(owner, slot)
			-- Empty graves show nothing unless money is still waiting there (e.g. a ghost was sold).
			local showAmount = stored > 0 or GhostService.getEntry(owner, slot) ~= nil
			label.amount.Text = if showAmount then "$" .. Format.cash(stored) else ""
			label.collect.Text = if stored > 0 then "COLLECT" else ""
		end
	end
end

function EconomyService.start(plots)
	for _, plot in plots do
		padLabels[plot] = {}
		for slot, pad in plot.collectPads do
			padLabels[plot][slot] = makePadLabel(pad)
		end
	end

	task.spawn(function()
		while true do
			task.wait(GameConfig.IncomeTickSeconds)
			incomeTick()
		end
	end)
	task.spawn(function()
		while true do
			updatePads(plots)
			task.wait(0.2)
		end
	end)
end

return EconomyService
