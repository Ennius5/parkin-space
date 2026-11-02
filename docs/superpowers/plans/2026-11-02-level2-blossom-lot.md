# Level 2 – Blossom Lot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Level 2 adds heavy ships, a petal-shaped lot, bronze/silver/gold tip tiers and retrieval requests. Level 1 plays as before.

**Architecture:**
- **Pure rules are tested directly:**
  - `ParkingRules.fits_lot` decides whether a set of ships can park in a lot.
  - A new `Customer` (a `RefCounted`) holds the tier, the tip rules, waiting time and retrieval state.
  - `ShiftLedger` gains fees and tips paid separately from serving.
- **`Level`** gives each ship a `Customer` and adds retrieval and the exit.
- **Scenes:** `ParkingSpace` gains gold spaces. `Ship` draws an upright badge. `Level02.tscn` is the petal lot.

**Tech Stack:** Godot 4.7.2 typed GDScript; the in-repo test runner.

**Spec:** `docs/superpowers/specs/2026-11-02-level2-blossom-lot-design.md`

## Global Constraints

- **Park fee:** stays ₵20 (`ShiftLedger.PARK_FEE`).
- **Tier mix:** Bronze 30%, Silver 50%, Gold 20%.
- **Tips:**

  | Tier | Tip |
  |---|---|
  | Bronze | a 50% chance, rolled at spawn, of ₵10 |
  | Silver | ₵15 − ₵5 per dent, never below 0 |
  | Gold | ₵40 while waiting ≤ 10 s, then −₵4 per second (`maxi(0, 40 - 4 * ceili(wait - 10))`). ₵0 unless parked in a gold space. |

- **Waiting** (gold): counts from arrival until parked, plus from the retrieval request until the ship is returned.
- **Retrieval:**
  - 2 of the 6 customers are chosen at the start of the shift.
  - Each asks for their ship back after `request_delay(rng, time_left) = minf(randf_range(20, 40), maxf(0, time_left - 30))` seconds from parking.
  - **Ruling against the spec's "fewer than 30 s left → straight away":** this formula also keeps a 20–40 s delay from landing in the last 30 s. That matches the spec's intent ("never too late to be finished").
- **When money is paid:**
  - Stayers are paid the fee and tip at parking.
  - Leavers are paid the fee at parking, and the tip plus "served" at the exit.
- **Level 2 settings:**

  | Setting | Value |
  |---|---|
  | Goal | "Serve 6 customers" |
  | Customers | `random_customers = 6` |
  | Shift | 180 s |
  | Base pay | 100 |
  | Silver target | 240 |
  | Gold target | 280 |
  | Arrival interval | 10 s |
  | Tiers | `use_tiers = true` |
  | Retrievals | `retrieval_count = 2` |

- **Level 1:** `use_tiers = false` and `retrieval_count = 0`, so it behaves exactly as now.
- **Test command:** `bash .superpowers/sdd/2026-11-01-ship-art-pipeline/t.sh`. Pass = `ALL TESTS PASSED`.
- Commit only after each task's tests pass. Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A requested (unparked) ship must never re-park.** Expect `_check_parking` and the trackers to skip it, and the ship to stay drivable until it is returned.
2. **A ship can leave its space mid-collision with a neighbour.** Expect the space to free only when no hull point is inside it, and never to free while the ship is still partly in it.
3. **The driven ship is the one being returned.** Expect `release_ship()` before the despawn, and no freed-node access afterwards (HUD, picker, trackers, `driven_ship`).
4. **The draw must stay safe with a pool where only some ships fit** (for example a pool with a heavy, in a lot with no heavy space). Expect only fitting ships drawn, with no infinite loop and no crash.
5. **The shift ending while a retrieval is pending.** Expect a timeout (lose) with no errors from that customer's timers.

---

### Task 1: Fair draws

**Files:**
- Modify: `scripts/core/ParkingRules.gd`, `scripts/Level.gd`
- Test: `tests/test_parking_rules.gd`, `tests/test_level.gd`

**Interfaces:**
- Produces:
  - `static func fits_lot(ship_classes: Array[int], space_classes: Array[int]) -> bool`. True iff, for every class c, (ships with class ≥ c) ≤ (spaces with class ≥ c).
  - `static func draw_customers(pool: Array[ShipSpec], count: int, rng: RandomNumberGenerator, space_classes: Array[int] = []) -> Array[ShipSpec]`:
    - An empty `space_classes` means no limit.
    - Each pick is weighted among the pool ships that keep `fits_lot` true.
    - It stops early if none fit.
  - `Level._space_classes() -> Array[int]` reads `$Spaces`, and `_ready` passes it to the draw.

