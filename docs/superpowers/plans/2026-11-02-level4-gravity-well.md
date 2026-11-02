# Level 4 – Gravity Well Lot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Level 4, an open lot with a black hole at its centre that pulls free ships, and orphaned ships that appear in spaces and pay a bonus when ejected at the right time.

**Architecture:**
- **BlackHole:** a `StaticBody2D` with a solid core, a pure `pull_at(distance)` function and a look that ignores the dark. Level.gd applies the pull as a per-frame central force on every ship that isn't parked.
- **Orphan:** a small RefCounted (countdown and payout) attached to a ship as `ship.orphan`.
- **Level.gd:**
  - rolls orphan appearance times
  - places orphans in fit-safe free spaces
  - lets parked orphans be selected
  - keeps them out of parking and serving
  - settles them at the exit through new ledger bonuses

**Tech Stack:** Godot 4.7.2, typed GDScript, the project's test runner (`tests/TestRunner.tscn`, `TestCase`).

**Spec:** `docs/superpowers/specs/2026-11-02-level4-gravity-well-design.md`

## Global Constraints

- Levels 1–3 play exactly as before. Every new Level.gd behaviour is a no-op when there is no `BlackHole` node and `orphan_count == 0`.
- Pull: `PULL_K = 1_800_000.0`, `MAX_PULL = 80.0` px/s², and acceleration is `min(MAX_PULL, PULL_K / d²)`. It's applied as `mass × acceleration` at the centre of mass, only to ships that aren't parked. `CORE_RADIUS = 60.0`.
- Orphans:
  - `COUNTDOWN = 60.0` s, `BONUS = 25`, `EARLY_COST = 15`
  - they appear at random moments between 25% and 60% of the shift
  - they retry every 1 s when no allowed space is free
- Allowed orphan space: free, and `ParkingRules.fits_lot(all customer classes, space classes minus orphan-held spaces minus this one)`. The orphan's ship fits that space.
- Orphan hint, exact copy: `"Orphaned ship! Eject it at the EXIT after its timer"`, once per shift.
- Result line, exact copy: `"\nBonuses ₵%d"`, shown when bonuses > 0.
- Level 4 settings:
  - level_number 4, goal `"Serve 7 customers"`, random_customers 7
  - base_pay 100, silver 280, gold 330, arrival_interval 10
  - use_tiers true, retrieval_count 2, orphan_count 2
  - pool = all 10 ships in `resources/ships/`
  - no `shift_seconds` (difficulty sets it)
- Every level is dark. Level 4 gets a `Floodlights` node, and every space centre lies within 75% of some floodlight's radius (the existing test in `tests/test_lighting.gd` covers this once Level 4 is added to its `LEVELS` list).
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never commit keystores, passwords or `export/`.
- **Test command:** `bash .superpowers/sdd/2026-11-01-ship-art-pipeline/t.sh`. Pass = `ALL TESTS PASSED`.

## Review Focus

1. **An orphan that re-enters a space while driven** must never park, be served or win the shift. Covered by `test_orphan_never_counts_as_parked` (Task 3).
2. **Orphans filling the spaces a customer needs.** Spawning refuses any space whose loss would make the shift unfittable. Covered by `test_orphan_never_blocks_the_shift` (Task 3).
3. **The pull on frozen or parked ships.** None at all, so parked ships never creep. Covered by `test_parked_ships_feel_no_pull` (Task 1).
4. **An orphan ejected while being driven, or while the picker lists it.** The ship is released, the picker closes, and there are no errors. Covered by `test_orphan_ejected_while_driven_releases_it` (Task 3).
5. **A ship at the hole's exact centre (d = 0).** No division by zero; the pull is capped at MAX_PULL with a zero direction. Covered by `test_pull_is_capped_and_safe_at_the_centre` (Task 1).

---

### Task 1: The black hole and its pull

**Files:**
- Create: `scripts/actors/BlackHole.gd`
- Modify: `scripts/Level.gd` (`@onready var _black_hole: BlackHole = get_node_or_null("BlackHole")`, `_apply_pull()` called from `_physics_process` before `_check_parking`)
- Test: `tests/test_black_hole.gd`, `tests/test_level.gd`

