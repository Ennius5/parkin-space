# Parkin' Space – Ship Art Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The developer's pixel-art PNGs (base, paint, lights, thruster markers) become playable ships with traced collision shapes, random paint, glowing lights, and thrusters placed from the marker colours.

**Architecture:**
- `ShipArtBuilder` is a pure `RefCounted` class. It turns a base `Image`, a marker `Image` and a ship class into ship fields plus warnings and errors. It is unit-tested with small images built in code.
- `tools/build_ships.gd` is a headless `SceneTree` script. It scans `art/ships/<class>/` and writes `resources/ships/<name>.tres`.
- `Ship` gains a polygon collision, a paint sprite and a lights sprite.
- `Level` gives each customer a random paint colour.

**Tech Stack:** Godot 4.7.2 GDScript. Uses `Image`, `BitMap.opaque_to_polygons` and `CollisionPolygon2D`. Tests use the in-repo runner.

**Spec:** `docs/GDD.md` §10, "Ship art pipeline", plus the chat design agreed on 2026-11-01.

## Global Constraints

- `ART_SCALE = 2`: one art pixel equals 2×2 game pixels. The local position of art pixel (px, py) is `(Vector2(px, py) + Vector2(0.5, 0.5) - size / 2) * 2`.
- The nose points to local −Y. A positive torque is clockwise. `torque = (pos − com).cross(push)`.
- Marker colours, matched exactly on RGB with alpha > 0.5:
  - red FF0000 = engine
  - blue 0000FF = retro
  - green 00FF00 = side
  - yellow FFFF00 = rotation
  - magenta FF00FF = centre of mass
- **Class budgets** (force per button; torque for rotation; the mass is fixed per class):

  | Class | Fwd | Back | Strafe (each side) | Rotate (each direction) | Mass |
  |---|---|---|---|---|---|
  | LIGHT | 260 | 180 | 180 | torque 900 | 1.0 |
  | MEDIUM | 650 | 220 | 380 | torque 3200 | 2.5 |
  | HEAVY | 1000 | 400 | 650 | torque 9000 | 6.0 |

- Force per pixel = budget ÷ the total pixels of that button's thrusters. For rotation: force per pixel = torque budget ÷ Σ(pixels × |lever|), where the lever is the torque arm per unit force.
- Hard errors (the ship is not written): no Fwd, no Back, a missing strafe side, or a missing rotation direction.
- `display_name` is kept if the `.tres` already exists. Otherwise it comes from the file name ("scout_a" becomes "Scout A").
- Never read the marker PNG at runtime. Import textures use the Nearest filter (project default).
- Test command: `bash .superpowers/sdd/2026-11-01-ship-art-pipeline/t.sh`. Pass = `ALL TESTS PASSED`. Before any APK build, also run `tools/check_export_pack.gd`.

## Review Focus

- A marker pixel on a transparent part of the base. The nozzle rule finds no edge; expect it to use the canvas edge, not crash.
- A yellow marker on the centre-of-mass row. The torque is zero; expect a warning and the thruster skipped, not divide-by-zero.
- Base art with several separate islands (for example a detached wing). Expect the largest polygon to be used, plus a warning.
- Non-marker colours in the marker layer (anti-aliasing, stray pixels). Expect them ignored, plus a warning with the count.
- Paint or lights PNG with a different size from the base. Expect an error for that ship.

---

### Task 1: ShipArtBuilder

**Files:**
- Create: `scripts/core/ShipArtBuilder.gd`
- Test: `tests/test_ship_art_builder.gd`

**Interfaces:**
- Produces: `class_name ShipArtBuilder extends RefCounted` with:
  - `const ART_SCALE := 2`
  - `static func build(base: Image, markers: Image, ship_class: ShipSpec.ShipClass) -> Dictionary`
  - The returned keys are `hull_size: Vector2`, `hull_polygon: PackedVector2Array`, `center_of_mass: Vector2`, `mass: float`, `thrusters: Array[ThrusterSpec]`, `warnings: PackedStringArray` and `errors: PackedStringArray`.

- [ ] **Step 1: Write the failing tests.** Use a helper `_rect_image(w, h)` (an opaque rectangle) and `_mark(img, x, y, color)`.
  - `test_basic_layout_directions_and_actions`: a 10×16 base with:
    - red at (5,15)
    - blue at (2,0) and (7,0)
    - green at (0,8) and (9,8)
    - yellow at (0,2), (9,2), (0,13) and (9,13)

    Expect:
    - red direction (0,−1), actions [thrust_forward]
    - blue direction (0,1)
    - green at x=0: direction (1,0), [strafe_right]; green at x=9: (−1,0), [strafe_left]
    - yellow at (0,2): [rotate_right]; yellow at (9,2): [rotate_left]
    - no errors
  - `test_positions_use_art_scale`: the red at (5,15) on a 10×16 base gives local position (1, 15).
  - `test_budgets_light`: in the basic layout, the summed Fwd force is 260, Back 180, strafe_right 180, and the rotate_right torque about the centre of mass is 900 (±0.5).
  - `test_bigger_blob_gets_bigger_share`: two red blobs of 1 px and 3 px share 260 as 65 and 195.
  - `test_com_default_is_opaque_centroid`: an asymmetric base, a 10×16 rectangle plus a 4×4 block at the right, has its centre of mass at the centroid in local px. Expect x > 0.
  - `test_magenta_overrides_com`: magenta at (5,10) gives com (1,5).
  - `test_nozzle_follows_outline`: an L-shaped base where a green marker sits next to the inner edge on the right side of the left column. Expect it to push left (strafe_left), because the nearest edge on its row is to its right.
  - `test_missing_retro_is_error`: no blue gives an error containing "Back".
  - `test_yellow_on_com_row_warns`: yellow on the centre-of-mass row gives a warning and is skipped.
  - `test_polygon_traced`: a 10×16 rectangle gives a polygon whose bounding rect is about (−10,−16, 20,32).
  - `test_stray_colours_warn`: a grey pixel in the markers gives a warning mentioning "1".
