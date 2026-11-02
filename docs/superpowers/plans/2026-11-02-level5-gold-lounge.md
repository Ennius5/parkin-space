# Level 5 – Gold Lounge Rush Hour Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Level 5. It has mostly gold customers, faster arrivals, and special requests for a named space. Parked ships can be moved to make room.

**Architecture:**
- Three Level settings drive everything: `tier_weights`, `allow_moving_parked` and `request_count`.
- Level 1–4 scenes don't set them, so their defaults keep those levels unchanged.
- The Customer gains the requested space's label. Level picks which customers make requests, chooses the space when each one arrives, pays the bonus, and lets a parked ship be picked up and re-parked for free.

**Tech Stack:** Godot 4.7.2, typed GDScript, the project's test runner.

**Spec:** `docs/superpowers/specs/2026-11-02-level5-gold-lounge-design.md`

## Global Constraints

- **Levels 1–4 unchanged.** The defaults are `tier_weights = {}` (meaning `Customer.TIER_WEIGHTS`), `allow_moving_parked = false` and `request_count = 0`.
- **Level 5 tiers:** `{GOLD: 60, SILVER: 30, BRONZE: 10}`, with the gold-fit rule still applied.
- **Requests:**
  - `request_count = 3`, disjoint from retrieval customers
  - the space fits the ship and prefers an occupied fitting space
  - `REQUEST_BONUS := 20`, paid through `ledger.add_bonus` only when the customer parks in the named space
  - parking elsewhere pays the fee but no tip and no bonus
  - copy: badge `"→ %s"` (space label), hint `"Special request: park them in their space"` (once per shift)
- **Re-parking a moved ship:** no ledger call at all. A leaver's `request_in` keeps counting.
- **Level 5 settings:**

  | Setting | Value |
  |---|---|
  | level_number | 5 |
  | goal | `"Serve 9 customers"` |
  | random_customers | 9 |
  | base_pay | 100 |
  | silver / gold targets | 360 / 420 |
  | arrival_interval | 6 |
  | use_tiers | true |
  | retrieval_count | 2 |
  | request_count | 3 |
  | allow_moving_parked | true |
  | pool | all 10 ships |
  | shift_seconds | none (difficulty sets it) |

- **Layout:** 12 spaces, all rotation π/2.
  - A1–A3 heavy at x 650 (y 400 / 700 / 1000)
  - B1–B3 light at x 1150 (y 450 / 700 / 950)
  - G1–G6 medium gold at x 1700 (y 290 / 470 / 650 / 830 / 1010 / 1190)
  - EXIT at (2260, 700), entrance at (140, 700) rotated π/2
  - floodlights so every space is covered, and every space corner at world y ≥ 220
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Test command:** `bash .superpowers/sdd/2026-11-01-ship-art-pipeline/t.sh`. Pass = `ALL TESTS PASSED`.

## Review Focus

1. **A request customer whose named space is taken when they park elsewhere** (the player gave up). They're served with no tip and no bonus, and the pin clears. Covered by `test_request_parked_elsewhere_pays_fee_only` (Task 3).
2. **Moving a parked leaver.** Its retrieval request still fires, and its tip still waits for the hand-over. Covered by `test_moved_leaver_still_asks_for_its_ship` (Task 2).
3. **Re-parking a moved ship as the shift's last serve.** It must not serve again, and must not end or win the shift early. Covered by `test_reparking_never_serves_twice` (Task 2).
4. **The named space is the only space that fits a heavy, and it holds another heavy.** The request still points there, and the player must move that ship. Covered by `test_request_prefers_an_occupied_fitting_space` (Task 3).
5. **Tapping near parked ships in Levels 1–4.** They still can't be picked. Covered by `test_parked_ships_stay_put_where_not_allowed` (Task 2).

---

### Task 1: Per-level tier odds

**Files:**
- Modify: `scripts/core/Customer.gd` (`roll`), `scripts/Level.gd`
- Test: `tests/test_customer.gd`, `tests/test_level.gd`

**Interfaces:**
- Produces:
  - `Customer.roll(rng, use_tiers: bool, gold_allowed := true, weights: Dictionary = {}) -> Customer`. An empty `weights` means `TIER_WEIGHTS`.
  - `Level`: `@export var tier_weights: Dictionary = {}`, passed to `Customer.roll` in `spawn_next_customer`.

- [ ] **Step 1: Write the failing tests:**
  - `test_custom_tier_weights`: 2000 rolls with `{GOLD: 60, SILVER: 30, BRONZE: 10}` and gold allowed → the gold share is between 0.55 and 0.65, and bronze is between 0.07 and 0.13.
  - `test_default_tier_weights_unchanged`: 2000 rolls with no weights → gold is between 0.16 and 0.24.
  - `test_custom_weights_still_respect_gold_fit`: 200 rolls with the Level 5 weights and `gold_allowed = false` → no gold.
