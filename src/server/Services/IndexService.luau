-- Index rewards: each ghost a player has found gives a one-time gem reward (by rarity, see
-- GhostConfig.Rarities indexGems), claimed from its card in the Index, or all at once with
-- "Claim all". The client only asks (IndexClaim remote); the server checks every claim.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GhostConfig = require(ReplicatedStorage.Shared.Config.GhostConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notify = require(script.Parent.Parent.Util.Notify)
local DataService = require(script.Parent.DataService)

local IndexService = {}

-- Claims one ghost's reward. Returns the gems given (0 if it can't be claimed).
local function claim(player: Player, ghostId: string): number
	local def = GhostConfig.byId[ghostId]
	if not def or not DataService.canClaimIndex(player, ghostId) then
		return 0
	end
	local gems = GhostConfig.Rarities[def.rarity].indexGems
	DataService.markIndexClaimed(player, ghostId)
	DataService.addGems(player, gems)
	return gems
end

function IndexService.start()
	Remotes.IndexClaim.OnServerEvent:Connect(function(player: Player, which: unknown)
		if typeof(which) ~= "string" then
			return
		end
		local total = 0
		if which == "all" then
			for _, def in GhostConfig.Ghosts do
				total += claim(player, def.id)
			end
		else
			total = claim(player, which)
		end
		if total > 0 then
			Notify.send(player, "+" .. total .. " gems!", "success")
		end
	end)
end

return IndexService
