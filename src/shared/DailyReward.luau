-- Daily reward maths, shared by the server (DailyRewardService) and the Daily Reward window.
local GameConfig = require(script.Parent.Config.GameConfig)

local DailyReward = {}

-- Today's day number (days since 1 January 1970, UTC). A new day starts at midnight UTC.
function DailyReward.today(): number
	return os.time() // 86400
end

-- Given the day a player last claimed and the streak day they claimed then, returns whether
-- they can claim today and which streak day today would be (1 if the streak broke).
function DailyReward.check(lastClaimDay: number?, lastStreak: number?, today: number): (boolean, number)
	if lastClaimDay == today then
		return false, lastStreak or 1
	end
	if lastClaimDay == today - 1 and lastStreak then
		return true, lastStreak + 1
	end
	return true, 1
end

-- Gems for a streak day (after the last listed day, the last reward repeats).
function DailyReward.gems(streakDay: number): number
	local rewards = GameConfig.DailyRewardGems
	return rewards[math.min(streakDay, #rewards)]
end

return DailyReward
