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
