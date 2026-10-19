-- Index rewards: each ghost a player has found gives a one-time gem reward (by rarity, see
-- GhostConfig.Rarities indexGems), claimed from its card in the Index. Each ghost also has a
-- reward per mutation (MutationConfig indexGems) once you've owned it with that mutation, claimed
-- on the ghost's page in the Index. "Claim all" in the Index claims every reward of both kinds;
-- the ghost page's "Claim all" claims that ghost's mutation rewards. The client only asks
-- (IndexClaim / IndexClaimMutation remotes); the server checks every claim.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GhostConfig = require(ReplicatedStorage.Shared.Config.GhostConfig)
local MutationConfig = require(ReplicatedStorage.Shared.Config.MutationConfig)
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
	DataService.markIndexClaimed(player, ghostId)
	return DataService.earnGems(player, GhostConfig.Rarities[def.rarity].indexGems)
end

-- Claims one ghost's reward for one mutation. Returns the gems given (0 if it can't be claimed).
local function claimMutation(player: Player, ghostId: string, mutationId: string): number
	local mutation = MutationConfig.byId[mutationId]
	if
		not GhostConfig.byId[ghostId]
		or not mutation
		or not DataService.canClaimIndexMutation(player, ghostId, mutationId)
	then
		return 0
	end
	DataService.markIndexMutationClaimed(player, ghostId, mutationId)
	return DataService.earnGems(player, mutation.indexGems)
end

-- Claims all of one ghost's mutation rewards.
local function claimGhostMutations(player: Player, ghostId: string): number
	local total = 0
	for _, mutation in MutationConfig.Mutations do
		total += claimMutation(player, ghostId, mutation.id)
	end
	return total
end

local function announce(player: Player, total: number)
	if total > 0 then
		Notify.send(player, "+" .. total .. " gems!", "success")
	end
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
				total += claimGhostMutations(player, def.id)
			end
		else
			total = claim(player, which)
		end
		announce(player, total)
	end)
	Remotes.IndexClaimMutation.OnServerEvent:Connect(function(player: Player, ghostId: unknown, mutationId: unknown)
		if typeof(ghostId) ~= "string" or typeof(mutationId) ~= "string" then
			return
		end
		if mutationId == "all" then
			announce(player, claimGhostMutations(player, ghostId))
		else
			announce(player, claimMutation(player, ghostId, mutationId))
		end
	end)
end

return IndexService
