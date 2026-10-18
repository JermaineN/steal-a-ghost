# Changelog

What changed while you were away, one section per change, newest last. Each section says what
it does for players, how it works, what was tested and what still needs a test from you.

Remember: merged changes only reach players after you **publish** from Studio
(File → Publish to Roblox).

## When you're back: quick summary

| # | Change | PR |
|---|---|---|
| 1 | Bug fix: the thief keeps the ghost if the owner leaves mid-steal, plus a "Don't leave!" warning | #28 |
| 2 | New rarities: Divine and Secret, with one placeholder ghost each | #29 |
| 3 | Rebirth system and Rebirth window | #30 |
| 4 | Haunted Hour server event (every 15 min) | #31 |
| 5 | Friend boost (+10% income per friend) and an Invite friends button | #32 |
| 6 | Shop and Inventory windows, with placeholder items | #33 |
| 7 | Daily reward streak (gems) | #34 |

**Your to-do list:**
1. **Publish** from Studio so players get all of this.
2. **Design the placeholders:** the Divine and Secret ghosts (names and models,
   `GhostConfig`, section 2) and the 6 Shop items (names, pictures, prices and what they do,
   `ItemConfig`, section 6).
3. **Pick sounds by ear** if you don't like mine: Divine/Secret spawn banners (they reuse the
   Mythic sound), the rebirth sound and the Haunted Hour thunder (all in `GameConfig`).
4. **2-player tests** I couldn't do alone (Test → Clients and Servers, 2 players):
   leaving mid-steal (section 1), the rebirth pillar and message as seen by the other player
   (section 3), and rebirth being blocked while someone steals from you.
5. **In the live game:** real friends joining (section 5), the invite window, and the
   next-day daily streak (section 7).
6. Tune numbers if needed: rebirth costs, Haunted Hour timing and luck, friend boost, daily
   gems, and the new ghosts' prices/odds are all in `GameConfig` / `GhostConfig`.

Nothing was removed. The only behaviour changes to existing features are: the leave-mid-steal
rule (section 1), the ghost label in your base showing rebirth-boosted income, and pop-up
messages now drawing above open windows (section 6).

---

## 1. Bug fix: leaving while being robbed no longer saves your ghost

**The problem:** if someone was carrying your ghost away and you left the game, the ghost
just went back into your save, so leaving was a free escape.

**Now:**
- If the owner leaves mid-steal, **the thief keeps the ghost**. It's taken out of the owner's
  base and save, and appears straight away in the thief's base. The thief sees
  "*<owner> left the game, so <ghost> is yours!*".
- If the thief's base filled up during the steal (they bought something while running), they
  get the ghost's sell price instead of the ghost.
- **Warning for the owner:** the "*X is stealing your Y! Hit them with your bat!*" message now
  has a smaller line above it: "*Don't leave! If you leave now, the thief gets your ghost.*"
  It stays up for 6 seconds instead of 3.

**How it works:**
- `StealService.giveToThief` runs from `StealService.playerRemoving`, before the owner's base
  is cleared and their data saved, so the save no longer has the ghost.
- Pop-up messages can now have a smaller line above them: `Notify.send(player, message, kind,
  { note = "...", seconds = 6 })`. `Hud.showToast` takes the same options. Any future message
  can use this.

**Tested:** solo playtest: the warning line shows above the steal message and fades out after
6 s; no errors. **Not tested:** the actual leave-mid-steal hand-over needs a 2-player test
(Test → Clients and Servers, 2 players: Player2 steals from Player1, then close Player1's
window). It could only be checked by reading the code.

---

## 2. New rarities: Divine and Secret (with placeholder ghosts)

**For players:** two rarities above Mythic.

| Rarity | Order | Index reward | Placeholder ghost | Price | Income | How rare |
|---|---|---|---|---|---|---|
| Divine | 7 | 300 gems | "Divine Ghost" (`divine_1`) | $2.5M | $20K/s | ~1 in 700 spawns (~30 min) |
| Secret | 8 | 600 gems | "Secret Ghost" (`secret_1`) | $15M | $100K/s | ~1 in 2,100 spawns (~90 min) |

- **Colours:** Divine is heavenly white/gold/sky-blue gradient text; Secret is silver with a
  blood-red streak (`Theme.RarityGradients`). Used on ghost labels, the Index and the sell
  pop-up automatically.
