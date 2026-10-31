# Parkin' Space – Weeks 1–2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Godot 4.7 project where Level 1 (Starter Lot) is fully playable offline on an Android phone: Title → Mode Select → Level Select (locks) → Level 1 → Result, with saved progress.

**Architecture:** Pure rule logic (parking, dents, pay, stars, save/unlock) lives in small `RefCounted` classes and the `GameState` autoload so it can be unit-tested headless. Scenes (`Ship`, `ParkingSpace`, `Level`, UI screens) are thin wrappers that call those rules. Ships are `RigidBody2D` with gravity off, driven by Input Map actions that on-screen `TouchScreenButton`s press.

**Tech Stack:** Godot 4.7 standard (GDScript), 2D physics, Compatibility renderer, Git. Tests: a tiny in-repo runner scene (no addons).

**Spec:** `docs/GDD.md` (moves to `parkin-space/docs/GDD.md` in Task 1). Lab handout: `ITSD 85 Lab Mobile Game with Level Progression and Offline Online Multiplayer.pdf`.

**Out of scope for this plan (later plans):** Levels 2–5, tip tiers, retrieval, radiation, gravity well, orphans, special requests, online mode, Main Menu/Settings/Credits, pause menu, sound, Android back gesture, final art.

## Global Constraints

- Project folder: `d:\SpecialTopics\lab5\parkin-space\` (Git repo root = Godot project root).
- Godot 4.7 standard (not .NET). Renderer: Compatibility (`gl_compatibility`) for desktop and mobile.
- Viewport 1280 × 720, stretch mode `canvas_items`, aspect `expand`, handheld orientation landscape, Emulate Touch From Mouse on.
- GDScript only, typed (`var x: int`, `-> void`), tabs for indentation, Godot 4 APIs only.
- Folder layout per lab Phase 2: `autoload/`, `scenes/ui/`, `scenes/levels/`, `scenes/actors/`, `scripts/`, `assets/art|audio|fonts/`, `docs/`, plus `resources/ships/` and `tests/`.
- Save file: `user://save.cfg`. `GameState.TOTAL_LEVELS = 5`. Level scenes: `res://scenes/levels/Level%02d.tscn`.
- Ship nose points local −Y (up). Forward = `-global_transform.y`.
- Ship classes: `LIGHT = 0, MEDIUM = 1, HEAVY = 2`. A ship fits a space if `ship_class <= space_class`.
- Starting tuning values (change only by playtest): see Task 3 table. Safe impact speed 120 px/s. Parked = all hull sample points inside space, speed < 10 px/s, spin < 0.2 rad/s, held 1.0 s.
- Level 1: goal "Park 4 ships before the shift ends", shift 180 s, base pay 100, park fee 20, customers light/medium/light/medium, silver target 150, gold target 170.
- Commit after every task. Every commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `$GODOT` = path to the Godot 4.7 console executable (e.g. `C:/Godot/Godot_v4.7-stable_win64_console.exe`). Test command (from `d:/SpecialTopics/lab5`):
  `"$GODOT" --headless --path parkin-space --import && "$GODOT" --headless --path parkin-space res://tests/TestRunner.tscn`
  Pass = last line `ALL TESTS PASSED`, exit code 0.

## Review Focus

1. **Corrupt or missing save file** → game starts with Level 1 unlocked, no crash. (Test in Task 2.)
2. **Replaying a cleared level with fewer stars** → best stars and unlocks never go down. (Test in Task 2.)
3. **Ship coasting through a space, or stopped half-in** → must not count as parked; leaving the space resets the 1-second hold. (Tests in Task 3.)
4. **Second ship settling in an occupied space, or a ship in a space too small** → not credited. (Test in Task 3.)
5. **Shift ends on the same frame the last ship parks, or pay hits zero after winning** → exactly one outcome, never changes afterward. (Test in Task 4.)

---

### Task 1: Project scaffold, Git and test runner

**Files:**
- Create: `parkin-space/project.godot`, `parkin-space/.gitignore`, `parkin-space/icon.svg` (copy Godot default or any 128 px SVG)
- Create: `parkin-space/tests/TestRunner.tscn`, `parkin-space/tests/run_tests.gd`, `parkin-space/tests/test_case.gd`, `parkin-space/tests/test_sanity.gd`
- Move: `d:/SpecialTopics/lab5/docs/` → `parkin-space/docs/`
- Create empty folders (with `.gitkeep`): `autoload/ scenes/ui/ scenes/levels/ scenes/actors/ scripts/core/ scripts/actors/ scripts/ui/ resources/ships/ assets/art/ assets/audio/ assets/fonts/`

