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
| 6 | Shop and Inventory windows | #33 |
| 7 | Daily reward streak (gems) | #34 |
| 8 | Mutations (eerie, spooky, undead, shiny), Divine recolour, Secret price | #36 |
| 9 | First-time tutorial | #37 |
| 10 | Leaderboards in the map | #38 |
| 11 | Base upgrades (More Graves, Longer Lock) | #39 |
| 12 | Offline earnings | #40 |
| 13 | Wanted / bounty for thieves on a streak | #41 |
| 14 | Custom hotbar and equipping items | #43 |
| 15 | Smoke Bomb | #44 |
| 16 | Gravity, and the Shop sorted by price | #45 |
| 17 | Universal Key | #46 |
| 18 | Gravity buff, and a fix for staying slowed after a cage | #47 |
| 19 | PolterPuller 4000, and balance changes | #48 |
| 20 | Upgrades prompt only on your own base | #49 |
| 21 | Lower offline earnings | #50 |
| 22 | Titles: THE GOAT and SUPERNOVA | #51 |
| 23 | Inventory tabs: Items and Titles | #52 |
| 24 | Old placeholder items removed (owners refunded) | #53 |
| 25 | Shield | #53 |
| 26 | Item prices doubled, Smoke Bomb cancels, quieter PolterPuller hint | #54 |
| 27 | Ghost pages in the Index: mutation finds and gems | #55 |
| 28 | Mega Mallet | #56 |
| 29 | Mega Mallet price | #57 |
| 30 | Tennis Racket | #57 |
| 31 | Speed and Carry Speed upgrades; upgrades reset on rebirth | #59 |
| 32 | Upgrade prices doubled | #60 |
| 33 | More Graves is kept through rebirths | #62 |
| 34 | Rebirth titles (REBORN, UNDYING, ETERNAL) and rebirth starting cash | #63 |
| 35 | SUPERNOVA is Winter_Unicorn79's | #63 |
| 36 | Item rarities: card and hotbar colours by rarity | #64 |
| 37 | Rebirth starting cash lowered to 1% | #65 |
| 38 | Spin Wheel: daily and online spins, gems, x2 money, a Mythic item | #65 |
| 39 | Phones: smaller HUD and buttons, Haunted Hour pill at the top | #67 |
| 40 | Phones: base texts 20% smaller | #68 |
| 41 | Mythic text shiny red; Secret and THE GOAT shiny dark grey, looping | #69 |
| 42 | Nuke (the Spin Wheel's Mythic prize) | #70 |
| 43 | Shop tabs: Items, Boosters, Currency (Robux gems), Gamepasses | #72 |
| 44 | Cosmetics: titles, auras, pets, tombstones and flowers (Shop and Inventory tabs) | #73 |
| 45 | Spin Wheel spins for gems in the Shop's Boosters tab | #74 |
| 46 | Gold Tombstones look like shiny cartoon gold | #75 |
| 47 | Mini Pumpkin pet: generated jack-o'-lantern with flapping bat wings | #76 |
| 48 | Ghost Buddy pet: any found ghost, half size, picked from the Index | #77 |
| 49 | Game passes created and on sale (VIP, 2x Money, Auto Collect, cosmetics…) | #78 |
| 50 | Pictures for all eight game passes | #79 |
| 51 | Flashier Golden Sparkles with a chime loop, Smoke Bomb hides effects, rarity sorting | #80 |
| 52 | The Secret ghost is now the Grim Reaper | #81 |
| 53 | The Divine ghost is now the Seraph | #82 |
| 54 | Gem packs can be bought with Robux | #83 |
| 55 | A "!" on the menu tab while something is waiting | #83 |
| 56 | Title rarities and milestone titles | #84 |
| 57 | Flat colours for Legendary-and-below titles | #85 |
| 58 | Codes: redeem codes for gems, cash or spins (side menu → Codes) | #86 |
| 59 | Spin "Get more", 2x Money badge, VIP and Fast Flight buffs | #PR |

**Your to-do list:**
1. **Publish** from Studio so players get all of this.
2. **Design the placeholders:** the Divine and Secret ghosts (names and models,
   `GhostConfig`, section 2) and the Spin Wheel's Mythic item (`mythic_placeholder`: name,
   picture and what it does, `ItemConfig`, section 38).
3. **Pick sounds by ear** if you don't like mine: Divine/Secret spawn banners (they reuse the
   Mythic sound), the rebirth sound and the Haunted Hour thunder (all in `GameConfig`).
4. **2-player tests** I couldn't do alone (Test → Clients and Servers, 2 players):
   leaving mid-steal (section 1), the rebirth pillar and message as seen by the other player
   (section 3), and rebirth being blocked while someone steals from you. Later sections list
   their own untested parts under **Tested** / **Not tested**.
5. **In the live game:** real friends joining (section 5), the invite window, the next-day
   daily streak (section 7), and the Spin Wheel's saving: unused spins, the x2 boost carrying
   over a rejoin, and the free spin after midnight (section 38).
6. Tune numbers if needed: rebirth costs, Haunted Hour timing and luck, friend boost, daily
   gems, Spin Wheel prizes and odds, and ghost prices/odds are all in `GameConfig` /
   `GhostConfig`.

Sections 1 to 7 removed nothing. The only behaviour changes they made to features that
existed before are: the leave-mid-steal rule (section 1), the ghost label in your base showing
rebirth-boosted income, and pop-up messages now drawing above open windows (section 6).

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

## 21. Lower offline earnings

Offline earnings now pay 20% of your income while you were away, down from 50%
(`GameConfig.OfflineIncomeShare`, changed by the user). Not playtested (a one-number change).

## 22. Titles: THE GOAT and SUPERNOVA

Titles are words shown above a player's head (everyone sees them) and in front of their name in
chat. One at a time, picked in the Inventory.

- **THE GOAT:** the Secret rarity's colours (silver stripes with a blood-red streak).
  **SUPERNOVA:** red and purple with a hot pink flash. Both slide their colours like the high
  rarities, and a white glint sweeps across them every few seconds so they look reflective.
- Both are only available to the game's creator for now (`allowedUserIds` in `TitleConfig`).
  Titles can also be saved as earned (`DataService.grantTitle`), ready for ways to earn them later.
- **Inventory:** owned titles get cards after the items, showing the animated title, with
  **Wear** / **Take off**; the worn one has a "WEARING" ribbon. The first time you own a title
  (and have never picked one), it's put on for you. The choice is saved.