- **Spawn banners:** both get the big Mythic-style banner in their own colours ("DIVINE GHOST
  SPAWNED!" / "SECRET GHOST SPAWNED!"). Secret flashes the screen **dark** instead of white.
  Both reuse the Mythic sound for now (`GameConfig.RareSpawnAnnouncements`), so pick your own.
- **Rarity aura:** every Divine ghost gets rising gold/white sparkles, every Secret ghost dark
  smoke with silver/red stars (`GhostModels.addRarityAura`). It's added on top of whatever
  look the ghost has, so it'll still be there when you design the real models.
- Selling either asks "are you sure?" (they're above `SellConfirmMinRarity`).

**Placeholders (for you to design):** names and models. Rename them freely in `GhostConfig`,
and give them a mesh in `ServerStorage.GhostMeshes.<id>` and a look in `GhostModels.<id>`;
until then they're the simple ball. **Keep the ids** (`divine_1`, `secret_1`): saves store
ghosts by id, so changing an id would delete that ghost from everyone who owns one. Prices,
income and spawn odds are also guesses to tune.

**Tested:** solo playtest with spawn boost: both spawn on the walkway with the right
label, aura and banner; the Index shows them as cards 9 and 10. Not tested: buying them
(needs $2.5M+).

---

## 3. Rebirth system (side menu → Rebirth)

**For players:** once you have enough cash you can **rebirth**: you lose your cash and every
ghost in your base, and in return get a **permanent income boost** and **gems**.

- **Costs:** $50K, $250K, $1M, $5M, $25M, $100M, $500M, $2B, then ×4 each time
  (`GameConfig.RebirthCosts` / `RebirthCostGrowth`).
- **Boost:** +50% income per rebirth (x1.5, x2, x2.5 ...), `RebirthIncomeBonus`. Ghost labels
  in your base show the boosted income, and the HUD income line includes it. Boosted income
  is rounded to whole dollars so the label always matches what you're paid.
- **Gem reward:** 50 × the rebirth number (rebirth 3 gives 150), `RebirthGems`.
- **Kept:** gems, the Index (found ghosts and claimed rewards), items, and the boost.
- **Rebirths** now shows on the player list (leaderstats) next to Cash and Gems, and is saved
  (`rebirths` in the save data; old saves start at 0).

**The Rebirth window** is built like the Ghost Index window (same shape, header, close button
and progress bar) in the Rebirth button's purple:
- "NOW" and "NEXT" cards side by side with a bobbing arrow: income multiplier, rebirth number,
  and the gem reward on the NEXT card.
- Red "You lose" / green "You keep" lines, so nobody rebirths by accident.
- A progress bar toward the cash needed ("$12.3K / $50K").
- The button is grey ("Need $250K") until you can afford it, then purple and pulsing. **Press
  twice:** the first press turns it orange ("Press again to confirm!") for 3 seconds.
- The side menu's Rebirth button gets a red **"!"** badge while you can afford a rebirth.
- Opening the Rebirth window closes the Index and the other way round.

**Celebration (built for clips):**
- Everyone sees a **purple pillar of light** shoot up from the player who rebirthed, with
  sparkles.
- The player gets a purple flash and a big **"REBIRTH 3!"** with a light sweep, plus
  "Income x2.5 forever! +150 gems", and a level-up sound.
- Everyone else gets a pop-up: "<name> reached Rebirth 3!".
- Sound: "Rewards Level Up - Next Tier" by Los Calientes Studio (unknown uploader, looks made
  for games). `GameConfig.RebirthSound`; swap it if you'd rather pick one by ear.

**Safety (server-checked in `RebirthService`):** enough cash, data loaded, not carrying a
stolen ghost, and nobody stealing from you at that moment (otherwise a thief would be left
holding a ghost that no longer exists).

**Files:** `Shared/Rebirth.luau` (the maths, shared by server and client),
`Services/RebirthService.luau`, `UI/RebirthPanel.luau`, `RebirthEffects.luau`, plus small
changes to DataService, EconomyService, GhostService, StealService (`isBeingRobbed`),
Sidebar, Theme (`RebirthPurple`) and Remotes (`Rebirth`, `Rebirthed`).

**Tested (solo, with Studio test cash):** opened the window from the side menu; NOW/NEXT,
progress bar, badge and the two-press confirm all work; rebirthing cleared the base, set cash
to $100, gave 50 gems, counted 1 rebirth and played the celebration and pillar; a ghost
bought afterwards earned 1.5× (Boo: $4.50/s, now rounded to $5/s). After rebirthing, the
window shows "Need $250K" and the "!" badge goes away; a fake rebirth request with too little
cash is refused by the server. **Not tested:** what other players see (pillar and pop-up)
needs a 2-player test, and the blocked-while-being-robbed check.

---

## 4. Haunted Hour (server-wide event)

**For players:** every 15 minutes there's a 2-minute **Haunted Hour**:
- A small pill at the top of the screen always counts down: "Haunted Hour in 12:34".
- 30 seconds before, everyone gets "Haunted Hour starts in 30 seconds!".
- When it starts: a lightning flicker, a thunder clap, and a big blood-red **"HAUNTED HOUR!"**
  title with "Rare ghosts x3 · Ghosts spawn 2x faster". The whole world turns red.
- While it's on, the pill turns red, pulses, and counts down the time left, with what's
  boosted written under it.
- **Legendary and rarer ghosts are 3× as likely**, and ghosts spawn **twice as often**.
- When it ends, the red fades and a message says "Haunted Hour is over!".

Why: a reason to stay in the server ("only 3 minutes until Haunted Hour"), a predictable
moment when everyone rushes the walkway (bidding wars and steals), and an obvious clip moment.

**Tuning** (all in `GameConfig`): `HauntedHourEverySeconds` (15 min), `HauntedHourSeconds`
(2 min), `HauntedHourLuck` (3), `HauntedHourLuckMinRarity` ("Legendary"),
`HauntedHourSpawnSpeed` (2), `HauntedHourWarnSeconds` (30), `HauntedHourSound`
("WX_Thunder_Close_03" by MSDLF; looks like a professional sound library, not a game rip).

**How it works:** `HauntedHourService` writes the next event's start and end times as
attributes on ReplicatedStorage, in server time (the same clock on every device), so every
device counts down without any extra messages. `Shared/HauntedHour.luau` reads them
(`isActive()`), GhostService uses it for the luck and spawn speed, and `UI/HauntedHourHud.luau`
draws everything. The red world is a ColorCorrectionEffect made on each device. Someone who
joins mid-event gets the red world and timer but not the big title.

**Tested (solo):** countdown pill on join; moved the event to start 33 s later from the
server: the 30-second warning appeared, then the title, red pill with boosts and red tint;
the walkway spawned 7 ghosts in 10 s (normally 4); at the end the "over" message showed and
the tint went back to normal. The rare-ghost luck wasn't measured (too rare to count in a short
test), only read in the code.

---

## 5. Friend boost and Invite button

**For players:**
- Each of your **Roblox friends in the same server gives +10% income**, up to +50%
  (`GameConfig.FriendBoostPerFriend` / `FriendBoostMax`). It stacks on top of rebirths.
- When a friend joins (or you join a friend), both get "Your friend X is here: +10% income!".
- The HUD income line shows it in pink: "Income: +$150/s  +20% friends".
- New **Invite friends** button in the bottom-right corner, next to the music button, same
  round dark style with a pink outline. It opens Roblox's own invite window. Its second line
  says "+10% income each", or "2 here: +20% income" while friends are in the server.

Why: friends playing together is how Roblox games spread. This rewards inviting and gives
people a reason to play with friends (who can then also steal from each other).

**How it works:** `FriendBoostService` checks `IsFriendsWith` for every pair of players when
someone joins (each check on its own, failures ignored), and sets the player attributes
`FriendsHere` and `FriendBoost`. EconomyService multiplies each ghost's income by
`1 + FriendBoost` (rounded to whole dollars; so +10% on a $1/s Wisp still rounds to $1).
Ghost labels show the income without the friend boost, since friends come and go.

**Tested (solo):** set 2 friends by hand on the server: income went from $3/s to $4/s ($3.60
rounded), the HUD showed "+20% friends", and the button showed "2 here: +20% income". The
button calls Roblox's invite window; Studio doesn't show it, so the window itself only appears
in the live game. **Not tested:** real friends joining (needs two friend accounts in a live
server).

---

## 6. Shop and Inventory windows (with placeholder items)

**For players:** the side menu's **Shop** and **Inventory** buttons now open real windows
instead of "coming soon". Both look like the Index and Rebirth windows (same frame, header and
close button) in their own button's colour: Shop green, Inventory orange.

- **Shop:** a card per item: picture, name, description, price (blue gem number with the gem
  picture, or a green "$X"), and a **Buy** button. It turns grey ("Can't afford") when you
  can't afford it and comes back as your balance changes. Each press buys one.
- **Inventory:** a card per item you own, with a pill showing how many ("x2"). With nothing
  owned it says "Nothing here yet. Visit the Shop!". Each card's button says "Coming soon",
  because the items don't do anything yet.
- Items are **saved** (`items` in the save data) and **kept through rebirths**.

**PLACEHOLDERS, for you to design:** `src/shared/Config/ItemConfig.luau` has 6 stand-in items
("Placeholder Item 1–6", "Design me!", a "?" picture): 3 for gems (25 / 75 / 200) and 3 for
cash ($5K / $50K / $500K). Give each a name, description, picture (`image`, an
rbxassetid) and price, or replace them with your own. Keep an item's `id` once it's live (saves
store items by id). What an item *does* when used still needs building; the Inventory's
"Coming soon" button is where that will go.

**Also changed:** pop-up messages now draw above open windows (HUD `DisplayOrder` 6), so
"You bought ..." isn't hidden behind the Shop. Before, every message was hidden behind an
open Index window too.

**How it works:** `ShopService` handles the `ShopBuy` remote. The price and currency always
come from `ItemConfig` on the server, never from the client. `DataService.spendGems` /
`addItem`; owned items are mirrored to the client as `Item_<id>` = count attributes. New
`UI/Window.luau` builds the shared window frame, buttons, card grid and item pictures, so
future windows match.

**Tested (solo, with Studio test cash):** opened both windows from the side menu; bought Item 4
twice and Item 6 once ($510K taken, correct); gem items showed "Can't afford" with 0 gems;
forcing a gem purchase, an unknown item id and a number from the client were all refused by
the server; the Inventory showed x2 and x1; the purchase message shows above the Shop.

---

## 7. Daily reward streak

**For players:** join on consecutive days for growing **gem** rewards:
Day 1 **10**, Day 2 **15**, Day 3 **20**, Day 4 **30**, Day 5 **40**, Day 6 **60**, Day 7 **100**,
then 100 every day after that (`GameConfig.DailyRewardGems`). Missing a day starts over at
Day 1. A new day starts at midnight UTC.

- A **Daily Reward** window (gem blue, same style as the other windows) pops up 3 seconds after
  joining when a reward is waiting: seven day cards (claimed days ticked, today's in gold and
  pulsing), and a pulsing green **"Claim +N gems"** button. On Day 2+ it says "Day 3 streak!
  Don't break it!".
- After claiming, today's card gets a tick, the button says "Come back tomorrow!", a message
  confirms the gems, and the window closes itself after 1.5 s.
- If you close it without claiming, a pulsing **"Daily reward!"** button above the Invite
  button brings it back.
- Players still in the game at midnight get the next reward without rejoining.

Why: a reason to come back every day, and gems now have something to buy (the Shop).

**How it works:** `Shared/DailyReward.luau` (the streak rules, shared), `DailyRewardService`
(checks and gives the reward; `DailyClaim` remote; `DailyAvailable` / `DailyStreakDay`
attributes), `UI/DailyRewardPanel.luau`. Saved as `daily = { day, streak }`.

**Tested:** the streak rules with every case (new player, already claimed, claimed yesterday,
missed a day, past day 7). Solo playtest: the window popped up on join with Day 1, claiming
gave 10 gems and ticked Day 1, two more forced claims from the client were refused (still 10
gems), and the window closed itself. **Not tested:** the actual next-day streak (Studio
doesn't save, so it needs the live game over two days).

---

## 8. Mutations, Divine recolour, Secret price

**Mutations:** a walkway ghost can spawn with one mutation that multiplies its income:

| Mutation | Chance | Income | Colours | Big announcement |
|---|---|---|---|---|
| Eerie | 1 in 20 | ×1.2 | grey and silver | no |
| Spooky | 1 in 50 | ×1.5 | orange and black | no |
| Undead | 1 in 115 | ×2 | green and dark grey | **yes** (small, big on Mythic+) |
| Shiny | 1 in 500 | ×3 | mostly white, a touch of gold | **yes** (big) |

- Max one per ghost. Each spawn rolls Shiny first, then Undead, Spooky, Eerie, and the first
  hit wins, so a rarer mutation always takes precedence.
- The mutation's name sits **above the rarity** on the ghost's label, in its own
  **animated gradient**. The ghost also gets sparkles in its mutation's colours (more for
  rarer ones). The name everywhere becomes e.g. "Shiny Boo" (prompts and messages).
- **Shiny** always gets the big spawn banner in its colours ("SHINY GHOST SPAWNED!") with a
  white screen flash. **Undead** gets the smaller Legendary-style banner in its colours
  ("UNDEAD GHOST SPAWNED!"), and the big one with a green flash only on a Mythic or rarer
  ghost ("UNDEAD MYTHIC GHOST SPAWNED!"); `bigBanner` in `MutationConfig` sets which. On a
  rare ghost the title combines both: "SHINY LEGENDARY GHOST SPAWNED!". They reuse the Mythic
  sound for now (`GameConfig.MutationAnnouncements`).
- A mutated ghost keeps its mutation when bought, outbid, stolen, or handed over when its owner
  leaves, and it's **saved** (`mutations` in the save data, next to `ghosts`; old saves are
  fine). The multiplier stacks with rebirths and friends.
