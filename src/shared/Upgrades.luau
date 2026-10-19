-- Upgrade maths, shared by the server (UpgradeService, GhostService, LockService, EconomyService,
-- and everything that sets a player's walk speed) and the Upgrades window. Tuning numbers live
-- in GameConfig.
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
	{
		id = "speed",
		name = "Speed",
		costs = GameConfig.SpeedUpgradeCosts,
	},
	{
		id = "carry",
		name = "Carry Speed",
		costs = GameConfig.CarrySpeedUpgradeCosts,
	},
}
Upgrades.byId = {}
for _, kind in Upgrades.Kinds do
	Upgrades.byId[kind.id] = kind
end

-- A player's level of an upgrade, from their "Upgrade_<id>" attribute (works on both sides).
function Upgrades.level(player: Player, kindId: string): number
	return player:GetAttribute("Upgrade_" .. kindId) or 0
end

-- How many graves are open at this More Graves level.
function Upgrades.graves(level: number): number
	return GameConfig.StartingGraves + level
end

-- How long the base stays locked at this Longer Lock level, in seconds.
function Upgrades.lockSeconds(level: number): number
	return GameConfig.LockDurationSeconds + level * GameConfig.LockUpgradeSeconds
end

-- How much faster than normal at this Speed / Carry Speed level (0.2 = +20%).
function Upgrades.speedBonus(level: number): number
	return level * GameConfig.SpeedUpgradeBonus
end
function Upgrades.carryBonus(level: number): number
	return level * GameConfig.CarrySpeedUpgradeBonus
end

-- The player's normal walk speed and their speed while carrying a stolen ghost, with upgrades.
function Upgrades.walkSpeed(player: Player): number
	return GameConfig.WalkSpeed * (1 + Upgrades.speedBonus(Upgrades.level(player, "speed")))
end
function Upgrades.carrySpeed(player: Player): number
	return GameConfig.CarryWalkSpeed * (1 + Upgrades.carryBonus(Upgrades.level(player, "carry")))
end

-- What a level means, for the window ("7 graves", "75s lock", "+40% speed").
function Upgrades.describe(kindId: string, level: number): string
	if kindId == "graves" then
		return Upgrades.graves(level) .. " graves"
	elseif kindId == "speed" then
		return `+{math.round(Upgrades.speedBonus(level) * 100)}% speed`
	elseif kindId == "carry" then
		return `+{math.round(Upgrades.carryBonus(level) * 100)}% carry speed`
	end
	return Upgrades.lockSeconds(level) .. "s lock"
end

-- The price of the next level, or nil when maxed.
function Upgrades.nextCost(kindId: string, level: number): number?
	return Upgrades.byId[kindId].costs[level + 1]
end

return Upgrades
