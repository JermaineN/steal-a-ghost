-- Upgrades: More Graves (how many of the base's graves are open), Longer Lock (how long the
-- base stays locked), Speed (walk speed) and Carry Speed (walk speed while carrying a stolen
-- ghost). Bought with cash in the Upgrades window, which opens from the Upgrades signpost at
-- your base's entrance. Levels are saved; all but More Graves reset to 0 on rebirth (DataService.applyRebirth);
-- the maths is in Shared.Upgrades. The player's device sees each level as an "Upgrade_<id>"
-- attribute.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Notify = require(script.Parent.Parent.Util.Notify)
local DataService = require(script.Parent.DataService)

local UpgradeService = {}

-- Gives the character its upgraded speed straight away (after a purchase or a rebirth reset).
-- Skipped while something else is controlling their speed (a cage or their own Gravity well);
-- those hand back Upgrades.walkSpeed themselves when they end.
local function applySpeed(player: Player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or player:GetAttribute("Caged") or player:GetAttribute("GravityUntil") then
		return
	end
	humanoid.WalkSpeed = if player:GetAttribute("Carrying")
		then Upgrades.carrySpeed(player)
		else Upgrades.walkSpeed(player)
end

-- Called once the player's data has loaded (before their ghosts are placed). Players who already
-- use more graves than they'd start with (saves from before upgrades existed) get enough grave
-- upgrades for free, so nobody loses a ghost.
function UpgradeService.playerLoaded(player: Player)
	local highestSlot = 0
	for slotKey in DataService.getGhosts(player) do
		highestSlot = math.max(highestSlot, tonumber(slotKey) or 0)
	end
	local needed = math.clamp(highestSlot - GameConfig.StartingGraves, 0, #GameConfig.GraveUpgradeCosts)
	for _, kind in Upgrades.Kinds do
		local level = DataService.getUpgrade(player, kind.id)
		if kind.id == "graves" then
			level = math.max(level, needed)
		end
		DataService.setUpgrade(player, kind.id, level)
	end
	applySpeed(player)
	player:GetAttributeChangedSignal("Upgrade_speed"):Connect(function()
		applySpeed(player)
	end)
	player:GetAttributeChangedSignal("Upgrade_carry"):Connect(function()
		applySpeed(player)
	end)
	-- The Shop's Speed Boost starting or ending (StoreService).
	player:GetAttributeChangedSignal("SpeedBoostUntil"):Connect(function()
		applySpeed(player)
	end)
end

local function buy(player: Player, kindId: unknown)
	local kind = typeof(kindId) == "string" and Upgrades.byId[kindId]
	if not kind or not DataService.isLoaded(player) then
		return
	end
	local level = DataService.getUpgrade(player, kind.id)
	local cost = Upgrades.nextCost(kind.id, level)
	if not cost then
		return -- already maxed
	end
	if not DataService.spendCash(player, cost) then
		Notify.send(player, `You need ${Format.cash(cost)} for that upgrade.`, "error")
		return
	end
	DataService.setUpgrade(player, kind.id, level + 1)
	Notify.send(player, `{kind.name} upgraded: {Upgrades.describe(kind.id, level + 1)}!`, "success")
end

function UpgradeService.start(plots)
	Remotes.BuyUpgrade.OnServerEvent:Connect(buy)
	-- Each base's Upgrades signpost opens the window, for that base's owner only.
	for _, plot in plots do
		plot.upgradePrompt.Triggered:Connect(function(player)
			if plot.owner == player then
				Remotes.OpenUpgrades:FireClient(player)
			else
				Notify.send(player, "You can only upgrade your own base.", "error")
			end
		end)
	end
end

return UpgradeService