- The **price stays the same** as the normal ghost (finding a mutation is pure luck), and so
  does the sell price. Easy to change if you'd rather mutated ghosts cost more.
- `MutationConfig.luau` holds the chances, multipliers and colours. Studio-only
  `GameConfig.StudioBoostMutations` gives every walkway ghost a random mutation for testing.

**Animated gradients:** rarity text on ghost labels used to be static (only the banners
moved). Now every Legendary-and-rarer rarity word and every mutation word shimmers back and
forth (client `GradientAnimator`, which animates any UIGradient tagged `AnimatedGradient`),
including in the Index and the sell pop-up.

**Divine** is now white and blue (gradient, card/light colour, placeholder ball and banner
flash), so it no longer looks like Mythic.

**Secret Ghost** now costs $15M and earns $100K/s.

**Tested (solo, with test cash, spawn boost and mutation boost, all turned back off):** all
four mutations spawned with the right label line, colours and multiplied income (e.g. Spooky
Divine $30K/s, Eerie Secret $120K/s, Shiny Secret $300K/s); the Shiny and Undead banners,
including a real "SHINY LEGENDARY GHOST SPAWNED!"; Divine's new colours; bought an Undead
Sheet Ghost: it kept "UNDEAD" in the base and earned $20/s. **Not tested:** a stolen mutated
ghost keeping its mutation (2 players), and saving (Studio doesn't save).

---

## 9. First-time tutorial

**For players:** new players get a 3-step tutorial on a card at the bottom of the screen
(above the hotbar), with a glowing line from their character to the target and a bouncing
orange "▼" above it:
1. **Buy a ghost from the walkway!** Points at the nearest walkway ghost they can afford
   (or the cheapest one).
2. **Collect your cash!** Points at the new ghost while it flies in, then at the green collect
   pad in front of its grave. Done on the first collect.
3. **Lock your base!** Points at the lock button. Done when the base locks.

Finishing pays **25 gems** (`GameConfig.TutorialGems`) with a message. Players who already
have progress (ghosts, found ghosts or rebirths) skip it, so existing players never see it.
Saved as `tutorialDone`.

**How it works:** `TutorialService` sets the `TutorialDone` attribute when data loads and pays
the reward on `TutorialComplete` (once, and only if they own a ghost). `UI/Tutorial.luau` runs
the steps on the player's device. Players now get a `PlotIndex` attribute (so their device can
find their base), and walkway ghosts a `GhostId` attribute.

