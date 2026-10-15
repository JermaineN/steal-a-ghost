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
	-- A bought ghost flies from the walkway toward its owner's base, facing where it's going.
	-- Once it reaches the front of the base it appears on its grave. It can't earn, be stolen
	-- or be sold until then.
	GhostTravelSpeed = 8, -- studs per second; slow enough that other players can catch it and bid
	GhostArrivalSnapDistance = 6, -- studs in front of the base's gate where it appears on its grave
	-- While a ghost is flying to its base, anyone else can buy it out from under the buyer (like
	-- bidding). Each re-buy costs this much more of the ghost's original price than the last
	-- ($100 -> $150 -> $200 ...), and whoever loses the ghost gets back what they paid.
	RepurchaseMarkup = 0.5,

	-- Banner across the top of everyone's screen when a top-rarity ghost spawns on the walkway
	-- (gold for Legendary, a bigger rainbow one for Mythic). Sounds are free Creator Store audio
	-- (the Mythic one is a Roblox-licensed APM Music track); swap the IDs for any other audio.
	RareSpawnAnnouncements = {
		Legendary = { soundId = 104000340117740, volume = 0.6, seconds = 4 }, -- "Notification Chime"
		Mythic = { soundId = 9047100306, volume = 0.6, seconds = 6 }, -- "Hustler Sting 2"
	},
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
	LockCooldownSeconds = 10, -- wait time after a lock ends before locking again
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