- [ ] **Step 1: Write the failing tests.**
  - `test_fits_lot_counts_bigger_spaces`:
    - `fits_lot([H, M], [H, M])` is true.
    - `fits_lot([M, M], [H, M])` is true.
    - `fits_lot([H, H], [H, M])` is false.
    - `fits_lot([L, L, L], [M, L])` is false.
  - `test_draw_never_exceeds_lot`: a pool of heavy w1 and light w1 with spaces `[H, L, L]` gives at most 1 heavy over 200 seeded draws of 3.
  - `test_draw_skips_ships_with_no_space`: a pool of heavy and medium with spaces `[M, M]` gives 2 mediums.
  - `test_draw_stops_when_nothing_fits`: a pool of only heavies with spaces `[M]` gives `[]`.
- [ ] **Step 2: Run** t.sh. Expected: FAIL (`fits_lot` not found).
- [ ] **Step 3: Implement.** Keep the existing two-argument calls working.
- [ ] **Step 4: Run** t.sh. Expected: ALL TESTS PASSED.
- [ ] **Step 5: Commit** `feat: random customers always fit the lot's spaces`.

### Task 2: Customer tiers, tips and retrieval timing

**Files:**
- Create: `scripts/core/Customer.gd`
- Test: `tests/test_customer.gd`

**Interfaces:**
- Produces `class_name Customer extends RefCounted` with:
  - `enum Tier { NONE, BRONZE, SILVER, GOLD }`
  - `const TIER_WEIGHTS := {BRONZE: 30, SILVER: 50, GOLD: 20}`
  - Fields:

    | Field | Type | Default |
    |---|---|---|
    | `tier` | `Tier` | `NONE` |
    | `bronze_tips` | bool | — |
    | `wants_retrieval` | bool | false |
    | `requested` | bool | false |
    | `request_in` | float | -1.0 (seconds until the request; < 0 means none scheduled) |
    | `dents` | int | 0 |
    | `wait` | float | 0.0 |
    | `parked_in_gold` | bool | false |
    | `parked_once` | bool | false |

  - `static func roll(rng: RandomNumberGenerator, use_tiers: bool) -> Customer`. Without tiers it gives `NONE`; with tiers it rolls the tier and `bronze_tips`.
  - `func tip() -> int`. `NONE` gives 0; the other tiers follow the Global Constraints.
  - `func is_waiting() -> bool`: `(not parked_once) or requested`.
  - `static func request_delay(rng: RandomNumberGenerator, time_left: float) -> float`
  - `func color() -> Color`:

    | Tier | Colour |
    |---|---|
    | Bronze | `Color(0.8, 0.5, 0.2)` |
    | Silver | `Color(0.8, 0.82, 0.86)` |
    | Gold | `Color(1, 0.82, 0.2)` |
    | None | transparent |

- [ ] **Step 1: Write the failing tests.**
  - `test_none_tier_never_tips`.
  - `test_bronze_tip_follows_roll`: gives 10 if `bronze_tips`, else 0.
  - `test_silver_tip_drops_per_dent`: 0 dents gives 15, 2 gives 5, 4 gives 0.
  - `test_gold_needs_gold_space`: wait 5, not in a gold space gives 0; in a gold space gives 40.
  - `test_gold_tip_shrinks_after_ten_seconds`: in a gold space, wait 10 gives 40, wait 12.5 gives 28, wait 25 gives 0.
  - `test_tier_mix`: with seed 85, 2000 rolls give a gold share within 0.17–0.23 and silver within 0.46–0.54.
  - `test_no_tiers_rolls_none`.
  - `test_request_delay_range`: 50 seeded calls with time_left 180 are all within [20, 40].
  - `test_request_delay_leaves_thirty_seconds`: time_left 50 gives ≤ 20; time_left 25 gives 0.
  - `test_is_waiting`: fresh is true; after `parked_once` it's false; after `requested` it's true.
- [ ] **Step 2: Run** t.sh. Expected: FAIL (Customer not declared).
- [ ] **Step 3: Implement.** Use `rng.rand_weighted` for the tier.
- [ ] **Step 4: Run** t.sh. Expected: ALL TESTS PASSED.
- [ ] **Step 5: Commit** `feat: customer tiers, tips and retrieval timing`.

### Task 3: Ledger fees and tips

**Files:**
- Modify: `scripts/core/ShiftLedger.gd`
- Test: `tests/test_shift_ledger.gd`

