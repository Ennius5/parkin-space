# Level 3 – Wreckage Lot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Level 3: Level 1's lot expanded to 9 spaces, with fixed wrecks, drifting asteroids, and radiation zones that dent ships every 2 s.

**Architecture:**
- **Node types:** three new ones, `Wreck` (StaticBody2D), `Asteroid` (RigidBody2D) and `RadiationZone` (Node2D). Each wreck and asteroid traces its collision polygon from its sprite with a shared `SpriteOutline` helper.
- **Level.gd:** reads optional `Asteroids` and `Radiation` child nodes. It counts asteroids in the arrival-bay check and runs a per-ship radiation timer that charges dents through the existing `_on_ship_dented` path.
- **Scene:** `Level03.tscn` is a copy of Level 1's scene with the new nodes added.

**Tech Stack:** Godot 4.7.2, typed GDScript, the project's own test runner (`tests/TestRunner.tscn`, `TestCase` base class).

**Spec:** `docs/superpowers/specs/2026-11-02-level3-wreckage-lot-design.md`

## Global Constraints

- Levels 1 and 2 play exactly as before. Every new Level.gd behaviour must be a no-op when the `Asteroids` / `Radiation` nodes are absent.
- Radiation: a **₵5 dent every 2 s** of continuous exposure. The first dent comes at 2 s, and leaving resets the timer. Each dent goes through `_on_ship_dented(ship, 5)`, so it costs pay, counts on the customer and shows "-₵5 dent!".
- Radiation hint, exact copy: `"Radiation! It dents ships inside"`, once per shift, at the first radiation dent.
- Level 3 settings: level_number 3, goal `"Serve 7 customers"`, random_customers 7, shift 180, base pay 100, silver 260, gold 300, arrival interval 10, use_tiers true, retrieval_count 2, pool = all 10 ships in `resources/ships/`.
- Spaces: A1/A2 medium, B1/B2 light, C1/C2 medium **gold**, D1/D2 heavy, E1 medium. That's 2 light, 5 medium and 2 heavy.
- Asteroid mass 1.75 (between light 1.0 and medium 2.5). Wrecks never move.
- Art: Kenney *Space Shooter Redux* (CC0). Only the used sprites go into `assets/art/kenney/`, and `docs/CREDITS.md` lists the pack, Kenney (kenney.nl) and CC0.
- Never commit keystores, passwords or `export/`. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Test command (whole suite):** `bash .superpowers/sdd/2026-11-01-ship-art-pipeline/t.sh`. Pass = last line `ALL TESTS PASSED`. The full log is in `.superpowers/sdd/2026-11-01-ship-art-pipeline/last_test.log`.

## Review Focus

1. **Asteroid drifting into the arrival bay before a spawn.** The next customer waits; it must never spawn overlapping a rock. Covered by a test in Task 3.
2. **Ship sitting in radiation across a frame where it leaves and re-enters.** The timer resets, so there's no dent until another full 2 s. Covered by a test in Task 4.
3. **Ship despawning (returned at the exit) while it has radiation time.** No error, and no stale dictionary entry is charged. Covered by a test in Task 4.
4. **Zones or wrecks overlapping a space, the bay or the exit,** which would make parked ships take radiation or spaces unreachable. Covered by the layout test in Task 5.
5. **Levels 1 and 2 without the new nodes.** No errors, and behaviour unchanged. Covered by the existing Level 1/2 shift tests staying green, plus a Task 4 test that Level 1 has no radiation timer entries.

---

### Task 1: Kenney art, credits and the sprite outline helper