- [ ] **Step 2: Run the suite.** Expected: FAIL (wrong argument count).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the suite.** Expected: `ALL TESTS PASSED`.
- [ ] **Step 5: Commit:** `feat: levels can set their own tier odds`.

### Task 2: Moving parked ships

**Files:**
- Modify: `scripts/Level.gd` (`@export var allow_moving_parked := false`, `select_ship`, `ships_near_world`, `_update_customers`, `_on_ship_parked`)
- Test: `tests/test_level.gd`

**Interfaces:**
- Produces:
  - `select_ship` accepts a parked customer ship when `allow_moving_parked` is true. It calls `ship.unpark()` and erases its tracker, then drives it.
  - `ships_near_world` lists parked customer ships under the same condition.
  - `_update_customers` releases the space of any customer ship that isn't parked and no longer touches it. This replaces the requested-only release.
  - `_on_ship_parked`, when the customer has `parked_once`: claim the space, release the ship if it's being driven, and set it parked. Nothing else (no ledger, no request rescheduling).

- [ ] **Step 1: Write the failing tests.** Use `_make_tiered_level()` with `level.allow_moving_parked = true`, set before adding the level to the tree. Use a small helper `_moving_level()`.
  - `test_parked_ship_can_be_moved_when_allowed`: park a silver stayer in A1 via `_on_ship_parked`. `select_ship(ship)` → `driven_ship == ship` and not parked. Move it to `OPEN_FLOOR`, call `_update_customers(0.1)` → `A1.occupant == null`.
  - `test_reparking_never_serves_twice`:
    - park a stayer in A1 → served 1
    - set `ledger.customers = 1`, so a second serve would win
    - move it as above, then `_on_ship_parked(ship, B1-or-free-fitting-space)`
    - served is still 1, `earned` is unchanged, and the outcome hasn't changed since the first park
    - re-parking doesn't end the shift a second time: `_ended` keeps the value it had after the first park
  - `test_moved_leaver_still_asks_for_its_ship`: `_park_silver_leaver`, record `customer.request_in`. Select it, move it, re-park it in another fitting space → `request_in` is unchanged and still ≥ 0. After `_update_customers(request_in + 0.1)` the customer is `requested`.
  - `test_parked_ships_stay_put_where_not_allowed`: plain tiered level (default false). Park a stayer, then `select_ship(ship)` → `driven_ship == null`, and `ships_near_world(ship.global_position, 50)` doesn't contain it.
- [ ] **Step 2: Run the suite.** Expected: FAIL.
- [ ] **Step 3: Implement** per the Interfaces block.
- [ ] **Step 4: Run the suite.** Expected: `ALL TESTS PASSED`. The existing retrieval and orphan tests must stay green, because the space-release change touches their path.
- [ ] **Step 5: Commit:** `feat: a level can let the valet move parked ships`.

### Task 3: Special requests

**Files:**
- Modify:
  - `scripts/core/Customer.gd`: `var wants_space := ""`, `var got_wanted_space := false`. `tip()` returns 0 when `wants_space != ""` and not `got_wanted_space`.
  - `scripts/Level.gd`
  - `scripts/actors/Ship.gd`: badge
  - `scripts/actors/ParkingSpace.gd`: pin
- Test: `tests/test_customer.gd`, `tests/test_level.gd`, `tests/test_parking_space.gd`

**Interfaces:**
- Produces:
  - In Level:
    - `@export var request_count := 0`
    - `const REQUEST_BONUS := 20`
    - `var _request_indexes: Array[int]`, chosen in `_ready` from the queue positions not in `_retrieval_indexes` (Fisher-Yates with `_rng`, like `_pick_retrievals`)
    - `var _request_hint_shown := false`
    - `func _pick_request_space(ship_class: int) -> ParkingSpace`: among spaces that fit, a random occupied one if any exists, otherwise a random fitting one
  - In `spawn_next_customer`, for a request position:
    - set `c.wants_space = space.label`
    - `space.set_pin(c.color())`
    - show the hint once
  - `_on_ship_parked`, first park, for a request customer:
    - `c.got_wanted_space = space.label == c.wants_space`
    - clear the pin on the named space (find it by label)
    - if `got_wanted_space`, `ledger.add_bonus(REQUEST_BONUS)`, before the tip and serve calls
  - `ParkingSpace`: `var pin_color := Color(0, 0, 0, 0)`, `set_pin(c: Color)`, `clear_pin()`. When `pin_color.a > 0`, `_draw` draws a small filled circle with a stem above the label, as a map pin.
  - `Ship._draw_badge`: while `customer.wants_space != ""` and not `parked_once`, draws `"→ %s" % customer.wants_space` under the coin, in the coin's colour.