**Interfaces:**
- Produces: `TestCase` base class (`tests/test_case.gd`, `class_name TestCase extends RefCounted`) with `var tree: SceneTree`, `func assert_eq(actual, expected, msg := "") -> void`, `func assert_true(cond: bool, msg := "") -> void`, `func assert_false(cond: bool, msg := "") -> void`, `var failures: Array[String]`. Every test file is `tests/test_*.gd`, `extends TestCase`, with methods named `test_*` (may `await`).

- [ ] **Step 1: Write `project.godot`** with `config/name="Parkin' Space"`, `config/features=PackedStringArray("4.7")`, `run/main_scene` left empty for now, and the Global Constraints display/render/input settings:
  - `[display]` `window/size/viewport_width=1280`, `window/size/viewport_height=720`, `window/stretch/mode="canvas_items"`, `window/stretch/aspect="expand"`, `window/handheld/orientation=0` (landscape)
  - `[input_devices]` `pointing/emulate_touch_from_mouse=true`
  - `[rendering]` `renderer/rendering_method="gl_compatibility"`, `renderer/rendering_method.mobile="gl_compatibility"`
  - `[input]` actions with keyboard keys for desktop testing: `thrust_forward` (W), `thrust_back` (S), `strafe_left` (A), `strafe_right` (D), `rotate_left` (Q), `rotate_right` (E).
  (Alternative: create the project in the editor with these settings; result must match.)

- [ ] **Step 2: Write `.gitignore`**: `.godot/`, `/android/`, `*.apk`, `*.aab`, `*.ipa`, `export/`, `*.keystore`, `*.jks`.

- [ ] **Step 3: Write the runner.** `TestRunner.tscn` = one `Node` with `run_tests.gd`:

```gdscript
extends Node

func _ready() -> void:
	await get_tree().process_frame  # let autoloads finish _ready
	var total := 0
	var failed := 0
	for file in DirAccess.get_files_at("res://tests/"):
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load("res://tests/" + file)
		for m in script.get_script_method_list():
			if not String(m.name).begins_with("test_"):
				continue
			var t: TestCase = script.new()
			t.tree = get_tree()
			await t.call(m.name)
			total += 1
			if t.failures.is_empty():
				print("  ok   %s.%s" % [file, m.name])
			else:
				failed += 1
				print("  FAIL %s.%s: %s" % [file, m.name, "; ".join(t.failures)])
	print("%d tests, %d failed" % [total, failed])
	print("ALL TESTS PASSED" if failed == 0 else "TESTS FAILED")
	get_tree().quit(0 if failed == 0 else 1)
```

- [ ] **Step 4: Write `test_case.gd`** (assert helpers append a message to `failures` instead of stopping) and `test_sanity.gd` with `test_math_works`: `assert_eq(1 + 1, 2)`.

- [ ] **Step 5: Run tests.** Run the Global Constraints test command. Expected: `ok   test_sanity.gd.test_math_works`, `ALL TESTS PASSED`.

- [ ] **Step 6: Init Git and commit.**

```bash
cd d:/SpecialTopics/lab5/parkin-space
git init -b main
git add .
git commit -m "chore: scaffold Parkin' Space project and test runner"
```

---

### Task 2: GameState autoload (progress, save, unlock)

**Files:**
- Create: `autoload/GameState.gd`; register in `project.godot` `[autoload]` as `GameState="*res://autoload/GameState.gd"`
- Test: `tests/test_game_state.gd`

**Interfaces:**
- Produces (`GameState`, extends Node): `const TOTAL_LEVELS := 5`; `var save_path: String = "user://save.cfg"`; `var unlocked_level: int = 1`; `var best_stars: Dictionary = {}`; `var current_level: int = 1`; `var mode: String = "offline"`; `var last_result: Dictionary = {}`; `var sound_on: bool = true`; `func is_unlocked(level: int) -> bool`; `func complete_level(level: int, stars: int) -> void`; `func save_progress() -> void`; `func load_progress() -> void`; `func reset_progress() -> void`; `func level_scene_path(level: int) -> String`; `func has_level_scene(level: int) -> bool`.

