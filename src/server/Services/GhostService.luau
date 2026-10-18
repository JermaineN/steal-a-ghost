-- Ghost models, the walkway shop, and the ghosts sitting in each player's base.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local GhostConfig = require(ReplicatedStorage.Shared.Config.GhostConfig)
local MutationConfig = require(ReplicatedStorage.Shared.Config.MutationConfig)
local Format = require(ReplicatedStorage.Shared.Format)
local HauntedHour = require(ReplicatedStorage.Shared.HauntedHour)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local GhostLabel = require(script.Parent.Parent.Util.GhostLabel)
local Notify = require(script.Parent.Parent.Util.Notify)
local DataService = require(script.Parent.DataService)
local GhostModels = require(script.Parent.GhostModels)
local PlotService = require(script.Parent.PlotService)

local GhostService = {}

-- StealService sets this, so this module doesn't have to require it (that would be a require loop).
GhostService.onStealPromptTriggered = function(_thief: Player, _owner: Player, _slot: number) end
-- CaptureService (the PolterPuller 4000) sets this, for the same reason.
GhostService.onCapturePromptTriggered = function(_capturer: Player, _owner: Player, _slot: number) end

-- `carried`: a thief is running off with it. `arriving`: just bought, still flying to its grave.
-- `paid` and `buyCount` only matter while arriving: what the owner paid (refunded if someone
-- re-buys it), and how many times it has been re-bought so far (sets the next re-buy price).
-- `mutation`: its MutationConfig id, if it has one (it keeps it when bought, re-bought or stolen).
-- `capturing`: someone is sucking it up with a PolterPuller 4000 (CaptureService).
type Entry = {
	id: string,
	mutation: string?,
	model: Model,
	carried: boolean,
	arriving: boolean,
	capturing: boolean?,
	paid: number,
	buyCount: number,
}

-- A ghost that was just bought: where it was bought, what the buyer paid, and how many times it
-- has been re-bought in flight (0 for a first purchase from the walkway).
type Arrival = { from: CFrame, paid: number, buyCount: number }
local placed: { [Player]: { [number]: Entry } } = {}
-- A sale waiting for the owner to confirm it (rare ghosts only, see trySell).
local pendingSells: { [Player]: { slot: number, ghostId: string, expiresAt: number } } = {}
local walkwayFolder: Folder

-- Turns a model to face `destination` (turning flat, without tilting), then moves it there in a
-- straight line at `speed` studs per second and calls `onArrived`. A tweened CFrameValue drives
-- the model (a tween smoothly changes a value over time). Stops quietly if the model is
-- destroyed first.
local function flyTo(model: Model, destination: Vector3, speed: number, onArrived: () -> ())
	local start = model:GetPivot().Position
	local flat = Vector3.new(destination.X - start.X, 0, destination.Z - start.Z)
	local facing = if flat.Magnitude > 0.1 then CFrame.lookAt(Vector3.zero, flat) else model:GetPivot().Rotation
	model:PivotTo(CFrame.new(start) * facing)

	local mover = Instance.new("CFrameValue")
	mover.Value = model:GetPivot()
	mover.Changed:Connect(function(cframe)
		if model.Parent then
			model:PivotTo(cframe)
		end
	end)
	local info = TweenInfo.new(math.max((destination - start).Magnitude / speed, 0.05), Enum.EasingStyle.Linear)
	local tween = TweenService:Create(mover, info, { Value = CFrame.new(destination) * facing })
	tween.Completed:Connect(function(state)
		mover:Destroy()
		if state == Enum.PlaybackState.Completed and model.Parent then
			onArrived()
		end
	end)
	model.Destroying:Connect(function()
		tween:Cancel()
	end)
	tween:Play()
end

-- "Shiny Boo", or just "Boo" without a mutation.
function GhostService.displayName(def, mutationId: string?): string
	local mutation = mutationId and MutationConfig.byId[mutationId]
	return if mutation then mutation.name .. " " .. def.name else def.name
end

