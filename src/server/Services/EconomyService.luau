-- Income: every tick, each ghost in a base adds its earnings to the green collect pad in front of
-- its grave. The owner steps on a pad to move that money into their balance.
-- It also runs the broke safety net: someone left with no ghosts and not enough money for the
-- cheapest one is topped up to its price (see topUpIfBroke).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local GhostConfig = require(ReplicatedStorage.Shared.Config.GhostConfig)
local StoreConfig = require(ReplicatedStorage.Shared.Config.StoreConfig)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Notify = require(script.Parent.Parent.Util.Notify)
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
-- Whether each pad is currently drawn as a locked (not yet opened) grave.
local padLocked: { [BasePart]: boolean } = {}
local LOCKED_GREY = Color3.fromRGB(110, 105, 120)

-- The cheapest ghost's price: the broke safety net tops players up to this.
local CHEAPEST_GHOST_PRICE = math.huge
for _, ghost in GhostConfig.Ghosts do
	CHEAPEST_GHOST_PRICE = math.min(CHEAPEST_GHOST_PRICE, ghost.price)
end
-- When each player last got a top-up (os.clock), for GameConfig.BrokeTopUpCooldownSeconds.
local lastTopUp: { [Player]: number } = {}

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

-- The broke safety net. If the player has no ghosts at all (none in the base, flying in or
-- being carried off, so a ghost that's being stolen still counts until it's delivered), isn't
-- carrying one home themselves, and their cash plus their pads can't buy the cheapest ghost,
-- their cash is topped up to its price. Never more often than BrokeTopUpCooldownSeconds.
local function topUpIfBroke(player: Player, plot)
	if not plot or player:GetAttribute("Carrying") then
		return
	end
	local money = DataService.getCash(player)
	for slot = 1, #plot.slots do
		if GhostService.getEntry(player, slot) then
			return
		end
		money += DataService.getStored(player, slot)
	end
	if money >= CHEAPEST_GHOST_PRICE then
		return
	end
	local last = lastTopUp[player]
	if last and os.clock() - last < GameConfig.BrokeTopUpCooldownSeconds then
		return
	end
	lastTopUp[player] = os.clock()
	-- Only their cash is made up to the price; anything on their pads stays there to collect.
	local gift = CHEAPEST_GHOST_PRICE - DataService.getCash(player)
	DataService.addCash(player, gift)
	Notify.send(
		player,
		`The graveyard took pity on you: +${Format.cash(gift)}!`,
		"success",
		{ note = "Out of ghosts and cash", seconds = 6 }
	)
end

-- Every income tick: each ghost in a base (not being carried off) adds to its pad, boosted by
-- the owner's rebirths, their friends in the server, VIP, a money boost (Spin Wheel or Shop
-- booster) and the 2x Money pass. With the Auto Collect pass it goes straight to their cash.
local function incomeTick()
	for _, player in Players:GetPlayers() do
		if not DataService.isLoaded(player) then
			continue
		end
		local plot = PlotService.getPlot(player)
		local rebirths = DataService.getRebirths(player)
		-- Friends in the server add their bonus on top (FriendBoostService).
		-- VIP adds its bonus the same way.
		local vipBonus = if StoreConfig.ownsPass(player, "vip") then GameConfig.VipIncomeBonus else 0
		local friendBoost = 1 + (player:GetAttribute("FriendBoost") or 0) + vipBonus
		-- A money boost multiplies everything while it lasts (SpinService), and so does the pass.
		local spinBoost = if (player:GetAttribute("MoneyBoostUntil") or 0) > workspace:GetServerTimeNow()
			then GameConfig.SpinBoostMultiplier
			else 1
		local passBoost = if StoreConfig.ownsPass(player, "double_money") then GameConfig.PassMoneyMultiplier else 1
		local autoCollect = StoreConfig.ownsPass(player, "auto_collect")
		local income = 0
		for slot = 1, if plot then #plot.slots else 0 do
			local entry = GhostService.getEntry(player, slot)
			if entry and GhostService.isInBase(entry) then
				local baseIncome = GhostService.ghostIncome(GhostConfig.byId[entry.id], entry.mutation, rebirths)
				local slotIncome = math.floor(baseIncome * friendBoost * spinBoost * passBoost + 0.5)
				income += slotIncome
				DataService.addStored(player, slot, slotIncome * GameConfig.IncomeTickSeconds)
			end
			if autoCollect then
				DataService.collectStored(player, slot)
			end
		end
		player:SetAttribute("IncomePerSecond", income)
		topUpIfBroke(player, plot)
	end
end

-- How many of the owner's graves are open (More Graves upgrade).
local function openGraves(owner: Player): number
	return Upgrades.graves(DataService.getUpgrade(owner, "graves"))
end

-- Greys out a locked grave's pad (or brings back its green). Only changes it when it flips.
local function setPadLocked(pad: BasePart, locked: boolean)
	if padLocked[pad] == locked then
		return
	end
	padLocked[pad] = locked
	for _, surface in pad:GetChildren() do
		local glow = surface:IsA("SurfaceGui") and surface:FindFirstChild("Glow")
		if glow then
			(glow :: Frame).BackgroundColor3 = if locked then LOCKED_GREY else Theme.MoneyGreen
		end
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
				setPadLocked(pad, false)
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
			local hasGhost = GhostService.getEntry(owner, slot) ~= nil
			-- Graves the owner hasn't opened yet (More Graves upgrade) are greyed out.
			local locked = slot > openGraves(owner) and not hasGhost and stored <= 0
			setPadLocked(pad, locked)
			if locked then
				label.amount.Text = ""
				label.collect.Text = "LOCKED"
				label.collect.TextColor3 = LOCKED_GREY
				continue
			end
			label.collect.TextColor3 = Color3.new(1, 1, 1)
			-- Empty graves show nothing unless money is still waiting there (e.g. a ghost was sold).
			local showAmount = stored > 0 or hasGhost
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

	Players.PlayerRemoving:Connect(function(player)
		lastTopUp[player] = nil
	end)
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
