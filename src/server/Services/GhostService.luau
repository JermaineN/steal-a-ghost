-- Ghost models, the walkway shop, and the ghosts sitting in each player's base.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local GhostConfig = require(ReplicatedStorage.Shared.Config.GhostConfig)
local Format = require(ReplicatedStorage.Shared.Format)
local Billboard = require(script.Parent.Parent.Util.Billboard)
local Notify = require(script.Parent.Parent.Util.Notify)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local GhostService = {}

-- StealService sets this, so this module doesn't have to require it (that would be a require loop).
GhostService.onStealPromptTriggered = function(_thief: Player, _owner: Player, _slot: number) end

type Entry = { id: string, model: Model, carried: boolean }
local placed: { [Player]: { [number]: Entry } } = {}
local walkwayFolder: Folder

local function buildModel(def, infoText: string): Model
	local rarity = GhostConfig.Rarities[def.rarity]
	local model = Instance.new("Model")
	model.Name = def.name
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

	local light = Instance.new("PointLight")
	light.Color = rarity.color
	light.Range = def.size * 3
	light.Brightness = 1.5
	light.Parent = body

	Billboard.create(body, {
		size = UDim2.fromOffset(180, 66),
		offset = Vector3.new(0, def.size / 2 + 1.8, 0),
		maxDistance = 70,
		lines = {
			{ text = def.name },
			{ text = def.rarity, color = rarity.color },
			{ text = infoText, color = Color3.fromRGB(120, 255, 140) },
		},
	})

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

local function pickRandomGhost()
	local total = 0
	for _, def in GhostConfig.Ghosts do
		total += def.spawnWeight
	end
	local roll = math.random() * total
	for _, def in GhostConfig.Ghosts do
		roll -= def.spawnWeight
		if roll <= 0 then
			return def
		end
	end
	return GhostConfig.Ghosts[1]
end

local function tryBuy(player: Player, def, model: Model)
	if model:GetAttribute("Sold") or not PlotService.getPlot(player) or not DataService.isLoaded(player) then
		return
	end
	local slot = GhostService.firstFreeSlot(player)
	if not slot then
		Notify.send(player, "Your base is full! Sell a ghost to make room.", "error")
		return
	end
	if not DataService.spendCash(player, def.price) then
		Notify.send(player, "Not enough cash for " .. def.name .. ".", "error")
		return
	end
	model:SetAttribute("Sold", true)
	model:Destroy()
	GhostService.placeGhost(player, slot, def.id)
	Notify.send(player, "You bought " .. def.name .. "!", "success")
end

local function spawnWalkwayGhost(startCFrame: CFrame, endCFrame: CFrame)
	local def = pickRandomGhost()
	local model = buildModel(def, "$" .. Format.cash(def.price))
	model:PivotTo(startCFrame)
	model.Parent = walkwayFolder

	local buyText = def.name .. " ($" .. Format.cash(def.price) .. ")"
	local prompt = makePrompt(model.PrimaryPart, "BuyPrompt", "Buy", buyText, 0.25)
	prompt.Triggered:Connect(function(player)
		tryBuy(player, def, model)
	end)

	-- Tween a CFrameValue and move the model along with it.
	local mover = Instance.new("CFrameValue")
	mover.Value = startCFrame
	mover.Changed:Connect(function(cframe)
		if model.Parent then
			model:PivotTo(cframe)
		end
	end)
	local distance = (endCFrame.Position - startCFrame.Position).Magnitude
	local tweenInfo = TweenInfo.new(distance / GameConfig.WalkwaySpeed, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(mover, tweenInfo, { Value = endCFrame })
	tween.Completed:Connect(function()
		mover:Destroy()
		model:Destroy()
	end)
	model.Destroying:Connect(function()
		tween:Cancel()
	end)
	tween:Play()
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
	for slot = 1, #plot.slots do
		if not ghosts[slot] then
			return slot
		end
	end
	return nil
end

-- Cash per second from every ghost in the base (ghosts being carried off don't count).
function GhostService.getIncome(player: Player): number
	local total = 0
	for _, entry in placed[player] or {} do
		if not entry.carried then
			total += GhostConfig.byId[entry.id].income
		end
	end
	return total
end

function GhostService.placeGhost(owner: Player, slot: number, ghostId: string)
	local plot = PlotService.getPlot(owner)
	local def = GhostConfig.byId[ghostId]
	if not plot or not def or not plot.slots[slot] then
		return
	end

	local model = buildModel(def, "$" .. Format.cash(def.income) .. "/s")
	model:SetAttribute("OwnerUserId", owner.UserId)
	model:SetAttribute("GhostId", ghostId)
	model:SetAttribute("Carried", false)
	model:PivotTo(plot.slots[slot])

	-- Both prompts exist on every ghost; the client hides the one that doesn't apply to you.
	-- The server re-checks everything, so a hacked client can't sell someone else's ghost.
	local stealPrompt = makePrompt(model.PrimaryPart, "StealPrompt", "Steal", def.name, GameConfig.StealHoldSeconds)
	stealPrompt.Triggered:Connect(function(thief)
		GhostService.onStealPromptTriggered(thief, owner, slot)
	end)
	local sellPrice = math.floor(def.price * GameConfig.SellRefund)
	local sellPrompt = makePrompt(model.PrimaryPart, "SellPrompt", "Sell for $" .. Format.cash(sellPrice), def.name, 1)
	sellPrompt.Triggered:Connect(function(player)
		GhostService.trySell(player, owner, slot)
	end)

	CollectionService:AddTag(model, "PlacedGhost")
	model.Parent = plot.ghostFolder

	placed[owner] = placed[owner] or {}
	placed[owner][slot] = { id = ghostId, model = model, carried = false }
	DataService.setGhost(owner, slot, ghostId)
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

function GhostService.trySell(player: Player, owner: Player, slot: number)
	if player ~= owner then
		return
	end
	local entry = GhostService.getEntry(owner, slot)
	if not entry or entry.carried then
		return
	end
	local def = GhostConfig.byId[entry.id]
	local refund = math.floor(def.price * GameConfig.SellRefund)
	GhostService.removeGhost(owner, slot)
	DataService.addCash(owner, refund)
	Notify.send(owner, "Sold " .. def.name .. " for $" .. Format.cash(refund) .. ".", "success")
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
			GhostService.placeGhost(player, slot, ghostId)
		end
	end
end

function GhostService.playerRemoving(player: Player)
	for _, entry in placed[player] or {} do
		entry.model:Destroy()
	end
	placed[player] = nil
end

function GhostService.start(map)
	walkwayFolder = Instance.new("Folder")
	walkwayFolder.Name = "WalkwayGhosts"
	walkwayFolder.Parent = workspace

	task.spawn(function()
		while true do
			spawnWalkwayGhost(map.walkwayStart, map.walkwayEnd)
			task.wait(GameConfig.WalkwaySpawnInterval)
		end
	end)
end

return GhostService
