-- Friend boost: playing in the same server as your Roblox friends boosts your income (see
-- GameConfig.FriendBoostPerFriend / FriendBoostMax). Each player gets two attributes:
-- "FriendsHere" (how many friends are in the server) and "FriendBoost" (the bonus, 0.2 = +20%),
-- which EconomyService adds to their income and the HUD shows.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Notify = require(script.Parent.Parent.Util.Notify)

local FriendBoostService = {}

-- friends[a][b] = true when a and b are friends and both in this server.
local friends: { [Player]: { [Player]: boolean } } = {}

local function update(player: Player)
	if not player.Parent then
		return
	end
	local count = 0
	for _ in friends[player] or {} do
		count += 1
	end
	player:SetAttribute("FriendsHere", count)
	player:SetAttribute("FriendBoost", math.min(count * GameConfig.FriendBoostPerFriend, GameConfig.FriendBoostMax))
end

local function percent(): string
	return "+" .. math.floor(GameConfig.FriendBoostPerFriend * 100 + 0.5) .. "%"
end

local function playerAdded(player: Player)
	friends[player] = {}
	update(player)
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		-- Asking Roblox can fail or take a moment, so each check runs on its own.
		task.spawn(function()
			local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
			-- (Two friends joining together both check each other; only count them once.)
			if not ok or not isFriend or not friends[player] or not friends[other] or friends[player][other] then
				return
			end
			friends[player][other] = true
			friends[other][player] = true
			update(player)
			update(other)
			Notify.send(player, `Your friend {other.DisplayName} is here: {percent()} income!`, "success")
			Notify.send(other, `Your friend {player.DisplayName} joined: {percent()} income!`, "success")
		end)
	end
end

local function playerRemoving(player: Player)
	for other in friends[player] or {} do
		if friends[other] then
			friends[other][player] = nil
			update(other)
		end
	end
	friends[player] = nil
end

function FriendBoostService.start()
	Players.PlayerAdded:Connect(playerAdded)
	Players.PlayerRemoving:Connect(playerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(playerAdded, player)
	end
end

return FriendBoostService
