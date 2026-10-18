-- Shows each player's title (TitleConfig, the "Title" attribute TitleService sets) in front of
-- their name in chat, coloured like the one above their head: "[THE GOAT] jerizaxe: hi".
-- Each device decorates the messages it shows (TextChatService.OnIncomingMessage).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local TitleConfig = require(ReplicatedStorage.Shared.Config.TitleConfig)
local TitleText = require(ReplicatedStorage.Shared.TitleText)

local ChatTitles = {}

function ChatTitles.start()
	-- Only one OnIncomingMessage callback can be set, so anything else that decorates chat
	-- belongs in here too.
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local source = message.TextSource
		local speaker = source and Players:GetPlayerByUserId(source.UserId)
		local title = speaker and TitleConfig.byId[speaker:GetAttribute("Title") or ""]
		if not title then
			return nil
		end
		local properties = Instance.new("TextChatMessageProperties")
		properties.PrefixText = TitleText.richText(title) .. " " .. message.PrefixText
		return properties
	end
end

return ChatTitles