**Interfaces:**
- Produces:
  - `var tips: int = 0`
  - `func add_fee(fee: int = PARK_FEE) -> void`: adds to `earned` without serving.
  - `func add_tip(amount: int) -> void`: adds to `tips` and `earned`.
  - `serve_customer(fee := PARK_FEE)` is unchanged; leavers call `serve_customer(0)`.
  - All three are ignored once the outcome is decided.

- [ ] **Step 1: Write the failing tests:**
  - `test_add_fee_does_not_serve`
  - `test_add_tip_counts_in_earnings`
  - `test_leaver_flow_wins_on_return`: customers=1, `add_fee()`, not won; `serve_customer(0)` gives WON and earned 20.
  - `test_no_money_after_outcome`
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: ALL TESTS PASSED.
- [ ] **Step 5: Commit** `feat: ledger pays fees and tips separately from serving`.

### Task 4: Gold spaces, leaving a space, unparking, and the ship badge

**Files:**
- Modify: `scripts/actors/ParkingSpace.gd`, `scripts/actors/Ship.gd`, `scripts/ui/ShipPicker.gd`
- Test: `tests/test_parking_space.gd`, `tests/test_ship.gd`, `tests/test_ship_picker.gd`

**Interfaces:**
- Produces:
  - **ParkingSpace:**
    - `@export var gold := false`. The label is drawn with a gold "★" after it.
    - `func release() -> void`
    - `func touches(ship: Ship) -> bool`: any hull point inside the rectangle.
  - **Ship:**
    - `var customer: Customer` (null means no badge).
    - `func unpark() -> void`: `is_parked = false`, unfreeze, modulate back to white.
    - A badge drawn by a child `Node2D` named `Badge` with `top_level = true`. Each frame it's placed at `global_position + Vector2(0, -(max(hull_size) / 2 + 24))`.
      - It draws a 14 px coin in `customer.color()`.
      - A gold customer gets "₵N" text (the current `tip()`).
      - A requested customer gets "↩".
      - Nothing is drawn for `NONE` with no request.
  - **ShipPicker:** when the ship's tier isn't `NONE`, a `Label` "●" coloured `customer.color()` (via `add_theme_color_override("font_color", …)`) sits between the swatch and the button. `func coin_color(i: int) -> Color` returns it for tests, or transparent if there's none.

- [ ] **Step 1: Write the failing tests:**
  - `test_gold_space_flag_and_release`: claim then release gives occupant null.
  - `test_touches_partial_overlap`: a ship half inside gives `touches` true and `check` false.
  - `test_unpark_restores_ship`: after `set_parked()` then `unpark()`, the ship isn't parked or frozen and modulate is `Color.WHITE`.
  - `test_badge_stays_upright_above_ship`: ship rotation 1.2 gives a Badge `global_rotation` of 0, with the badge above the ship.
  - `test_picker_row_shows_tier_coin`: a gold-customer ship gives a row with a coin label coloured gold.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: ALL TESTS PASSED.
- [ ] **Step 5: Commit** `feat: gold spaces, unparking and customer badges`.

### Task 5: Level runs tiers, retrieval and the exit

**Files:**
- Create: `scenes/actors/ExitPad.tscn` + `scripts/actors/ExitPad.gd`
- Modify: `scripts/Level.gd`, `scripts/ui/HUD.gd`, `scripts/ui/Result.gd`
- Test: `tests/test_level.gd`

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces:
  - **New Level exports:** `use_tiers := false` and `retrieval_count := 0`.
  - **Optional `$Exit` node** (an ExitPad). Without it, retrieval is off.
  - **ExitPad:** `class_name ExitPad extends Node2D` with `const RADIUS := 90.0`, `func contains(point: Vector2) -> bool`, and a floor drawing of a 140×220 rectangle labelled "EXIT".
  - **Level:** `customers: Dictionary` maps Ship → Customer, and `customer_for(ship) -> Customer`.
    - In `_ready`, `retrieval_count` distinct queue indexes are chosen with the level's rng.
    - In `spawn_next_customer`, `ship.customer = Customer.roll(...)`, plus `wants_retrieval` for the chosen indexes.
  - **Per physics frame:**
    - `wait += delta` while `is_waiting()`.
    - Count down `request_in`, and on 0 call `_request(ship)`.
    - For a requested ship: release its space once `not space.touches(ship)`, and if `$Exit.contains(ship.global_position)` call `_return(ship)`.
  - **Parking:**
    - Mark `parked_once` and `parked_in_gold = space.gold`.
    - A leaver is paid `add_fee()` and given `request_in = Customer.request_delay(rng, ledger.time_left)`.
    - Everyone else is paid `serve_customer()` + `add_tip(customer.tip())`.
  - **`_request(ship)`:** `requested = true`, `ship.unpark()`, and the hint "Return it to the EXIT" once per shift.
  - **`_return(ship)`:**
    - `release_ship()` if it's the driven ship.
    - Free its space if it still holds it.
    - `serve_customer(0)` + `add_tip(tip())`.
    - Erase it from the customers dictionary and the trackers, then `queue_free()`.
  - **Rules:**
    - `_check_parking` skips requested ships.
    - A dent adds to `customer.dents`.
    - The HUD's customers text becomes "Served %d / %d".
    - `last_result` gains `"tips"`.
    - The Result screen adds "Tips ₵%d" when tips > 0, and "Parked" becomes "Served".