-- What a ghost earns per second for this owner: its income, times its mutation, boosted by the
-- owner's rebirths (rounded to whole dollars).
function GhostService.ghostIncome(def, mutationId: string?, rebirths: number): number
	return Rebirth.income(def.income * MutationConfig.multiplier(mutationId), rebirths)
end

-- `infoLines` are shown under the name: price and income on the walkway, income in a base.
local function buildModel(def, infoLines: { GhostLabel.InfoLine }, mutationId: string?): Model
	local rarity = GhostConfig.Rarities[def.rarity]
	local mutation = mutationId and MutationConfig.byId[mutationId]
	local model = Instance.new("Model")
	model.Name = GhostService.displayName(def, mutationId)
	model:SetAttribute("GhostId", def.id)
	model:SetAttribute("Mutation", mutationId)
	-- Stream the whole ghost in/out at once so client-side prompt setup always sees every part.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.one * def.size
	body.Color = def.color
	body.Material = Enum.Material.SmoothPlastic
	body.Transparency = 0.15
	body.Anchored = true
	body.CanCollide = false
	body.CastShadow = false
	body.CFrame = CFrame.new()
	body.Parent = model
	model.PrimaryPart = body

	local light = Instance.new("PointLight")
	light.Color = rarity.color
	light.Range = def.size * 3
	light.Brightness = 1.5
	light.Parent = body

	-- Ghosts with a detailed look (see GhostModels) add their own parts around the body and
	-- return the label height (or nil if their mesh is missing); the rest get two simple eyes.
	local customLook = GhostModels[def.id]
	local labelHeight = if customLook then customLook(model, body, def) else nil
	if not labelHeight then
		labelHeight = def.size / 2 + 1.8
		for _, side in { -1, 1 } do
			local eye = Instance.new("Part")
			eye.Name = "Eye"
			eye.Shape = Enum.PartType.Ball
			eye.Size = Vector3.one * def.size * 0.2
			eye.Color = Color3.new(0, 0, 0)
			eye.Anchored = true
			eye.CanCollide = false
			eye.CastShadow = false
			eye.CFrame = CFrame.new(side * def.size * 0.2, def.size * 0.12, -def.size * 0.42)
			eye.Parent = model
		end
	end

	GhostModels.addRarityAura(body, def.rarity, def.size)
	if mutation then
		GhostModels.addMutationAura(body, mutation, def.size)
	end
	GhostLabel.create(body, def, rarity, infoLines, labelHeight + 0.4, mutation)

	return model
end

local function makePrompt(parent: BasePart, name: string, actionText: string, objectText: string, hold: number)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

---------------------------------------------------------------------------
-- Walkway shop
---------------------------------------------------------------------------

-- Studio-only testing boost (GameConfig.StudioBoostSpawns): every ghost equally likely, and
-- they spawn twice as often. Live servers always use the normal rates.
local boostSpawns = RunService:IsStudio() and GameConfig.StudioBoostSpawns == true

-- How likely a ghost is to spawn. During Haunted Hour the rarest ghosts are boosted.
local function spawnWeight(def, haunted: boolean): number
	local luckyOrder = GhostConfig.Rarities[GameConfig.HauntedHourLuckMinRarity].order
	if haunted and GhostConfig.Rarities[def.rarity].order >= luckyOrder then
		return def.spawnWeight * GameConfig.HauntedHourLuck
	end
	return def.spawnWeight
end

