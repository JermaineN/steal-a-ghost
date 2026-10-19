-- Redeemable codes: the Codes window (client UI/CodesPanel) sends the typed text with the
-- RedeemCode remote; this checks it against Server.Config.CodeConfig, pays the reward once per
-- player (redeemed codes are saved by DataService as `codes`) and answers with CodeResult.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CodeConfig = require(script.Parent.Parent.Config.CodeConfig)
local Format = require(ReplicatedStorage.Shared.Format)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local CodeService = {}

local codes = {} -- [CODE] = its CodeConfig row
local lastTry: { [Player]: number } = {}

-- "  spooky " → "SPOOKY"
local function normalize(text: string): string
	return string.upper(string.match(text, "^%s*(.-)%s*$") or "")
end

-- A row's "YYYY-MM-DD" expiry as a time: the very end of that day (UTC). nil = never expires.
local function expiryTime(row): number?
	if not row.expires then
		return nil
	end
	local year, month, day = string.match(row.expires, "^(%d+)-(%d+)-(%d+)$")
	if not year then
		warn(`[CodeService] Code {row.code} has a bad expires date "{row.expires}" (use "YYYY-MM-DD")`)
		return 0 -- treat a typo as expired rather than giving it out forever
	end
	return DateTime.fromUniversalTime(tonumber(year), tonumber(month), tonumber(day), 23, 59, 59).UnixTimestamp
end

-- "+100 gems, +$5.00K and +1 spin!" (`gems` is what was actually given, with any VIP bonus)
local function rewardText(row, gems: number?): string
	local parts = {}
	if gems then
		table.insert(parts, `+{gems} gems`)
	end
	if row.cash then
		table.insert(parts, "+$" .. Format.cash(row.cash))
	end
	if row.spins then
		table.insert(parts, `+{row.spins} spin{if row.spins == 1 then "" else "s"}`)
	end
	if #parts == 0 then
		return "Code redeemed!"
	end
	local last = table.remove(parts)
	return (if #parts > 0 then table.concat(parts, ", ") .. " and " else "") .. last .. "!"
end

local function reply(player: Player, success: boolean, message: string)
	Remotes.CodeResult:FireClient(player, success, message)
end

local function redeem(player: Player, text: any)
	-- Never trust what the client sends: it must be a short string.
	if typeof(text) ~= "string" or #text > GameConfig.CodeMaxLength * 2 then
		return
	end
	local now = os.clock()
	if lastTry[player] and now - lastTry[player] < GameConfig.CodeCooldownSeconds then
		reply(player, false, "Slow down! Try again in a moment.")
		return
	end
	lastTry[player] = now
	if not DataService.isLoaded(player) then
		reply(player, false, "Still loading your data, try again in a moment.")
		return
	end

	local code = normalize(text)
	local row = if #code > 0 and #code <= GameConfig.CodeMaxLength then codes[code] else nil
	local expires = row and expiryTime(row)
	if not row or (expires and os.time() > expires) then
		reply(player, false, "Invalid or expired code")
		return
	end
	if DataService.hasRedeemedCode(player, code) then
		reply(player, false, "Already used")
		return
	end

	DataService.markCodeRedeemed(player, code)
	local gems = if row.gems then DataService.earnGems(player, row.gems) else nil
	if row.cash then
		DataService.addCash(player, row.cash)
	end
	if row.spins then
		DataService.addSpins(player, row.spins)
	end
	reply(player, true, rewardText(row, gems))
end

function CodeService.start()
	for _, row in CodeConfig do
		codes[normalize(row.code)] = row
	end
	Remotes.RedeemCode.OnServerEvent:Connect(redeem)
	Players.PlayerRemoving:Connect(function(player)
		lastTry[player] = nil
	end)
end

return CodeService