- [ ] **Step 1: Write the failing tests** on a test-built level. Instantiate Level01, set `use_tiers`/`retrieval_count` before `add_child`, and add an ExitPad child named `Exit` in code.
  - `test_level1_has_no_tiers_or_retrievals`: the spawned ship's customer tier is NONE and `wants_retrieval` is false.
  - `test_stayer_pays_fee_and_tip_on_parking`: force a silver customer, call `_on_ship_parked(ship, space)`. Expect earned 35 and served 1.
  - `test_leaver_pays_fee_then_requests`:
    - Parking gives earned 20, served 0, and `request_in` in [20, 40].
    - Set `request_in = 0.01` and step physics. Expect `requested`, the ship unparked, and `_check_parking` not re-parking it while it sits in its space.
  - `test_space_frees_after_ship_leaves`: move the requested ship fully out of its space and step. Expect `space.occupant == null`.
  - `test_return_at_exit_serves_and_despawns`:
    - Move the requested, driven ship onto the exit and step.
    - Expect served +1, the tip added, the ship freed, `driven_ship == null`, and no script errors.
  - `test_waiting_counts_until_parked_and_after_request`.
  - `test_timeout_with_pending_request_loses_cleanly`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: ALL TESTS PASSED, and Level01 runs headless for 600 frames with no errors.
- [ ] **Step 5: Commit** `feat: tip tiers, retrieval requests and the exit pad`.

### Task 6: Level02 – Blossom Lot

**Files:**
- Create: `scenes/levels/Level02.tscn`
- Modify: `autoload/GameState.gd` (only if `has_level_scene` needs it; check first), `docs/GDD.md` (§5 tier numbers, retrieval, the Level 2 layout)
- Test: `tests/test_level.gd`

**Interfaces:**
- Consumes: Task 5's exports and `ExitPad`.
- Produces: `Level02.tscn` built like Level01:
  - Walls 2400×1400 and the same floor.
  - **Island:** a `StaticBody2D` with a `CircleShape2D` of radius 160 at (1200, 700), plus a round floor polygon.
  - **Entrance** at (140, 700), rotation π/2, as in Level01.
  - **`Exit`** (ExitPad) at (2260, 700).
  - The HUD, Controls, ShipPicker and LotCamera, as in Level01.
  - **Spaces P1–P10:** at angle θ = 18° + 36°·k, position `(1200 + 300·cos θ, 700 + 300·sin θ)`, rotation θ − 90°. Classes by θ:

    | θ | 18 | 54 | 90 | 126 | 162 | 198 | 234 | 270 | 306 | 342 |
    |---|---|---|---|---|---|---|---|---|---|---|
    | Class | M (gold) | H | M | L | H | M | L | M | H | M (gold) |

  - **Pool:** every Level01 pool ship plus `AgriShip.tres` and `heavy_freighter.tres`.
  - All other settings as in the Global Constraints.

- [ ] **Step 1: Write the failing test** `test_level02_layout`:
  - 10 spaces: 3 heavy, 5 medium, 2 light, with exactly 2 gold, both with x > 1400.
  - Has an `Exit`.
  - Exports as in the Global Constraints.
  - The pool contains AgriShip and heavy_freighter.
  - `GameState.has_level_scene(2)` is true.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Build the scene.** Compute the space transforms with a throwaway script, then paste them into the .tscn. Update the GDD.
- [ ] **Step 4: Run** t.sh. Expected: ALL TESTS PASSED.
  - Run Level02 headless for 900 frames. Expected: no errors.
  - Take a windowed screenshot. Expected: petals visible around the island; spaces don't overlap each other or the island.
- [ ] **Step 5: Commit** `feat: Level 2 Blossom Lot`. Then the user playtests on desktop.
