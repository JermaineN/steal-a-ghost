# Changelog

What changed while you were away, one section per change, newest last. Each section says what
it does for players, how it works, what was tested and what still needs a test from you.

Remember: merged changes only reach players after you **publish** from Studio
(File → Publish to Roblox).

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
| Secret | 8 | 600 gems | "Secret Ghost" (`secret_1`) | $10M | $75K/s | ~1 in 2,100 spawns (~90 min) |

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
