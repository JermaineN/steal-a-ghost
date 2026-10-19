-- Network events between server and client.
-- The server creates them; clients wait for them to exist.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENT_NAMES = {
	"Notify", -- server -> client: show a message toast (message, kind, options: { note?, seconds? })
	"CashCollected", -- server -> the pad's owner only: they collected a collect pad (pad)
	"RareSpawn", -- server -> all clients: a Legendary or rarer ghost, or one with an announced mutation, spawned (ghostId, mutationId?)
	"BatSwing", -- server -> every client except the swinger: play this character's swing (character)
	"Ragdoll", -- server -> the hit player only: go floppy (true, knockback velocity) or get up (false)
	"Landmine", -- server -> the mine's owner only: draw ("placed", id, position) or remove ("removed", id)
	"LandmineExploded", -- server -> all clients: play the explosion (position, radius)
	"SellConfirm", -- server -> the owner only: ask "sell this rare ghost?" (slot, ghostId, refund)
	"SellConfirmed", -- client -> server: the owner said yes (slot)
	"IndexClaim", -- client -> server: claim the gem reward for a found ghost (ghostId, or "all" for every ghost and mutation reward)
	"IndexClaimMutation", -- client -> server: claim a ghost's mutation reward (ghostId, mutationId or "all" for that ghost's)
	"StealAlarm", -- server -> a ghost's owner only: someone is carrying one of your ghosts away (true) or not any more (false)
	"Rebirth", -- client -> server: rebirth now (no arguments; the server checks the cost)
	"Rebirthed", -- server -> all clients: a player rebirthed (player, rebirth number reached)
	"ShopBuy", -- client -> server: buy one of a Shop item (itemId); the server checks the price
	"BuyBooster", -- client -> server: buy a Shop booster with gems (boosterId from StoreConfig.Boosters)
	"DailyClaim", -- client -> server: claim today's daily reward (no arguments)
	"EquipItem", -- client -> server: put an owned item in the hotbar or take it out (itemId, equip: boolean)
	"MalletSwing", -- server -> all clients: a Mega Mallet swing (character, slamAt server time, origin CFrame) or a cancel (character, false)
	"EquipTitle", -- client -> server: show one of your titles above your head (titleId), or none ("")
	"TutorialComplete", -- client -> server: finished the first-time tutorial (no arguments)
	"OpenUpgrades", -- server -> a base's owner: they used their Upgrades signpost, open the window
	"BuyUpgrade", -- client -> server: buy the next level of a base upgrade (kindId: "graves" or "lock")
	"Spin", -- client -> server: use one Spin Wheel spin (no arguments; the server picks the prize)
	"SpinResult", -- server -> the spinner only: the wheel landed on this prize (index in GameConfig.SpinPrizes)
	"OfflineEarnings", -- server -> a rejoining player: their ghosts earned this while away (amount, secondsAway)
	"NukeLaunched", -- server -> all clients: a nuke is coming (launcher's display name, cutsceneAt, explodeAt server times, ground target Vector3)
}

local folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENT_NAMES do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for _, name in EVENT_NAMES do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
