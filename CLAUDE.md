# Steal a Ghost (Roblox)

Collect-and-defend idle tycoon with PvP theft, inspired by "Steal a Brainrot". 8-player servers (one base each), 15–60 min sessions, built for short clips. Halloween event theme.

- **Economy loop:** buy a ghost from the walkway → it flies to your base (other players can outbid you while it flies) → its income piles up on the green collect pad in front of its grave → step on the pad to collect → buy better ghosts.
- **Risk loop:** good ghosts get stolen. Defend your base (lock it, catch thieves) or raid others.

The user is new to Roblox development: explain Roblox concepts briefly when they come up, and keep code readable over clever.

## Toolchain
- **Rojo** syncs `src/` into Studio (`default.project.json`). Start `rojo serve` in a Terminal tab (`run_in_terminal`, so it keeps running), then the user presses Connect in Studio's Rojo plugin; Studio reopening needs a fresh Connect. After editing, confirm the change reached Studio (`script_grep`) before playtesting: a playtest started before Rojo syncs runs old code, and edits made during a playtest only apply after restarting it.
- **Roblox_Studio MCP** (`.mcp.json` → `%LOCALAPPDATA%\Roblox\mcp.bat`, Studio's built-in server). Use it to inspect the game tree, run Luau, playtest (`start_stop_play`, `get_console_output`, `screen_capture`), and generate meshes. The place is published (placeId 125248956556861); the Studio id changes whenever Studio reopens, so call `list_roblox_studios` again if one stops working.
- Tools live in `%USERPROFILE%\.roblox-tools\bin` (rojo, stylua, selene, wally). Rokit and Selene can't reach the internet on this machine (Rust HTTP stack fails); `scripts/install-tools-direct.ps1` re-downloads tools via PowerShell instead.
- Format with `stylua src` before finishing a change. Stylua also rewrites line endings in files you didn't touch, so check the real changes with `git diff --ignore-cr-at-eol --stat` and `git checkout --` any file with no real change before committing.
- **Git:** private repo https://github.com/JermaineN/steal-a-ghost, branch `main`. Commit only when asked; push only when asked. The GitHub CLI is at `C:\Program Files\GitHub CLI\gh.exe` (not on PATH).
- **"Create a PR and merge it"** is the usual request: make a branch, commit only the files for this change, push, `gh pr create --body-file <file>` (in PowerShell 5.1, quotes inside an inline `--body` break the arguments), `gh pr merge <n> --merge --delete-branch`, then switch back to `main`, pull, and delete the local branch.
- Merged changes only reach players after the user **publishes** from Studio (File → Publish to Roblox); remind them.

## Layout
- `src/shared` → ReplicatedStorage.Shared: `Config/GameConfig` (all tuning numbers, including `PlotCount = 8`), `Config/GhostConfig` (ghost list and rarities), `Theme` (shared colours: money green, walkway-income yellow, and the Legendary gold / Mythic rainbow `RarityGradients`), `Format`, `Remotes` (`Notify`, `CashCollected`, `RareSpawn`).
- `src/server` → ServerScriptService.Server: `init.server.luau` starts services, sets walk speed, and owns the PlayerAdded/PlayerRemoving order.
  - `MapBuilder` builds the walkway, 8 graveyard bases (`GraveyardBase`; spacing `PLOT_SPACING`, distance from the walkway `PLOT_DISTANCE`), each base's collect pads and lock bars/wall, invisible walls, and the map edge, all in code. `HalloweenDecor` adds lighting, decorations, cliffs and portals (`GhostPortal`); toggled by `GameConfig.HalloweenMap`. Its graveyard decor is placed from the map edge, so it follows the bases if they move.
  - `PlotService` plot ownership/bounds/lock state. `GhostService` ghost models, walkway shop, placed ghosts (single source of truth: `placed[player][slot]`). A bought ghost is owned and saved immediately, then flies (`flyTo`) to just in front of its base and appears on its grave; while `arriving` it can't earn, be stolen or be sold (`isInBase`), but other players can re-buy it (`tryRebuy`: price +`RepurchaseMarkup` of the original per re-buy, the outbid player is refunded). It also fires `RareSpawn` for Legendary/Mythic walkway spawns. `GhostModels` per-ghost 3D looks and particles. `StealService` carrying/delivering/returning. `LockService` lock button, see-through jail bars plus an invisible wall across the entrance (the owner passes through the wall via per-base collision groups `LockWall<n>` / `PlotOwner<n>`), and ejecting anyone inside when it locks. `EconomyService` income tick into each slot's collect pad (saved as `stored`); only the owner can collect, by stepping on it. `DataService` DataStore load/save.
  - `Util/`: `Parts` (part builder, plus `paintFullbright` for the lit-up look of the pads and lock bars without lighting their surroundings), `GhostLabel` (floating ghost name/rarity/price text), `Billboard`, `Notify` (every pop-up message goes through `Notify.send`).
- `src/client` → StarterPlayerScripts.Client: `UI/Hud` (bottom-left cash + income, and the pop-up messages: big outlined text in the lower middle, coloured by kind), `UI/RareSpawnBanner` (top-of-screen banner when a Legendary/Mythic spawns), `CollectEffect` (owner-only pad flash, cha-ching and cash burst on collect), `GhostPrompts` (hides Steal on own ghosts / Sell on others', and shows "Buy for $X" on others' ghosts in flight), `GhostAnimation` (bob/sway/flicker; Spectre King waddle on the walkway), `MusicPlayer` (background music + mute button).

## Ghost models (live in Studio, not git)
- Each ghost's AI-generated mesh is in **ServerStorage.GhostMeshes**, named by ghost id (`wisp`, `boo`, … `spectre_king`). A template is a MeshPart or a Model of MeshParts (the Wraith is split into pieces). `ServerStorage.GhostMeshBackups` holds the Wraith's original.
- These are saved with the place, so remind the user to save/publish after changing them. If a mesh is missing, the ghost falls back to a simple ball.
- `GhostModels.<id>` sets size, transparency, glow and particles. Mesh attributes: `Flicker = false` skips the flame stretch; `Walk = true` waddles while unowned. Animated parts carry the `Animated` attribute so StealService leaves their welds alone.
- When generating meshes, keep designs original (no copies of other games' characters) and compare candidates side by side at ground level, then reset the Edit camera.
- Sounds come from the Creator Store; prefer Roblox-licensed APM Music tracks or audio made for games over clips ripped from other games. Their IDs live in `GameConfig`.

## Testing
- `GameConfig.StudioTestCashOn` (start with `StudioTestCash`, $1B, never saved) and `GameConfig.StudioBoostSpawns` (equal ghost odds, 2× spawn rate) only apply in Studio. Both are off by default; turn on for testing expensive/rare ghosts, and turn back off before committing.
- Stealing, catching, lock-with-thief, bidding and anything about what other players see need a 2-player test (Test → Clients and Servers, 2 players); the user starts it. `list_roblox_studios` then shows the server and each player window, and `execute_luau` / `user_keyboard_input` can drive each one.
- DataStore warnings in Studio output are expected (Studio API access is off), and so is the "Infinite yield ... leaderstats" warning they cause. Cash only appears a few seconds after joining.
- `execute_luau` gets its own copy of every ModuleScript, so requiring a service there gives a fresh, empty copy (no plots, no players). Test like a player instead: move the character (`PivotTo`), press E with `user_keyboard_input` to use a prompt, and read results from the Server or Client. Stateless modules (`GhostModels`, `GhostLabel`) are fine to require for building previews.
- To test UI, fire the existing remote directly from the Server: `game.ReplicatedStorage.Remotes.<Name>:FireAllClients(...)`. Don't require `Shared.Remotes` there; it would create a second Remotes folder.
- `screen_capture` with a camera position doesn't draw particles; to see particles, move the character next to the thing and capture without one. Effects that last about a second need a frozen `Clone()` of the parts to catch in a screenshot.
- A tool round trip takes a few seconds, while a short ghost flight lands in about 10 s: buy far from the buyer's base when testing bidding.
- Live settings that aren't code: Max Players is 8 (Creator Hub → place → Access settings → "Maximum Visitor Count"; Studio's `Players.MaxPlayers` may still show an old value). It must match `PlotCount`.

## Rules
- **Server authoritative.** The client only displays. Every buy/sell/steal/re-buy/collect is validated on the server (ownership, cash, distance/inside-plot, lock state, still in flight). Never trust values sent from a client.
- Avoid require loops: GhostService must not require StealService (it uses the `onStealPromptTriggered` hook).
- Data changes only through DataService. Never save a profile whose load failed (`canSave = false`).
- Put tunable numbers in `GameConfig`/`GhostConfig`, not inline.
- Studio-only edits (parts built by hand, settings, generated meshes) are not in git — prefer building things in code or saving the place file, and tell the user when something lives only in Studio.