**Interfaces:**
- Produces:
  - `class_name BlackHole extends StaticBody2D`
    - `const PULL_K := 1_800_000.0`, `const MAX_PULL := 80.0`, `const CORE_RADIUS := 60.0`
    - `static func pull_at(distance: float) -> float`
    - `func pull_on(point: Vector2) -> Vector2`: the acceleration vector towards `global_position`, or `Vector2.ZERO` when the point is at the centre.
    - `_ready`:
      - adds a `CollisionShape2D` with a `CircleShape2D` of radius CORE_RADIUS
      - sets `material = Lighting.unlit()`
      - adds a purple `PointLight2D`, `Color(0.6, 0.3, 1.0)`, energy 0.8, `Lighting.round_texture()`, texture_scale 3.0
    - `_draw`: a black disc of CORE_RADIUS, plus an accretion ring between 1.0× and 1.8× CORE_RADIUS (3 arcs in orange-purple that rotate over time; `queue_redraw` in `_process`).
  - `Level._apply_pull()`: for each ship in `_ships` that isn't parked, calls `ship.apply_central_force(_black_hole.pull_on(ship.global_position) * ship.mass)`.

- [ ] **Step 1: Write the failing tests:**
  - `test_black_hole.gd`:
    - `test_pull_grows_closer_in`:
      - `pull_at(300)` within 0.01 of 20.0
      - `pull_at(950)` within 0.05 of 1.994
      - `pull_at(150) == 80.0`
      - `pull_at(40) == 80.0`
    - `test_pull_is_capped_and_safe_at_the_centre`: `pull_at(0) == 80.0`. A hole at (500, 500) gives `pull_on(Vector2(500, 500)) == Vector2.ZERO`, and `pull_on(Vector2(800, 500))` is within 0.01 of `Vector2(-20, 0)`.
    - `test_core_is_solid`: a hole in the tree has a `CollisionShape2D` child whose `CircleShape2D.radius == 60`.
    - `test_hole_ignores_the_dark`: `material.light_mode == LIGHT_MODE_UNSHADED`.
  - `test_level.gd`. Use `_make_level()`, add a `BlackHole` at `OPEN_FLOOR + Vector2(400, 0)`, and set `level._black_hole`.
    - `test_free_ship_drifts_towards_the_hole`: unfreeze the first ship at `OPEN_FLOOR` with zero velocity. After 30 physics frames, `linear_velocity.x > 0`.
    - `test_parked_ships_feel_no_pull`: park the first ship in A1 (as `_park_silver_leaver` does on a tiered level). After 30 frames it hasn't moved more than 0.01 px.
- [ ] **Step 2: Run the suite.** Expected: FAIL, because `BlackHole` is not declared.
- [ ] **Step 3: Implement** `BlackHole.gd` and `Level._apply_pull` per the Interfaces block.
- [ ] **Step 4: Run the suite.** Expected: `ALL TESTS PASSED`.
- [ ] **Step 5: Commit:** `feat: black hole that pulls free ships, stronger up close`.

### Task 2: Orphan rules, ledger bonuses and the result line

**Files:**
- Create: `scripts/core/Orphan.gd`
- Modify:
  - `scripts/core/ShiftLedger.gd`: add `var bonuses := 0` and `func add_bonus(amount: int) -> void`, which adds to `bonuses` and `earned` and is ignored once the outcome is decided
  - `scripts/ui/Result.gd`: the Bonuses line
  - `scripts/Level.gd`: put `"bonuses": ledger.bonuses` in `last_result`
- Test: `tests/test_orphan.gd`, `tests/test_shift_ledger.gd`, `tests/test_ui_flow.gd`

**Interfaces:**
- Produces:
  - `class_name Orphan extends RefCounted`
    - `const COUNTDOWN := 60.0`, `const BONUS := 25`, `const EARLY_COST := 15`
    - `var time_left := COUNTDOWN`
    - `func tick(delta: float) -> void`, floored at 0
    - `func ready_to_eject() -> bool`
    - `func badge_text() -> String`: `"%d:%02d"` while counting, `"EJECT ✓"` when ready
  - `ShiftLedger.add_bonus(amount: int)`

- [ ] **Step 1: Write the failing tests:**
  - `test_countdown_runs_a_minute_then_ejects`: a new Orphan has `badge_text() == "1:00"` and isn't ready. After `tick(59.5)` it reads `"0:01"` (rounded up with ceil) and isn't ready. After `tick(0.5)` it reads `"EJECT ✓"` and is ready. After `tick(5)`, `time_left == 0`.
  - `test_ledger_bonus_adds_to_earnings`: `add_bonus(25)` → `bonuses == 25` and `earned` up by 25. After the outcome is WON, `add_bonus(25)` changes nothing.
  - `test_result_shows_bonuses`: `show_result` with `"bonuses": 50` → Earnings text contains `"Bonuses ₵50"`. With 0, it doesn't contain `"Bonuses"`.
- [ ] **Step 2: Run the suite.** Expected: FAIL, because `Orphan` is not declared.
- [ ] **Step 3: Implement** per the Interfaces block.
- [ ] **Step 4: Run the suite.** Expected: `ALL TESTS PASSED`.
- [ ] **Step 5: Commit:** `feat: orphan countdown rules and ledger bonuses`.

### Task 3: Orphans in the lot

