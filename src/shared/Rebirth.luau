-- Rebirth maths, shared by the server (RebirthService, EconomyService) and the Rebirth panel,
-- so both always agree. Tuning numbers live in GameConfig.
local GameConfig = require(script.Parent.Config.GameConfig)

local Rebirth = {}

-- Cash needed to go from `rebirths` to `rebirths + 1`.
function Rebirth.cost(rebirths: number): number
	local costs = GameConfig.RebirthCosts
	if rebirths < #costs then
		return costs[rebirths + 1]
	end
	return costs[#costs] * GameConfig.RebirthCostGrowth ^ (rebirths + 1 - #costs)
end

-- Income multiplier with this many rebirths (0 rebirths = x1).
function Rebirth.multiplier(rebirths: number): number
	return 1 + rebirths * GameConfig.RebirthIncomeBonus
end

-- What a ghost earning `baseIncome` per second makes for someone with this many rebirths,
-- rounded to whole dollars (so the "+$X/s" on its label is exactly what it pays).
function Rebirth.income(baseIncome: number, rebirths: number): number
	return math.floor(baseIncome * Rebirth.multiplier(rebirths) + 0.5)
end

-- The cash a player restarts with after rebirthing from `rebirths` (RebirthStartingCashShare of
-- what that rebirth cost, and never less than StartingCash).
function Rebirth.startingCash(rebirths: number): number
	return math.max(GameConfig.StartingCash, math.floor(Rebirth.cost(rebirths) * GameConfig.RebirthStartingCashShare))
end

-- Gems given for reaching rebirth number `reached`.
function Rebirth.gems(reached: number): number
	return GameConfig.RebirthGems * reached
end

-- "x1.5", "x2", "x12.5"
function Rebirth.formatMultiplier(multiplier: number): string
	if multiplier == math.floor(multiplier) then
		return "x" .. multiplier
	end
	return "x" .. string.format("%.1f", multiplier)
end

return Rebirth
