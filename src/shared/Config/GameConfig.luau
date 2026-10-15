-- Tuning values for the whole game. Change numbers here instead of inside scripts.
return {
	-- Plots / server size (set Max Players in Game Settings to match PlotCount)
	PlotCount = 8,
	HalloweenMap = true, -- night sky, pumpkins, graveyard and ghost portals (visual only)

	-- Economy
	StartingCash = 100,
	-- Extra cash for testing, ONLY when playing in Studio (live servers ignore it).
	-- A test profile is never saved. Set to 0 to test with normal starting cash.
	StudioTestCash = 0,
	SellRefund = 0.5, -- selling a ghost returns 50% of its price
	IncomeTickSeconds = 1,
	-- Each ghost's income piles up on the green pad in front of its grave until the owner
	-- steps on the pad to collect it.
	CollectPadMargin = 0.5, -- extra studs around a pad that still count as standing on it
	-- Collecting plays a "cha-ching" and bursts cash out of the pad.
	CollectSoundId = 101396758527961, -- "Cash Register Cha Ching" from the Creator Store
	CollectSoundVolume = 0.6,
	CollectCashPieces = 10, -- bills and coins in each burst

	-- Walkway shop (ghosts float past and players buy them)
	WalkwaySpawnInterval = 2.5, -- seconds between new ghosts
	WalkwaySpeed = 10, -- studs per second
	-- Testing only, ONLY when playing in Studio (live servers ignore it): true makes every ghost
	-- equally likely to spawn and halves the spawn interval. Set to false for normal rates.
	StudioBoostSpawns = false,

	-- Stealing
	StealHoldSeconds = 1.5, -- how long the thief holds E to grab a ghost
	-- Walk speeds in studs per second (Roblox's default is 16).
	WalkSpeed = 24.5, -- increased from the default
	CarryWalkSpeed = 13, -- decreased from the default, while carrying a stolen ghost
	TagDistance = 6, -- owner this close to the thief = ghost goes home
	StealCooldownSeconds = 3, -- after a failed steal

	-- Base lock
	LockDurationSeconds = 60,
	LockCooldownSeconds = 30, -- wait time after a lock ends before locking again
	LockButtonMargin = 1, -- extra studs around the button that still count as standing on it

	-- Background music: Roblox-licensed tracks (free to use in any experience), played in a
	-- shuffled loop. Swap an ID for any other audio from the Creator Store.
	MusicVolume = 0.24,
	MusicTracks = {
		111631783838916, -- Spooky cartoon music
		137626560269194, -- Foggy Nights
	},

	-- Saving
	AutoSaveSeconds = 120,
	DataStoreName = "StealAGhost_v1",
}