**Tested (solo):** fresh profile: the card appeared, buying a Wisp moved to step 2, the marker
sat on the new ghost's pad, stepping on it moved to step 3, stepping on the lock button
finished it with +25 gems; a repeated completion request was refused; everything was cleaned
up. You confirmed the line and arrow show in-game, and spotted the card under the hotbar (now
fixed).

---

## 10. Leaderboards in the map

**For players:** three glowing graveyard-stone boards in the gaps between the two middle bases,
facing the walkway:
- **RICHEST** (green, current cash) and **MOST REBIRTHS** (purple) on one side.
- **TOP THIEVES** (red, ghosts successfully stolen) on the other side.

Each shows the **top 10 players worldwide**, with #1–#3 in gold, silver and bronze, and refreshes
every minute (`GameConfig.LeaderboardRefreshSeconds`, `LeaderboardSize`). A player who joins
shows up a few seconds after their data loads.

**How it works:** `LeaderboardService` builds the boards in code (`GeneratedMap.Leaderboards`)
and keeps one OrderedDataStore per stat (`Leaderboard_Cash`, `Leaderboard_Rebirths`,
`Leaderboard_Steals`). Each refresh saves everyone's current number in this server, then reads
the top 10. If DataStores can't be reached (always in Studio), a board shows "Players in this
server" instead. **Steals are now counted and saved** (`steals`), including a ghost taken
because its owner left mid-steal.