local function pickRandomGhost()
	if boostSpawns then
		return GhostConfig.Ghosts[math.random(#GhostConfig.Ghosts)]
	end
	local haunted = HauntedHour.isActive()
	local total = 0
	for _, def in GhostConfig.Ghosts do
		total += spawnWeight(def, haunted)
	end
	local roll = math.random() * total
	for _, def in GhostConfig.Ghosts do
		roll -= spawnWeight(def, haunted)
		if roll <= 0 then
			return def
		end
	end
	return GhostConfig.Ghosts[1]
end

-- Studio-only testing boost (GameConfig.StudioBoostMutations): every walkway ghost gets a
-- random mutation. Live servers always use the normal chances.
local boostMutations = RunService:IsStudio() and GameConfig.StudioBoostMutations == true

-- Rolls a new walkway ghost's mutation: rarest first, and the first one that hits wins (so a
-- rarer mutation always takes precedence). Usually nil (no mutation).
local function rollMutation(): string?
	if boostMutations then
		return MutationConfig.Mutations[math.random(#MutationConfig.Mutations)].id
	end
	for _, mutation in MutationConfig.Mutations do
		if math.random() < 1 / mutation.chance then
			return mutation.id
		end
	end
	return nil
end

local function tryBuy(player: Player, def, model: Model, mutationId: string?)
	if model:GetAttribute("Sold") or not PlotService.getPlot(player) or not DataService.isLoaded(player) then
		return
	end
	local slot = GhostService.firstFreeSlot(player)
	if not slot then
		Notify.send(player, "Your base is full! Sell a ghost to make room.", "error")
		return
	end
	local name = GhostService.displayName(def, mutationId)
	if not DataService.spendCash(player, def.price) then
		Notify.send(player, "Not enough cash for " .. name .. ".", "error")
		return
	end
	model:SetAttribute("Sold", true)
	local boughtAt = model:GetPivot()
	model:Destroy()
	-- It's yours (and saved) right away, then flies from where you bought it to its grave.
	GhostService.placeGhost(player, slot, def.id, { from = boughtAt, paid = def.price, buyCount = 0 }, mutationId)
	Notify.send(player, "You bought " .. name .. "! It's flying to your base.", "success")
end

local function spawnWalkwayGhost(startCFrame: CFrame, endCFrame: CFrame)
	local def = pickRandomGhost()
	local mutationId = rollMutation()
	local mutation = mutationId and MutationConfig.byId[mutationId]
	local income = def.income * MutationConfig.multiplier(mutationId)
	local model = buildModel(def, {
		{ text = "$" .. Format.cash(def.price), color = Theme.MoneyGreen },
		{ text = "+$" .. Format.cash(income) .. "/s", color = Theme.PreviewIncomeYellow },
	}, mutationId)
	model:PivotTo(startCFrame)
	model.Parent = walkwayFolder

	-- Everyone gets a banner when a top-rarity ghost, or a ghost with a big mutation, appears
	-- (client RareSpawnBanner).
	if GameConfig.RareSpawnAnnouncements[def.rarity] or (mutation and mutation.announce) then
		Remotes.RareSpawn:FireAllClients(def.id, mutationId)
	end

	local buyText = GhostService.displayName(def, mutationId) .. " ($" .. Format.cash(def.price) .. ")"
	local prompt = makePrompt(model.PrimaryPart, "BuyPrompt", "Buy", buyText, 0.25)
	prompt.Triggered:Connect(function(player)
		tryBuy(player, def, model, mutationId)
	end)

	-- Float down the walkway, and vanish at the far end if nobody buys it.
	flyTo(model, endCFrame.Position, GameConfig.WalkwaySpeed, function()
		model:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Ghosts in bases
---------------------------------------------------------------------------

function GhostService.getEntry(owner: Player, slot: number): Entry?
	local ghosts = placed[owner]
	return ghosts and ghosts[slot]
end

function GhostService.firstFreeSlot(player: Player): number?
	local plot = PlotService.getPlot(player)
	if not plot then
		return nil
	end
	local ghosts = placed[player] or {}
	-- Only open graves count (More Graves upgrade, see UpgradeService).
	local open = math.min(#plot.slots, Upgrades.graves(DataService.getUpgrade(player, "graves")))
	for slot = 1, open do
		if not ghosts[slot] then
			return slot
		end
	end
	return nil
end

-- True when the ghost is sitting on its grave: not being carried off by a thief, not being
-- captured, and not still flying in after being bought. Only then does it earn, and only then
-- can it be stolen, captured or sold.
function GhostService.isInBase(entry: Entry): boolean
	return not entry.carried and not entry.arriving and not entry.capturing
end

-- Cash per second from every ghost sitting in the base.
function GhostService.getIncome(player: Player): number
	local total = 0
	for _, entry in placed[player] or {} do
		if GhostService.isInBase(entry) then
			total += GhostConfig.byId[entry.id].income * MutationConfig.multiplier(entry.mutation)
		end
	end
	return total
end

-- Where a newly bought ghost flies to: just in front of its base's gate. It flies straight
-- there over the open ground between the walkway and the bases, so it never crosses a fence,
-- and then appears on its grave (so it can't clip through the base's walls or tombstones).
local function arrivalPoint(plot): Vector3
	local inFront = plot.size / 2 + GameConfig.GhostArrivalSnapDistance
	return (plot.cframe * CFrame.new(0, 4, -inFront)).Position
end

-- What it costs to buy a ghost that has already been bought `buyCount` times in flight: the
-- original price plus RepurchaseMarkup of it for each one ($100 -> $150 -> $200 ...).
local function rebuyPrice(def, buyCount: number): number
	return math.floor(def.price * (1 + GameConfig.RepurchaseMarkup * buyCount))
end

-- `arrival`: the ghost was just bought (see Arrival). It flies from where it was bought to the
-- front of the base (see arrivalPoint), then appears on its grave; until then it can't earn, be
-- stolen or be sold, but anyone else can buy it out from under the owner (see tryRebuy).
-- Without `arrival` it appears on its grave straight away (loading a saved base, or a thief
-- delivering a stolen ghost). `mutationId` is the ghost's mutation, if it has one.
function GhostService.placeGhost(owner: Player, slot: number, ghostId: string, arrival: Arrival?, mutationId: string?)
	local plot = PlotService.getPlot(owner)
	local def = GhostConfig.byId[ghostId]
	if not plot or not def or not plot.slots[slot] then
		return
	end
	if mutationId and not MutationConfig.byId[mutationId] then
		mutationId = nil
	end
	local name = GhostService.displayName(def, mutationId)

	-- Its label shows what it earns for this owner (mutation and rebirths; rebirthing clears the
	-- base, so the boost can't change while it sits here).
	local income = GhostService.ghostIncome(def, mutationId, DataService.getRebirths(owner))
	local model =
		buildModel(def, { { text = "+$" .. Format.cash(income) .. "/s", color = Theme.MoneyGreen } }, mutationId)
	model:SetAttribute("OwnerUserId", owner.UserId)
	model:SetAttribute("GhostId", ghostId)
	model:SetAttribute("Carried", false)
	model:SetAttribute("Arriving", arrival ~= nil)
	model:PivotTo(if arrival then arrival.from else plot.slots[slot])

	-- Both prompts exist on every ghost; the client hides the one that doesn't apply to you.
	-- The server re-checks everything, so a hacked client can't sell someone else's ghost.
	local stealPrompt = makePrompt(model.PrimaryPart, "StealPrompt", "Steal", name, GameConfig.StealHoldSeconds)
	stealPrompt.Triggered:Connect(function(thief)
		GhostService.onStealPromptTriggered(thief, owner, slot)
	end)
	local sellPrice = math.floor(def.price * GameConfig.SellRefund)
	local sellPrompt = makePrompt(model.PrimaryPart, "SellPrompt", "Sell for $" .. Format.cash(sellPrice), name, 1)
	sellPrompt.Triggered:Connect(function(player)
		GhostService.trySell(player, owner, slot)
	end)
	-- Shown instead of Steal to someone holding a PolterPuller 4000 (client GhostPrompts). The
	-- capture itself takes time (CaptureService), so the prompt is instant.
	local capturePrompt = makePrompt(model.PrimaryPart, "CapturePrompt", "Capture", name, 0)
	capturePrompt.MaxActivationDistance = GameConfig.CaptureRange
	capturePrompt.Triggered:Connect(function(capturer)
		GhostService.onCapturePromptTriggered(capturer, owner, slot)
	end)

	local entry: Entry = {
		id = ghostId,
		mutation = mutationId,
		model = model,
		carried = false,
		arriving = arrival ~= nil,
		paid = if arrival then arrival.paid else 0,
		buyCount = if arrival then arrival.buyCount else 0,
	}

	-- While it flies, everyone else sees "Buy for $X" (the next re-buy price).
	local rebuyPrompt
	if arrival then
		local price = rebuyPrice(def, entry.buyCount + 1)
		rebuyPrompt = makePrompt(model.PrimaryPart, "RebuyPrompt", "Buy for $" .. Format.cash(price), name, 0.25)
		rebuyPrompt.Triggered:Connect(function(buyer)
			GhostService.tryRebuy(buyer, owner, slot, entry)
		end)
	end

	CollectionService:AddTag(model, "PlacedGhost")
	model.Parent = plot.ghostFolder

	placed[owner] = placed[owner] or {}
	placed[owner][slot] = entry
	DataService.setGhost(owner, slot, ghostId, mutationId)

	if arrival then
		flyTo(model, arrivalPoint(plot), GameConfig.GhostTravelSpeed, function()
			model:PivotTo(plot.slots[slot])
			entry.arriving = false
			model:SetAttribute("Arriving", false)
			rebuyPrompt:Destroy() -- it's home; from now on it can only be stolen
		end)
	end
end

-- `buyer` takes a ghost that's still flying to `owner`'s base, paying the next re-buy price.
-- The owner gets back what they paid, and the ghost turns and flies to the buyer's base instead.
-- `entry` is the flight the buyer saw, so a stale button (it already landed, or someone else
-- re-bought it first) does nothing.
function GhostService.tryRebuy(buyer: Player, owner: Player, slot: number, entry: Entry)
	if buyer == owner or GhostService.getEntry(owner, slot) ~= entry or not entry.arriving then
		return
	end
	if not PlotService.getPlot(buyer) or not DataService.isLoaded(buyer) then
		return
	end
	local def = GhostConfig.byId[entry.id]
	local name = GhostService.displayName(def, entry.mutation)
	local newSlot = GhostService.firstFreeSlot(buyer)
	if not newSlot then
		Notify.send(buyer, "Your base is full! Sell a ghost to make room.", "error")
		return
	end
	local buyCount = entry.buyCount + 1
	local price = rebuyPrice(def, buyCount)
	if not DataService.spendCash(buyer, price) then
		Notify.send(buyer, "Not enough cash for " .. name .. " ($" .. Format.cash(price) .. ").", "error")
		return
	end

	local from = entry.model:GetPivot()
	GhostService.removeGhost(owner, slot)
	DataService.addCash(owner, entry.paid)
	GhostService.placeGhost(
		buyer,
		newSlot,
		entry.id,
		{ from = from, paid = price, buyCount = buyCount },
		entry.mutation
	)

	local outbid = rebuyPrice(def, buyCount + 1)
	Notify.send(buyer, `You bought {name} for ${Format.cash(price)}! It's flying to your base.`, "success")
	Notify.send(
		owner,
		`{buyer.DisplayName} outbid you for {name}! You got ${Format.cash(entry.paid)} back. Buy it back for ${Format.cash(
			outbid
		)}.`,
		"error"
	)
end

function GhostService.removeGhost(owner: Player, slot: number)
	local entry = GhostService.getEntry(owner, slot)
	if not entry then
		return
	end
	entry.model:Destroy()
	placed[owner][slot] = nil
	DataService.setGhost(owner, slot, nil)
end

-- Sells a ghost. Ghosts of GameConfig.SellConfirmMinRarity or higher aren't sold straight away:
-- the owner first gets an "are you sure?" pop-up (SellConfirm remote, shown by SellConfirmPopup),
-- and only their answer (SellConfirmed remote) sells it, with `confirmed` true.
function GhostService.trySell(player: Player, owner: Player, slot: number, confirmed: boolean?)
	if player ~= owner then
		return
	end
	local entry = GhostService.getEntry(owner, slot)
	if not entry or not GhostService.isInBase(entry) then
		return
	end
	local def = GhostConfig.byId[entry.id]
	local refund = math.floor(def.price * GameConfig.SellRefund)
	local rarityOrder = GhostConfig.Rarities[def.rarity].order
	local needsConfirm = rarityOrder >= GhostConfig.Rarities[GameConfig.SellConfirmMinRarity].order
	if needsConfirm and not confirmed then
		pendingSells[owner] =
			{ slot = slot, ghostId = entry.id, expiresAt = os.clock() + GameConfig.SellConfirmSeconds }
		Remotes.SellConfirm:FireClient(owner, slot, entry.id, refund)
		return
	end
	pendingSells[owner] = nil
	local name = GhostService.displayName(def, entry.mutation)
	GhostService.removeGhost(owner, slot)
	DataService.addCash(owner, refund)
	Notify.send(owner, "Sold " .. name .. " for $" .. Format.cash(refund) .. ".", "success")
end

function GhostService.getSlotCFrame(owner: Player, slot: number): CFrame?
	local plot = PlotService.getPlot(owner)
	return plot and plot.slots[slot]
end

-- Puts the player's saved ghosts back into their base after their data loads.
function GhostService.loadGhosts(player: Player)
	for slotKey, ghostId in DataService.getGhosts(player) do
		local slot = tonumber(slotKey)
		if slot and GhostConfig.byId[ghostId] then
			GhostService.placeGhost(player, slot, ghostId, nil, DataService.getMutation(player, slot))
		end
	end
end

function GhostService.playerRemoving(player: Player)
	pendingSells[player] = nil
	for _, entry in placed[player] or {} do
		entry.model:Destroy()
	end
	placed[player] = nil
end

-- One clean copy of every ghost in ReplicatedStorage.GhostPreviews, for the Index window to
-- show (the meshes live in ServerStorage, which players' devices can't see). No label, light or
-- animation tag; each sits at the origin.
local function buildPreviews()
	local folder = Instance.new("Folder")
	folder.Name = "GhostPreviews"
	for _, def in GhostConfig.Ghosts do
		local model = buildModel(def, {})
		model.Name = def.id
		for _, item in model:GetDescendants() do
			if item:IsA("BillboardGui") or item:IsA("Light") then
				item:Destroy()
			end
		end
		CollectionService:RemoveTag(model, GhostModels.ANIMATED_TAG)
		model.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

function GhostService.start(map)
	buildPreviews()
	-- The owner confirmed a rare-ghost sale. Never trust the client: it only counts if it matches
	-- the sale we asked about, in time, and the same ghost is still in that slot.
	Remotes.SellConfirmed.OnServerEvent:Connect(function(player: Player, slot: unknown)
		local pending = pendingSells[player]
		pendingSells[player] = nil
		if not pending or slot ~= pending.slot or os.clock() > pending.expiresAt then
			return
		end
		local entry = GhostService.getEntry(player, pending.slot)
		if entry and entry.id == pending.ghostId then
			GhostService.trySell(player, player, pending.slot, true)
		end
	end)

	walkwayFolder = Instance.new("Folder")
	walkwayFolder.Name = "WalkwayGhosts"
	walkwayFolder.Parent = workspace

	local spawnInterval = GameConfig.WalkwaySpawnInterval
	if boostSpawns then
		spawnInterval /= 2
		print("[GhostService] Studio spawn boost is on: every ghost equally likely, spawning twice as often.")
	end
	task.spawn(function()
		while true do
			spawnWalkwayGhost(map.walkwayStart, map.walkwayEnd)
			-- Haunted Hour: ghosts spawn faster.
			task.wait(
				if HauntedHour.isActive() then spawnInterval / GameConfig.HauntedHourSpawnSpeed else spawnInterval
			)
		end
	end)
end

return GhostService
