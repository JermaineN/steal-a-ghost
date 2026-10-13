# Steal a Ghost (Roblox)

Collect-and-defend idle tycoon with PvP theft, inspired by "Steal a Brainrot". 8–12 player servers, 15–60 min sessions, built for short clips.

- **Economy loop:** buy ghosts from the walkway → they earn cash/sec in your base → buy better ghosts.
- **Risk loop:** good ghosts get stolen. Defend your base (lock it, catch thieves) or raid others.

The user is new to Roblox development: explain Roblox concepts briefly when they come up, and keep code readable over clever.

## Toolchain
- **Rojo** syncs `src/` into Studio (`default.project.json`). Run `rojo serve`, then press Connect in Studio's Rojo plugin.
- **Roblox_Studio MCP** (`.mcp.json` → `%LOCALAPPDATA%\Roblox\mcp.bat`, Studio's built-in server). Use it to inspect the game tree, run Luau, playtest (`start_stop_play`, `get_console_output`, `screen_capture`).
- Tools live in `%USERPROFILE%\.roblox-tools\bin` (rojo, stylua, selene, wally). Rokit and Selene can't reach the internet on this machine (Rust HTTP stack fails); `scripts/install-tools-direct.ps1` re-downloads tools via PowerShell instead.
- Format with `stylua src` before finishing a change.

## Layout
- `src/shared` → ReplicatedStorage.Shared: `Config/GameConfig` (all tuning numbers), `Config/GhostConfig` (ghost list), `Format`, `Remotes`.
- `src/server` → ServerScriptService.Server: `init.server.luau` starts services and owns the PlayerAdded/PlayerRemoving order.
  - `MapBuilder` builds walkway + 10 plots in code. `PlotService` plot ownership/bounds/lock state. `GhostService` models, walkway shop, placed ghosts (single source of truth: `placed[player][slot]`). `StealService` carrying/delivering/returning. `LockService` lock button + ejecting intruders. `EconomyService` income tick. `DataService` DataStore load/save.
- `src/client` → StarterPlayerScripts.Client: `UI/Hud` (cash, income, toasts), `GhostPrompts` (hides Steal on own ghosts / Sell on others').

## Rules
- **Server authoritative.** The client only displays. Every buy/sell/steal is validated on the server (ownership, cash, distance/inside-plot, lock state). Never trust values sent from a client.
- Avoid require loops: GhostService must not require StealService (it uses the `onStealPromptTriggered` hook).
- Data changes only through DataService. Never save a profile whose load failed (`canSave = false`).
- Put tunable numbers in `GameConfig`/`GhostConfig`, not inline.
- Studio-only edits (parts built by hand, settings) are not in git — prefer building things in code or saving the place file, and tell the user when something lives only in Studio.
