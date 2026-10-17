-- Offline earnings maths, shared by the server (OfflineService) and the Welcome Back window.
local GameConfig = require(script.Parent.Config.GameConfig)

local Offline = {}

-- Cash earned while away: OfflineIncomeShare of `incomePerSecond`, for up to OfflineMaxHours.
-- Absences shorter than OfflineMinSeconds earn nothing.
function Offline.earnings(incomePerSecond: number, secondsAway: number): number
	if secondsAway < GameConfig.OfflineMinSeconds or incomePerSecond <= 0 then
		return 0
	end
	local counted = math.min(secondsAway, GameConfig.OfflineMaxHours * 3600)
	return math.floor(incomePerSecond * GameConfig.OfflineIncomeShare * counted)
end

-- "2h 15m", "45m", "1m"
function Offline.formatDuration(seconds: number): string
	local minutes = math.max(math.floor(seconds / 60), 1)
	local hours = minutes // 60
	if hours == 0 then
		return minutes .. "m"
	end
	return if minutes % 60 == 0 then hours .. "h" else `{hours}h {minutes % 60}m`
end

return Offline
