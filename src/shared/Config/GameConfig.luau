-- Tuning values for the whole game. Change numbers here instead of inside scripts.

-- The landmine's other sizes are based on this: 2/3 of the walkway's 12-stud width.
local LANDMINE_TRIGGER_RADIUS = 8

return {
	-- Plots / server size (set Max Players in Game Settings to match PlotCount)
	PlotCount = 8,
	HalloweenMap = true, -- night sky, pumpkins, graveyard and ghost portals (visual only)

	-- Economy
	StartingCash = 100,
	GemIcon = "rbxassetid://87137328805739", -- the gem currency's picture (source: assets/gem-icon.png)
	-- Extra cash for testing, ONLY when playing in Studio (live servers ignore it).
	-- A test profile is never saved. Turn StudioTestCashOn on to start with StudioTestCash.
	StudioTestCashOn = false,
	StudioTestCash = 1000000000, -- $1B
	SellRefund = 0.5, -- selling a ghost returns 50% of its price
	-- Selling a ghost of this rarity or higher asks "Are you sure?" first (see GhostConfig.Rarities).
	SellConfirmMinRarity = "Mythic",
	SellConfirmSeconds = 15, -- the question goes away (and nothing is sold) after this long
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
	-- (gold for Legendary, a bigger rainbow one for Mythic, and the big one again in heavenly
	-- colours for Divine and silver-and-red with a dark flash for Secret). Sounds are free Creator
	-- Store audio (the Mythic one is a Roblox-licensed APM Music track); swap the IDs for any other
	-- audio. Divine and Secret reuse the Mythic sound until you pick their own.
	RareSpawnAnnouncements = {
		Legendary = { soundId = 104000340117740, volume = 0.6, seconds = 4 }, -- "Notification Chime"
		Mythic = { soundId = 9047100306, volume = 0.6, seconds = 6 }, -- "Hustler Sting 2"
		Divine = { soundId = 9047100306, volume = 0.7, seconds = 7 },
		Secret = { soundId = 9047100306, volume = 0.8, seconds = 8 },
	},
	-- Testing only, ONLY when playing in Studio (live servers ignore it): true makes every ghost
	-- equally likely to spawn and halves the spawn interval. Set to false for normal rates.
	StudioBoostSpawns = false,

	-- Stealing
	StealHoldSeconds = 1.5, -- how long the thief holds E to grab a ghost
	-- Walk speeds in studs per second (Roblox's default is 16).
	WalkSpeed = 24.5, -- increased from the default
	CarryWalkSpeed = 14.3, -- decreased from the default, while carrying a stolen ghost (no jumping or items)
	StealCooldownSeconds = 3, -- after a failed steal

	-- Bat (every player's slot-1 item): hitting a player knocks them over; hitting a thief also
	-- sends the stolen ghost home
	BatIcon = "rbxassetid://81006760675555", -- hotbar picture (source: assets/bat-icon.png)
	BatRange = 8, -- studs from the swinger (centre to centre) that count as a hit
	-- How wide a bat swing reaches, as a cone centred on where you face (150 = 75 degrees to
	-- either side; 180 would be everything in front of you).
	BatHitArcDegrees = 150,
	BatSwingCooldown = 0.7, -- seconds between swings (the swing animation lasts about this long)
	BatHitDelay = 0.22, -- seconds from click to the bat reaching the front (matches the animation)
	BatKnockbackSpeed = 5, -- sideways push away from the swinger, in studs per second (5 lands about 4 studs back)
	BatKnockbackLift = 60, -- upward launch in studs per second (60 flies them about 9 studs up)
	BatKnockbackSpin = 6, -- tumble while flying, in radians per second
	BatRagdollSeconds = 3.5, -- how long a hit player stays floppy (in the air and on the ground)
	BatHitSound = { soundId = 137041944943141, volume = 0.8, pitch = 1 }, -- "bonk" (DEGG_20)
	BatHitImmunitySeconds = 1, -- after getting up, can't be knocked over again for this long
	RagdollMaxAirSeconds = 6, -- a launched player counts as landed after this long, even if they never seem to

	-- Cage (slot 2, only for the players listed below): swing it like the bat; the closest player
	-- hit drops any stolen ghost and is frozen inside a cage
	-- UserIds of who gets the Cage. A UserId is the number in a player's profile link
	-- (roblox.com/users/<UserId>/profile). Studio test players: Player1 = -1, Player2 = -2.
	CageAllowedUserIds = {
		701124691, -- Winter_Unicorn79
	},
	CageIcon = "rbxassetid://83040114543592", -- hotbar picture (source: assets/cage-icon.png)
	CageRange = 12, -- studs from the swinger (centre to centre) that count as a hit
	CageHitArcDegrees = 180, -- cone centred on where you face (180 = everything in front of you)
	CageSeconds = 7, -- how long a caged player stays stuck
	CageCooldownSeconds = 12, -- after caging someone, before the cage can be used again (misses are free)

	-- Landmine (only for the players listed below): click to place one at your feet. Only its
	-- owner can see it. Anyone else who walks near it sets it off and everyone in the blast (except
	-- the owner) is launched much harder than the bat, and stays down longer
	LandmineAllowedUserIds = {
		5783726738, -- jerizaxe
	},
	LandmineIcon = "rbxassetid://108281657379293", -- hotbar picture (source: assets/landmine-icon.png)
	LandmineTriggerRadius = LANDMINE_TRIGGER_RADIUS, -- studs from the mine that set it off
	LandmineExplosionRadius = LANDMINE_TRIGGER_RADIUS * 1.3, -- everyone this close gets launched
	LandmineMinSpacing = LANDMINE_TRIGGER_RADIUS * 2.5, -- closest a new mine can be to another (20 studs)
	LandmineMaxPlaced = 4, -- placing another removes the oldest
	LandmineCooldownSeconds = 15, -- after placing a mine, before placing the next
	LandmineArmSeconds = 1, -- a new mine can't go off for this long (so it can't blow up as it lands)
	LandmineKnockbackSpeed = 50, -- sideways push away from the mine, in studs per second
	LandmineKnockbackLift = 125, -- upward launch (125 flies them about 40 studs up; the bat's 60 is about 9)
	LandmineRagdollSeconds = 1.75, -- how long they stay floppy after landing back on the ground
	-- "Dynamite Explosion" (BuilderBillbert)
	LandmineSound = { soundId = 117211977307268, volume = 1 },

	-- Side menu (press M) button pictures (source: assets/menu-*.png, drawn by
	-- scripts/draw-menu-icons.ps1)
	MenuIcons = {
		Shop = "rbxassetid://107829839670669",
		Rebirth = "rbxassetid://117203030563415",
		Index = "rbxassetid://95666104073571",
		Inventory = "rbxassetid://129386900876231",
	},

	-- Rebirth (side menu → Rebirth): trade in all your cash and ghosts once you have enough cash,
	-- for a permanent income boost and a gem reward. Gems, the Index and your items stay.
	-- Cash needed for rebirth 1, 2, 3 ...; after the last one, each costs RebirthCostGrowth
	-- times the one before.
	RebirthCosts = { 50000, 250000, 1000000, 5000000, 25000000, 100000000, 500000000, 2000000000 },
	RebirthCostGrowth = 4,
	RebirthIncomeBonus = 0.5, -- each rebirth adds +50% income (1 rebirth = x1.5, 2 = x2, ...)
	RebirthGems = 50, -- gem reward = this × the rebirth number reached (rebirth 3 gives 150)
	-- Played on the rebirthing player's device with the celebration. "Rewards Level Up - Next
	-- Tier" (Los Calientes Studio, unknown uploader; swap it if you prefer another).
	RebirthSound = { soundId = 134821092416328, volume = 0.7 },

	-- Base lock
	LockDurationSeconds = 60,
	LockCooldownSeconds = 10, -- wait time after a lock ends before locking again
	LockButtonMargin = 1, -- extra studs around the button that still count as standing on it

	-- Background music: Roblox-licensed tracks (free to use in any experience), played in a
	-- shuffled loop. Swap an ID for any other audio from the Creator Store.
	MusicVolume = 0.24,
	-- While someone is carrying one of your ghosts away: a looping alarm, the music dips to this
	-- fraction of its volume, and a red border pulses around your screen.
	StealAlarmSound = { soundId = 7846610326, volume = 0.5 }, -- "Audio/Looped alarm" (ilmue), picked by ear
	StealAlarmMusicDuck = 0.3,
	MusicTracks = {
		111631783838916, -- Spooky cartoon music
		137626560269194, -- Foggy Nights
	},

	-- Saving
	AutoSaveSeconds = 120,
	DataStoreName = "StealAGhost_v1",
}
