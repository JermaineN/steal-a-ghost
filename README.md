# Steal a Ghost

Buy ghosts, earn cash, defend your base, and steal from everyone else.

## Every time you work on the game

1. Open the project folder in VS Code (`E:\Claude`).
2. Start Rojo: in a terminal run `rojo serve` (leave it running).
3. Open Roblox Studio → your place → **Plugins** tab → **Rojo** → **Connect**.
4. Press **Play** in Studio.

Code lives in `src/`. Edit there (or ask Claude), and Rojo copies changes into Studio instantly.

## How to play
- Ghosts float down the red carpet. Walk up and hold **E** to buy one. It goes to your base and earns cash every second.
- Step on the green pad in your base to **lock** it for 60 seconds.
- Walk into someone else's base and hold **E** on a ghost to **steal** it. Carry it back into your base before the owner touches you.
- Hold **E** on your own ghost to **sell** it for half price.

## Tuning
All the numbers are in `src/shared/Config/GameConfig.luau`, and every ghost is in `src/shared/Config/GhostConfig.luau`.

## One-time Studio setup
- **Saving:** publish the place (File → Publish to Roblox), then Game Settings → Security → turn on **Enable Studio Access to API Services**.
- **Server size:** Game Settings → Places → set Max Players to **10** (one per base).
- **Claude MCP:** Studio → Assistant → **Manage MCP Servers** → turn the MCP server on.
- **Testing steals:** Test tab → Clients and Servers → 2 players → Start.
