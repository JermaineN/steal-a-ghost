-- Loads and saves each player's cash and ghosts with DataStores.
-- In Studio, saving only works with Game Settings > Security > "Enable Studio Access to API Services".
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local GhostConfig = require(ReplicatedStorage.Shared.Config.GhostConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local Format = require(ReplicatedStorage.Shared.Format)
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

-- Items taken out of the Shop (ItemConfig), with what they cost. Anyone who still owns one is
-- refunded and it's removed from their save when they join.
local RETIRED_ITEMS = {
	item_1 = { price = 25, currency = "gems" },
	item_2 = { price = 75, currency = "gems" },
	item_3 = { price = 200, currency = "gems" },
	item_4 = { price = 5000, currency = "cash" },
	item_5 = { price = 50000, currency = "cash" },
	item_6 = { price = 500000, currency = "cash" },
}

-- Items whose id changed: old id = new id. Saves still holding the old id are moved over on join.
local RENAMED_ITEMS = {
	mythic_placeholder = "nuke", -- the Spin Wheel's Mythic prize, before it became the Nuke
}

-- Refunds and removes retired items, moves renamed ones to their new id, and drops any unknown
-- item from the hotbar.
local function clearRetiredItems(data): (number, number)
	for oldId, newId in RENAMED_ITEMS do
		local count = data.items[oldId]
		if count then
			data.items[newId] = (data.items[newId] or 0) + count
			data.items[oldId] = nil
		end
	end
	local gems, cash = 0, 0
	for itemId, count in data.items do
		local retired = RETIRED_ITEMS[itemId]
		if retired then
			if retired.currency == "gems" then
				gems += retired.price * count
			else
				cash += retired.price * count
			end
			data.items[itemId] = nil
		end
	end
	for index = #data.equipped, 1, -1 do
		if not ItemConfig.byId[data.equipped[index]] then
			table.remove(data.equipped, index)
		end
	end
	data.gems += gems
	data.cash += cash
	return gems, cash
end
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
		mutationsFound = {}, -- ["ghostId:mutationId"] = true for every ghost owned with that mutation
		mutationsClaimed = {}, -- ["ghostId:mutationId"] = true once its Index gem reward is claimed
		gems = 0,
		rebirths = 0, -- how many times they've rebirthed (each one boosts income, see Shared.Rebirth)
		items = {}, -- [itemId] = how many they own (bought in the Shop, see ItemConfig)
		equipped = {}, -- itemIds in the hotbar, in slot order (max GameConfig.MaxEquippedItems)
		titles = {}, -- [titleId] = true for titles earned in game (see TitleConfig)
		title = nil :: string?, -- the title shown above their head; "" = they chose none, nil = never chose
		daily = {}, -- daily reward: { day = the day they last claimed, streak = which streak day that was }
		spins = 0, -- unused Spin Wheel spins
		spinDay = 0, -- the day (Shared.DailyReward.today) they last got their free daily spin
		moneyBoostLeft = 0, -- seconds of Spin Wheel income boost left (only counts down while playing)
		boosts = {}, -- [boosterId] = seconds left of a Shop booster that's yours (StoreConfig; the money booster uses moneyBoostLeft)
		receipts = {}, -- ids of the latest Robux purchases already paid out (StoreService), so none is paid twice
		cosmetics = {}, -- [cosmeticId] = true for cosmetics bought with gems (CosmeticConfig; Robux ones come from game passes)
		worn = {}, -- the cosmetic worn of each kind: { aura = id, pet = id, tombstone = id, flowers = id }
		petGhost = GameConfig.GhostPetDefault, -- the ghost the Ghost Buddy pet looks like (picked in the Index, must be found)
		codes = {}, -- [CODE] = true for every code they have redeemed (side menu → Codes, Server.Config.CodeConfig)
		tutorialDone = false, -- finished (or skipped) the first-time tutorial
		steals = 0, -- ghosts successfully stolen (the Top Thieves leaderboard)
		stats = {}, -- milestone counters for titles: { ghostsBought = n, mutations = n, shinies = n }
		upgrades = {}, -- upgrade levels: { graves = n, lock = n, speed = n, carry = n } (see Shared.Upgrades); all but graves reset on rebirth
		lastSeen = 0, -- os.time() of the last save (offline earnings measure the time since)
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

-- Returns true if it saved.
local function save(player: Player, profile: Profile): boolean
	if not profile.canSave or not store then
		return false
	end
	activeSaves += 1
	profile.data.lastSeen = os.time() -- offline earnings count from the last save
	local ok, err = pcall(store.UpdateAsync, store, keyFor(player), function()
		return profile.data
	end)
	activeSaves -= 1
	if not ok then
		warn(`[DataService] Save failed for {player.Name}: {err}`)
	end
	return ok
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
-- Milestone stats (TitleConfig `milestone`): "steals", "found" (ghosts in the Index), and the
-- counters in data.stats. Shown to the player's device as "Stat_<name>" attributes, which
-- TitleService also watches to unlock milestone titles.
local function statValue(data, name: string): number
	if name == "steals" then
		return data.steals
	elseif name == "found" then
		local count = 0
		for ghostId in data.discovered do
			if GhostConfig.byId[ghostId] then
				count += 1
			end
		end
		return count
	end
	return data.stats[name] or 0
end

local function syncStat(player: Player, data, name: string)
	player:SetAttribute("Stat_" .. name, statValue(data, name))
end

function DataService.playerAdded(player: Player): boolean
	local data, canSave = loadData(player)
	if not player.Parent then
		return false
	end

	local refundGems, refundCash = clearRetiredItems(data)
	if refundGems > 0 or refundCash > 0 then
		local parts = {}
		if refundGems > 0 then
			table.insert(parts, refundGems .. " gems")
		end
		if refundCash > 0 then
			table.insert(parts, "$" .. Format.cash(refundCash))
		end
		Notify.send(
			player,
			"Old placeholder items were removed. Refunded " .. table.concat(parts, " and ") .. ".",
			"success"
		)
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
	-- Studio-only test gems (GameConfig.StudioTestGemsOn / StudioTestGems), never saved either.
	if RunService:IsStudio() and GameConfig.StudioTestGemsOn then
		data.gems = math.max(data.gems, GameConfig.StudioTestGems)
		canSave = false
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
	-- Mutation finds per ghost (the Index's ghost pages), as "IndexMut_<ghostId>_<mutationId>"
	-- and "IndexMutClaimed_<ghostId>_<mutationId>". Mutated ghosts already in the base count.
	for slotKey, mutationId in data.mutations do
		local ghostId = data.ghosts[slotKey]
		if ghostId then
			data.mutationsFound[ghostId .. ":" .. mutationId] = true
		end
	end
	for key in data.mutationsFound do
		player:SetAttribute("IndexMut_" .. string.gsub(key, ":", "_"), true)
	end
	for key in data.mutationsClaimed do
		player:SetAttribute("IndexMutClaimed_" .. string.gsub(key, ":", "_"), true)
	end
	-- Owned items are shown to the player's device as "Item_<itemId>" = count (the Inventory).
	for itemId, count in data.items do
		player:SetAttribute("Item_" .. itemId, count)
	end
	-- Equipped items (the hotbar), as "smoke_bomb,gravity" (attributes can't hold lists).
	player:SetAttribute("Equipped", table.concat(data.equipped, ","))
	player:SetAttribute("Spins", data.spins)
	-- Cosmetics bought with gems, as "Cosmetic_<id>" = true (CosmeticService adds Robux ones).
	for cosmeticId in data.cosmetics do
		player:SetAttribute("Cosmetic_" .. cosmeticId, true)
	end
	player:SetAttribute("PetGhost", data.petGhost)
	for _, name in { "steals", "found", "ghostsBought", "mutations", "shinies" } do
		syncStat(player, data, name)
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

-- Saves straight away (after a Robux purchase, so it can't be lost). Returns true if it saved.
function DataService.saveNow(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and save(player, profile)
end

-- Whether this session's progress will be saved (false if the load failed or Studio test money is on).
function DataService.canSave(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.canSave
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

-- How many of an item the player owns.
function DataService.getItemCount(player: Player, itemId: string): number
	local profile = profiles[player]
	return if profile then profile.data.items[itemId] or 0 else 0
end

-- The equipped items (hotbar), in slot order.
function DataService.getEquipped(player: Player): { string }
	local profile = profiles[player]
	return if profile then profile.data.equipped else {}
end

function DataService.setEquipped(player: Player, equipped: { string })
	local profile = profiles[player]
	if profile then
		profile.data.equipped = equipped
		player:SetAttribute("Equipped", table.concat(equipped, ","))
	end
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

-- Titles earned in game (special ones come from TitleConfig's allow-lists instead, TitleService).
function DataService.hasEarnedTitle(player: Player, titleId: string): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.data.titles[titleId] == true
end

function DataService.grantTitle(player: Player, titleId: string)
	local profile = profiles[player]
	if profile then
		profile.data.titles[titleId] = true
	end
end

-- The title shown above their head: an id, "" for none, or nil if they've never chosen.
function DataService.getTitle(player: Player): string?
	local profile = profiles[player]
	return if profile then profile.data.title else nil
end

function DataService.setTitle(player: Player, titleId: string)
	local profile = profiles[player]
	if profile then
		profile.data.title = titleId
	end
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

-- Spin Wheel: unused spins, mirrored to the player's device as the "Spins" attribute.
function DataService.getSpins(player: Player): number
	local profile = profiles[player]
	return if profile then profile.data.spins else 0
end

function DataService.addSpins(player: Player, amount: number)
	local profile = profiles[player]
	if profile then
		profile.data.spins = math.max(0, profile.data.spins + amount)
		player:SetAttribute("Spins", profile.data.spins)
	end
end

function DataService.getSpinDay(player: Player): number
	local profile = profiles[player]
	return if profile then profile.data.spinDay else 0
end

function DataService.setSpinDay(player: Player, day: number)
	local profile = profiles[player]
	if profile then
		profile.data.spinDay = day
	end
end

-- Seconds of Spin Wheel income boost left.
function DataService.getMoneyBoostLeft(player: Player): number
	local profile = profiles[player]
	return if profile then profile.data.moneyBoostLeft else 0
end

function DataService.setMoneyBoostLeft(player: Player, seconds: number)
	local profile = profiles[player]
	if profile then
		profile.data.moneyBoostLeft = math.max(0, seconds)
	end
end

-- Seconds left of one of the player's Shop boosters (StoreConfig.Boosters).
function DataService.getBoostLeft(player: Player, boosterId: string): number
	local profile = profiles[player]
	return if profile then profile.data.boosts[boosterId] or 0 else 0
end

function DataService.setBoostLeft(player: Player, boosterId: string, seconds: number)
	local profile = profiles[player]
	if profile then
		profile.data.boosts[boosterId] = if seconds > 0 then seconds else nil
	end
end

-- Cosmetics bought with gems (CosmeticConfig).
function DataService.addCosmetic(player: Player, cosmeticId: string)
	local profile = profiles[player]
	if profile then
		profile.data.cosmetics[cosmeticId] = true
		player:SetAttribute("Cosmetic_" .. cosmeticId, true)
	end
end

-- The cosmetic worn of each kind ({ aura = id, ... }).
function DataService.getWorn(player: Player): { [string]: string }
	local profile = profiles[player]
	return if profile then profile.data.worn else {}
end

function DataService.setWorn(player: Player, kind: string, cosmeticId: string?)
	local profile = profiles[player]
	if profile then
		profile.data.worn[kind] = cosmeticId
	end
end

-- The ghost the Ghost Buddy pet looks like (mirrored as the "PetGhost" attribute).
function DataService.getPetGhost(player: Player): string
	local profile = profiles[player]
	return if profile then profile.data.petGhost else GameConfig.GhostPetDefault
end

function DataService.setPetGhost(player: Player, ghostId: string)
	local profile = profiles[player]
	if profile then
		profile.data.petGhost = ghostId
		player:SetAttribute("PetGhost", ghostId)
	end
end

-- Has the player found this ghost (it's in their Index)?
function DataService.hasDiscovered(player: Player, ghostId: string): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.data.discovered[ghostId] == true
end

-- Robux purchases: has this one (MarketplaceService's PurchaseId) been paid out already?
local MAX_RECEIPTS = 50
function DataService.hasReceipt(player: Player, purchaseId: string): boolean
	local profile = profiles[player]
	return profile ~= nil and table.find(profile.data.receipts, purchaseId) ~= nil
end

function DataService.addReceipt(player: Player, purchaseId: string)
	local profile = profiles[player]
	if profile then
		table.insert(profile.data.receipts, purchaseId)
		if #profile.data.receipts > MAX_RECEIPTS then
			table.remove(profile.data.receipts, 1)
		end
	end
end

-- Codes (CodeService): has this player already redeemed this code (in capitals)?
function DataService.hasRedeemedCode(player: Player, code: string): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.data.codes[code] == true
end

function DataService.markCodeRedeemed(player: Player, code: string)
	local profile = profiles[player]
	if profile then
		profile.data.codes[code] = true
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

-- Can the player claim the Index reward for this ghost in this mutation?
function DataService.canClaimIndexMutation(player: Player, ghostId: string, mutationId: string): boolean
	local profile = profiles[player]
	local key = ghostId .. ":" .. mutationId
	return profile ~= nil and profile.data.mutationsFound[key] == true and not profile.data.mutationsClaimed[key]
end

function DataService.markIndexMutationClaimed(player: Player, ghostId: string, mutationId: string)
	local profile = profiles[player]
	if profile then
		profile.data.mutationsClaimed[ghostId .. ":" .. mutationId] = true
		player:SetAttribute("IndexMutClaimed_" .. ghostId .. "_" .. mutationId, true)
	end
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
			syncStat(player, profile.data, "found")
		end
		-- ...and this ghost's mutation, on its Index page.
		local key = ghostId and mutationId and ghostId .. ":" .. mutationId
		if key and not profile.data.mutationsFound[key] then
			profile.data.mutationsFound[key] = true
			player:SetAttribute("IndexMut_" .. ghostId .. "_" .. mutationId, true)
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

-- When the player's data was last saved (os.time()), or 0 for a brand-new player.
function DataService.getLastSeen(player: Player): number
	local profile = profiles[player]
	return if profile then profile.data.lastSeen or 0 else 0
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
		syncStat(player, profile.data, "steals")
	end
end

function DataService.getStat(player: Player, name: string): number
	local profile = profiles[player]
	return if profile then statValue(profile.data, name) else 0
end

-- A new ghost for this player (bought, out-bid, stolen or captured; not one loaded from their
-- save): counts toward the milestone titles. `bought` = paid for it on the walkway or in flight.
function DataService.recordGhost(player: Player, mutationId: string?, bought: boolean)
	local profile = profiles[player]
	if not profile then
		return
	end
	local stats = profile.data.stats
	local function add(name: string)
		stats[name] = (stats[name] or 0) + 1
		syncStat(player, profile.data, name)
	end
	if bought then
		add("ghostsBought")
	end
	if mutationId then
		add("mutations")
		if mutationId == "shiny" then
			add("shinies")
		end
	end
end

function DataService.getRebirths(player: Player): number
	local profile = profiles[player]
	return if profile then profile.data.rebirths else 0
end

-- The data side of a rebirth (RebirthService has already cleared the base): cash back to the
-- starting amount, uncollected pad cash gone, one more rebirth, and the gem reward.
function DataService.applyRebirth(player: Player, gems: number, startingCash: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.data.cash = startingCash
	profile.cashValue.Value = profile.data.cash
	profile.data.stored = {}
	profile.data.ghosts = {}
	profile.data.mutations = {}
	-- Upgrades start over too, except More Graves (UpgradeService gives the character its normal
	-- speed back).
	for kindId in profile.data.upgrades do
		if kindId ~= "graves" then
			profile.data.upgrades[kindId] = nil
			player:SetAttribute("Upgrade_" .. kindId, 0)
		end
	end
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
