-- Passive income: every tick, each player earns cash from the ghosts in their base.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local DataService = require(script.Parent.DataService)
local GhostService = require(script.Parent.GhostService)

local EconomyService = {}

function EconomyService.start()
	task.spawn(function()
		while true do
			task.wait(GameConfig.IncomeTickSeconds)
			for _, player in Players:GetPlayers() do
				if DataService.isLoaded(player) then
					local income = GhostService.getIncome(player)
					player:SetAttribute("IncomePerSecond", income)
					if income > 0 then
						DataService.addCash(player, income * GameConfig.IncomeTickSeconds)
					end
				end
			end
		end
	end)
end

return EconomyService
