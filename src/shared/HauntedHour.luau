-- When the Haunted Hour event is on. The server (HauntedHourService) writes the start and end
-- times as attributes on ReplicatedStorage, in server time (workspace:GetServerTimeNow(), the
-- same clock on every device), and everything else reads them through this module.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HauntedHour = {}

HauntedHour.START_ATTRIBUTE = "HauntedHourStart"
HauntedHour.END_ATTRIBUTE = "HauntedHourEnd"

-- The next (or current) event's start and end, or nil before the server has set them.
function HauntedHour.times(): (number?, number?)
	return ReplicatedStorage:GetAttribute(HauntedHour.START_ATTRIBUTE),
		ReplicatedStorage:GetAttribute(HauntedHour.END_ATTRIBUTE)
end

function HauntedHour.isActive(): boolean
	local startAt, endAt = HauntedHour.times()
	local now = workspace:GetServerTimeNow()
	return startAt ~= nil and endAt ~= nil and now >= startAt and now < endAt
end

-- "4:05"
function HauntedHour.formatTime(seconds: number): string
	seconds = math.max(math.ceil(seconds), 0)
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return HauntedHour
