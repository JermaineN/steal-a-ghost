# Steal a Ghost (Roblox)

Collect-and-defend idle tycoon with PvP theft, inspired by "Steal a Brainrot". 8–12 player servers, 15–60 min sessions, built for short clips. Halloween event theme.

- **Economy loop:** buy ghosts from the walkway → they earn cash/sec in your base → buy better ghosts.
- **Risk loop:** good ghosts get stolen. Defend your base (lock it, catch thieves) or raid others.

The user is new to Roblox development: explain Roblox concepts briefly when they come up, and keep code readable over clever.

## Toolchain
- **Rojo** syncs `src/` into Studio (`default.project.json`). Run `rojo serve`, then press Connect in Studio's Rojo plugin. After editing, confirm the change reached Studio before playtesting (a playtest started before Rojo syncs runs old code).
- **Roblox_Studio MCP** (`.mcp.json` → `%LOCALAPPDATA%\Roblox\mcp.bat`, Studio's built-in server). Use it to inspect the game tree, run Luau, playtest (`start_stop_play`, `get_console_output`, `screen_capture`), and generate meshes. The place is published (placeId 125248956556861); the Studio id changes whenever Studio reopens, so call `list_roblox_studios` again if one stops working.
- Tools live in `%USERPROFILE%\.roblox-tools\bin` (rojo, stylua, selene, wally). Rokit and Selene can't reach the internet on this machine (Rust HTTP stack fails); `scripts/install-tools-direct.ps1` re-downloads tools via PowerShell instead.
- Format with `stylua src` before finishing a change.
- **Git:** private repo https://github.com/JermaineN/steal-a-ghost, branch `main`. Commit only when asked; push only when asked. The GitHub CLI is at `C:\Program Files\GitHub CLI\gh.exe` (not on PATH).

## Layout
- `src/shared` → ReplicatedStorage.Shared: `Config/GameConfig` (all tuning numbers), `Config/GhostConfig` (ghost list), `Theme` (shared UI colours: money green, walkway-income yellow), `Format`, `Remotes`.
- `src/server` → ServerScriptService.Server: `init.server.luau` starts services, sets walk speed, and owns the PlayerAdded/PlayerRemoving order.
  - `MapBuilder` builds walkway, 10 graveyard bases (`GraveyardBase`), invisible walls, and the map edge in code. `HalloweenDecor` adds lighting, decorations, cliffs and portals (`GhostPortal`); toggled by `GameConfig.HalloweenMap`.
  - `PlotService` plot ownership/bounds/lock state. `GhostService` ghost models, walkway shop, placed ghosts (single source of truth: `placed[player][slot]`). `GhostModels` per-ghost 3D looks. `StealService` carrying/delivering/returning. `LockService` lock button + ejecting intruders. `EconomyService` income tick into each slot's green collect pad (saved as `stored`), collecting when the owner steps on it. `DataService` DataStore load/save.
  - `Util/`: `Parts` (part builder), `GhostLabel` (floating ghost name/rarity/price text), `Billboard`, `Notify`.
- `src/client` → StarterPlayerScripts.Client: `UI/Hud` (bottom-left cash + income, toasts), `GhostPrompts` (hides Steal on own ghosts / Sell on others'), `GhostAnimation` (bob/sway/flicker; Spectre King waddle on the walkway), `MusicPlayer` (background music + mute button).

## Ghost models (live in Studio, not git)
- Each ghost's AI-generated mesh is in **ServerStorage.GhostMeshes**, named by ghost id (`wisp`, `boo`, … `spectre_king`). A template is a MeshPart or a Model of MeshParts (the Wraith is split into pieces). `ServerStorage.GhostMeshBackups` holds the Wraith's original.
- These are saved with the place, so remind the user to save/publish after changing them. If a mesh is missing, the ghost falls back to a simple ball.
- `GhostModels.<id>` sets size, transparency, glow and particles. Mesh attributes: `Flicker = false` skips the flame stretch; `Walk = true` waddles while unowned. Animated parts carry the `Animated` attribute so StealService leaves their welds alone.
- When generating meshes, keep designs original (no copies of other games' characters) and compare candidates side by side at ground level, then reset the Edit camera.

## Testing
- `GameConfig.StudioTestCash` (extra starting cash, never saved) and `GameConfig.StudioBoostSpawns` (equal ghost odds, 2× spawn rate) only apply in Studio. Both are off by default; turn on for testing expensive/rare ghosts.
- Stealing, catching and lock-with-thief need a 2-player test (Test → Clients and Servers, then Add Clients); the user starts it.
- DataStore warnings in Studio output are expected (Studio API access is off).

## Rules
- **Server authoritative.** The client only displays. Every buy/sell/steal is validated on the server (ownership, cash, distance/inside-plot, lock state). Never trust values sent from a client.
- Avoid require loops: GhostService must not require StealService (it uses the `onStealPromptTriggered` hook).
- Data changes only through DataService. Never save a profile whose load failed (`canSave = false`).
- Put tunable numbers in `GameConfig`/`GhostConfig`, not inline.
- Studio-only edits (parts built by hand, settings, generated meshes) are not in git — prefer building things in code or saving the place file, and tell the user when something lives only in Studio.
