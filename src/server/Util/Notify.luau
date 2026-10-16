-- Sends a toast message to one player's screen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Notify = {}

-- Extras for a message: `note` is a smaller line shown above it (a warning or tip), and
-- `seconds` keeps it on screen longer than usual.
export type Options = { note: string?, seconds: number? }

-- kind: "info" | "success" | "error"
function Notify.send(player: Player, message: string, kind: string?, options: Options?)
	if player.Parent then
		Remotes.Notify:FireClient(player, message, kind or "info", options)
	end
end

return Notify
