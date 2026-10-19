-- Redeemable codes (side menu → Codes). Server-only on purpose: this lives in
-- ServerScriptService, which players' devices can't see, so nobody can read the codes out of
-- the game before you post them.
--
-- One row per code:
--   code     what players type. Matching ignores upper/lower case and spaces around it, so
--            write it in CAPITALS here ("SPOOKY" also matches "spooky" and " Spooky ").
--   gems     gems it gives (optional)
--   cash     cash it gives (optional)
--   spins    Spin Wheel spins it gives (optional)
--   expires  last day it works, "YYYY-MM-DD" (UTC; it stops working at the end of that day).
--            Leave it out for a code that never expires.
--
-- Each player can redeem each code once (saved in their data as `codes`). Never rename a code
-- that's already out: players who used it could use the new name again. Add a new row instead.
return {
	{ code = "SPOOKY", gems = 100 },
	{ code = "HALLOWEEN", gems = 500, cash = 10000, expires = "2026-11-01" },
	-- Ready for later:
	-- { code = "1KLIKES", gems = 250, spins = 1 },
}