**Tested (solo):** the boards build in both gaps, face the walkway and fill in with the player
once their data loads (Studio's server-only mode). **Not tested:** the worldwide lists (Studio
has no DataStore access; check the boards in the live game after publishing), and a real steal
adding to the count (2 players).

---

## 11. Base upgrades

**For players:** a wooden **UPGRADES** signpost at every base entrance (across from the lock
button). Its prompt opens a **Base Upgrades** window (gold, same style as the other windows)
for that base's owner; anyone else is told it's not their base. Two upgrades, each a card with
level pips, "Now / Next", the price and an Upgrade button:

| Upgrade | Start | Levels and cost |
|---|---|---|
| **More Graves** | 6 of the base's 10 graves open | 7: $5K · 8: $25K · 9: $100K · 10: $500K |
| **Longer Lock** | 60 s | 75 s: $10K · 90 s: $50K · 105 s: $250K |

- Graves that aren't open yet have a **grey pad with "LOCKED"** over it, and new ghosts only
  go into open graves (the base counts as full when they're taken).
- **Nobody loses a ghost:** a player whose save already uses more graves gets enough More
  Graves levels for free when they join.
- Upgrades are saved (`upgrades`) and **kept through rebirths**.
- I made the second upgrade *Longer Lock* rather than *faster lock cooldown*, because the
  cooldown is only 10 s, so shortening it wouldn't mean much.

**This changes the early game:** new players start with 6 graves instead of 10. Tune
`StartingGraves`, `GraveUpgradeCosts`, `LockUpgradeCosts` and `LockUpgradeSeconds` in
`GameConfig` (set `StartingGraves = 10` to turn the grave limit off).

**How it works:** `Shared/Upgrades.luau` (maths), `UpgradeService` (`BuyUpgrade`,
`OpenUpgrades`; `Upgrade_<id>` attributes), `UI/UpgradePanel.luau`. GhostService only fills
open graves, LockService uses the upgraded duration, EconomyService greys out locked pads,
MapBuilder builds the signpost.

**Tested (solo, with test cash):** graves 7–10 showed LOCKED; the signpost opened the
window; buying More Graves opened grave 7 and Longer Lock made the lock last 75 s; the
window updated (pips, next level, prices). **Not tested:** the free levels for old saves
(needs a live save with ghosts in graves 7–10), and a non-owner using the sign (2 players).

---

## 12. Offline earnings

**For players:** rejoining after at least a minute away pays **50% of your ghosts' income** for
the time you were gone, **up to 8 hours** (`GameConfig.OfflineIncomeShare`,
`OfflineMaxHours`, `OfflineMinSeconds`). It includes your rebirth boost and mutations, but not
the friend boost. The cash is added straight away, and a green **"Welcome back!"** window says
"You were away for 2h 15m. Your ghosts earned: **+$405K**" (the amount counts up), with a
"Nice!" button. The daily reward pop-up waits until it's closed.

Examples at $100/s: 10 minutes away → $30K; 2h 15m → $405K; 3 days → $1.44M (capped at 8 h).

**How it works:** every save now stores `lastSeen` (the time). `OfflineService` runs when data
loads: it works out the saved ghosts' income per second, pays `Shared/Offline.earnings`, and
sends `OfflineEarnings` to the player's device (`UI/WelcomeBackPanel.luau`). Brand-new players
(no `lastSeen`) get nothing.

**Tested:** the maths for every case (too short, normal, capped, no ghosts) and the time text;
in a playtest, the window showed the amount and time, and the daily reward pop-up waited until
"Nice!" was pressed. **Not tested:** a real rejoin paying out (Studio doesn't save, so it needs
the live game: play, leave for a few minutes, rejoin).

---

## 13. Wanted / bounty

**For players:** a thief who pulls off **3 steals in a row** without being stopped becomes
**WANTED**:
- Everyone gets "*<name> is WANTED! Bonk them to claim the $X bounty!*".
- The thief **glows red** and gets a shimmering red-and-yellow **"WANTED / $32.8K BOUNTY"**
  tag over their head, visible from far away. It stays after respawning.
- The bounty is **25% of the price of every ghost stolen in the streak** and keeps growing with
  each further steal (`GameConfig.WantedStreak`, `BountyShare`).
- The **first player to hit them** with any item (bat, cage or landmine) claims it, and
  everyone sees "*<attacker> claimed the $X bounty on <thief>!*". It's **paid from the thief's
  own cash** (as much as they have), so friends can't farm free money.
- A failed steal (hit, base locked, died) resets a not-yet-wanted thief's streak; once wanted,
  only a hit clears it. Leaving clears it too. Nothing about it is saved.

**How it works:** `BountyService` (streak, bounty, the glow and tag on the character). StealService
calls it on every delivered steal, failed steal and item hit (`knockLoose`, which all items
already go through). `Wanted` / `Bounty` player attributes.

**Tested (solo):** 2 steals → not wanted, 3 → WANTED with the right bounty ($6K + $25K + $100K
→ $32,750), the red glow and the tag (shown in a screenshot); a hit cleared it and paid out.
**Not tested:** real steals and a real bonk between 2 players, and the messages other players
see. A 2-player test is the next thing to do.

---

## 14. New hotbar and equipping items

**For players:** Roblox's built-in hotbar is replaced by one in the game's own style, matching
the Inventory cards (dark gradient, rounded, outlined in the item's colour, a number badge per
slot):
- **Slot 1:** the Bat (always there).
- **Slots 2–4:** the items you've **equipped** from the Inventory (max 3,
  `GameConfig.MaxEquippedItems`). Empty slots show a "+" that opens the Inventory.