- [ ] **Step 1: Write failing tests.** Each test creates its own instance: `var gs = load("res://autoload/GameState.gd").new()`, sets `gs.save_path = "user://test_save.cfg"`, deletes that file first, and calls `gs.free()` at the end.
  - `test_fresh_start_only_level_1_unlocked`: `load_progress()` with no file → `is_unlocked(1)` true, `is_unlocked(2)` false.
  - `test_clearing_level_unlocks_next_and_persists`: `complete_level(1, 2)`; new instance with same path, `load_progress()` → `unlocked_level == 2`, `best_stars[1] == 2`.
  - `test_replay_never_lowers_stars_or_unlocks`: `complete_level(1, 3)`, `complete_level(2, 1)`, then `complete_level(1, 1)` → `best_stars[1] == 3`, `unlocked_level == 3`.
  - `test_last_level_does_not_unlock_beyond_total`: set `unlocked_level = 5`, `complete_level(5, 1)` → `unlocked_level == 5`.
  - `test_corrupt_save_falls_back_to_defaults`: write the text `"not a config {{{"` to the save path with `FileAccess`, `load_progress()` → `unlocked_level == 1`, `best_stars.is_empty()`.
  - `test_sound_setting_persists`: `sound_on = false`, `save_progress()`, reload → `sound_on == false`.
  - `test_level_scene_path_format`: `level_scene_path(3) == "res://scenes/levels/Level03.tscn"`.

- [ ] **Step 2: Run tests.** Expected: FAIL (script missing).

- [ ] **Step 3: Implement `GameState.gd`.** Follow the lab handout's Step 3.2 code, plus: `save_path` var instead of const; save/load `sound_on` under section `"settings"`; `unlocked_level` only ever increases (`max`); clamp loaded `unlocked_level` to `1..TOTAL_LEVELS`; if `cfg.load()` fails or a loaded value has the wrong type, keep defaults; `has_level_scene` = `ResourceLoader.exists(level_scene_path(level))`.

- [ ] **Step 4: Run tests.** Expected: all `test_game_state` tests ok, `ALL TESTS PASSED`.

- [ ] **Step 5: Commit** `feat: add GameState with saved level progress`.

---

### Task 3: Ship specs and parking rules

**Files:**
- Create: `scripts/core/ShipSpec.gd`, `scripts/core/ParkingRules.gd`, `scripts/core/ParkTracker.gd`
- Create: `resources/ships/light_scout.tres`, `resources/ships/medium_shuttle.tres`, `resources/ships/heavy_freighter.tres`
- Test: `tests/test_parking_rules.gd`

**Interfaces:**
- Produces:
  - `class_name ShipSpec extends Resource`: `enum ShipClass { LIGHT, MEDIUM, HEAVY }`; `@export var ship_class: ShipClass`; `@export var display_name: String`; `@export var mass: float`; `@export var thrust: float`; `@export var strafe_thrust: float`; `@export var torque: float`; `@export var hull_size: Vector2`; `@export var texture: Texture2D` (null = placeholder drawing).
  - `class_name ParkingRules extends RefCounted` (all static): `const MAX_PARK_SPEED := 10.0`; `const MAX_PARK_SPIN := 0.2`; `const HOLD_SECONDS := 1.0`; `const SPACE_SIZES := {0: Vector2(64, 96), 1: Vector2(88, 132), 2: Vector2(124, 196)}`; `static func fits_class(ship_class: int, space_class: int) -> bool`; `static func points_inside(points: PackedVector2Array, space_xform: Transform2D, space_size: Vector2) -> bool` (space rect centred on its origin; transform each global point by `space_xform.affine_inverse()` and test `Rect2(-space_size / 2, space_size).has_point`); `static func is_settled(linear_speed: float, angular_speed: float) -> bool` (uses `abs(angular_speed)`); `static func can_credit(ship_class: int, space_class: int, occupied: bool, points_ok: bool, settled: bool) -> bool`.
  - `class_name ParkTracker extends RefCounted`: `func update(delta: float, ok: bool) -> bool` — accumulates time while `ok`, resets to 0 when not `ok`, returns `true` exactly once when held ≥ `HOLD_SECONDS`.

Ship spec values (starting tuning):

| File | class | display_name | mass | thrust | strafe_thrust | torque | hull_size |
|---|---|---|---|---|---|---|---|
| light_scout.tres | LIGHT | Scout Pod | 1.0 | 260 | 180 | 900 | (40, 64) |
| medium_shuttle.tres | MEDIUM | Shuttle | 2.5 | 550 | 380 | 3200 | (60, 100) |
| heavy_freighter.tres | HEAVY | Freighter | 6.0 | 1000 | 650 | 12000 | (90, 160) |

