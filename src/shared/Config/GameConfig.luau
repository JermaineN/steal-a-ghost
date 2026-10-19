-- Tuning values for the whole game. Change numbers here instead of inside scripts.

-- The landmine's other sizes are based on this: 2/3 of the walkway's 12-stud width.
local LANDMINE_TRIGGER_RADIUS = 8

return {
	-- Plots / server size (set Max Players in Game Settings to match PlotCount)
	PlotCount = 8,
	HalloweenMap = true, -- night sky, pumpkins, graveyard and ghost portals (visual only)
	-- On phones and tablets, the cash/income/gems display, the Invite, Daily reward and Spin
	-- buttons, and the titles above heads are drawn at this size (0.7 = 30% smaller).
	MobileHudScale = 0.7,
	-- On phones and tablets, the floating text on the bases (ghost names, mutations, rarities,
	-- incomes, "COLLECT $X") is drawn at this size (0.8 = 20% smaller). Base signs and the lock
	-- text, and ghosts on the walkway, keep their size.
	MobileBaseTextScale = 0.8,

	-- Economy
	StartingCash = 100,
	GemIcon = "rbxassetid://87137328805739", -- the gem currency's picture (source: assets/gem-icon.png)
	-- Extra cash for testing, ONLY when playing in Studio (live servers ignore it).
	-- A test profile is never saved. Turn StudioTestCashOn on to start with StudioTestCash.
	StudioTestCashOn = false,
	StudioTestCash = 1000000000, -- $1B
	-- Same for gems: start with StudioTestGems (Studio only, never saved).
	StudioTestGemsOn = false,
	StudioTestGems = 10000,
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
	-- (gold for Legendary, a bigger shiny red one for Mythic, and the big one again in heavenly
	-- colours for Divine and black-and-white with a dark flash for Secret). Sounds are free Creator
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
	-- Testing only, ONLY in Studio: true gives every walkway ghost a random mutation (see
	-- MutationConfig for the real chances). Set to false for normal rates.
	StudioBoostMutations = false,
	-- Spawn banner sounds for the mutations that announce (MutationConfig `announce`). Undead uses
	-- the Legendary chime and timing (on a Mythic or rarer ghost, the longer rarity sound wins);
	-- Shiny reuses the Mythic sound until you pick its own.
	MutationAnnouncements = {
		undead = { soundId = 104000340117740, volume = 0.6, seconds = 4 }, -- "Notification Chime", like Legendary
		shiny = { soundId = 9047100306, volume = 0.7, seconds = 7 },
	},

	-- Leaderboards (glowing boards between the middle bases): the top players worldwide, saved in
	-- OrderedDataStores. In Studio (no DataStore access) they show the players in the server.
	LeaderboardRefreshSeconds = 60,
	LeaderboardSize = 10, -- rows per board

	-- Offline earnings: rejoining pays OfflineIncomeShare of your ghosts' income (with your
	-- rebirth boost) for the time you were away, up to OfflineMaxHours. Shorter absences than
	-- OfflineMinSeconds pay nothing (so rejoining doesn't farm it).
	OfflineIncomeShare = 0.2,
	OfflineMaxHours = 8,
	OfflineMinSeconds = 60,

	-- First-time tutorial: gems for finishing it (buy a ghost, collect, lock your base).
	TutorialGems = 25,

	-- Daily rewards: gems for joining on consecutive days (a new day starts at midnight UTC).
	-- Day 1, 2, 3 ... of a streak; after the last day it keeps giving the last reward. Missing a
	-- day starts the streak over at day 1.
	DailyRewardGems = { 10, 15, 20, 30, 40, 60, 100 },

	-- Spin Wheel (the "Spin" button, bottom right): one free spin each day (midnight UTC) plus
	-- one for every SpinOnlineSeconds played in a row (the timer starts over each time you join).
	-- Unused spins are saved. The prizes go clockwise from the top, one 60-degree slice each;
	-- `weight` is the chance out of all the weights (these add up to 100, so they're percents).
	--   kind "gems"  amount gems
	--   kind "boost" income × SpinBoostMultiplier for `seconds` of play (pauses while offline;
	--                winning another adds its time)
	--   kind "item"  one of ItemConfig item `itemId`
	SpinOnlineSeconds = 10 * 60,
	SpinBoostMultiplier = 2,
	SpinSeconds = 6, -- from pressing Spin to the wheel stopping and the prize being paid
	SpinIcon = "rbxassetid://127321308714174", -- the window's icon (source: assets/spin-wheel-icon.png)
	SpinWedgeImage = "rbxassetid://119683871169650", -- one white slice, tinted per prize (assets/spin-wedge.png)
	-- stylua: ignore
	SpinPrizes = {
		{ kind = "gems",  amount = 10, weight = 35 },
		{ kind = "boost", seconds = 10 * 60, weight = 12 },
		{ kind = "gems",  amount = 20, weight = 30 },
		{ kind = "item",  itemId = "nuke", weight = 1 },
		{ kind = "gems",  amount = 50, weight = 15 },
		{ kind = "boost", seconds = 30 * 60, weight = 7 },
	},

	-- Friend boost: each of your Roblox friends in the same server adds this much to your income
	-- (0.1 = +10%), up to FriendBoostMax. The Invite button (bottom right) invites friends.
	FriendBoostPerFriend = 0.1,
	FriendBoostMax = 0.5,

	-- Haunted Hour: a server-wide event. A countdown at the top of the screen shows when the next
	-- one starts; while it's on, the sky turns blood red, ghosts spawn faster and the rarest ones
	-- are much more likely.
	HauntedHourEverySeconds = 15 * 60, -- wait between one ending and the next starting
	HauntedHourSeconds = 120, -- how long it lasts
	HauntedHourLuck = 3, -- ghosts of HauntedHourLuckMinRarity or rarer are this many times as likely
	HauntedHourLuckMinRarity = "Legendary",
	HauntedHourSpawnSpeed = 2, -- ghosts spawn this many times as often
	HauntedHourWarnSeconds = 30, -- everyone gets a "starting soon" message this long before
	HauntedHourSound = { soundId = 91289467382888, volume = 0.8 }, -- "WX_Thunder_Close_03" (MSDLF)

	-- Stealing
	StealHoldSeconds = 1.5, -- how long the thief holds E to grab a ghost
	-- Walk speeds in studs per second (Roblox's default is 16).
	WalkSpeed = 24.5, -- increased from the default
	CarryWalkSpeed = 15.3, -- decreased from the default, while carrying a stolen ghost (no jumping or items)
	StealCooldownSeconds = 3, -- after a failed steal
	-- Wanted: this many successful steals in a row (without being stopped) make a thief WANTED,
	-- with a bounty of BountyShare of the price of every ghost they stole in the streak. Whoever
	-- hits them first (bat, cage or landmine) gets the bounty, paid from the thief's own cash.
	WantedStreak = 3,
	BountyShare = 0.25,

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
	-- Tennis Racket (Shop item): swings and hits exactly like the bat (same range, arc and swing
	-- speed, no cooldown and the same height) but knocks people this many times further back,
	-- with a tennis "thwock".
	RacketPushMultiplier = 11,
	-- After getting up from a racket hit, can't be knocked over again for this many times the
	-- bat's BatHitImmunitySeconds.
	RacketImmunityMultiplier = 1.9,
	RacketIcon = "rbxassetid://95075449356080", -- source: assets/racket-icon.png
	-- "Tennis Ball Hits CU Impacts 3" (Pro Sound Effects): only the racket hit, which starts at
	-- `startAt` seconds into the clip and lasts `length` (the rest is footsteps and bounces).
	RacketHitSound = { soundId = 9119985856, volume = 1, pitch = 1, startAt = 1.27, length = 0.7 },
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
	CageCooldownSeconds = 15, -- after caging someone, before the cage can be used again (misses are free)

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
	RebirthStartingCashShare = 0.01, -- you restart with this share of the rebirth's cost (rebirth 2 at $250K → $2.5K)
	RebirthTitleMessageDelay = 3.5, -- seconds after rebirthing before "New title unlocked" shows (after the celebration)
	-- Played on the rebirthing player's device with the celebration. "Rewards Level Up - Next
	-- Tier" (Los Calientes Studio, unknown uploader; swap it if you prefer another).
	RebirthSound = { soundId = 134821092416328, volume = 0.7 },

	-- Hotbar: how many Inventory items can be equipped at once (they go in the slots after the bat).
	MaxEquippedItems = 2,

	-- Shop boosters and game passes (what they are and their prices: StoreConfig).
	LuckBoostMultiplier = 2, -- Server Luck: ghosts of LuckBoostMinRarity or rarer are this many times as likely
	LuckBoostMinRarity = "Epic",
	SpeedBoostBonus = 0.3, -- Speed Boost: +30% walk speed (on top of the Speed upgrade)
	PassMoneyMultiplier = 2, -- 2x Money pass: income × this, forever
	VipIncomeBonus = 0.1, -- VIP pass: +10% income (added like the friend boost)
	PassExtraSlots = 1, -- Extra Hotbar Slot pass: this many more equipped items
	FastFlightMultiplier = 2, -- Fast Flight pass: bought ghosts fly home this many times as fast

	-- Smoke Bomb (Shop item): click to vanish in a smoke cloud. You're invisible for
	-- SmokeBombSeconds, or until you're knocked over, caged or die, then you reappear in another
	-- puff. No other items while invisible. The cooldown starts when you use it.
	SmokeBombSeconds = 7,
	SmokeBombCooldownSeconds = 35,
	SmokeBombFadeSeconds = 3, -- how long each smoke cloud takes to fade away
	SmokeBombIcon = "rbxassetid://109587585269112", -- source: assets/smoke-bomb-icon.png
	-- "Smoke_Teleport_Poof_4" (aarondeminecraft1, unknown uploader); swap it if you prefer another.
	SmokeBombSound = { soundId = 108688312097046, volume = 0.8 },

	-- Gravity (Shop item): click to open a gravity well around you for GravitySeconds. You're slowed
	-- to GravityUserWalkSpeed, and everyone else within GravityRadius is slowed to
	-- GravityVictimWalkSpeed and pulled toward you at GravityPullSpeed (always stronger than they
	-- can walk, so everyone caught reaches the middle in time). Anyone pulled within
	-- GravityCatchRadius drops a ghost they're stealing (it flies home). The cooldown starts when
	-- you use it.
	GravitySeconds = 5,
	GravityCooldownSeconds = 35,
	GravityRadius = 60, -- studs: the area is 120 across, three times a base's 40-stud length
	GravityPullSpeed = 30, -- studs per second at the edge, rising to about 40 near the middle
	GravityUserWalkSpeed = 8,
	GravityVictimWalkSpeed = 8, -- players being pulled can barely walk against it
	GravityCatchRadius = 7,
	GravityIcon = "rbxassetid://100121928705722", -- source: assets/gravity-icon.png
	GravitySound = { soundId = 9114344093, volume = 0.7 }, -- "Energy Presence 8" (Pro Sound Effects), loops
	-- Played once as the well opens: a reversed whoosh swelling inward, the space warping.
	GravityWarpSound = { soundId = 9043345004, volume = 0.8 }, -- "REVERSE NOISE VERB TAIL 10" (APM Music)

	-- Universal Key (Shop item): click near a locked base's gate to unlock it. The unlock takes
	-- UniversalKeyUnlockSeconds (the owner is told the moment it starts) and is cancelled if you're
	-- knocked over, caged, die or walk off. The cooldown starts when the unlock begins.
	UniversalKeyUnlockSeconds = 2.5,
	UniversalKeyCooldownSeconds = 120,
	UniversalKeyRange = 12, -- studs from the base's gate (its lock bars)
	UniversalKeyIcon = "rbxassetid://86142974980494", -- source: assets/key-icon.png
	UniversalKeyPickSound = { soundId = 9114152830, volume = 0.6 }, -- "Door Shake 4" (Pro Sound Effects)
	UniversalKeyUnlockSound = { soundId = 9116723292, volume = 0.9 }, -- "Metal Latches 8" (Pro Sound Effects)

	-- PolterPuller 4000 (Shop item): while you hold it, other players' ghosts show "Capture" instead
	-- of "Steal". Capturing takes CaptureSeconds[rarity] (you must stay within CaptureRange of the
	-- ghost and keep holding it); the ghost then goes straight into your base and counts as a
	-- steal. The same rules as stealing apply to start (inside their base, unlocked, a free
	-- grave). Cooldown: CaptureCooldownMultiplier x the capture time, success or not.
	CaptureSeconds = {
		Common = 3,
		Uncommon = 4,
		Rare = 5,
		Epic = 6,
		Legendary = 9,
		Mythic = 16,
		Divine = 16,
		Secret = 16,
	},
	CaptureCooldownMultiplier = 6,
	CaptureRange = 15, -- studs from the capturer to the ghost
	PolterPullerIcon = "rbxassetid://110348892274923", -- source: assets/polterpuller-icon.png
	CaptureVacuumSound = { soundId = 9120360676, volume = 0.5, startAt = 2 }, -- "Vacuum Cleaner 1" (Pro Sound Effects)
	CapturePopSound = { soundId = 9119669074, volume = 0.9 }, -- "Suction Pop 5" (Pro Sound Effects)

	-- Shield (Shop item): click for ShieldSeconds of immunity to crowd control (bat/landmine
	-- knockback, cages, Gravity's pull). Ends straight away if you pick up (or capture) a ghost.
	-- Cooldown starts on use.
	ShieldSeconds = 7,
	ShieldCooldownSeconds = 25,
	ShieldIcon = "rbxassetid://108221968843411", -- source: assets/shield-icon.png

	-- Mega Mallet (Shop item): click to raise it over your head. You're frozen in place for the
	-- wind-up while a red cone grows on the ground in front of you, then you slam it down: a
	-- shockwave and rock spikes rip outward through the cone and launch everyone they reach.
	MegaMalletWindupSeconds = 2, -- from the click to the slam
	MegaMalletTelegraphSeconds = 1.5, -- the red cone grows to full size over this long
	MegaMalletRange = 112.5, -- studs: 1.5x Gravity's 60-stud pull radius, then +25%
	MegaMalletHalfAngle = 50, -- degrees each side of where you face (a 100 degree cone; the cone pictures are drawn to match)
	MegaMalletWaveSpeed = 150, -- studs per second the shockwave travels (reaches the edge in 0.75 s)
	MegaMalletKnockbackSpeed = 50, -- sideways push away from you, like a landmine
	MegaMalletKnockbackLift = 125, -- upward launch, as high as a landmine
	MegaMalletRagdollSeconds = 3.5, -- floppy after landing: double a landmine's
	MegaMalletCooldownSeconds = 62.5,
	MegaMalletIcon = "rbxassetid://78467553699874", -- source: assets/mallet-icon.png
	MegaMalletConeImage = "rbxassetid://128411154166555", -- source: assets/mallet-cone.png
	MegaMalletWaveImage = "rbxassetid://105875569794102", -- source: assets/mallet-wave.png
	MegaMalletWindupSound = { soundId = 9043345004, volume = 0.9 }, -- same as GravityWarpSound (rising)
	MegaMalletSlamSound = { soundId = 117211977307268, volume = 1 }, -- same as LandmineSound (boom)

	-- Nuke (the Spin Wheel's Mythic prize, not sold in the Shop): a remote control. Press its
	-- button and everyone is warned ("X has launched a nuke!") with a countdown and sirens. Then
	-- everyone is frozen while a cutscene shows the nuke falling onto the middle of the map, seen
	-- from a low camera that follows it down. When it hits, the cutscene ends and every player
	-- (the launcher too) is launched up and away from the blast. One nuke at a time per server.
	NukeCountdownSeconds = 5, -- from pressing the button to the cutscene
	NukeFallSeconds = 4, -- the cutscene: the nuke falling from NukeDropHeight to the ground
	NukeDropHeight = 450, -- studs above the middle of the map where the nuke appears
	NukeKnockbackSpeed = 75, -- sideways push away from the blast: 1.5x the Mega Mallet's
	NukeKnockbackLift = 187.5, -- upward launch: 1.5x the Mega Mallet's
	NukeRagdollSeconds = 3.5, -- floppy after landing: the same as the Mega Mallet
	NukeCooldownSeconds = 200,
	NukeSharedCooldownSeconds = 50, -- a launch puts everyone else's nuke on at least this cooldown
	NukeIcon = "rbxassetid://81602201807177", -- source: assets/nuke-icon.png
	NukeSirenSound = { soundId = 9113073742, volume = 0.6 }, -- "Air Raid Siren Old Fashioned 1" (Pro Sound Effects)
	NukeBeepSound = { soundId = 9117060349, volume = 0.8 }, -- "Nasa Transmission Beep 2" (Pro Sound Effects), each countdown second
	NukeFallSound = { soundId = 116150406781332, volume = 1 }, -- "Falling whistle sound effect" (Grummgus)
	NukeBlastSound = { soundId = 9125484367, volume = 1 }, -- "Deep Hits Big Reverberant Booms" (Pro Sound Effects)
	NukeBoomSound = { soundId = 117211977307268, volume = 1 }, -- same as LandmineSound, layered on the blast

	-- Upgrades (the Upgrades signpost at each base's entrance). All but More Graves reset to 0 on rebirth.
	-- More Graves: you start with StartingGraves of the base's 10 graves; each upgrade opens one more.
	StartingGraves = 6,
	GraveUpgradeCosts = { 10000, 250000, 1000000, 5000000 }, -- graves 7, 8, 9, 10
	-- Longer Lock: each upgrade adds LockUpgradeSeconds to LockDurationSeconds.
	LockUpgradeCosts = { 100000, 1000000, 5000000 },
	LockUpgradeSeconds = 15,
	-- Speed: each upgrade adds SpeedUpgradeBonus × WalkSpeed (5 levels = x2 speed).
	SpeedUpgradeCosts = { 6000, 30000, 120000, 500000, 2000000 },
	SpeedUpgradeBonus = 0.2,
	-- Carry Speed: each upgrade adds CarrySpeedUpgradeBonus × CarryWalkSpeed (5 levels = x1.3).
	CarrySpeedUpgradeCosts = { 10000, 50000, 200000, 800000, 3000000 },
	CarrySpeedUpgradeBonus = 0.06,

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