- [ ] **Step 2: Run** t.sh. Expected: FAIL (ShipArtBuilder not declared).
- [ ] **Step 3: Implement.**
  - Flood-fill the markers with 4-connectivity, grouping pixels by colour.
  - The cluster position is the mean of its pixel centres.
  - Nozzle rule for green and yellow: from the cluster's rounded centre row, scan left and right in the base alpha until the first transparent pixel or the canvas edge. The nozzle faces the nearer side (ties go left), and the push direction is the opposite.
  - Polygon: `BitMap.create_from_image_alpha` then `opaque_to_polygons(Rect2i(...), 0.5)`. Take the largest by area, scale it and centre it.
- [ ] **Step 4: Run** t.sh. Expected: ALL TESTS PASSED.
- [ ] **Step 5: Commit** `feat: ShipArtBuilder turns pixel-art layers into ship data`.

### Task 2: Ship renders the art layers and uses the outline

**Files:**
- Modify: `scripts/core/ShipSpec.gd` (add `hull_polygon: PackedVector2Array`, `paint_texture: Texture2D`, `lights_texture: Texture2D`), `scripts/actors/Ship.gd`, `scenes/actors/Ship.tscn` (add `Paint` and `Lights` Sprite2D children; `Lights` gets a `CanvasItemMaterial` with additive blending), `scripts/Level.gd`, `project.godot` (`rendering/textures/canvas_textures/default_texture_filter=0`)
- Test: `tests/test_ship.gd`, `tests/test_level.gd`

**Interfaces:**
- Produces:
  - `Ship.paint_color: Color`, set before `add_child`
  - `Ship.lights_level() -> float`: 1.0 while driven, a blink in [0.3, 1.0] while waiting, 0.25 when parked
  - `Level.PAINT_COLORS: Array[Color]`
  - `hull_points()` returns the polygon vertices plus the centre when `hull_polygon` isn't empty

- [ ] **Step 1: Write the failing tests:**
  - `test_polygon_spec_uses_collision_polygon`: a spec with a triangle `hull_polygon` gets an enabled `CollisionPolygon2D` child and a disabled rectangle shape.
  - `test_hull_points_use_polygon`: the triangle's vertices are returned in global coordinates, plus the centre.
  - `test_paint_color_tints_paint_layer`: with a paint texture and `paint_color` red, the Paint sprite's modulate is red and it is visible. With no paint texture, the Paint sprite is hidden.
  - `test_lights_levels`: driven gives 1.0, parked gives 0.25, and waiting stays within [0.3, 1.0].
  - `test_customers_get_a_paint_color`: a spawned ship's `paint_color` is in `Level.PAINT_COLORS`.
- [ ] **Step 2: Run** t.sh. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - Sprites are scaled by `hull_size / texture size`.
  - The Lights sprite's modulate alpha is set to `lights_level()` in `_process`.
  - Flames stay in the parent `_draw`, so they render under the art.
- [ ] **Step 4: Run** t.sh. Expected: ALL TESTS PASSED.
- [ ] **Step 5: Commit** `feat: ships draw paint and lights layers and collide by outline`.

### Task 3: build_ships tool and a sample ship

**Files:**
- Create:
  - `tools/build_ships.gd`
  - `art/ships/README.md` (the colour key and sizes, for the artist)
  - `art/ships/light/sample_scout.png`, `art/ships/light/sample_scout_paint.png`, `art/ships/light/sample_scout_lights.png`, `art/ships/light/sample_scout_thrusters.png` (a placeholder made by script, proving the pipeline end to end)
- Modify: `tools/check_export_pack.gd` (also check every `.tres` in `resources/ships/`)

- [ ] **Step 1:** Write `build_ships.gd`.
  - For each `art/ships/<class>/<name>.png` without a suffix, load the layers with `Image.load_from_file(ProjectSettings.globalize_path(...))` and call `ShipArtBuilder.build`.
  - Check that the paint and lights PNGs are the same size as the base.
  - Write `resources/ships/<name>.tres` with the textures set to the imported `res://` PNGs.
  - Print the warnings, the errors and a quirk report per ship. The report gives the net torque for Fwd, Back and each strafe direction, and the Rot L vs Rot R strength.
  - Exit code = the number of ships with errors.
- [ ] **Step 2:** Generate the sample-scout PNGs, run `--import`, then run the tool. Expected: `sample_scout` is written with no errors.
- [ ] **Step 3:** Take a screenshot of `sample_scout` driven, with paint and lights visible, then run t.sh. Expected: ALL TESTS PASSED.
- [ ] **Step 4:** Export the pack and run the export check. Expected: EXPORT CHECK PASSED.
- [ ] **Step 5: Commit** `feat: build_ships tool, artist guide, sample scout`.