- [ ] **Step 1: Write failing tests.**
  - `test_fits_own_class_or_larger`: `fits_class(0,0)`, `fits_class(0,2)`, `fits_class(1,2)` true; `fits_class(2,1)`, `fits_class(1,0)` false.
  - `test_points_inside_rotated_space`: space at `Transform2D(PI/4, Vector2(500, 300))`, size `(88, 132)`; points `[Vector2(500,300), Vector2(500,300) + Vector2(0,-50).rotated(PI/4)]` → true; adding `Vector2(500,300) + Vector2(0,-80).rotated(PI/4)` → false.
  - `test_half_in_is_not_inside`: unrotated space at origin size `(64, 96)`, points `[Vector2(0,0), Vector2(0,60)]` → false.
  - `test_settled_thresholds`: `is_settled(9.9, 0.19)` true; `is_settled(10.1, 0)` false; `is_settled(0, -0.3)` false.
  - `test_occupied_or_too_small_never_credits`: `can_credit(0, 1, true, true, true)` false; `can_credit(2, 1, false, true, true)` false; `can_credit(1, 1, false, true, true)` true.
  - `test_tracker_needs_full_hold`: `update(0.5, true)` false, `update(0.6, true)` true, `update(0.5, true)` false (fires once).
  - `test_tracker_resets_when_leaving`: `update(0.9, true)`, `update(0.016, false)`, `update(0.5, true)` → all false.
  - `test_spec_resources_load`: each `.tres` loads as `ShipSpec` with the table's `ship_class` and `hull_size`.

- [ ] **Step 2: Run tests.** Expected: FAIL.

- [ ] **Step 3: Implement** the three scripts and three `.tres` files per the interfaces and table.

- [ ] **Step 4: Run tests.** Expected: `ALL TESTS PASSED`.

- [ ] **Step 5: Commit** `feat: add ship specs and parking rules`.

---

### Task 4: Shift ledger (pay, dents, fees, outcome, stars)

**Files:**
- Create: `scripts/core/ShiftLedger.gd`
- Test: `tests/test_shift_ledger.gd`

**Interfaces:**
- Produces `class_name ShiftLedger extends RefCounted`:
  - `enum Outcome { PLAYING, WON, FIRED, TIMEOUT }`; `const SAFE_IMPACT_SPEED := 120.0`; `const PARK_FEE := 20`
  - `func _init(base_pay: int, customers: int, shift_seconds: float)`
  - `var pay: int`, `var earned: int`, `var served: int`, `var customers: int`, `var time_left: float`, `var outcome: Outcome`
  - `func add_dent(cost: int) -> void` (pay floors at 0; pay 0 → FIRED)
  - `func serve_customer(fee: int = PARK_FEE) -> void` (`served += 1`, `earned += fee`; all served → WON)
  - `func tick(delta: float) -> void` (`time_left` floors at 0; reaching 0 → TIMEOUT)
  - `func earnings() -> int` (= `pay + earned`)
  - `static func dent_cost(impact_speed: float) -> int` (0 if `<= SAFE_IMPACT_SPEED`, else `5 + int((impact_speed - SAFE_IMPACT_SPEED) * 0.25)`)
  - `static func stars_for(earnings: int, silver: int, gold: int, won: bool) -> int` (0 if not won; 3 if `>= gold`; 2 if `>= silver`; else 1)
  - All mutators do nothing once `outcome != PLAYING`.

- [ ] **Step 1: Write failing tests.**
  - `test_dent_cost_curve`: `dent_cost(120) == 0`, `dent_cost(121) == 5`, `dent_cost(200) == 25`.
  - `test_serving_all_customers_wins`: `ShiftLedger.new(100, 2, 180)`; `serve_customer()` twice → `outcome == WON`, `earnings() == 140`.
  - `test_pay_zero_fires`: `new(100, 4, 180)`, `add_dent(60)`, `add_dent(60)` → `pay == 0`, `outcome == FIRED`.
  - `test_timeout`: `new(100, 4, 1.0)`, `tick(0.6)`, `tick(0.6)` → `time_left == 0.0`, `outcome == TIMEOUT`.
  - `test_outcome_is_final`: win with `new(100, 1, 1.0)` + `serve_customer()`, then `tick(5)` and `add_dent(500)` → still `WON`, `pay == 100`.
  - `test_stars`: `stars_for(180, 150, 170, true) == 3`, `stars_for(160, 150, 170, true) == 2`, `stars_for(120, 150, 170, true) == 1`, `stars_for(180, 150, 170, false) == 0`.

- [ ] **Step 2: Run tests.** Expected: FAIL.

- [ ] **Step 3: Implement `ShiftLedger.gd`** per the interface.

- [ ] **Step 4: Run tests.** Expected: `ALL TESTS PASSED`.

- [ ] **Step 5: Commit** `feat: add shift ledger for pay, dents and stars`.

---

### Task 5: Ship scene (physics, controls, dents, selection)

**Files:**
- Create: `scenes/actors/Ship.tscn`, `scripts/actors/Ship.gd`
- Test: `tests/test_ship.gd`

