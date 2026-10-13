-- Sends a toast message to one player's screen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Notify = {}

-- kind: "info" | "success" | "error"
function Notify.send(player: Player, message: string, kind: string?)
	if player.Parent then
		Remotes.Notify:FireClient(player, message, kind or "info")
	end
end

return Notify