- [ ] **Step 1: Write the failing tests:**
  - `test_customer.gd` / `test_request_customer_tips_only_in_their_space`: a silver customer with `wants_space = "G4"`, `parked_once`, and `got_wanted_space` false → `tip() == 0`. With it true → 15.
  - `test_parking_space.gd` / `test_pin_shows_and_clears`: `set_pin(Color.GOLD)` → `pin_color.a > 0`. `clear_pin()` → 0.
  - `test_level.gd`. Use a Level 1-based tiered level with an exit, `request_count = 3`, `retrieval_count = 2`, `random_customers = 0`, and a 6-ship queue of light_scouts (all fit everywhere).
    - `test_requests_never_overlap_retrievals`: `_request_indexes.size() == 3`, and no index is in `_retrieval_indexes`.
    - `test_request_prefers_an_occupied_fitting_space`: park a stayer in A1 (or claim A1 with the first ship). `_pick_request_space(LIGHT)` returns A1 in 20 of 20 calls when A1 is the only occupied space. With no occupied space, the result is always a space that fits.
    - `test_request_in_named_space_pays_bonus_and_tip`: take the first spawned ship, make its customer silver with `wants_space = "B1"`, and park it in B1 → bonuses 20, tips 15, served +1, and the B1 pin is cleared.
    - `test_request_parked_elsewhere_pays_fee_only`: same, but park it in A2 → bonuses 0, tips 0, `earned` up by exactly 20, served +1, and the B1 pin is cleared.
- [ ] **Step 2: Run the suite.** Expected: FAIL.
- [ ] **Step 3: Implement** per the Interfaces block.
- [ ] **Step 4: Run the suite.** Expected: `ALL TESTS PASSED`.
- [ ] **Step 5: Commit:** `feat: special requests for a named space, with a bonus for honouring them`.

### Task 4: The Level 5 scene, Level Select, Result and the GDD

**Files:**
- Create: `scenes/levels/Level05.tscn`, generated by a scratchpad Python script from Level 4's scene, minus BlackHole, Asteroids and Boulders, with the Global Constraints' layout and settings
- Modify: `tests/test_level.gd`, `tests/test_lighting.gd` (add Level 5 to `LEVELS`), `tests/test_ui_flow.gd`, `docs/GDD.md`

- [ ] **Step 1: Write the failing tests:**
  - `test_level05_layout`:
    - `has_level_scene(5)`
    - counts `{HEAVY: 3, MEDIUM: 6, LIGHT: 3}`
    - gold is exactly G1–G6
    - an Exit, and no BlackHole, Radiation, Asteroids or Boulders node
    - every setting from the Global Constraints, including `tier_weights`, `request_count`, `allow_moving_parked` and `arrival_interval == 6`
    - all 10 ships in the pool
  - `test_level05_spaces_clear_hud_bay_and_exit`: every space corner is at world y ≥ 220 and outside the bay and exit rectangles.
  - `test_level05_runs_a_shift`: 9 customers, `_request_indexes.size() == 3`, and 120 frames with no errors.
  - Add Level 5 to `LEVELS` in `test_lighting.gd`.
  - `test_ui_flow.gd`:
    - replace `test_level5_says_coming_soon` with `test_level5_opens`: with 5 unlocked, button 5 is enabled
    - `test_result_after_level5_has_no_next`: a won result with `"level": 5` → `%Next.disabled`
- [ ] **Step 2: Run the suite.** Expected: FAIL.
- [ ] **Step 3: Generate `Level05.tscn`.**
- [ ] **Step 4: Run the suite.** Expected: `ALL TESTS PASSED`. Then run the scene headless for 300 frames, and capture a frame to confirm it looks right.
- [ ] **Step 5: Update the GDD.** In the §5 Level 5 row, add the rows layout, 60/30/10 tiers, 6 s arrivals, 3 requests (+₵20), and moving parked ships. In §4, add a "Special requests" rule paragraph.
- [ ] **Step 6: Commit:** `feat: Level 5 Gold Lounge Rush Hour`.

### Task 5: Export check and playtests

- [ ] **Step 1:** Export the pack, then run `check_export_pack` → PASSED, and run Level 5 from the pack → no errors.
- [ ] **Step 2:** Open it on desktop. Build the APK and install it on the phone, keeping a background `adb nodaemon server` running. Ask the user to play.
