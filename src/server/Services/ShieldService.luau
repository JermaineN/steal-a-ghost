-- The Shield (a Shop item, used from the hotbar): click for GameConfig.ShieldSeconds of
-- immunity to crowd control. While the "ShieldUntil" attribute (server time) is on you:
--   * bat hits and landmines can't knock you over (RagdollService.canKnock);
--   * cages can't catch you (CageService.trap, and the cage's target finding uses canKnock);
--   * Gravity wells don't pull or slow you (client GravityClient) or catch you (GravityService).
-- Three shields circle you so everyone can tell (client ShieldClient). It ends straight away if
-- you pick up a stolen ghost ("Carrying") or start a PolterPuller capture (CaptureService calls
-- ShieldService.stop), and when you die. The cooldown starts on use and survives respawning.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Notify = require(script.Parent.Parent.Util.Notify)
local DataService = require(script.Parent.DataService)
local RagdollService = require(script.Parent.RagdollService)

local ShieldService = {}

ShieldService.ITEM_ID = "shield"

-- When each player's shield can next be used, in server time.
local readyAt: { [Player]: number } = {}

-- True while the player is shielded (used by the services that would crowd-control them).
function ShieldService.isShielded(player: Player): boolean
	local untilTime = player:GetAttribute("ShieldUntil")
	return untilTime ~= nil and workspace:GetServerTimeNow() < untilTime
end

-- Ends the shield now (stealing a ghost, dying, time's up).
function ShieldService.stop(player: Player)
	player:SetAttribute("ShieldUntil", nil)
end

-- Called by ItemService when a player clicks while holding the shield.
function ShieldService.tryUse(player: Player, tool: Tool)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	if
		DataService.getItemCount(player, ShieldService.ITEM_ID) <= 0
		or player:GetAttribute("ShieldUntil")
		or player:GetAttribute("Invisible")
		or player:GetAttribute("Caged")
		or player:GetAttribute("Carrying")
		or RagdollService.isRagdolled(player)
	then
		return
	end
	local now = workspace:GetServerTimeNow()
	local waitLeft = (readyAt[player] or 0) - now
	if waitLeft > 0 then
		Notify.send(player, "Shield ready in " .. math.ceil(waitLeft) .. "s", "error")
		return
	end
	readyAt[player] = now + GameConfig.ShieldCooldownSeconds
	tool:SetAttribute("ReadyAt", readyAt[player]) -- the hotbar shows the cooldown from this

	local endsAt = now + GameConfig.ShieldSeconds
	player:SetAttribute("ShieldUntil", endsAt)

	-- Watch for the end: time's up, picked up a ghost, died or respawned.
	task.spawn(function()
		while player.Parent and player:GetAttribute("ShieldUntil") == endsAt do
			if
				workspace:GetServerTimeNow() >= endsAt
				or player:GetAttribute("Carrying")
				or player.Character ~= character
				or humanoid.Health <= 0
			then
				ShieldService.stop(player)
				break
			end
			task.wait(0.1)
		end
	end)
end

-- The shield's cooldown for a new copy of the tool (after respawning).
function ShieldService.readyAt(player: Player): number?
	return readyAt[player]
end

function ShieldService.start()
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
	end)
end

return ShieldService