**Interfaces:**
- Consumes: `ShipSpec`, `ShiftLedger.dent_cost`.
- Produces `class_name Ship extends RigidBody2D`:
  - `@export var spec: ShipSpec`
  - `signal dented(ship: Ship, cost: int)`, `signal selected(ship: Ship)`
  - `var is_driven: bool = false`, `var is_parked: bool = false`
  - `func set_driven(on: bool) -> void` (also makes `$DriveCamera` current when on)
  - `func set_parked() -> void` (`is_parked = true`, `is_driven = false`, `freeze = true`, dims the sprite)
  - `func hull_points() -> PackedVector2Array` (4 hull corners + centre, in global coordinates, from `spec.hull_size`)
  - Scene tree: `Ship (RigidBody2D)` → `Sprite2D`, `CollisionShape2D` (RectangleShape2D), `DriveCamera (Camera2D, ignore_rotation = false)`

- [ ] **Step 1: Write failing tests** (instantiate `Ship.tscn`, set `spec`, add to `tree.root`, `await tree.physics_frame` as needed, `queue_free` at end; always `Input.action_release` everything after).
  - `test_applies_spec`: with `medium_shuttle.tres` → `mass == 2.5`, `gravity_scale == 0.0`, collision rect size `== Vector2(60, 100)`.
  - `test_forward_thrust_moves_nose_direction`: light ship at rotation 0, `set_driven(true)`, `Input.action_press("thrust_forward")`, wait 20 physics frames → `linear_velocity.y < -10` and `abs(linear_velocity.x) < 1`.
  - `test_ignores_input_when_not_driven`: same as above without `set_driven` → `linear_velocity.length() < 0.01`.
  - `test_rotate_right_spins_clockwise`: driven, `rotate_right` 20 frames → `angular_velocity > 0`.
  - `test_hull_points_follow_rotation`: light ship at `Vector2(100,100)`, `rotation = PI/2` → `hull_points()` has 5 points; the point for local `(-20,-32)` is ≈ `Vector2(132, 80)` (tolerance 0.5).
  - `test_hard_impact_emits_dent`: light ship moving `Vector2(0, -300)` toward a `StaticBody2D` wall 60 px above it; collect `dented` → exactly one emission with cost `== ShiftLedger.dent_cost(300)` ± 5 (cost uses speed from the frame *before* contact).
  - `test_soft_bump_no_dent`: same at `Vector2(0, -80)` → no emission.

- [ ] **Step 2: Run tests.** Expected: FAIL.