- After that: the Cage and Landmine, for the allow-listed players only (unchanged).
- Press **1–9** or click a slot to select it (it grows and gets a white outline); select it
  again to put it away. It hides while you carry a ghost or are caged.

**Inventory:** each card now has an **Equip / Unequip** button, an orange **"EQUIPPED"**
ribbon and outline while it's in the hotbar, and "Hotbar full" when 3 are already equipped.
The header shows "Hotbar: 2/3 equipped". Equipped items are saved (`equipped`).

**Placeholder items still don't do anything:** selecting one in the hotbar just highlights it
(and puts the bat away). Each item's behaviour comes next.

**How it works:** `UI/Hotbar.luau` (turns off Roblox's Backpack hotbar and equips tools itself
with `Humanoid:EquipTool`), `EquipItem` remote handled in `ShopService` (must own it, max 3),
`Equipped` player attribute ("item_4,item_6"). CarryControls no longer touches Roblox's hotbar.

**Tested (solo, with test cash):** bought 3 cash items, equipped all three from the Inventory
(ribbons, "Unequip", counter 2/3 → 3/3, hotbar slots filled in order), key 1 held the bat,
key 3 selected an item and put the bat away, and forged equip requests (unowned or unknown
item) were refused. **Not checked:** the hotbar on a phone-sized screen.

---

## 15. Smoke Bomb (first real item)

**For players:** buy the **Smoke Bomb** in the Shop for **125 gems** (one-time purchase; the
Shop then says "Owned"), equip it from the Inventory, and it appears in your hotbar with its
own sticker-style icon (a dark purple bomb with a lit fuse and a puff of smoke).
- Select it and **click** to use it: a **smoke cloud** bursts where you stand with a **"poof"**,
  and the smoke fades away over **3 seconds**.
- You're **invisible to everyone for 7 seconds** (body, accessories, face, name and any WANTED
  tag). On your own screen a faint purple outline shows where you are.
- It **ends early** if you're knocked over (bat, landmine), caged or die. Either way you
  reappear in **another puff of smoke** with the same poof.
- **No other items while invisible:** the bomb is put away, the hotbar won't select tools
  ("You can't use items while invisible!"), and the server ignores item use.