**Files:**
- Modify: `scripts/Level.gd`, `scripts/actors/Ship.gd`
- Test: `tests/test_level.gd`

**Interfaces:**
- Consumes: `Orphan` and `ShiftLedger.add_bonus` (Task 2).
- Produces:
  - In `Ship.gd`:
    - `var orphan: Orphan`
    - `_draw_badge` draws the orphan badge when `orphan != null`: a grey coin `Color(0.6, 0.6, 0.6)` while counting, green `Color(0.3, 0.9, 0.4)` when ready, with `orphan.badge_text()` beside it
    - `func make_orphan(o: Orphan) -> void`: sets `orphan`, hides the paint and lights layers, and sets the sprite modulate to `Color(0.65, 0.65, 0.7)`
  - In `Level.gd`:
    - `@export var orphan_count := 0`
    - `var _pool: Array[ShipSpec]`, a copy of `customer_queue` taken in `_ready` before the draw
    - `var _orphans_due: Array[float]`, shift-elapsed seconds
    - `var _orphan_hint_shown := false`
    - `static func orphan_times(rng: RandomNumberGenerator, count: int, shift: float) -> Array[float]`, each `randf_range(0.25, 0.6) * shift`
    - `func _spawn_orphan() -> Ship`: returns null when no allowed space is free
      - picks a random allowed space, then a random `_pool` spec that fits it
      - puts the ship at the space's transform, adds it to `_ships`, connects `dented`
      - calls `_on_ship_parked`-equivalent bookkeeping: `space.claim(ship)` and `ship.set_parked()`, but with no ledger call
      - shows the hint once
    - `func _allowed_orphan_spaces() -> Array[ParkingSpace]`
    - `func _update_orphans(delta: float) -> void`, called from `_physics_process`:
      - spawns due orphans, pushing a failed time 1 s later
      - ticks each orphan
      - releases its space once it no longer touches it
      - settles it at the exit
    - `func _eject_orphan(ship: Ship) -> void`:
      - releases the ship if driven, closes the picker, releases the space
      - removes and frees the ship
      - if ready: `ledger.add_bonus(Orphan.BONUS)`
      - otherwise: `ledger.add_dent(Orphan.EARLY_COST)` and the hint `"-₵15 ejected too early"`. Don't go through `_on_ship_dented`, because an orphan has no customer to count the dent against.
  - **Changed behaviour:**
    - `ships_near_world` lists a parked ship when it has an orphan
    - `select_ship` allows a parked orphan: it calls `ship.unpark()` and erases its tracker before driving
    - `_check_parking` skips ships with an orphan

- [ ] **Step 1: Write the failing tests** in `tests/test_level.gd`. Use a tiered Level 1 with an exit (`_make_tiered_level()`) unless noted.
  - `test_orphan_times_fall_in_the_window`: 50 rolls of `Level.orphan_times(rng, 2, 300.0)`. Each has 2 entries in [75, 180].
  - `test_orphan_takes_an_allowed_free_space`:
    - move the first ship to `OPEN_FLOOR`
    - `_spawn_orphan()` returns a ship with `orphan != null`, `is_parked`
    - some space's `occupant` is that ship, and `ParkingRules.fits_class(ship.spec.ship_class, space.space_class)`
  - `test_orphan_never_blocks_the_shift`: before adding the level to the tree, set `customer_queue` to 2 light and 4 medium fixture specs, so they need all 6 Level 1 spaces, and `random_customers = 0`. `_spawn_orphan()` returns null.
  - `test_orphan_waits_for_a_free_space`:
    - claim every space with dummy occupants and set `_orphans_due = [0.0]`
    - after `_update_orphans(0.1)` there's no orphan
    - release A1, then call `_update_orphans(0.5)` twice and `_update_orphans(0.1)` once → an orphan sits in A1
  - `test_parked_orphan_can_be_driven`: spawn one. `select_ship(orphan)` → `driven_ship == orphan` and `not orphan.is_parked`.
  - `test_orphan_ejected_after_countdown_pays_bonus`: spawn, set `orphan.orphan.time_left = 0`, move it to `EXIT_POS`, call `_update_orphans(0.1)`. The ship is gone from Ships, `ledger.bonuses == 25`, and `served` is unchanged.
  - `test_orphan_ejected_early_costs_pay`: same, without zeroing the timer. `ledger.pay` is down by 15, `bonuses == 0`, and served is unchanged.
  - `test_orphan_ejected_while_driven_releases_it`: select it, move it to the exit, update → `driven_ship == null`, and no errors.
  - `test_orphan_never_counts_as_parked`: select an orphan, release it, place it centred in its own space (frozen), and run `_check_parking(0.5)` four times → served unchanged, and `is_parked` false.
  - `test_shift_wins_with_an_orphan_present`: spawn an orphan, set `ledger.served = customers - 1`, park a stayer via `_on_ship_parked` → outcome WON.
  - `test_level_without_orphans_rolls_none`: plain Level 1 → `_orphans_due.is_empty()`.