- **Chat:** your messages start with the title, e.g. "[THE GOAT] jerizaxe:", each letter coloured
  from its gradient (chat text can't animate).
- Hidden while invisible (Smoke Bomb). A WANTED tag moves up above the title.

**How it works:** `Config/TitleConfig` (the titles), `Shared/TitleText` (draws a title with its
gradient and glint, plus the chat version), `TitleService` (ownership, `Title` / `Title_<id>`
attributes, the head tag, `EquipTitle` remote), client `ChatTitles`, the Inventory cards, and
`GradientAnimator` sweeping `ShineGradient` glints. New save keys: `title`, `titles`.

**Solo test:** THE GOAT was put on automatically and showed above the head; the Inventory showed
both title cards (THE GOAT "WEARING" with Take off, SUPERNOVA with Wear); a chat message came
through as "[THE GOAT] jerizaxe:" with the coloured letters. **Not tested:** pressing Wear on
SUPERNOVA (the test click failed), how the title sits with someone else's name tag and a WANTED
tag (needs 2 players), and saving (live game only).

## 23. Inventory tabs: Items and Titles

The Inventory window now has two tabs under its header: **Items** (the Shop items, with the
"Hotbar: n/2 equipped" count) and **Titles** (your titles, with Wear / Take off). Each tab has
its own empty message ("Nothing here yet. Visit the Shop!" / "No titles yet."). It opens on Items.

**Solo test:** with two items bought (test gems), Items showed Smoke Bomb and Gravity and the
hotbar count; Titles showed THE GOAT (WEARING) and SUPERNOVA, with the count hidden. Pressing Wear
on SUPERNOVA switched the title above the head to SUPERNOVA.

## 24. Placeholder items removed

The six "Placeholder Item" rows are gone from the Shop and Inventory; only the real items are
left (Smoke Bomb, Universal Key, Gravity, PolterPuller 4000). Anyone who bought a placeholder is
refunded its price (gems or cash) when they next join, with a message, and it's removed from
their save (`RETIRED_ITEMS` in `DataService`). Unknown items are also dropped from the hotbar.

**Solo test:** the Shop showed only the four real items, no errors. **Not tested:** the refund
(Studio can't load a save that owns placeholders; it runs on join in the live game).

## 25. Shield item

A new Shop item (150 gems, bought once): click it for **7 seconds of immunity to crowd control**.

- While shielded, bat hits and landmines can't knock you over, cages can't catch you, and
  Gravity wells don't pull, slow or catch you.
- **Three shield icons circle you** so everyone can see it; they blink in the last second and
  hide while you're invisible (Smoke Bomb).
- **Ends straight away when you steal a ghost** (picking one up, or starting a PolterPuller
  capture), and when you die.
- **25 second cooldown**, starting on use. Can't be used while invisible, caged, knocked over or
  carrying a ghost.
- Icon: a blue shield with a ghost emblem (`scripts/draw-shield-icon.ps1`). No sound yet.

**How it works:** `ShieldService` (`ShieldUntil` attribute), checked by
`RagdollService.canKnock`, `CageService.trap`, `GravityService` (catch) and client
`GravityClient` (pull); `CaptureService` ends it on capture; client `ShieldClient` draws the
orbit; `ItemService` builds the held buckler.

**Solo test:** bought it (−150 gems), equipped and used it: shield for 7.0 s (ended at 7.06 s),
3 icons circling, 25 s cooldown on the hotbar. While shielded, knockback was refused and a cage
didn't catch. Setting `Carrying` (picking up a ghost) ended it in 0.03 s.
**2-player test (Gravity):** Player1 opened a well with shielded Player2 28 studs away: Player2
stayed at 28 studs and kept full walk speed. The same well without the shield pulled Player2
from 26 to 3 studs and slowed them to 8. **Not tested:** real bat/cage swings from another player
(they use the same checks as the solo test).

## 26. Item prices doubled, Smoke Bomb cancels, quieter PolterPuller hint

- **Gem prices doubled:** Smoke Bomb 250, Shield 300, Universal Key 500, Gravity 700,
  PolterPuller 4000 1,100.
- **Smoke Bomb can be cancelled:** while invisible, picking the Smoke Bomb again (its hotbar key
  or slot) ends the invisibility straight away, in a puff of smoke. Picking up a stolen ghost
  ends it too. Other items still can't be used while invisible; the cooldown isn't reset.
- **PolterPuller:** clicking with it shows the "Walk up to someone's ghost and press Capture!"
  hint at most once every 3 seconds, instead of on every click.

**Solo test:** the Shop charged 250 and 1,100 gems. Cast the Smoke Bomb, then took it out again:
visible again in 0.07 s; cast again and pressed its hotbar key (2): visible again, holding it.
Cast again and set `Carrying` (picking up a ghost): visible again in 0.03 s. Five PolterPuller
clicks over about 3.5 s showed the hint twice (0 s and 3.3 s).

## 27. Ghost pages in the Index: mutation finds and gems

- **Click a found ghost in the Index** to open its page: the model big on the left (turning),
  its name and rarity under it, and its four mutations on the right (Eerie, Spooky, Undead,
  Shiny) with their income boost. A mutation you haven't owned this ghost with is greyed out
  ("Not found"); a found one shows in its own colours, shimmering. "< Back" returns to the grid.
- **Each ghost × mutation pays gems once:** Eerie 10, Spooky 25, Undead 75, Shiny 175 (half the
  first idea, since every ghost has its own). A Spooky Boo and a Spooky Sheet Ghost each pay.
  Claim one by pressing its row, or with the page's green **Claim all** (bottom right).
- The Index's main **Claim all** now claims every ghost reward *and* every mutation reward.
- Ghost cards with mutation gems waiting show a **red "!"**; the side-menu badge and the Claim
  all count include mutation rewards.
- Finds are saved and **not reset by rebirth** (`mutationsFound` / `mutationsClaimed`). Mutated
  ghosts already in a base count as found when the player joins.

**How it works:** `MutationConfig.indexGems`; `DataService.setGhost` records the find
(`IndexMut_<ghostId>_<mutationId>` attribute), `canClaimIndexMutation` /
`markIndexMutationClaimed` (`IndexMutClaimed_...`); `IndexService` handles the new
`IndexClaimMutation` remote (one, or "all" for a ghost) and adds mutation rewards to "all";
`UI/IndexPanel` builds the page.

**Solo test** (test cash and every walkway ghost mutated): bought a Spooky Sheet Ghost: found
attributes set, card "!" and the counts went up; the page showed Spooky in colour with "Claim 💎25"
and the other three greyed; pressing the row paid 25 ("Claimed ✓"). Bought a Spooky Banshee
(a separate find); the main Claim all paid the Banshee's ghost reward and its Spooky reward
together. On a Spooky Poltergeist, the page's Claim all paid 25 and the "!" went away; Back
returned to the grid.

## 28. Mega Mallet

A new Shop item (2,500 gems, bought once): a giant mallet that launches everyone in front of you.

- **Click while standing on the ground:** you're frozen in place (root anchored by the server,
  like the cage) for a **2 second wind-up**, leaning far back with the mallet raised behind your
  head, trembling as it loads up.
- **Red warning cone:** a see-through red slice of the ground grows from you to the full hit
  area over 1.5 s, then pulses until the slam, so everyone can see where it'll land. The hit area
  is **112.5 studs** long (1.5x Gravity's radius, plus 25%) and **50 degrees each side** of where
  you face.
- **The slam:** you lunge forward and drive the head into the ground in front. A flash, a dust
  cloud, sparks and flying rocks burst from the impact; three glowing shockwave rings race out
  through the cone; rows of rock spikes with red-hot bases burst out of the ground as the wave
  passes, then sink back; nearby cameras shake.
- **Hits:** everyone the shockwave reaches inside the cone (at 150 studs per second) is launched
  as high as a landmine and stays floppy for **3.5 s after landing** (double a landmine). A thief
  drops the ghost they were carrying. Shielded, caged or already knocked-over players aren't hit.
- **Cancelled** if you're knocked over, caged, die or put the mallet away during the wind-up.
- **62.5 second cooldown**, starting on use. Can't be used while invisible, caged, knocked over
  or carrying a ghost.

**How it works:** `MalletService` (checks, the anchored wind-up, `MalletUntil` attribute, the
cone hit timed to the wave, `MalletSwing` remote to every device); client `MalletClient` (the
animation on the waist, shoulders, wrist, hips and knees, timed to the server's slam moment; the
cone and wave as pictures on flat parts; spikes, debris and camera shake). `RagdollService`
un-anchors a swinger who gets hit. The tool, icon and ground pictures: `ItemService`,
`scripts/draw-mallet-icon.ps1`, `scripts/draw-mallet-cone.ps1` (drawn at the same angle as
`MegaMalletHalfAngle`; redraw and re-upload if that changes). Sounds reuse the Gravity warp
(wind-up) and the landmine boom (slam).

**Solo test:** bought it (2,500 gems), 62.5 s cooldown. The swinger stayed anchored for 2.0 s and
was released at the slam. Screenshots with a marker in front confirmed the wind-up leans back with the
mallet raised behind the head and the slam leans forward with the head in the ground (picked by
the user after trying a few versions); the cone
grows in front, the size and angle match the settings, and the spikes and waves sweep out
through it. Putting the mallet away mid wind-up unfroze the player, removed the cone, and no slam
followed.
**2-player test:** Player1 swung at Player2 standing 50 studs straight ahead: the hit arrived
0.33 s after the slam (the wave's travel time), Player2 was launched with (50, 125, 0) (away
from Player1, landmine strength), got "Player1 flattened you with the Mega Mallet!", and was
down for 5.1 s (in the air, then 3.5 s after landing); Player1 got "SMASH! You launched 1
player!". With Player2 40 studs away at 60 degrees to the side (outside the 50 degree cone), the
swing didn't hit them. One earlier swing hit nobody, most likely because the tool was replaced
while it was still loading in (that counts as putting it away).

## 29. Mega Mallet price

The Mega Mallet now costs 2,000 gems (was 2,500). Not playtested (a one-number change).

## 30. Tennis Racket

A new Shop item (200 gems, bought once).

- **Swings and hits exactly like the bat:** same range, arc, swing animation and speed, no
  cooldown, same launch height. Thieves it hits drop their ghost.
- **Knocks people 11 times further back** than the bat: push (55, 60, 0) vs the bat's (5, 60, 0).
- **Longer protection:** after getting up from a racket hit, a player can't be knocked over again
  for 1.9 s (1.9x the bat's 1 s).
- **Tennis "thwock" on hit:** Pro Sound Effects' "Tennis Ball Hits CU Impacts 3", only the racket
  hit (0.7 s from 1.27 s into the clip; the rest is footsteps and bounces).
- Orange racket model with white strings; icon from `scripts/draw-racket-icon.ps1`.

**How it works:** the racket is an Inventory tool (`tennis_racket`) that goes through the bat's
`swing` / `ITEMS` path with its own `racketHits`. Config: `RacketPushMultiplier`,
`RacketImmunityMultiplier`, `RacketIcon`, `RacketHitSound` (GameConfig). `RagdollService.knock`
takes an optional `immunitySeconds`; `playBonk` plays a sound from `startAt` for `length`.

**Tested:**
- 2-player, first version (2x push and height): bought for 200 gems; the racket hit made the
  tennis sound and launched Player2 (10, 120, 0); a bat hit gave (5, 60, 0).
- The user found the hit sound silent: the clip's racket hit is at 1.33 s and was being cut off
  at 0.7 s. Fixed by starting at 1.27 s; a server-made copy measured loud on the client (peak
  181; the bat's bonk is about 238).
- The user tested the 3x-distance version themselves.

**Not tested:** the final 11x push and 1.9 s immunity in a 2-player test.

## 31. Speed upgrades, and upgrades reset on rebirth

Two new cards in the Upgrades window (now titled just **Upgrades**, four cards in a row):

| Upgrade | Per level | Max (5 levels) | Costs |
|---|---|---|---|
| **Speed** | +20% walk speed | x2 (24.5 → 49) | $3K · $15K · $60K · $250K · $1M |
| **Carry Speed** | +6% speed while carrying a stolen ghost | x1.3 (15.3 → 19.9) | $5K · $25K · $100K · $400K · $1.5M |

- A bought level applies straight away (and on every respawn).
- **All upgrades now reset on rebirth**, including More Graves and Longer Lock (they used to be
  kept). The Rebirth window's "You lose" line now says so.

**How it works:** `Upgrades.walkSpeed(player)` / `Upgrades.carrySpeed(player)` (Shared) read the
`Upgrade_speed` / `Upgrade_carry` attributes; everything that sets or restores walk speed
(`init.server.luau` on spawn, StealService, CageService, GravityService) uses them.
UpgradeService re-applies the speed when either level changes (skipped while caged or in your
own Gravity well; those restore it when they end). `DataService.applyRebirth` clears
`upgrades`. Config: `SpeedUpgradeCosts`, `SpeedUpgradeBonus`, `CarrySpeedUpgradeCosts`,
`CarrySpeedUpgradeBonus` (GameConfig).

**Tested (solo, with test cash):** buying Speed went 24.5 → 29.4 → … → 49 and stopped at
level 5; Carry Speed maxed at level 5 (19.89 by the formula); the window showed all four cards;
after a rebirth every level was 0 and speed was back to 24.5, also after respawning. No errors.
**Not tested:** the carry speed while actually stealing (needs a 2-player test).

## 32. Upgrade prices doubled

Every upgrade costs twice as much, then More Graves level 2 and the first two Longer Lock levels were raised further:

| Upgrade | Costs |
|---|---|
| More Graves | $10K · $250K · $1M · $5M |
| Longer Lock | $100K · $1M · $5M |
| Speed | $6K · $30K · $120K · $500K · $2M |
| Carry Speed | $10K · $50K · $200K · $800K · $3M |

Not playtested (only the numbers in `GameConfig` changed).

## 33. More Graves is kept through rebirths

Rebirthing now resets Longer Lock, Speed and Carry Speed but **keeps More Graves**. The Rebirth
window's lose/keep lines say so. (`DataService.applyRebirth` clears every upgrade except
`graves`.)
**Tested (solo, test cash):** bought More Graves ×2, Longer Lock, Speed and Carry Speed, then
rebirthed: graves stayed at 2, the other three went to 0 and walk speed went back to 24.5. The
new Rebirth window lines fit.

## 34. Rebirth titles and starting cash

**Rebirth titles:** reaching rebirth 1, 5 and 10 unlocks a title:

| Title | Rebirths | Look |
|---|---|---|
| **REBORN** | 1 | plain purple |
| **UNDYING** | 5 | plain orange |
| **ETERNAL** | 10 | shiny silver (Eerie's colours, with the glint) |

- The Inventory's Titles tab shows them even while locked: the word is dimmed, the card says
  "Locked: 5 rebirths", and a progress bar replaces the Wear button ("1/5 rebirths"). The bar
  counts rebirths done plus your cash toward the next rebirth, so it fills as you play.
  Owned titles come first, then the locked ones.
- Unlocking one shows "New title unlocked: REBORN!" a few seconds after the rebirth
  celebration. Someone who has never picked a title puts it on automatically.
- Players who already have rebirths get their titles when they join.

**Starting cash:** after a rebirth you restart with 10% of what that rebirth cost (rebirth 1:
$5K, rebirth 2: $25K) instead of $100. The Rebirth window's "You keep" line says how much.

**How it works:** TitleConfig rows can have `rebirths = N`; `TitleService` treats them as owned
once the player has that many rebirths, and `TitleService.rebirthed` (called by RebirthService)
unlocks new ones. `Rebirth.startingCash(rebirths)` (Shared) → `DataService.applyRebirth`.
Config: `RebirthStartingCashShare`, `RebirthTitleMessageDelay` (GameConfig).

**Tested (solo, test cash):** the Titles tab showed REBORN, UNDYING and ETERNAL locked with
bars; rebirthing gave $5K cash and unlocked REBORN (Wear button, unlock message); UNDYING's bar
then read "1/5 rebirths" at 20.4% and ETERNAL's "1/10" at 10.2%; the Rebirth window said
"restart with $25.0K"; all text fit. The delay on the unlock message was added after that test
and wasn't re-checked.

## 35. SUPERNOVA is Winter_Unicorn79's

The SUPERNOVA title is now only for Winter_Unicorn79 (UserId 701124691, looked up in Studio);
the creator no longer has it. If you were wearing it, you'll show no title until you pick
another one in the Inventory. Not playtested (an allow-list change; the other account can't
join a Studio test).

## 36. Item rarities

Every item now has a rarity, using the same colours as the ghosts: Tennis Racket **Rare**
(blue), Smoke Bomb and Shield **Epic** (purple), Universal Key, Gravity and PolterPuller
**Legendary** (gold), Mega Mallet, Cage and Landmine **Mythic** (red). Item cards in the Shop
and Inventory and hotbar slots take their rarity's colour, and Shop/Inventory cards show the
rarity word above the picture (Legendary and Mythic shimmer, like the ghosts' rarity words).

**How it works:** each `ItemConfig` row has `rarity` instead of its own `color`; ItemConfig fills
in `item.color` from `GhostConfig.Rarities`, so anything that colours an item by `item.color`
follows the rarity automatically. `ItemConfig.ToolRarities` gives the Cage and Landmine theirs
(the Bat has none and stays brown). `Window.rarityLabel(picture, item)` draws the word.

**Tested (solo):** the Shop showed blue/purple/gold cards with RARE/EPIC/LEGENDARY words, the
Inventory showed the Mythic Mega Mallet in red, and the hotbar slots were blue (racket), purple
(shield) and red (landmine); no errors. On equipped Inventory cards the EQUIPPED ribbon covers
the rarity word (the colour still shows). The Cage's colour wasn't seen (not on my account).

## 37. Rebirth starting cash lowered to 1%

After a rebirth you now restart with 1% of what that rebirth cost instead of 10% (rebirth 1:
$500 instead of $5K, rebirth 2: $2.5K instead of $25K); never less than the normal $100.
One number: `RebirthStartingCashShare = 0.01` (GameConfig). Not playtested (a config change;
the Rebirth window's "You keep" line reads the same number).

## 38. Spin Wheel

A **Spin!** button (bottom right, above Daily reward) opens the Spin Wheel. You get one free
spin each day (midnight UTC) and one for every 10 minutes you play in a row; the 10-minute timer
starts over every time you join. Unused spins are saved. The button shows how many spins you
have, or the time until the next one.

Prizes (each slice shows its odds): 10 gems 35%, 20 gems 30%, 50 gems 15% (blue slices),
x2 money for 10 mins 12%, x2 money for 30 mins 7% (green), and a Mythic item 1% (red, the
Mythic rarity colour). The money boost doubles ghost income, shows as "x2 9:41" next to your
income, only counts down while you're playing, and winning another adds its time.

**The Mythic item is a placeholder:** `mythic_placeholder` in ItemConfig ("Mythic Item", no
picture, not sold in the Shop, not usable). Give it a name, picture and what it does; keep its id.

**How it works:** `SpinService` (server) picks the prize by weight, tells the spinner's device
where to stop (`SpinResult`), and pays out when the wheel stops (or at once if they leave
mid-spin). Data: `spins`, `spinDay`, `moneyBoostLeft`. Attributes: `Spins`, `NextSpinAt`,
`MoneyBoostUntil`. Config: `SpinPrizes`, `SpinOnlineSeconds`, `SpinBoostMultiplier`,
`SpinSeconds` (GameConfig). Window: `UI/SpinPanel`; pictures from `scripts/draw-spin-wheel.ps1`.

**Tested (solo):** the free daily spin arrived on join; spinning landed on 10 gems and paid
+10 gems; setting the online timer to 2 seconds gave a spin and restarted it at 10:00; the
boost doubled income (Boo: $3/s → $6/s) and the HUD showed its clock; the Mythic item showed
in the Inventory in red without an Equip button. Not tested: winning a boost or the Mythic item
from an actual spin (forced instead), the boost carrying over a rejoin, and the daily spin at
midnight (saving only works in the live game).

**Update: wheel motion.** While nobody is spinning, the wheel drifts slowly round. Pressing
Spin speeds it straight up to full speed (no jump), then it slows down dramatically over about
5 seconds (at least 3 more turns) and stops on the prize; after 3 seconds it starts drifting
again. The whole spin now takes 6 seconds (`SpinSeconds`). The motion numbers are at the top of
`UI/SpinPanel`. **Tested:** measured the speed 4 times a second: 18°/s drifting, up to ~900°/s,
then down smoothly to 0; it stopped on 20 gems and 20 gems were paid.

## 39. Phone layout: smaller HUD, Haunted Hour pill at the top (#67)

On phones and tablets (a touch screen and no keyboard), these are now 30% smaller: the money,
income and gems in the bottom-left, the Invite friends, Daily reward and Spin buttons in the
bottom-right (still stacked neatly), and the titles above everyone's head. The Haunted Hour
countdown pill moves up into the top bar's row (the middle of that row is empty). PC is unchanged.

**How it works:** `UI/Mobile` decides once whether this device is a phone (`Mobile.isMobile`) and
gives `Mobile.scale` (`GameConfig.MobileHudScale`, 0.7, on phones; 1 elsewhere). Each piece's
existing UIScale starts at that size and its pop/pulse/hover is multiplied by it.
`Mobile.start` shrinks the server-built `TitleTag` billboards on this device only.

**Tested (solo, phone mode forced on for the test and switched back off):** the cash display
measured 238×67 (was 340×96), the buttons 105 wide (was 150), title tags 168×29 (was 240×42),
the buttons stacked without overlapping, and the pill sat at the very top. Not tested: a real
phone or Studio's device emulator, and the floating "+$"/"+N gems" positions on a phone.

## 40. Phones: base texts 20% smaller (#68)

On phones and tablets, the floating text on the bases is 20% smaller: ghost names, mutations,
rarities and incomes, and the collect pads' "COLLECT $X". The base signs ("Empty Base" / a
player's base), "Step here to LOCK" and ghosts on the walkway keep their size. PC is unchanged.

**How it works:** `UI/Mobile` shrinks the server-built `GhostLabel` and `StoredCash` billboards
on this device only (not those under `workspace.WalkwayGhosts`): the billboard gets
`GameConfig.MobileBaseTextScale` (0.8) of its size, and a UIScale inside shrinks its text to match.

**Tested (solo, phone mode forced on for the test and switched back off):** bought a Wisp; its
base label measured 152×68 (was 190×85) with the name at 80% width, the
collect pads 96×44 (was 120×56), walkway labels stayed 190 wide, and the screenshot showed the
lock text and base sign unchanged. Not tested on a real phone.

## 41. Mythic shiny red; Secret and THE GOAT shiny dark grey, looping (#69)

Mythic text everywhere (ghost labels, the Index, spawn banners, the sell pop-up, item cards,
the capture sign) is now shiny red instead of rainbow: deep red with bright highlights, still
sliding back and forth. The Spectre King's sparkle stars stay rainbow.

Secret text no longer looks like Mythic: it's dark grey with two thin white shines that scroll
one way in a seamless loop (5 seconds per loop) instead of sliding back and forth. THE GOAT
title now uses the Secret colours, so it matches and follows any future change.

**How it works:** the colours are `Theme.RarityGradients.Mythic` / `.Secret`; THE GOAT's
`gradient` is `Theme.RarityGradients.Secret`. `GradientAnimator` scrolls any `AnimatedGradient`
whose colours are in its `LOOPING` list (Secret) by shifting the colours along each frame and
wrapping them round (`LOOP_SECONDS`); a looping pattern must start and end on the same colour.
The big spawn banner hands a looping gradient to GradientAnimator instead of its own swing.

**Tested (solo):** fired the Mythic and Secret spawn banners from the server and screenshotted
them; THE GOAT above the head showed the new colours; measured the shine moving one way
(0.1 of the width every half second, wrapping round) on the title and the banner. Not tested:
a Secret ghost's label on the walkway (no Secret ghost spawned; same gradient code path).

## 42. Nuke: the Spin Wheel's Mythic prize (#70)

The Spin Wheel's Mythic slice now gives the **Nuke** (not sold in the Shop): a remote control
with a big red button, equipped from the Inventory like other items. Pressing it tells everyone
"X HAS LAUNCHED A NUKE!" with a 5-second countdown, beeps, an air-raid siren and a red screen
pulse. Then everyone is frozen while a cutscene shows the nuke falling onto the middle of the
map from a low camera that follows it down. When it hits, the screen flashes, the cutscene ends
and every player (the launcher too) is launched up and away: 1.5x the Mega Mallet's push and
lift, the same 3.5 s ragdoll. Thieves drop their ghost. Cooldown 200 s; one nuke at a time per
server. A launch also puts everyone else's nuke on a 50 s cooldown
(`NukeSharedCooldownSeconds`; a longer cooldown already running is kept). Anyone who had won the old "mythic_placeholder" item gets a Nuke instead.

**How it works:** `NukeService` (server) checks the use, sends `NukeLaunched` (name, cutsceneAt,
explodeAt, target) to everyone, anchors every free character for the cutscene (no items work
meanwhile, `NukeService.isFrozen()`), then unanchors and launches them with
`RagdollService.knock`. `NukeClient` plays the countdown, sounds, cutscene camera, nuke model
and explosion (fireball, shockwave ring, mushroom cloud, camera shake) from those times.
Tuning and sounds are the `Nuke*` values in `GameConfig`; the remote is built in `ItemService`
(`buildNukeRemote`); icon `assets/nuke-icon.png` (`scripts/draw-nuke-icon.ps1`). Shielded,
caged or already-ragdolled players aren't launched (same rule as every other knock).

**Tested (solo):** won it from the wheel, equipped it, saw the remote in hand and on the wheel's
Mythic slice; you played the warning, sounds and cutscene and confirmed they work. Not tested:
other players being launched and thieves dropping ghosts (needs a 2-player test). The falling
whistle sound is from an unknown uploader (Grummgus); the others are Pro Sound Effects.

## 43. Shop tabs: Items, Boosters, Currency, Gamepasses (#72)

The Shop now has four tabs:
- **Items**: the items, as before.
- **Boosters** (gems, stack by adding time): 2x Money for 15 min (150 gems, the same boost as the
  Spin Wheel's prize), Server Luck for 15 min (250 gems: Epic-and-rarer walkway ghosts are 2x as
  likely *for everyone in the server*, everyone is told who started it; stacks with Haunted Hour),
  Speed Boost for 10 min (75 gems, +30% walk speed). A running booster shows "ACTIVE mm:ss" on its
  card. Money and Speed pause while you're offline; Server Luck ends with the server.
- **Currency**: gem packs for Robux (500 / 1,200 / 3,000 / 8,000).
- **Gamepasses** (Robux): 2x Money (double income forever), VIP (gold VIP title, put on when
  bought, and +10% income), Extra Hotbar Slot (3 equipped items instead of 2), Fast Flight
  (bought ghosts fly home 2x faster), Auto Collect (income goes straight to your cash).

**Before the Robux tabs work:** make the products on the Creator Hub (your experience →
Monetization → Developer Products for the 4 gem packs, Passes for the 5 passes), set their
prices there, and paste each ID into `src/shared/Config/StoreConfig.luau` (`productId` /
`passId`). While an ID is 0 the card says "Coming soon". Prices on the cards are read from Roblox.

**How it works:** `StoreConfig` lists everything; `StoreService` sells boosters (`BuyBooster`
remote), pays gem packs in `ProcessReceipt` (each purchase id is remembered in the save, so it's
never paid twice, and the save happens straight away), checks owned passes on join and sets
`Pass_<id>` player attributes (also straight after a purchase). Effects: `EconomyService`
(2x Money, VIP, Auto Collect), `GhostService` (Server Luck, Fast Flight), `Upgrades.walkSpeed`
(Speed Boost) and `Upgrades.maxEquipped` (Extra Hotbar Slot, used by the hotbar, Inventory and
ShopService). The VIP title is a `TitleConfig` row with `gamePass = "vip"`. Tuning numbers are in
`GameConfig` (`LuckBoost*`, `SpeedBoostBonus`, `PassMoneyMultiplier`, `VipIncomeBonus`,
`PassExtraSlots`, `FastFlightMultiplier`). Card pictures are emoji for now (gem packs use the gem icon).

**Tested (solo, Studio):** all four tabs and their cards; buying all three boosters (gems taken,
timers start, speed 24.5 → 31.9, a made-up booster id is ignored); faking every pass on the
server: the hotbar got a third item slot, a bought Wisp flew home at ~2x speed, income was $4/s
($1 × 1.1 VIP × 2 booster × 2 pass) and went straight to cash without the pad. **Not tested:**
real Robux purchases (need the IDs; then try them in Studio, where purchases are free test
purchases), the VIP title unlocking on purchase, boosters carrying over a rejoin (saving only
works in the live game), and Server Luck's announcement to other players (2-player test).

## 44. Cosmetics: titles, auras, pets, tombstones, flowers (#73)

A new **Cosmetics** tab in the Shop (between Boosters and Currency) and in the Inventory (between
Items and Titles). Everyone sees them; they don't change the game.

| Cosmetic | Kind | Price |
|---|---|---|
| PHANTOM title (pale ghostly blue) | Title | 500 gems |
| NIGHTMARE title (blood red, shiny) | Title | Robux |
| Purple Flames | Aura (flames around your feet) | 750 gems |
| Golden Sparkles | Aura (gold glitter around you) | Robux |
| Mini Pumpkin | Pet (glowing jack-o'-lantern that floats beside you) | 1,000 gems |
| Bat Buddy | Pet (purple bat with red eyes) | Robux |
| Gold Tombstones | Your base's tombstones turn gold | 1,500 gems |
| Ghost Lilies | Glowing flowers beside your graves | 400 gems |

Buying one puts it on straight away; the Inventory's Cosmetics tab has Wear / Take off (one of
each kind at a time). Bought titles go in the Titles tab like the others. The aura and pet hide
while you're invisible (Smoke Bomb); your base goes back to normal when you leave.

**Before the Robux ones work:** make a **game pass** for each (Creator Hub → Monetization →
Passes) and paste its ID into `passId` in `src/shared/Config/CosmeticConfig.luau`. Until then
they say "Coming soon".

**How it works:** `CosmeticConfig` lists them (one row each, so more is easy), `CosmeticModels`
builds the looks in code, `CosmeticService` handles buying (`BuyCosmetic`), wearing
(`WearCosmetic`), saving (`cosmetics`, `worn`) and putting them on characters and bases. The two
titles are `TitleConfig` rows with `cosmetic = <id>`. Card pictures are emoji for now.

**Tested (solo, Studio):** bought all five gem cosmetics (right gems taken; the Robux one and a
made-up id refused), saw each one (flames, pumpkin, gold tombstones, lilies, PHANTOM title), took
them off and put them back, a not-owned or wrong-kind cosmetic is refused, the aura and pet
vanish during the Smoke Bomb and come back. Gave myself the two Robux ones on the server: the bat
and the gold sparkles show. Both Shop and Inventory tabs look right. **Not tested:** real game pass
purchases (need IDs), cosmetics coming back after rejoining (saving only works live), what other
players see (2-player test) and the base resetting when its owner leaves.

## 45. Spins for gems (Boosters tab)

The Shop's Boosters tab now sells Spin Wheel spins: **1 Spin for 60 gems, 2 Spins for 110, 3
Spins for 150**. They're added straight away (the Spin! button's count goes up) with a message
pointing to the Spin Wheel.

**How it works:** three rows in `StoreConfig.Boosters` with `spins` instead of `seconds`;
`StoreService` gives them with `DataService.addSpins`. The Shop's cards don't show an "ACTIVE"
timer for them.

**Tested (solo, Studio):** bought each pack from the client: spins went 1 → 2 → 4 → 7 → 8 and the
right gems were taken (60, 110, 150), no errors; the four cards' text reads right. **Not
tested:** a screenshot of the Shop window (the capture didn't show it), and bought spins being
kept after rejoining (saving only works live).

## 46. Shiny cartoon Gold Tombstones

The Gold Tombstones cosmetic used to just paint the stones plain yellow. Now it looks like
cartoon gold: bright gold stones with a darker gold outline, white shine streaks on the rounded
top (upper left, like the game's icons), dark-brown R.I.P. lettering, a few twinkles, and a soft
warm glow (dimmer than the collect pads). The plinth under each stone and the grave's border turn
a slightly deeper gold; the soil stays as it is.

**How it works:** the style in `CosmeticModels.Tombstones` now has `trimColor`, `reflectance`,
`textColor` and a `decorate` function (outline, shine streaks, twinkles and a dim PointLight per
stone). `CosmeticService.paintTombstones` paints the stones and trim, puts the extra parts in a
`CosmeticTombstones` folder, and clears it all when the tombstones are taken off.

**Tested (solo, Studio):** wore it and checked screenshots of the stones, trim and glow; took it
off (plain stones back, nothing left over) and put it back on; no errors. **Not tested:** the
twinkles (Studio screenshots don't show particles), what other players see (2-player test), and
how it looks on a base with all its graves unlocked.

## 47. Mini Pumpkin pet: a jack-o'-lantern with bat wings

The Mini Pumpkin pet used to be a ball with neon dots. Now it's a model generated in Studio: a
cartoon jack-o'-lantern with a curly stem, a face carved deep into it and painted glowing yellow
inside, and two purple bat wings. A warm light behind the face makes it shine in the dark map,
the wings flap, and the pet slowly floats up and down beside its owner.

**How it works:** the model is in `ServerStorage.CosmeticMeshes.pet_pumpkin` (saved with the
place, not git; the untouched original is in `ServerStorage.CosmeticMeshBackups`): a `Body`
mesh with a `Glow` attachment, and `WingLeft` / `WingRight` meshes, each with a `Hinge`
attachment and a `Side` attribute. `CosmeticModels` (`MESH_PETS`) clones and scales it, adds
the light, and joins each wing with a Weld tagged `FlappingWing`. The new client script
`PetAnimation` flaps the wings by turning those welds, and floats your own pet by moving the
attachment it follows (your device moves your pet, so everyone sees it float). If the model is
missing, the old code-built pumpkin is used.

The face isn't cut all the way through: Studio's solid modelling can cut real holes, but the cut
meshes showed up as grey boxes in a playtest, so the generated face is used instead.

**Tested (solo, Studio):** wore the pet; screenshots from the front and back in the dark map
(face glowing, wings in place); wings flapping; it stays 3.4 studs away while walking; it floats
0.6 studs up and down, seen the same on the server; it disappears while Invisible and comes back
after; no errors. **Not tested:** what other players see (2-player test).

**Remember:** save and publish the place, or the new model is lost.

## 48. Ghost Buddy pet (replaces Bat Buddy)

The Bat Buddy pet is now **Ghost Buddy**: a half-size copy of one of your ghosts that follows
you around. It's a Wisp until you pick another one: open a ghost you've found in the Index and
press the new pink **Equip as pet** button (it shows once you own Ghost Buddy, and reads "Your
pet ✓" for the one you have). It has no name tag and plays the ghosts' usual float animation.
It lags behind while you walk, speeds up the further back it is, and slows down as it reaches
you.

It's still a Mythic Robux pet with no game pass yet (passId 0, "Coming soon"), so nobody can get
it in the live game until you make the pass and put its id in `CosmeticConfig`.

**How it works:** `CosmeticConfig` row `pet_ghost` (was `pet_bat`; nobody owned it). The chosen
ghost is saved as `petGhost` (default `GameConfig.GhostPetDefault`, Wisp) and mirrored as the
`PetGhost` attribute. The Index button fires `ChoosePetGhost` (ghostId); `CosmeticService`
checks the ghost exists, is found and that they own Ghost Buddy, saves it and wears the pet.
`CosmeticModels` copies the ghost from `ReplicatedStorage.GhostPreviews` (the Index's clean
copies), scales it by `GameConfig.GhostPetScale` (0.5) and tags it so `GhostAnimation` floats
it. The lag is in client `PetAnimation`: on the owner's device it aims the pet at its spot and
caps its speed at `GameConfig.GhostPetFollowSpeed` (2.5) × the distance. Bigger ghosts float a
little further out.

**Tested (solo, Studio):** Wisp by default, half its size, no tags, floating; bought a Boo and a
Banshee, equipped each from the Index (button, message, "Your pet ✓"); an unfound ghost is
refused; at a walk speed of 24.5 it trails about 10 studs behind (about 6 at normal speed),
then slows down to its spot; hidden while Invisible; the Mini Pumpkin still stays right beside
you. **Not tested:** what other players see (2-player test), and the chosen ghost being kept
after rejoining (saving only works live).

## 49. Game passes are on sale

All eight Robux passes that said "Coming soon" now exist on the Creator Hub (made in the
browser) and are on sale. Their ids are in `StoreConfig.Passes` and `CosmeticConfig`.

| Pass | Robux | Pass id |
|---|---|---|
| VIP | 299 | 2037118830 |
| 2x Money | 249 | 2038180854 |
| Ghost Buddy Pet | 199 | 2038216814 |
| Auto Collect | 179 | 2037802785 |
| Golden Sparkles Aura | 149 | 2039740559 |
| Extra Hotbar Slot | 129 | 2038342811 |
| Fast Flight | 99 | 2036308633 |
| NIGHTMARE Title | 99 | 2038366859 |

Prices follow what similar games charge (permanent income boosts highest, small conveniences and
cosmetics lowest). Managed pricing is off; Roblox may still show lower local prices in some
regions. The passes use Roblox's default picture for now; change pictures or prices any time on
the Creator Hub (prices are read live, so no code change is needed).

**Tested:** in Studio, every id returns the right pass and says it's for sale. **Not tested:**
buying one (that spends real Robux) and the Shop window showing the prices (needs a playtest).

## 50. Pictures for the game passes

The eight Robux passes now have drawn pictures in the same sticker style as the item icons,
instead of emojis: a stack of bills with "2x" (2x Money), a gold crown (VIP), a new hotbar slot
with a plus (Extra Hotbar Slot), a zooming ghost (Fast Flight), a magnet pulling a coin (Auto
Collect), a horned skull (NIGHTMARE title), gold sparkles (Golden Sparkles) and a ghost with a
collar (Ghost Buddy).

`scripts/draw-pass-icons.ps1` draws two files per pass into `assets/`:
- `pass-<id>.png` (transparent): uploaded, set as `image` on the pass rows in `StoreConfig` and
  `CosmeticConfig`, and shown on the Shop and Inventory cards.
- `pass-<id>-hub.png` (512x512 on a coloured glow): for the pass icon on the Creator Hub, which
  crops it to a circle. **Not uploaded yet**: on the Creator Hub, open each pass under
  Monetization → Passes and change its image to the matching file.

The NIGHTMARE title card in the Shop still shows the animated title word itself, so its picture
only appears on the Creator Hub.

**Tested:** in a Studio playtest, the Gamepasses tab and the Cosmetics tab show the new pictures.
**Not tested:** the Inventory's Cosmetics tab (same code path).

## 51. Flashier Golden Sparkles, Smoke Bomb hides effects, rarity sorting

**Golden Sparkles** (a Robux aura) is now much louder: bigger, denser gold glitter, big white
star flashes popping on and off around you, gold motes rising from your feet, a warm gold glow
(PointLight), a gold trail behind you as you move, and a soft looping wind-chime sound
(`GameConfig.GoldenAuraSound`, "Wind Chimes 2 (SFX)" by Pro Sound Effects, volume 0.3, heard up
to 40 studs away). Auras in `CosmeticModels` can now have `light`, `trail` and `sound` besides
their particle emitters; all of it sits on the `CosmeticAura` attachments, so taking the aura
off removes everything.

**Smoke Bomb:** while invisible, worn auras (now including their sound and trail) and pets were
already taken off; the Smoke Bomb now also turns off any particles, trails, beams, lights, fire,
smoke and sparkles on the character itself (for example from avatar accessories), and turns them
back on when you reappear.

**Sorting:** the Shop's Items and Cosmetics tabs and the Inventory's Items and Cosmetics tabs
list the rarest first (`ItemConfig.sortByRarity`). Within a rarity, Shop items show the priciest
first; everything else keeps its config order.

**Tested:** in a Studio playtest, the aura has its 12 emitters, light, trail and a playing,
looping sound; with the Smoke Bomb, the aura, its sound and the pet are gone while invisible and
come back after; the Shop and Inventory list Mythic → Legendary → Epic → Rare.
**Not tested:** whether the sound volume feels right to other players (needs a 2-player test).

## 52. The Secret ghost is now the Grim Reaper

`secret_1` (id unchanged, so saves are safe) is renamed **Grim Reaper** and gets a real look
instead of the placeholder ball: a menacing cartoon reaper in an all-black hood with a grinning
skull and glowing eyes, skeletal hands, a scythe and a lantern on a strap, its robe trailing
into wispy tendrils. `GhostModels.secret_1` makes him solid, about as tall as the Spectre King
(height scale 1.28), floating just above the ground, with a cold pale glow and pale "lost soul"
wisps rising off him; the Secret rarity aura adds its smoke and stars on top.

The mesh is AI-generated in Studio (picked from three candidates) and lives in
`ServerStorage.GhostMeshes.secret_1`, so it's **only in the place file: save and publish**.
A first version built in Blender from a script (`scripts/blender/grim_reaper.py`, run with
`E:\Apps\Blender\blender.exe -b --python scripts/blender/grim_reaper.py -- assets/grim_reaper`)
was too plain next to the other ghosts; it's kept as `ServerStorage.GhostMeshBackups.secret_1_blender`.

**Tested:** in a Studio playtest (with boosted spawns), the Grim Reaper spawns on the walkway
with his name, Secret label, price and income, faces the way he's travelling like the other
ghosts, and has his glow, particles and the Secret aura; size checked next to the King.
**Not tested:** buying him and how he looks on a grave in a base.

## 53. The Divine ghost is now the Seraph

`divine_1` (id unchanged, so saves are safe) is renamed **Seraph** and gets a real look instead
of the placeholder ball: a tall, faceless angel spirit in a gold-trimmed white robe with its arms
open, two soft glowing eyes under its hood, big feathered wings and a golden halo, its robe
curling into a ghostly tail. `GhostModels.divine_1` makes it solid and a bit smaller than the
Grim Reaper (height scale 1.15), with a warm gold glow, a Neon halo, and soft white motes
drifting down off it like falling feathers; the Divine rarity aura adds its rising sparkles.
The wings slowly beat: they hang on a `WingWeld` and are tagged `FlappingWing`, so the pets'
wing code (client `PetAnimation`) flaps them too. Wings can now set their own `FlapSpeed` /
`FlapAngle` attributes; the Seraph's are slower and gentler than the pets'.

The mesh is AI-generated in Studio (picked from four candidates; glowing eyes added as two Neon
parts and a `Hinge` attachment on each wing) and lives in `ServerStorage.GhostMeshes.divine_1`,
so it's **only in the place file: save and publish**. The other designs are kept in
`ServerStorage.GhostMeshBackups` (`divine_1_alt_laurel`, `divine_1_alt_cute`, and the
untouched `divine_1_alt_majestic`).

**Tested:** in a Studio playtest, the Seraph built by the real GhostService (its Index preview
copy) shows its eyes, glowing halo, falling motes and wings, and the wings beat on the client;
no errors. **Not tested:** it spawning on the walkway, buying it, and how it looks on a grave.

## 54. Gem packs can be bought with Robux

The four gem packs in Shop → Currency were "Coming soon"; they now have Developer Products on
the Creator Hub, and their IDs are in `StoreConfig.GemPacks`: 500 gems for 25 R$, 1,200 for 49,
3,000 for 99 and 8,000 for 249 (the bonus labels still fit: about +22%, +52% and +60% more
gems per Robux than the 500 pack). Prices are set on the Creator Hub, not in code. Managed
Pricing is on (agreed on the Creator Hub), so Roblox shows cheaper regional prices in some
countries and may run price tests; the products are marked "does not allow trading or gifting",
so if trading is ever added, use the Price Levels API. The products have no picture yet (add
`assets/gem-icon.png` on the Creator Hub if you want one in Roblox's purchase pop-up).
StoreService already paid gem packs out (`ProcessReceipt`, once per purchase id, saved straight
away), so no game code changed.

**Tested:** in a Studio playtest, all four cards show their Robux price (your regional price,
e.g. R$ 23 for the 25 R$ pack). **Not tested:** actually buying one (Studio purchases are free
test purchases: open Shop → Currency, click a pack and confirm, and you should get the gems).

## 55. A "!" on the menu tab while something is waiting

The side menu's tab (the ☰ button on the left, M) now shows a red "!" in its top-right corner
while anything inside is waiting: Index rewards to claim or a rebirth you can afford. It hides
while the menu is open, since the Index and Rebirth buttons show their own badges then.
(Daily reward and Spin! have their own buttons on screen, so they aren't counted.) `Sidebar`
listens to the same `IndexPanel.claimableChanged` / `RebirthPanel.availableChanged` signals as
those buttons.

**Tested:** in a Studio playtest with a rebirth affordable, the "!" shows on the tab, hides when
the menu opens and comes back when it closes; no errors. **Not tested:** the Index case on its
own (it uses the same signal as the Index button's badge).

## 56. Title rarities and milestone titles

Every title now has a rarity (Common to Secret), and its card in the Inventory and Shop is
coloured like an item of that rarity, with the rarity word on top. The title words keep their
own colours. THE GOAT and SUPERNOVA are Secret, VIP and NIGHTMARE Mythic, PHANTOM Legendary
(now also Legendary in the Shop), and the rebirth titles REBORN, UNDYING and ETERNAL are
Rare, Epic and Legendary. The Titles tab lists them rarest first, owned and locked together.

Ten new milestone titles are earned by playing, and show locked in the Titles tab with a
progress bar until then:

| Title | Rarity | Goal |
|---|---|---|
| GHOST HUNTER | Common | Buy 20 ghosts |
| PICKPOCKET | Common | Steal 3 ghosts |
| COLLECTOR | Uncommon | Find 5 ghosts in the Index |
| GHOST HOARDER | Uncommon | Buy 100 ghosts |
| ODDBALL | Rare | Get 5 mutated ghosts |
| CAT BURGLAR | Rare | Steal 25 ghosts |
| MUTATED | Epic | Get 20 mutated ghosts |
| MASTER THIEF | Epic | Steal 100 ghosts |
| SHINY HUNTER | Legendary | Get 5 Shiny ghosts |
| GRAVEKEEPER | Legendary | Find every ghost in the Index |

Only PHANTOM (gems) and NIGHTMARE (Robux) can be bought. New saved counters in DataService
(`stats`: `ghostsBought`, `mutations`, `shinies`; `DataService.recordGhost` is called on a walkway
buy, an out-bid, a steal and a capture) plus the existing `steals` and Index finds are shown as
`Stat_<name>` attributes. TitleService watches them and unlocks a title when its goal is reached
(TitleConfig `milestone = { stat, goal }`). Counting starts now: steals and Index finds from
before count, but ghosts bought and mutations from before don't (they were never saved).

**Tested:** in a Studio playtest, the Titles tab shows the rarity colours and order, locked
milestone titles with their goal and a 0/25-style bar, and buying a walkway ghost raised
`ghostsBought` and `found` and (with the goal set to 1 for the test) unlocked GHOST HUNTER, which
then showed as owned. No errors. **Not tested:** the steal, capture and Shiny counters (they
need a 2-player test or a lucky Shiny), and saving the counters (only in the live game).

## 57. Flat colours for Legendary-and-below titles

Titles from Common up to Legendary are now one flat colour, their rarity's (the same colour as
their card), with no gradient, glint or animation, so the shiny animated look is kept for Mythic
and rarer titles. PHANTOM is the exception and keeps its pale-blue gradient. In TitleConfig, a
title without a `gradient` gets `flat = true` and its rarity colour, and TitleText doesn't tag a
flat title's gradient for the client's GradientAnimator.

**Tested:** in a Studio playtest, every Legendary-and-below title except PHANTOM has one colour,
no animation tag and no glint; PHANTOM, VIP, NIGHTMARE, THE GOAT and SUPERNOVA are unchanged; the
Titles tab shows the flat colours. No errors. **Not tested:** the title above the head and in
chat for a flat title (they use the same TitleText code).

## 58. Codes (side menu → Codes)

A fifth side menu button, **Codes** (a teal gift box icon), opens a window with a text box and a
Redeem button. Players type a code you've posted (in a clip, a video description or the Roblox
group) and get its reward once. The line under the box answers: "+100 gems!" in green, or in red
"Already used", "Invalid or expired code", "Type a code first" or "Slow down! Try again in a
moment." Enter in the box works like the button. The first code is **SPOOKY** (100 gems).

**How to add a code:** open `src/server/Config/CodeConfig.luau` and add a row, then publish:

```lua
{ code = "1KLIKES", gems = 250, spins = 1 },
{ code = "HALLOWEEN", gems = 500, cash = 10000, expires = "2026-11-01" },
```

`gems`, `cash` and `spins` are all optional (use any mix); `expires` is the last day it works
(UTC, it stops at the end of that day), left out = never expires. Upper/lower case and spaces
around the code don't matter. Each player can use each code once. Don't rename a code that's
already out (people who used it could use the new name again); add a new one instead.

How it works: CodeConfig is in ServerScriptService, which players' devices never receive, so
exploiters can't read codes before you post them. The window (client `UI/CodesPanel`) only sends
the typed text with the `RedeemCode` remote. `CodeService` checks it's a short string, allows one
try per player every `GameConfig.CodeCooldownSeconds` (2), looks the code up, checks the expiry
and whether this player used it, then saves it in their data (new `codes` key, `[CODE] = true`)
and pays through DataService (`addGems` / `addCash` / `addSpins`). It answers with `CodeResult`
(success, message). Text longer than `GameConfig.CodeMaxLength` (30) is never looked up.

With five buttons the side menu was tall enough to cover the gems counter, so it now sits 40
pixels above the middle of the left edge and is full size from 900 pixels of screen height
(was 800).

**Tested:** in a Studio playtest, like a player: pressed M, clicked Codes, typed " spooky " in the
box and clicked Redeem: "+100 gems!" and gems went 0 → 100. Typing SPOOKY again and pressing Enter
said "Already used" with no gems; a wrong code said "Invalid or expired code"; Redeem with an empty
box said "Type a code first". Sent from the client: a number and a 500-letter text were ignored, and
two codes in a row got "Slow down!" for the second. Checked the expiry date maths on the server
(2026-11-01 is still valid today, 2026-10-01 has expired), that the client sees nothing in
ServerScriptService, and the side menu clear of the gems counter. No errors. **Not tested:** an
expired code through the window (no expired code exists), and saving which codes were used (only
in the live game; DataStores are off in Studio).

## 59. Spin "Get more", 2x Money badge, VIP and Fast Flight buffs

**Spin Wheel "Get more":** with no spins left, the Spin Wheel's button now says **Get more** (gold)
instead of the countdown (the countdown is still in the line above the wheel). Clicking it closes
the wheel and opens the Shop on the Boosters tab, scrolled to the 1/2/3 Spins cards
(`ShopPanel.openTab(tab, cardName)`).

**2x Money badge:** owners of the 2x Money game pass see a gold, tilted **x2** right beside their
cash number (bottom left). It follows the number as it grows, and the floating "+$X" starts past it.

**VIP pass:** +15% income (was +10%), **+15% on gems earned by playing** (Index rewards, daily
reward, rebirth, codes, Spin Wheel gem prizes, tutorial; not Robux gem packs), and **2 spins every
10 minutes online** instead of 1. The Shop card says "Title, +15% cash & gems, 2 spins/10 min".
Tuned in GameConfig (`VipIncomeBonus`, `VipGemBonus`, `VipOnlineSpins`). Earned gems now go
through `DataService.earnGems`, which adds the bonus and returns the real amount, so messages
like "Day 1 reward: +12 gems!" show what you actually got.

**Fast Flight pass:** bought ghosts fly home **3x** as fast (was 2x) and leave a white **wind
trail** (a faint streak plus two thin lines off the sides) while flying. The trail comes off
just before the ghost lands on its grave. When someone outbids you, the ghost is rebuilt for the
new buyer, so it flies at their speed: fast with a trail if they own Fast Flight, normal and
without one if not. Outbidding back works the same way.

**Tested** in Studio playtests: with no spins the button said "Get more" and clicking it opened
the Shop on Boosters with the spin cards in view. With `Pass_double_money` set the x2 badge
appeared beside the cash, and hid when removed. With `Pass_vip` set, the online spin timer gave
2 spins and the daily reward of 10 gems gave 12; the VIP card text fits. With `Pass_fast_flight`
set, a bought Wisp flew with all three trails, landed in about 3.5 s, and had no trail after
landing (screenshot taken mid-flight). No errors. **Not tested:** the outbid switching (needs a
2-player test: buy with the pass, get outbid by a player without it, then outbid back), and
the +15% income in play (it's a config number in the existing VIP income code).
