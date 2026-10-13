-- Loads and saves each player's cash and ghosts with DataStores.
-- In Studio, saving only works with Game Settings > Security > "Enable Studio Access to API Services".
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Notify = require(script.Parent.Parent.Util.Notify)

local DataService = {}

type Profile = { data: any, canSave: boolean, cashValue: NumberValue }
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

	-- Studio-only test money (GameConfig.StudioTestCash). A boosted profile is never saved,
	-- so test money can't leak into anyone's real save data. Live servers never run this.
	local testCash = GameConfig.StudioTestCash
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
	leaderstats.Parent = player

	profiles[player] = { data = data, canSave = canSave, cashValue = cashValue }
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

function DataService.setGhost(player: Player, slot: number, ghostId: string?)
	local profile = profiles[player]
	if profile then
		profile.data.ghosts[tostring(slot)] = ghostId
	end
end

function DataService.getGhosts(player: Player): { [string]: string }
	local profile = profiles[player]
	return if profile then profile.data.ghosts else {}
end

return DataService