- [ ] **Step 2: Run the suite.** Expected: FAIL, because `_spawn_orphan` / `orphan_times` are not declared.
- [ ] **Step 3: Implement** per the Interfaces block. In `_ready`, when `orphan_count > 0`, set `_orphans_due = orphan_times(_rng, orphan_count, GameState.shift_seconds())`. Elapsed time = `GameState.shift_seconds() - ledger.time_left`.
- [ ] **Step 4: Run the suite.** Expected: `ALL TESTS PASSED`.
- [ ] **Step 5: Commit:** `feat: orphaned ships appear in spare spaces and pay to be ejected on time`.

### Task 4: The Level 4 scene, Level Select and the GDD

**Files:**
- Create: `scenes/levels/Level04.tscn`, generated with a scratchpad Python script in the style of Level 2's
- Modify: `tests/test_level.gd`, `tests/test_lighting.gd` (add Level 4 to `LEVELS`), `tests/test_ui_flow.gd`, `docs/GDD.md`

**Scene contents:**
- **Copied from Level 2:** root `Level04` with Level.gd, plus the walls (WallTop/Bottom/Left/Right), Floor, Entrance at (140, 700) rotated π/2, LotCamera, HUD, Controls, ShipPicker, the `Exit` ExitPad at (2260, 700) and `Ships`. There is no island.
- **New nodes:**

  | Node | Notes |
  |---|---|
  | `BlackHole` (StaticBody2D) | BlackHole.gd at (1200, 700) |
  | `Spaces` | per the spec's table: top row rotation 0, bottom row rotation π, G1/G2 rotation 0 with `gold = true` |
  | `Floodlights` / FT1 | (545, 170), covering T1 and T2 |
  | `Floodlights` / FT2 | (865, 150), covering T3 and T4 |
  | `Floodlights` / FT3 | (1215, 150), covering T5 and T6 |
  | `Floodlights` / FU1 | (545, 1230) |
  | `Floodlights` / FU2 | (790, 1260) |
  | `Floodlights` / FG1 | (2000, 250) |
  | `Floodlights` / FG2 | (2000, 1150) |
  | `Floodlights` / FEntrance | (300, 700) |
  | `Floodlights` / FExit | (2120, 700) |

- **Settings:** per the Global Constraints.

- [ ] **Step 1: Write the failing tests:**
  - `test_level04_layout`:
    - `has_level_scene(4)`
    - counts `{HEAVY: 3, MEDIUM: 5, LIGHT: 3}`
    - gold spaces are exactly G1 and G2
    - an `Exit`
    - `BlackHole` at (1200, 700)
    - every setting, and all 10 ships in the pool
  - `test_level04_spaces_stay_clear`: for every space, the distance from the hole's centre to the space's rectangle is greater than 150 (using `_circle_hits_rect`). No space overlaps the bay or the exit.
  - `test_level04_runs_a_shift`: loads with 7 customers and `_orphans_due.size() == 2`, runs 120 frames, and shows no errors.
  - Add Level 4 to `LEVELS` in `test_lighting.gd`.
  - `test_ui_flow.gd`:
    - `test_level_select_locks`: with 3 unlocked, button 4 is "LOCKED"; check the existing assertions still hold
    - rename `test_level4_says_coming_soon` to `test_level5_says_coming_soon` (unlocked 5, button 5)
- [ ] **Step 2: Run the suite.** Expected: FAIL, because there's no Level 4 scene.
- [ ] **Step 3: Generate `Level04.tscn`.**
- [ ] **Step 4: Run the suite.** Expected: `ALL TESTS PASSED`. Then run the scene headless for 300 frames and grep for `ERROR`. Expected: no matches.
- [ ] **Step 5: Update the GDD.** In the §5 Level 4 row, add the 11 rim spaces, the gold G1/G2, the pull rule and the core. Under "Orphaned ships", add the numbers (2 per shift, 25–60% of the shift, 60 s, +₵25 / −₵15, not served, fit-safe spaces).
- [ ] **Step 6: Commit:** `feat: Level 4 Gravity Well Lot`.

### Task 5: Export check and playtests

- [ ] **Step 1:** Export the pack and run `tools/check_export_pack.gd` → `EXPORT CHECK PASSED`. Run Level 4 from the pack headless → no `ERROR`.
- [ ] **Step 2:** Open Level 4 on desktop, export a debug APK, and install it on the phone (`D:/Astudio/SDK/platform-tools/adb.exe`). Ask the user to play and report on the pull strength, orphan timing and bonus size.
