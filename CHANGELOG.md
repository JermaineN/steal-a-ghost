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
