-- Runs the Haunted Hour event on a timer (see GameConfig.HauntedHour*): it schedules the next
-- one by writing its start and end times on ReplicatedStorage (Shared.HauntedHour reads them),
-- waits for it to start and finish, then schedules the next. GhostService reads whether it's on
-- for the spawn boost; each device draws the countdown, red sky and banners itself.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local HauntedHour = require(ReplicatedStorage.Shared.HauntedHour)

local HauntedHourService = {}

local function waitUntil(serverTime: number)
	while workspace:GetServerTimeNow() < serverTime do
		task.wait(math.min(serverTime - workspace:GetServerTimeNow(), 5))
	end
end

function HauntedHourService.start()
	task.spawn(function()
		while true do
			local startAt = workspace:GetServerTimeNow() + GameConfig.HauntedHourEverySeconds
			local endAt = startAt + GameConfig.HauntedHourSeconds
			ReplicatedStorage:SetAttribute(HauntedHour.START_ATTRIBUTE, startAt)
			ReplicatedStorage:SetAttribute(HauntedHour.END_ATTRIBUTE, endAt)
			waitUntil(endAt)
		end
	end)
end

return HauntedHourService
