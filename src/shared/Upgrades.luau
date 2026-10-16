-- Base upgrade maths, shared by the server (UpgradeService, GhostService, LockService,
-- EconomyService) and the Upgrades window. Tuning numbers live in GameConfig.
local GameConfig = require(script.Parent.Config.GameConfig)

local Upgrades = {}

-- The upgrades, in the order the window shows them. `costs[n]` is the price of level n.
Upgrades.Kinds = {
	{
		id = "graves",
		name = "More Graves",
		costs = GameConfig.GraveUpgradeCosts,
	},
	{
		id = "lock",
		name = "Longer Lock",
		costs = GameConfig.LockUpgradeCosts,
	},
}
Upgrades.byId = {}
for _, kind in Upgrades.Kinds do
	Upgrades.byId[kind.id] = kind
end

-- How many graves are open at this More Graves level.
function Upgrades.graves(level: number): number
	return GameConfig.StartingGraves + level
end

-- How long the base stays locked at this Longer Lock level, in seconds.
function Upgrades.lockSeconds(level: number): number
	return GameConfig.LockDurationSeconds + level * GameConfig.LockUpgradeSeconds
end

-- What a level means, for the window ("7 graves", "75s lock").
function Upgrades.describe(kindId: string, level: number): string
	if kindId == "graves" then
		return Upgrades.graves(level) .. " graves"
	end
	return Upgrades.lockSeconds(level) .. "s lock"
end

-- The price of the next level, or nil when maxed.
function Upgrades.nextCost(kindId: string, level: number): number?
	return Upgrades.byId[kindId].costs[level + 1]
end

return Upgrades
