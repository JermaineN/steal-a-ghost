-- Rebirth: once a player has enough cash (Shared.Rebirth.cost), they can trade in all their cash
-- and every ghost in their base for a permanent income boost and a gem reward. Gems, the Index
-- and their items stay. The Rebirth panel only asks (Rebirth remote); everything is checked here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notify = require(script.Parent.Parent.Util.Notify)
local DataService = require(script.Parent.DataService)
local GhostService = require(script.Parent.GhostService)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)

local RebirthService = {}

local function tryRebirth(player: Player)
	if not DataService.isLoaded(player) then
		return
	end
	local rebirths = DataService.getRebirths(player)
	local cost = Rebirth.cost(rebirths)
	if DataService.getCash(player) < cost then
		Notify.send(player, "You need $" .. Format.cash(cost) .. " to rebirth.", "error")
		return
	end
	-- A steal in progress (either way round) would be left holding a ghost that no longer exists.
	if player:GetAttribute("Carrying") then
		Notify.send(player, "Drop the ghost you're carrying before rebirthing!", "error")
		return
	end
	if StealService.isBeingRobbed(player) then
		Notify.send(player, "Someone is stealing from you! Stop them before rebirthing.", "error")
		return
	end

	-- Clear the base (ghosts on graves and ghosts still flying in), then reset the data.
	local plot = PlotService.getPlot(player)
	for slot = 1, if plot then #plot.slots else 0 do
		GhostService.removeGhost(player, slot)
	end
	local reached = rebirths + 1
	local gems = Rebirth.gems(reached)
	DataService.applyRebirth(player, gems)
	player:SetAttribute("IncomePerSecond", 0)

	-- Everyone's device plays the light pillar on this player; their own gets the big celebration.
	Remotes.Rebirthed:FireAllClients(player, reached)
end

function RebirthService.start()
	Remotes.Rebirth.OnServerEvent:Connect(tryRebirth)
end

return RebirthService