- **35 second cooldown** from when you use it, shown on the hotbar slot as a shade that shrinks
  with the seconds left (the Cage's cooldown now shows the same way). It survives respawning.

Tuning in `GameConfig`: `SmokeBombSeconds`, `SmokeBombCooldownSeconds`, `SmokeBombFadeSeconds`,
`SmokeBombSound` ("Smoke_Teleport_Poof_4", unknown uploader; pick another by ear if you like).
Price and colour in `ItemConfig`.

**How items work now** (for the next ones): an `ItemConfig` row with `tool = true` gets a real
tool, named by its item id, put in the Backpack while it's equipped (`ItemService.syncItemTools`);
the hotbar's item slot uses that tool. `once = true` makes it a one-time purchase.

**Also:** `GameConfig.StudioTestGemsOn` / `StudioTestGems` (10K gems in Studio, never saved),
like test cash.

**Tested (solo, test cash + gems):** bought it (125 gems, "Owned"), equipped it, used it from
slot 2: invisible for exactly 7.0 s with the bomb put away and the own-outline showing, visible
again after; the smoke cloud showed and faded; the cooldown counted down (tested at 20 s, since changed to 35 s); getting caged
ended it at 2.1 s. **Not tested:** a real bat hit ending it, and what other players see
(2 players).

---

## 16. Gravity item, and the Shop sorted by price

**Gravity** (Shop, **350 gems**, one-time; sticker-style vortex icon): select it and click to
open a **gravity well** around you for **5 seconds**:
- **You're slowed** to walk speed 8 while it's open (back to normal after).
- **Everyone else within 60 studs** (an area 120 studs across, three times a base's length) is
  **pulled toward you** at 30 studs/s, rising to about 40 near the middle, and **slowed to walk
  speed 8** while inside, so they can't walk out of it: **everyone caught reaches the middle**
  (from the very edge, running away, in about 3 seconds).
- Anyone **pulled within 7 studs** of you is caught: a ghost they're stealing **drops and flies
  home** (and a WANTED player's bounty is claimed), just like being bonked. Once per well.
- **Look:** the area is a purple tint on the ground with a **glowing ring at its edge** (the
  edge of the pull), with **streaks of light swirling in** from the ring toward a **dark vortex
  under you**, plus a **warping whoosh** as it opens ("REVERSE NOISE VERB TAIL 10", APM Music) and a rumbling hum while it lasts ("Energy Presence 8", Pro Sound Effects). It grows out when
  opened and shrinks away when closed.
- Ends early if you're knocked over, caged or die. **35 second cooldown** from when you use it,
  shown on the hotbar slot.

Tuning in `GameConfig`: `GravitySeconds`, `GravityCooldownSeconds`, `GravityRadius`,
`GravityPullSpeed`, `GravityUserWalkSpeed`, `GravityVictimWalkSpeed`, `GravityCatchRadius`, `GravitySound`, `GravityWarpSound`.

**Shop order:** cheapest first. Gem items come first, then cash items (125 gems and $5K can't be
compared directly).

**How it works:** `GravityService` (server: the well, the slowdown, catching, the effects
welded to the user; a `GravityUntil` attribute marks the well), `GravityClient` (each player's
own device pulls their character toward an open well, since devices move their own
characters). Item tools now go through one table in ItemService (`ITEM_TOOLS`: the tool and
the service that runs it), so the next item is a row plus its service.

**Tested (solo, test cash + gems):** Shop order (25, 75, 125, 200, 350 gems, then $5K, $50K,
$500K); bought and equipped Gravity; the well lasted 5.2 s, walk speed 8 during and 24.5 after;
the area was 80 studs across with the ring and vortex (screenshots from the player's view and
from above; since made 120 across, with a 35 s cooldown); cooldown overlay. **2-player test:** Player2 carrying Player1's stolen Boo, 50 studs away:
pulled to the middle in 1.5 s (50 -> 40 -> 22 -> 3 studs), dropped the ghost at 1.5 s ("Player1
caught you! The ghost flew home."), walk speed 8 during and 24.5 after.

**Also fixed:** the hotbar's bat slot could show no picture right after carrying a ghost or
respawning (the tool was briefly missing); built-in items now always have their icon.

---

## 17. Universal Key

**For players:** buy the **Universal Key** in the Shop for **250 gems** (one-time; a gold key
icon with a little ghost cut into it), equip it, and click while standing at someone's
**locked** base gate (within 12 studs of the bars):
- The base's owner is told **immediately**: "*<name> is unlocking your base with a Universal
  Key!*", with "*Stop them! Bonk or cage them before the lock breaks.*" above it.
- The unlock takes **2.5 seconds**. A gold key jiggles over the gate with "*<name> is
  unlocking...*" and a progress bar filling up, everyone can see it, and the bars rattle
  ("Door Shake 4", Pro Sound Effects).
- When it finishes, the **lock breaks** with a heavy latch clunk ("Metal Latches 8", Pro Sound
  Effects): the bars drop, both players are told, and the owner's normal wait before relocking
  starts (so they can't relock instantly).
- It's **cancelled** if the key user is knocked over, caged, dies or walks away from the gate
  (the owner is told if they stopped it), or the lock ends on its own first.
- **120 second cooldown**, starting when the unlock begins. Clicking away from a locked gate
  just says "Stand at a locked base's gate to use the key." and doesn't use it up. You can't use
  it on your own base, while invisible, caged or carrying a ghost.

Tuning in `GameConfig`: `UniversalKeyUnlockSeconds`, `UniversalKeyCooldownSeconds`,
`UniversalKeyRange`, `UniversalKeyPickSound`, `UniversalKeyUnlockSound`.

**How it works:** `UniversalKeyService` (finds the nearest locked gate, runs the unlock, shows
the progress over the gate), `PlotService.forceUnlock` / `getPlots`.

**2-player test:** Player1 locked their base; Player2 bought the key (−250 gems), equipped it,
stood at the gate and clicked: Player1 got the warning (with the note) at 0.0 s and "Player2
unlocked your base!" at 2.5 s, the lock wall opened, and the key's 120 s cooldown started.
**Not tested:** the cancel cases (bonked, caged or walking away mid-unlock), because of the long
cooldown.

**Also:** the **Undead** mutation's spawn banner now plays the Legendary chime ("Notification
Chime") and lasts 4 s like the Legendary banner. On an Undead Mythic-or-rarer ghost, the bigger
rarity sound plays instead (`GameConfig.MutationAnnouncements`).

## 18. Gravity buff, and a fix for being slowed for good after a cage

- **Gravity can't be interrupted by hits any more.** While your well is open you can't be
  knocked over: bat swings pass you by and landmines don't go off under you
  (`RagdollService.canKnock` refuses anyone with `GravityUntil` set). Being caged or dying still
  ends the well.
- **Fixed:** being caged while using Gravity left you at the slow Gravity speed forever. The
  cage remembered your speed when it closed (the slowed one) and gave it back when it opened,
  after the well had already ended. The cage now gives back normal walk speed if Gravity was
  open, and the well no longer resets your speed while you're caged.

**Solo test:** with the well open, `canKnock` said no and a knock did nothing (joints stayed
on); the well was still open a second later. Caging then closed the well (speed 0 in the cage),
and after the cage opened the speed was back to the normal 24.5. **Not tested:** a real bat
swing from a second player (the swing uses the same `canKnock` check).

## 19. PolterPuller 4000, and balance changes

A vacuum that sucks other players' ghosts straight into your base (550 gems, bought once).

- **Hold it to capture.** While the PolterPuller is in your hand, other players' ghosts show
  **Capture** instead of Steal. You wear a vacuum tank on your back with a hose to the nozzle in
  your hands (an original design: purple tank with a green glass window).
- **Capturing takes time, by rarity:** Common 3 s, Uncommon 4 s, Rare 5 s, Epic 6 s, Legendary
  9 s, Mythic and rarer 16 s (`GameConfig.CaptureSeconds`). Meanwhile a green suction beam runs
  from the nozzle to the ghost, which shakes, leans in and shrinks; a sign over it shows
  "CAPTURING!", its rarity in its colours and a countdown bar; the vacuum roars.
- **Same rules as stealing to start:** the ghost must be in an unlocked base, you must be inside
  that base, within `CaptureRange` (15 studs), and have a free grave. The owner's steal alarm
  goes off and they get a warning.
- **It's cancelled** if you're knocked over, caged, die, put the vacuum away or walk out of
  range, or the base locks. When it finishes, the ghost pops into the nozzle and appears in your
  base, counting as a steal (Top Thieves, steal streak / WANTED). If the owner leaves
  mid-capture, you get the ghost, like stealing.
- **Cooldown:** 6× the capture time (`CaptureCooldownMultiplier`), whether it worked or not. The
  hotbar shows the right length from the tool's `CooldownTotal` attribute.

**How it works:** `CaptureService` (checks, effects, countdown, finish), `GhostService`
(`CapturePrompt` on each base ghost, `capturing` entries can't be stolen/earn/sell),
`StealService.markRobbed` (alarm for captures), client `GhostPrompts` (Capture vs Steal while
holding it), `ItemService` (nozzle tool and the worn tank). Icon: `scripts/draw-polterpuller-icon.ps1`.

**Tested:** the user tried it in the live game and it works. In Studio, 2-player: Player2 bought
and equipped it, wore the tank, and saw Capture instead of Steal on Player1's ghosts.

**Balance changes** (made by the user): mutations are rarer and stronger (Eerie 1/60 ×2, Spooky
1/120 ×3, Undead 1/250 ×5, Shiny 1/1500 ×10), carrying speed 15.3, cage cooldown 15 s, 2 equip
slots instead of 3, and pricier later grave/lock upgrades.

## 20. Upgrades prompt only on your own base

Every base still has its UPGRADES signpost, but the "Upgrade" prompt now only shows at your own
base; other bases' prompts are hidden on your device (`UI/UpgradePanel`, using your `PlotIndex`).
The server already refused upgrades from anyone but the owner.

**Solo test:** in a playtest on Plot 1, only Plot 1's prompt was enabled; the other 7 were off.
**Not tested:** pressing the prompt to open the window (the Daily Reward pop-up was in the way;
that code didn't change).
