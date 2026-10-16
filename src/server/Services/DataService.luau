-- Loads and saves each player's cash and ghosts with DataStores.
-- In Studio, saving only works with Game Settings > Security > "Enable Studio Access to API Services".
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Notify = require(script.Parent.Parent.Util.Notify)

local DataService = {}

type Profile = {
	data: any,
	canSave: boolean,
	cashValue: NumberValue,
	gemsValue: IntValue,
	rebirthsValue: IntValue,
}
local profiles: { [Player]: Profile } = {}
local activeSaves = 0

local storeOk, store = pcall(DataStoreService.GetDataStore, DataStoreService, GameConfig.DataStoreName)
if not storeOk then
	warn("[DataService] DataStores unavailable, progress won't save:", store)
	store = nil
end

local function newData()
	return {
		cash = GameConfig.StartingCash,
		ghosts = {}, -- ["slotNumber"] = ghostId (string keys so DataStores accept it)
		mutations = {}, -- ["slotNumber"] = mutationId, for ghosts that have one (see MutationConfig)
		stored = {}, -- ["slotNumber"] = uncollected cash waiting on that slot's collect pad
		discovered = {}, -- [ghostId] = true for every ghost the player has owned (the Index)
		claimed = {}, -- [ghostId] = true once its Index gem reward has been claimed
		gems = 0,
		rebirths = 0, -- how many times they've rebirthed (each one boosts income, see Shared.Rebirth)
		items = {}, -- [itemId] = how many they own (bought in the Shop, see ItemConfig)
		daily = {}, -- daily reward: { day = the day they last claimed, streak = which streak day that was }
		tutorialDone = false, -- finished (or skipped) the first-time tutorial
		steals = 0, -- ghosts successfully stolen (the Top Thieves leaderboard)
		upgrades = {}, -- base upgrade levels: { graves = n, lock = n } (see Shared.Upgrades)
	}
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

-- Returns the data and whether it is safe to save it back.
-- If loading failed we must NOT save, or we'd overwrite the player's real progress.
local function loadData(player: Player)
	if not store then
		return newData(), false
	end
	for attempt = 1, 3 do
		local ok, result = pcall(store.GetAsync, store, keyFor(player))
		if ok then
			local data = result or newData()
			for key, default in newData() do
				if data[key] == nil then
					data[key] = default
				end
			end
			return data, true
		end
		warn(`[DataService] Load attempt {attempt} failed for {player.Name}: {result}`)
		if attempt < 3 then
			task.wait(2)
		end
	end
	return newData(), false
end

local function save(player: Player, profile: Profile)
	if not profile.canSave or not store then
		return
	end
	activeSaves += 1
	local ok, err = pcall(store.UpdateAsync, store, keyFor(player), function()
		return profile.data
	end)
	activeSaves -= 1
	if not ok then
		warn(`[DataService] Save failed for {player.Name}: {err}`)
	end
end

function DataService.start()
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutoSaveSeconds)
			for player, profile in profiles do
				task.spawn(save, player, profile)
			end
		end
	end)
end

-- Returns true once the player's data is loaded (false if they left while loading).
function DataService.playerAdded(player: Player): boolean
	local data, canSave = loadData(player)
	if not player.Parent then
		return false
	end

	-- Studio-only test money (GameConfig.StudioTestCashOn / StudioTestCash). A boosted profile is never saved,
	-- so test money can't leak into anyone's real save data. Live servers never run this.
	local testCash = if GameConfig.StudioTestCashOn then GameConfig.StudioTestCash else 0
	if RunService:IsStudio() and testCash and testCash > 0 then
		data.cash = math.max(data.cash, testCash)
		canSave = false
		Notify.send(player, "Studio test cash is on (progress won't be saved).", "info")
	elseif not canSave then
		Notify.send(player, "Progress won't be saved this session.", "error")
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cashValue = Instance.new("NumberValue")
	cashValue.Name = "Cash"
	cashValue.Value = data.cash
	cashValue.Parent = leaderstats
	local gemsValue = Instance.new("IntValue")
	gemsValue.Name = "Gems"
	gemsValue.Value = data.gems
	gemsValue.Parent = leaderstats
	local rebirthsValue = Instance.new("IntValue")
	rebirthsValue.Name = "Rebirths"
	rebirthsValue.Value = data.rebirths
	rebirthsValue.Parent = leaderstats
	leaderstats.Parent = player

	profiles[player] = {
		data = data,
		canSave = canSave,
		cashValue = cashValue,
		gemsValue = gemsValue,
		rebirthsValue = rebirthsValue,
	}

	-- The Index: ghosts already in their base count as found (saves from before the Index), and
	-- each found ghost is shown to the player's device as an "Index_<ghostId>" attribute.
	for _, ghostId in data.ghosts do
		data.discovered[ghostId] = true
	end
	for ghostId in data.discovered do
		player:SetAttribute("Index_" .. ghostId, true)
	end
	for ghostId in data.claimed do
		player:SetAttribute("IndexClaimed_" .. ghostId, true)
	end
	-- Owned items are shown to the player's device as "Item_<itemId>" = count (the Inventory).
	for itemId, count in data.items do
		player:SetAttribute("Item_" .. itemId, count)
	end
	return true
end

function DataService.playerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profiles[player] = nil
	save(player, profile)
end

-- Called when the server shuts down: save everyone and wait for saves to finish.
function DataService.saveAll()
	for player, profile in profiles do
		task.spawn(save, player, profile)
	end
	task.wait()
	while activeSaves > 0 do
		task.wait()
	end
end

