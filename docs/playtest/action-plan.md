# Parkin' Space – Playtest Action Plan (Step 8.5)

Fill after the first round (T1–T5+). Fix the highest-severity, most-mentioned issues first (at least 3), then retest with at least 2 new testers and record the result.

Severity: **Critical** = crash, lost progress, cannot finish a level · **Major** = confusing goal, unfair difficulty, online fails often · **Minor** = cosmetic, typos, small sound issues.

| # | Issue found | Testers who reported it (of N) | Severity | Planned fix | Fixed? (commit) | Result after retest |
|---|---|---|---|---|---|---|
| 1 | No warning before a ship hits the lot walls | Developer playtest (2026-11-03), before the tester round | Major | Red lot-edge outline that glows when the driven ship nears a wall | Yes (`feature/playtest-fixes`) | _retest_ |
| 2 | Players think the game is stuck while parked ships wait to be asked for, and quit | Developer playtest (2026-11-03) | Major | Countdown on each parked leaver + HUD "Waiting for customers to return – next in 0:12" | Yes (`feature/playtest-fixes`) | _retest_ |
| 3 | Players hold the thrust buttons and overshoot | Developer playtest (2026-11-03) | Minor | Yellow tip on the How to Play Controls page: tap, don't hold | Yes (`feature/playtest-fixes`) | _retest_ |
| 4 | | | | | | |
