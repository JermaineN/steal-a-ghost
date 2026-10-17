-- Offline earnings: when a player rejoins, their saved ghosts pay a share of their income (with
-- the rebirth boost and mutations, but not the friend boost) for the time since their last save
-- (Shared.Offline, GameConfig.Offline*). The cash is added straight away, and their device shows
-- a "Welcome back!" window (OfflineEarnings remote).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GhostConfig = require(ReplicatedStorage.Shared.Config.GhostConfig)
local Offline = require(ReplicatedStorage.Shared.Offline)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local GhostService = require(script.Parent.GhostService)

local OfflineService = {}

-- Called once the player's data has loaded.
function OfflineService.playerLoaded(player: Player)
	local lastSeen = DataService.getLastSeen(player)
	if lastSeen <= 0 then
		return -- a brand-new player
	end
	local secondsAway = os.time() - lastSeen

	-- What their saved ghosts earn per second.
	local rebirths = DataService.getRebirths(player)
	local income = 0
	for slotKey, ghostId in DataService.getGhosts(player) do
		local def = GhostConfig.byId[ghostId]
		if def then
			income += GhostService.ghostIncome(def, DataService.getMutation(player, tonumber(slotKey) or 0), rebirths)
		end
	end

	local earned = Offline.earnings(income, secondsAway)
	if earned > 0 then
		DataService.addCash(player, earned)
		Remotes.OfflineEarnings:FireClient(player, earned, secondsAway)
	end
end

return OfflineService
