-- System lines in this device's chat window, like "[HAUNTED HOUR] Haunted Hour has begun!",
-- with the tag in bold and its own colour. Used for server-wide events everyone should notice:
-- rare spawns (RareSpawnBanner), Haunted Hour (HauntedHourHud), the Nuke (NukeClient), and
-- lines the server sends with the SystemChat remote (server boosters, StoreService).
-- Every device posts its own copy, so everyone in the server sees it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SystemChat = {}

-- Makes a player's name (or any text) safe to put inside rich text.
function SystemChat.escape(text: string): string
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

-- Text in a colour, for rich text: SystemChat.colored("($500K)", Theme.MoneyGreen).
function SystemChat.colored(text: string, color: Color3): string
	return `<font color="#{color:ToHex()}">{text}</font>`
end

-- Posts "[TAG] message" (message may contain rich text; escape any player names in it).
function SystemChat.post(tag: string, color: Color3, message: string)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local channel = channels and (channels:FindFirstChild("RBXSystem") or channels:FindFirstChild("RBXGeneral"))
	if not channel then
		return
	end
	local line = SystemChat.colored(`<b>[{tag}]</b>`, color) .. " " .. message
	-- A chat hiccup shouldn't break whatever called this.
	pcall(function()
		(channel :: TextChannel):DisplaySystemMessage(line)
	end)
end

function SystemChat.start()
	Remotes.SystemChat.OnClientEvent:Connect(function(tag: string, color: Color3, message: string)
		SystemChat.post(tag, color, message)
	end)
end

return SystemChat