function DataService.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService.addCash(player: Player, amount: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.data.cash += amount
	profile.cashValue.Value = profile.data.cash
end

-- Returns true if the player could afford it (and the cash was taken).
function DataService.spendCash(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or profile.data.cash < amount then
		return false
	end
	DataService.addCash(player, -amount)
	return true
end

function DataService.addGems(player: Player, amount: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.data.gems += amount
	profile.gemsValue.Value = profile.data.gems
end

-- Returns true if the player could afford it (and the gems were taken).
function DataService.spendGems(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or profile.data.gems < amount then
		return false
	end
	DataService.addGems(player, -amount)
	return true
end

function DataService.addItem(player: Player, itemId: string, count: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	local owned = (profile.data.items[itemId] or 0) + count
	profile.data.items[itemId] = if owned > 0 then owned else nil
	player:SetAttribute("Item_" .. itemId, if owned > 0 then owned else nil)
end

-- The daily reward record: { day = last claim day, streak = streak day claimed then }, or nil.
function DataService.getDaily(player: Player): { day: number?, streak: number? }?
	local profile = profiles[player]
	return if profile then profile.data.daily else nil
end

function DataService.setDaily(player: Player, day: number, streak: number)
	local profile = profiles[player]
	if profile then
		profile.data.daily = { day = day, streak = streak }
	end
end

-- The first-time tutorial. Players who already have progress (from before the tutorial
-- existed) count as done. Only meaningful when they join (buying a ghost is progress too).
function DataService.isTutorialDone(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return true
	end
	local data = profile.data
	return data.tutorialDone or next(data.ghosts) ~= nil or data.rebirths > 0 or next(data.discovered) ~= nil
end

function DataService.setTutorialDone(player: Player)
	local profile = profiles[player]
	if profile then
		profile.data.tutorialDone = true
	end
end

-- Can the player claim the Index reward for this ghost? (Found it, and hasn't claimed it yet.)
function DataService.canClaimIndex(player: Player, ghostId: string): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.data.discovered[ghostId] == true and not profile.data.claimed[ghostId]
end

function DataService.markIndexClaimed(player: Player, ghostId: string)
	local profile = profiles[player]
	if profile then
		profile.data.claimed[ghostId] = true
		player:SetAttribute("IndexClaimed_" .. ghostId, true)
	end
end

function DataService.setGhost(player: Player, slot: number, ghostId: string?, mutationId: string?)
	local profile = profiles[player]
	if profile then
		profile.data.ghosts[tostring(slot)] = ghostId
		profile.data.mutations[tostring(slot)] = if ghostId then mutationId else nil
		-- Every way of getting a ghost (buying, out-bidding, stealing) ends up here, so this is
		-- where the Index learns about it.
		if ghostId and not profile.data.discovered[ghostId] then
			profile.data.discovered[ghostId] = true
			player:SetAttribute("Index_" .. ghostId, true)
		end
	end
end

-- Uncollected cash on a slot's collect pad.
function DataService.getStored(player: Player, slot: number): number
	local profile = profiles[player]
	return if profile then profile.data.stored[tostring(slot)] or 0 else 0
end

function DataService.addStored(player: Player, slot: number, amount: number)
	local profile = profiles[player]
	if profile then
		local key = tostring(slot)
		profile.data.stored[key] = (profile.data.stored[key] or 0) + amount
	end
end

-- Moves a slot's stored cash into the player's balance. Returns how much was collected.
function DataService.collectStored(player: Player, slot: number): number
	local profile = profiles[player]
	local amount = DataService.getStored(player, slot)
	if not profile or amount <= 0 then
		return 0
	end
	profile.data.stored[tostring(slot)] = nil
	DataService.addCash(player, amount)
	return amount
end

function DataService.getCash(player: Player): number
	local profile = profiles[player]
	return if profile then profile.data.cash else 0
end

-- A base upgrade's level (0 = not upgraded).
function DataService.getUpgrade(player: Player, kindId: string): number
	local profile = profiles[player]
	return if profile then profile.data.upgrades[kindId] or 0 else 0
end

function DataService.setUpgrade(player: Player, kindId: string, level: number)
	local profile = profiles[player]
	if profile then
		profile.data.upgrades[kindId] = level
		player:SetAttribute("Upgrade_" .. kindId, level)
	end
end

function DataService.getSteals(player: Player): number
	local profile = profiles[player]
	return if profile then profile.data.steals else 0
end

function DataService.addSteal(player: Player)
	local profile = profiles[player]
	if profile then
		profile.data.steals += 1
	end
end

function DataService.getRebirths(player: Player): number
	local profile = profiles[player]
	return if profile then profile.data.rebirths else 0
end

-- The data side of a rebirth (RebirthService has already cleared the base): cash back to the
-- starting amount, uncollected pad cash gone, one more rebirth, and the gem reward.
function DataService.applyRebirth(player: Player, gems: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.data.cash = GameConfig.StartingCash
	profile.cashValue.Value = profile.data.cash
	profile.data.stored = {}
	profile.data.ghosts = {}
	profile.data.mutations = {}
	profile.data.rebirths += 1
	profile.rebirthsValue.Value = profile.data.rebirths
	DataService.addGems(player, gems)
end

-- The mutation of the ghost saved in a slot, or nil.
function DataService.getMutation(player: Player, slot: number): string?
	local profile = profiles[player]
	return if profile then profile.data.mutations[tostring(slot)] else nil
end

function DataService.getGhosts(player: Player): { [string]: string }
	local profile = profiles[player]
	return if profile then profile.data.ghosts else {}
end

return DataService
