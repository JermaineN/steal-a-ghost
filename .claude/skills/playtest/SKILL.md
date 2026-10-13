---
name: playtest
description: Playtest Steal a Ghost in Roblox Studio through the Roblox_Studio MCP server and report what broke. Use after changing game code, or when the user says "test it", "playtest", "does it work", or "run the game".
---

# Playtest in Studio

1. **Check the connection.** Call `get_studio_state`. If the Roblox_Studio tools are missing, tell the user to open Studio, enable the MCP server (Assistant → Manage MCP Servers), and restart this Claude session.
2. **Check sync.** Make sure `rojo serve` is running (look for a terminal tab running it; otherwise start it with run_in_terminal from the project root) and that the Rojo plugin in Studio is connected. If code in Studio doesn't match `src/`, ask the user to press Connect in the Rojo plugin.
3. **Start play** with `start_stop_play`. Wait a few seconds for the server to build the map and load data.
4. **Read the console** with `get_console_output`. Look for errors and warnings from `Server`, `Client`, or any service. A DataStore warning in Studio is expected unless "Enable Studio Access to API Services" is on.
5. **Exercise the feature you changed.** Use `execute_luau`/`inspect_instance` to check state (e.g. a player's `leaderstats.Cash`, children of `workspace.GeneratedMap.PlotN.Ghosts`), `character_navigation` to walk somewhere, and `screen_capture` to see the result.
6. **Stop play** with `start_stop_play`.
7. **Report** in plain language: what worked, each error with the script and line, and the fix you suggest. Fix bugs in `src/` (not directly in Studio) so Rojo stays the source of truth.

Stealing needs two players; Studio's Test → Clients and Servers (2 players) is a manual step for the user.