**Files:**
- Create: `assets/art/kenney/` (only the sprites listed below, plus the pack's `License.txt`)
- Create: `docs/CREDITS.md`
- Create: `scripts/core/SpriteOutline.gd`
- Test: `tests/test_sprite_outline.gd`

**Interfaces:**
- Produces: `SpriteOutline.outline(texture: Texture2D, scale: float) -> PackedVector2Array`. It returns the largest opaque outline (alpha > 0.5), centred on the texture's centre and multiplied by `scale`, in local pixels.

- [ ] **Step 1: Download the pack.** Fetch the page `https://kenney.nl/assets/space-shooter-redux` and find the `.zip` download link. Download the zip into the scratchpad, in a new empty directory, and unzip it there. Copy only these files into `assets/art/kenney/`:
  - `PNG/Meteors/meteorBrown_big1.png` … `meteorBrown_big4.png`
  - `PNG/playerShip1_orange.png`, `PNG/playerShip2_blue.png`, `PNG/playerShip3_green.png`
  - `PNG/Damage/playerShip1_damage3.png`, `PNG/Damage/playerShip2_damage3.png`, `PNG/Damage/playerShip3_damage3.png`
  - `License.txt`

  If the page has no reachable zip, stop and ask. Don't substitute other art.
- [ ] **Step 2: Write `docs/CREDITS.md`.** Add a heading "Credits". Add one entry: "Space Shooter Redux by Kenney (kenney.nl), CC0 1.0. Used for: asteroids and wrecks in Level 3. Files: assets/art/kenney/". Add a line saying the ships and all other art are original by the developer.
- [ ] **Step 3: Write the failing test** `tests/test_sprite_outline.gd`:

```gdscript
func test_outline_of_a_solid_rectangle_is_centred_and_scaled() -> void:
	var img := Image.create(20, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var poly := SpriteOutline.outline(ImageTexture.create_from_image(img), 2.0)
	assert_true(poly.size() >= 4)
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	assert_true(box.position.distance_to(Vector2(-20, -10)) < 2.5, str(box))
	assert_true(box.end.distance_to(Vector2(20, 10)) < 2.5, str(box))

func test_kenney_sprites_have_outlines() -> void:
	for f in ["meteorBrown_big1", "playerShip1_orange"]:
		var tex: Texture2D = load("res://assets/art/kenney/%s.png" % f)
		assert_true(SpriteOutline.outline(tex, 1.0).size() >= 3, f)
```

- [ ] **Step 4: Run the suite.** Expected: FAIL, because `SpriteOutline` is not declared.
- [ ] **Step 5: Implement `SpriteOutline.outline`.** Use `BitMap.create_from_image_alpha(image, 0.5)` and `opaque_to_polygons(Rect2i(Vector2i.ZERO, size), 2.0)`. Pick the polygon with the most points. Subtract `size / 2.0` from each point, then multiply by `scale`.
- [ ] **Step 6: Run the suite.** Expected: `ALL TESTS PASSED`.
- [ ] **Step 7: Commit:** `feat: Kenney CC0 art for Level 3 wreckage, credits, sprite outline helper`.

### Task 2: Wreck and Asteroid actors

**Files:**
- Create: `scripts/actors/Wreck.gd`, `scripts/actors/Asteroid.gd`
- Test: `tests/test_wreckage.gd`

**Interfaces:**
- Consumes: `SpriteOutline.outline` (Task 1).
- Produces:
  - `class_name Wreck extends StaticBody2D`
    - `@export var texture: Texture2D`, `@export var overlay: Texture2D`, `@export var art_scale := 1.4`
    - In `_ready` it adds a Sprite2D (with the overlay as a child Sprite2D) modulated `Color(0.55, 0.55, 0.6)`, and a CollisionPolygon2D from `SpriteOutline.outline(texture, art_scale)`.
  - `class_name Asteroid extends RigidBody2D`
    - `@export var texture: Texture2D`, `@export var art_scale := 0.6`, `@export var drift_speed := 25.0`
    - `const MASS := 1.75`
    - `func hull_points() -> PackedVector2Array`: the outline points plus the centre, in global coordinates (same contract as `Ship.hull_points()`).
    - In `_ready` it sets `mass = MASS`, `gravity_scale = 0`, `linear_damp_mode = DAMP_MODE_REPLACE` with `linear_damp = 0`, adds the sprite and collision polygon, and sets `linear_velocity` to `drift_speed` in a random direction and `angular_velocity` to a random value in ±0.4.

- [ ] **Step 1: Write the failing tests** in `tests/test_wreckage.gd`:
  - `test_wreck_collides_with_its_sprite_outline`: a Wreck with `playerShip1_orange` in the tree has a `CollisionPolygon2D` child whose polygon has ≥ 3 points and spans more than 60 px wide.
  - `test_asteroid_is_shoveable_and_drifts`: an Asteroid with `meteorBrown_big1` in the tree has `mass == Asteroid.MASS`, a collision polygon, and `linear_velocity.length()` within 0.5 of `drift_speed`.
  - `test_asteroid_hull_points_follow_it`: put an Asteroid at (500, 400). Every `hull_points()` entry is within 60 px of (500, 400), and the last entry is (500, 400).
  - `test_ship_hitting_an_asteroid_hard_dents`: a light_scout fixture ship at speed 400 px/s heading into a resting asteroid (`drift_speed = 0`) emits `dented` within 60 physics frames.
- [ ] **Step 2: Run the suite.** Expected: FAIL, because `Wreck` / `Asteroid` are not declared.
- [ ] **Step 3: Implement `Wreck.gd` and `Asteroid.gd`** per the Interfaces block. `Ship._on_body_entered` already treats any `RigidBody2D` as a dent source, so it needs no change.
- [ ] **Step 4: Run the suite.** Expected: `ALL TESTS PASSED`.
- [ ] **Step 5: Commit:** `feat: fixed wrecks and drifting asteroids traced from their sprites`.

### Task 3: The arrival bay waits for asteroids

**Files:**
- Modify: `scripts/actors/ArrivalBay.gd` (`touches`, `is_clear`)
- Modify: `scripts/Level.gd` (`_physics_process` bay check; a new `@onready var _asteroids: Node = get_node_or_null("Asteroids")`)
- Test: `tests/test_arrival_bay.gd`, `tests/test_level.gd`

**Interfaces:**
- Consumes: `Asteroid.hull_points()` (Task 2).
- Produces:
  - `ArrivalBay.touches(body: Node2D) -> bool`, which accepts a `Ship` or an `Asteroid` (any other type → false).
  - `ArrivalBay.is_clear(bodies: Array[Node]) -> bool`.
  - Level passes its ships' children plus `_asteroids` children (when present) to `is_clear`.

- [ ] **Step 1: Write the failing tests:**
  - In `test_arrival_bay.gd`: `test_asteroid_in_the_bay_blocks_it`. Put a bay at (300, 300) and a frozen Asteroid (`drift_speed = 0`) at (300, 300). Assert `is_clear([asteroid])` is false. After moving the asteroid to (300, 700), assert it's true.
  - In `test_level.gd`: `test_asteroid_in_the_bay_holds_the_next_arrival`. Make a level with `_make_level()` and add a `Node` named "Asteroids". Note `_asteroids` is `@onready`, so set `level._asteroids` directly. Add a frozen asteroid at the bay's position and move the first ship to `OPEN_FLOOR`. Set `_arrival_timer = 999`. After 90 physics frames there is still 1 ship. Move the asteroid away, and after 70 frames there are 2 ships.
- [ ] **Step 2: Run the suite.** Expected: FAIL. Either `touches` rejects an Asteroid argument, or the arrival test sees 2 ships.
- [ ] **Step 3: Implement.** `touches` gets its points with an `if body is Ship … elif body is Asteroid …` branch, because typed GDScript can't call `hull_points()` on a plain `Node2D`. Level builds `var bodies: Array[Node] = _ships.get_children()` and appends `_asteroids.get_children()` when `_asteroids` exists.
- [ ] **Step 4: Run the suite.** Expected: `ALL TESTS PASSED`. The existing arrival-bay tests also stay green.
- [ ] **Step 5: Commit:** `feat: arrivals wait for asteroids to clear the bay`.

### Task 4: Radiation zones

**Files:**
- Create: `scripts/actors/RadiationZone.gd`
- Modify: `scripts/Level.gd`
- Test: `tests/test_radiation.gd`, `tests/test_level.gd`

**Interfaces:**
- Produces:
  - `class_name RadiationZone extends Node2D`
    - `@export var radius := 110.0`
    - `func touches(ship: Ship) -> bool`: any `hull_points()` entry within `radius` of `global_position`.
    - `_draw`: a translucent green disc `Color(0.3, 1.0, 0.3, 0.18)` with an outline whose alpha pulses (queue_redraw in `_process`).
  - In Level.gd:
    - `const RADIATION_DENT_COST := 5`, `const RADIATION_INTERVAL := 2.0`
    - `@onready var _radiation: Node = get_node_or_null("Radiation")`
    - `var _radiation_time: Dictionary = {}`, keyed Ship → seconds of continuous exposure
    - `var _radiation_hint_shown := false`
    - `func _update_radiation(delta: float) -> void`, called from `_physics_process` after the bay check, only when `_radiation` exists.
      - For each ship touching any zone, it adds delta.
      - When the time reaches `RADIATION_INTERVAL`, it calls `_on_ship_dented(ship, RADIATION_DENT_COST)` and subtracts the interval.
      - Ships touching no zone are erased from the dictionary.
      - Freed ships are skipped and erased.
      - On the first radiation dent of the shift it shows `"Radiation! It dents ships inside"` for 3 s, after the dent hint so the radiation hint stays visible.

- [ ] **Step 1: Write the failing tests:**
  - `tests/test_radiation.gd`: `test_zone_touches_any_part_of_a_ship`. Use a zone at (300, 300) with radius 110 and a frozen light_scout. At (300, 300): true. At (300 + 110 + 40, 300), so the centre is outside but the hull edge is inside: true. At (800, 300): false.
  - `tests/test_level.gd`. Each test builds a tiered level from `_make_tiered_level()`, adds a `Node2D` "Radiation" with one RadiationZone at `OPEN_FLOOR`, sets `level._radiation` to it, moves the first ship to `OPEN_FLOOR`, and drives `level._update_radiation(...)` directly.
    - `test_radiation_dents_after_two_seconds_inside`: `_update_radiation(1.9)` → `ledger.pay` unchanged and `customer_for(ship).dents == 0`. Then `_update_radiation(0.2)` → pay down by 5 and dents == 1.
    - `test_leaving_radiation_resets_the_timer`: inside 1.5 s, move out and call `_update_radiation(0.1)`, move back in, call `_update_radiation(1.5)` → no dent yet. Another `_update_radiation(0.6)` → 1 dent.
    - `test_radiation_dents_keep_coming_every_two_seconds`: inside for 6.1 s in 0.1 s steps → 3 dents, pay down by 15.
    - `test_returned_ship_leaves_no_radiation_entry`: give the ship 1 s of exposure, `queue_free` it, await a frame, then `_update_radiation(1.5)` → no error, and `_radiation_time` is empty.
    - `test_level01_has_no_radiation`: a plain `_make_level()` (Level 1) has `_radiation == null`, and after 60 physics frames `_radiation_time` is empty.
- [ ] **Step 2: Run the suite.** Expected: FAIL, because `RadiationZone` and `_update_radiation` are not declared.
- [ ] **Step 3: Implement** `RadiationZone.gd` and the Level.gd additions per the Interfaces block.
- [ ] **Step 4: Run the suite.** Expected: `ALL TESTS PASSED`.
- [ ] **Step 5: Commit:** `feat: radiation zones dent ships every 2 s inside`.

### Task 5: The Level 3 scene, Level Select and the GDD

**Files:**
- Create: `scenes/levels/Level03.tscn`, by copying `Level01.tscn`
- Modify: `tests/test_level.gd`, `tests/test_ui_flow.gd`, `docs/GDD.md`
- Test: `tests/test_level.gd`, `tests/test_ui_flow.gd`

**Interfaces:**
- Consumes: `Wreck`, `Asteroid`, `RadiationZone`, the Level `Asteroids` / `Radiation` node names, and `ExitPad.tscn`.

**Scene contents.** Start from Level 1. Keep its walls, island (both the IslandFloor polygon and the CollisionPolygon2D), Floor, Entrance, LotCamera, HUD, Controls, ShipPicker and spaces A1–C2. Rename the root to `Level03`. Then add:

| Node | Position | Notes |
|---|---|---|
| C1, C2 | unchanged | `gold = true` |
| D1, D2 | (420, 1180), (560, 1180) | `space_class = 2`, rotation 0 |
| E1 | (2260, 1050) | medium, rotation 0 |
| `Exit` (ExitPad.tscn) | (2260, 700) | |
| `Radiation` / Z1, Z2, Z3 | (1300, 330), (1050, 1100), (2040, 880) | radius 100 |
| `Wrecks` / W1–W4 | (350, 300), (800, 1300), (1800, 1150), (2250, 200) | playerShip1/2/3 + matching damage3 overlay; rotations 0.4, -1.2, 2.5, -0.3 |
| `Asteroids` / R1–R4 | (450, 450), (1500, 330), (1600, 950), (2000, 1250) | meteorBrown_big1–4 |

- Settings and pool follow the Global Constraints. The pool's ext_resource lines are Level 2's ten ships.
- The positions above are a starting point. The layout test decides: if it reports an overlap, nudge that node and note a Ruling.

- [ ] **Step 1: Write the failing tests** in `tests/test_level.gd`:
  - `test_level03_layout`:
    - `GameState.has_level_scene(3)`
    - space counts `{HEAVY: 2, MEDIUM: 5, LIGHT: 2}`
    - gold spaces are exactly C1 and C2
    - an `Exit` ExitPad
    - 3 RadiationZones, at least 3 Wrecks and at least 3 Asteroids
    - every setting from the Global Constraints
    - all 10 `resources/ships/*.tres` in the pool
  - `test_level03_zones_and_wrecks_stay_off_spaces`: for each zone, the distance from its centre to each space's rotated rectangle, to the bay (140×220 at the Entrance transform) and to the exit rect is greater than its radius. For each wreck, the same check, using the radius of its collision outline's bounding circle.
  - `test_level03_runs_a_shift`: mirror `test_level02_runs_a_shift`. It loads with 7 customers, runs 120 physics frames, and shows no errors.
  - In `tests/test_ui_flow.gd`, change `test_level_select_locks`: with 3 levels unlocked, button 3 is enabled. Add `test_level4_says_coming_soon`: with 4 unlocked, button 4 is disabled and contains "Coming soon".
- [ ] **Step 2: Run the suite.** Expected: FAIL. There is no Level 3 scene, and button 3 is disabled.
- [ ] **Step 3: Build `Level03.tscn`** per the table above.
- [ ] **Step 4: Run the suite.** Expected: `ALL TESTS PASSED`. Also run `D:/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . res://scenes/levels/Level03.tscn --quit-after 300` and grep the output for `ERROR`. Expected: no matches.
- [ ] **Step 5: Update the GDD.** In §5, append to the Level 3 row: "9 spaces (2 heavy D1–D2, gold C1–C2), fixed wrecks and drifting asteroids, radiation dents ₵5 every 2 s inside". Add a line under §4 Arrivals saying asteroids also block the bay. In §10, point to `docs/CREDITS.md`.
- [ ] **Step 6: Commit:** `feat: Level 3 Wreckage Lot`.

### Task 6: Desktop playtest

- [ ] **Step 1:** Run `tools/check_export_pack.gd` as before, and confirm `EXPORT CHECK PASSED` (the Kenney PNGs must be in the pack).
- [ ] **Step 2:** Launch Level 3 in a window: `D:/godot/Godot_v4.7.2-stable_win64_console.exe --path . res://scenes/levels/Level03.tscn`, run in the background. Ask the user to play a shift and report on feel: radiation pace, asteroid drift speed, wreck sizes, and whether the art style clashes. Tuning changes from that feedback go in a follow-up commit.