- [ ] **Step 3: Implement `Ship.gd` and `Ship.tscn`.**
  - `_ready`: copy `spec.mass`; `gravity_scale = 0`; `linear_damp = 0.3`; `angular_damp = 2.0`; `contact_monitor = true`; `max_contacts_reported = 4`; `input_pickable = true`; make the collision shape unique and size it to `hull_size`; use `spec.texture` scaled to `hull_size`, or if null draw a placeholder in `_draw` (hull rectangle in a class colour — light cyan, medium yellow, heavy orange — plus a white nose triangle at −Y).
  - `_physics_process`: store `_prev_velocity = linear_velocity` at the end of each frame. When driven: forward/back = `Input.get_axis("thrust_back", "thrust_forward")` along `-global_transform.y` × `spec.thrust`; strafe = `Input.get_axis("strafe_left", "strafe_right")` along `global_transform.x` × `spec.strafe_thrust`; `apply_torque(Input.get_axis("rotate_left", "rotate_right") * spec.torque)`.
  - `body_entered(other)`: impact speed = `(_prev_velocity - other_velocity).length()` (`other_velocity` = the other body's `linear_velocity` if it is a `RigidBody2D`, else zero); emit `dented` if `dent_cost > 0`. Ignore impacts while `is_parked`.
  - `_input_event`: a screen-touch or left-click press emits `selected`.

- [ ] **Step 4: Run tests.** Expected: `ALL TESTS PASSED`.

- [ ] **Step 5: Commit** `feat: add physics-driven ship scene`.

---

### Task 6: Parking space scene

**Files:**
- Create: `scenes/actors/ParkingSpace.tscn`, `scripts/actors/ParkingSpace.gd`
- Test: `tests/test_parking_space.gd`

**Interfaces:**
- Consumes: `ParkingRules`, `Ship.hull_points()`, `Ship.spec.ship_class`.
- Produces `class_name ParkingSpace extends Node2D`: `@export var space_class: ShipSpec.ShipClass = ShipSpec.ShipClass.MEDIUM`; `@export var label: String` (e.g. "A1"); `var occupant: Ship = null`; `func size() -> Vector2` (from `ParkingRules.SPACE_SIZES`); `func check(ship: Ship) -> bool` (= `ParkingRules.can_credit(...)` using this space's global transform, `occupant != null`, `ship.hull_points()`, the ship's speeds); `func claim(ship: Ship) -> void` (sets `occupant`, stops pulsing, turns outline solid white).

- [ ] **Step 1: Write failing tests** (spaces and ships added to `tree.root`; ships frozen in place for exact positions).
  - `test_centered_still_ship_passes`: medium space at `(300,300)`, medium ship at `(300,300)`, velocity zero → `check(ship)` true.
  - `test_light_ship_in_heavy_space_passes`: heavy space, light ship centred → true.
  - `test_heavy_ship_in_light_space_fails`: light space, heavy ship centred → false.
  - `test_claimed_space_rejects_second_ship`: `claim(ship_a)`, then `check(ship_b)` → false.
  - `test_moving_ship_fails`: ship centred with `linear_velocity = Vector2(30, 0)` (not frozen; check same frame) → false.

- [ ] **Step 2: Run tests.** Expected: FAIL.

- [ ] **Step 3: Implement.** `_draw` draws the rectangle outline (3 px) in green and the class letter `L`/`M`/`H` plus `label` in the centre; `_process` pulses the outline's alpha between 0.4 and 1.0 (about 1 Hz) until claimed, then calls `queue_redraw()`.

- [ ] **Step 4: Run tests.** Expected: `ALL TESTS PASSED`.

- [ ] **Step 5: Commit** `feat: add parking space scene`.

---

### Task 7: Level controller, HUD, controls and Level 1

**Files:**
- Create: `scripts/Level.gd`, `scenes/ui/HUD.tscn`, `scripts/ui/HUD.gd`, `scenes/ui/ShipControls.tscn`, `scripts/ui/ShipControls.gd`, `scenes/levels/Level01.tscn`
- Test: `tests/test_level.gd`

**Interfaces:**
- Consumes: `Ship`, `ParkingSpace`, `ParkTracker`, `ShiftLedger`, `GameState`.
- Produces:
  - `class_name Level extends Node2D`: `@export var level_number: int`, `@export var goal_text: String`, `@export var customer_queue: Array[ShipSpec]`, `@export var shift_seconds: float`, `@export var base_pay: int`, `@export var silver_target: int`, `@export var gold_target: int`, `@export var arrival_interval: float = 8.0`; `var ledger: ShiftLedger`; `var driven_ship: Ship`; `func spawn_next_customer() -> Ship`; `func select_ship(ship: Ship) -> void`; `func release_ship() -> void`; `func end_level() -> void`. Required child nodes: `Spaces` (ParkingSpace children), `Ships` (Node2D), `Entrance` (Marker2D; spawned ships face its rotation), `LotCamera` (Camera2D showing the whole lot), `HUD`, `Controls`.
  - `HUD.gd`: `func set_goal(text: String) -> void`, `func set_time(seconds: float) -> void` (shows `m:ss`), `func set_pay(pay: int, earned: int) -> void`, `func set_customers(served: int, total: int) -> void`, `func show_hint(text: String, seconds: float) -> void`.
  - `ShipControls.gd`: `signal done_pressed`; `func set_driving(on: bool) -> void` (button panel visible only while driving).
  - `GameState.last_result` shape: `{"won": bool, "stars": int, "level": int, "earnings": int, "served": int, "customers": int, "reason": String}` with `reason` one of `"won"`, `"fired"`, `"timeout"`.

- [ ] **Step 1: Write failing tests** (instantiate `Level01.tscn` under `tree.root`, `await tree.process_frame`, free at end; call `GameState.reset_progress()` first and restore after).
  - `test_level01_exports`: `level_number == 1`, `goal_text == "Park 4 ships before the shift ends"`, `customer_queue.size() == 4` with classes `[LIGHT, MEDIUM, LIGHT, MEDIUM]`, `shift_seconds == 180`, `base_pay == 100`, `silver_target == 150`, `gold_target == 170`.
  - `test_first_customer_spawns_at_start`: one `Ship` under `Ships` positioned at `Entrance`.
  - `test_select_and_release`: `select_ship(ship)` → `ship.is_driven`, `driven_ship == ship`; `release_ship()` → `not ship.is_driven`, `driven_ship == null`.
  - `test_parking_all_customers_wins_and_unlocks` (logic path, no physics): for 4 customers, spawn, `set_parked()` and call the level's park handler `_on_ship_parked(ship, space)` with distinct spaces → `ledger.outcome == WON`, `GameState.last_result.won == true`, `GameState.is_unlocked(2)`.
  - `test_firing_records_loss_without_unlock`: `_on_ship_dented(ship, 100)` → `last_result.reason == "fired"`, `last_result.stars == 0`, `not GameState.is_unlocked(2)`.
  - (Make the scene change to `Result.tscn` skippable in tests: `Level` has `var change_scene_on_end := true`; tests set it false.)

- [ ] **Step 2: Run tests.** Expected: FAIL.

- [ ] **Step 3: Build `ShipControls.tscn`.** A `CanvasLayer` with `TouchScreenButton`s, each ≥ 120 × 120 px with a `GradientTexture2D` placeholder and a `Label` glyph: left cluster ▲ `thrust_forward`, ▼ `thrust_back`, ◀ `strafe_left`, ▶ `strafe_right`; right cluster ⟲ `rotate_left`, ⟳ `rotate_right`; plus a **Done** button (emits `done_pressed`). Keep 40 px from screen edges. Use the `action` property so presses feed the Input Map (multi-touch works).

- [ ] **Step 4: Build `HUD.tscn`.** `CanvasLayer` with labels for goal (top centre), time (top right), pay and earned (top left), customers served (below pay), and a hint label (centre bottom, auto-hides). Font size ≥ 28.

- [ ] **Step 5: Implement `Level.gd`.**
  - `_ready`: create `ledger = ShiftLedger.new(base_pay, customer_queue.size(), shift_seconds)`; fill HUD; `LotCamera.make_current()`; spawn the first customer; show hint "Tap a ship to drive it" for 4 s.
  - Spawning: every `arrival_interval` seconds (and when the entrance is clear — no ship within 120 px of `Entrance`), instance `Ship.tscn` with the next spec at `Entrance`; connect `dented` and `selected`.
  - `select_ship`: ignore parked ships; release the current ship first; `set_driven(true)`; `Controls.set_driving(true)`; show hint "Stop inside a green space" for 3 s the first time.
  - `release_ship` / `done_pressed`: `set_driven(false)`; `LotCamera.make_current()`; `Controls.set_driving(false)`.
  - `_physics_process`: `ledger.tick(delta)`; for every unparked ship, `ok` = any `space.check(ship)`; keep one `ParkTracker` per ship; when it returns true call `_on_ship_parked(ship, space)`.
  - `_on_ship_parked`: `space.claim(ship)`; `ship.set_parked()`; release if driven; `ledger.serve_customer()`.
  - `_on_ship_dented`: `ledger.add_dent(cost)`; show the cost floating briefly via `show_hint("-%d dent!" % cost, 1.0)`.
  - After any ledger change or tick: update HUD; if `ledger.outcome != PLAYING` call `end_level()` once.
  - `end_level`: stars = `ShiftLedger.stars_for(...)`; if won `GameState.complete_level(level_number, stars)`; write `GameState.last_result`; if `change_scene_on_end` change to `res://scenes/ui/Result.tscn`.

- [ ] **Step 6: Build `Level01.tscn`** (root `Node2D` with `Level.gd`, exports per test). Lot roughly 2400 × 1400 px enclosed by `StaticBody2D` walls; `Entrance` at the left edge facing right; `LotCamera` zoomed to show the whole lot. Spaces (6 total, so there is a choice): lane A **perpendicular** — 2 MEDIUM spaces; lane B **parallel** (spaces rotated 90°) — 2 LIGHT spaces; lane C **diagonal** (spaces rotated 45°) — 2 MEDIUM spaces. A grey `Polygon2D` floor with lane markings is enough.

- [ ] **Step 7: Run tests.** Expected: `ALL TESTS PASSED`.

- [ ] **Step 8: Play it on the desktop.** Set `run/main_scene` temporarily to `Level01.tscn`, run, and check: tapping a ship switches to the rotating driving camera; W/A/S/D/Q/E and the on-screen buttons both work; a hard wall hit shows a dent and lowers pay; stopping inside a space for 1 s claims it; parking all 4 ends the level. Tune Task 3's ship numbers if a ship feels wrong, and record changes in the commit message.

- [ ] **Step 9: Commit** `feat: add level controller, HUD, controls and Level 1`.

---

### Task 8: Screen flow (Title, Mode Select, Level Select, Result)

**Files:**
- Create: `scenes/ui/Title.tscn` + `scripts/ui/Title.gd`, `scenes/ui/ModeSelect.tscn` + `scripts/ui/ModeSelect.gd`, `scenes/ui/LevelSelect.tscn` + `scripts/ui/LevelSelect.gd`, `scenes/ui/Result.tscn` + `scripts/ui/Result.gd`
- Modify: `project.godot` (`run/main_scene="res://scenes/ui/Title.tscn"`)
- Test: `tests/test_ui_flow.gd`

**Interfaces:**
- Consumes: `GameState` (all of Task 2), `GameState.last_result` (Task 7 shape).
- Produces: `LevelSelect.gd` `func build() -> void` (fills `$Grid`, called from `_ready`); `Result.gd` `func show_result(result: Dictionary) -> void`, nodes `$Title` (Label), `$Stars` (Label), `$Earnings` (Label), `$Retry`, `$Next`, `$Menu` (Buttons).

- [ ] **Step 1: Write failing tests** (instantiate scenes under `tree.root`; reset and restore `GameState` progress).
  - `test_level_select_locks`: with `unlocked_level = 2` → `Grid` has 5 buttons; button 1 enabled, button 2 disabled (Level02 scene doesn't exist yet, text contains "Coming soon"), buttons 3–5 disabled with text containing "LOCKED".
  - `test_result_win`: `show_result({"won": true, "stars": 2, "level": 1, "earnings": 160, "served": 4, "customers": 4, "reason": "won"})` → `$Title.text == "Shift complete!"`, `$Stars.text == "★★☆"`, `$Earnings.text` contains `"160"`, `$Next.disabled == true` (Level02 missing).
  - `test_result_fired`: reason `"fired"` → `$Title.text == "You're fired!"`, `$Next.disabled`.
  - `test_result_timeout`: reason `"timeout"` → `$Title.text == "Shift over – customers still waiting"`.

- [ ] **Step 2: Run tests.** Expected: FAIL.

- [ ] **Step 3: Implement the screens.** All are `Control` roots, large buttons (≥ 120 px tall), font ≥ 28.
  - **Title:** game name, motto "Anything that flies, I can.", "Tap to start" → ModeSelect.
  - **ModeSelect:** **Play Offline** (`GameState.mode = "offline"` → LevelSelect); **Play Online** disabled with caption "Online – coming soon"; **Back** → Title.
  - **LevelSelect:** the lab's Step 3.4 code, 3-column grid, buttons 180 × 180, "Level n\nStars: s/3"; unlocked but `not has_level_scene(n)` → disabled "Level n\nComing soon"; locked → disabled "Level n\nLOCKED"; **Back** → ModeSelect.
  - **Result:** `_ready` calls `show_result(GameState.last_result)`. Retry reloads `level_scene_path(level)`; Next goes to level + 1 (disabled if lost, last level, or scene missing); Menu → LevelSelect.

- [ ] **Step 4: Run tests.** Expected: `ALL TESTS PASSED`.

- [ ] **Step 5: Desktop flow check.** Run the project (F5 / `"$GODOT" --path parkin-space`): Title → Mode Select → Level Select (Level 1 open, others locked) → play and win Level 1 → Result shows stars → Menu → Level 2 now shows "Coming soon" instead of "LOCKED". Close and reopen: Level 1 stars are still shown.

- [ ] **Step 6: Commit** `feat: add title, mode select, level select and result screens`.

---

### Task 9: Android build and phone test (Week 2 checkpoint)

**Files:**
- Create: `export_presets.cfg` (via the editor)
- Create: `parkin-space/README.md` (lab headings; fill "How to build" now, others as stubs)

**Interfaces:**
- Consumes: the full game from Tasks 1–8.

- [ ] **Step 1: Install build tools** (one time): Godot export templates for 4.7 (Editor → Manage Export Templates → Download and Install); OpenJDK 17 (adoptium.net); Android SDK command-line tools per Godot's "Exporting for Android" page. Set Editor Settings → Export → Android → Java SDK Path and Android SDK Path.

- [ ] **Step 2: Create the Android preset**: Project → Export → Add → Android. Unique Name `com.itsd85.ecampomanes.parkinspace`; Name `Parkin' Space`; Screen orientation Landscape; Permissions **Internet** and **Access Network State** ticked (needed in Week 4). Export debug APK to `export/parkin-space.apk` (git-ignored).

- [ ] **Step 3: Install on the phone** (copy the APK and allow "Install unknown apps", or USB debugging + Godot's one-click deploy).

- [ ] **Step 4: Phone checklist** — every item must pass:
  - App opens on Title in landscape; nothing cut off by the notch or screen edges.
  - All text readable; buttons easy to hit with thumbs; two buttons can be held at once (thrust + rotate).
  - Level 1 can be won; a dent visibly lowers pay; deliberately ramming walls gets you fired.
  - Clear Level 1, force-close the app, reopen → Level 1 stars are kept (R5).
  - Airplane mode on → everything above still works (R6).
  - **Is it fun?** Note anything that feels bad (camera rotation, ship handling, button placement) in `docs/playtest/week2-notes.md` for the next plan.

- [ ] **Step 5: Write `README.md`** with the lab's headings; fill **How to build** (Godot 4.7, export steps above); leave the others as one-line stubs.

- [ ] **Step 6: Commit** `chore: add Android export preset, README and week 2 phone notes`.
