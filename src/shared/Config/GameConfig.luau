-- Tuning values for the whole game. Change numbers here instead of inside scripts.
return {
	-- Plots / server size (set Max Players in Game Settings to match PlotCount)
	PlotCount = 10,

	-- Economy
	StartingCash = 100,
	SellRefund = 0.5, -- selling a ghost returns 50% of its price
	IncomeTickSeconds = 1,

	-- Walkway shop (ghosts float past and players buy them)
	WalkwaySpawnInterval = 2.5, -- seconds between new ghosts
	WalkwaySpeed = 10, -- studs per second

	-- Stealing
	StealHoldSeconds = 1.5, -- how long the thief holds E to grab a ghost
	CarrySpeedMultiplier = 0.75, -- thieves are slower while carrying
	TagDistance = 6, -- owner this close to the thief = ghost goes home
	StealCooldownSeconds = 3, -- after a failed steal

	-- Base lock
	LockDurationSeconds = 60,
	LockCooldownSeconds = 30, -- wait time after a lock ends before locking again
	LockButtonMargin = 1, -- extra studs around the button that still count as standing on it

	-- Saving
	AutoSaveSeconds = 120,
	DataStoreName = "StealAGhost_v1",
}
