# Parkin' Space – Thruster Ships Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ships become a mass pushed by thrusters placed on the hull, so the scout, shuttle and freighter each handle differently.

**Architecture:** A new `ThrusterSpec` Resource holds one thruster (position, direction, force, actions) and its own math (`torque_about`, `push_along`). `ShipSpec` swaps `thrust/strafe_thrust/torque` for `thrusters: Array[ThrusterSpec]` and `center_of_mass`. `Ship` fires the thrusters whose actions are held with `apply_force` at each thruster's position, and computes STOP / Stop Spin strength from the thruster layout.

**Tech Stack:** Godot 4.7.2 GDScript, 2D physics. Tests: the in-repo runner `res://tests/TestRunner.tscn`.

**Spec:** `docs/GDD.md` §3 (Physics, Thrusters, Brakes, ship-class table, controls table), plus the design agreed in chat on 2026-11-01 (option A: each button fires a fixed set of thrusters per ship).

## Global Constraints

- Godot 4.7.2, typed GDScript. The nose points local −Y. Godot's y axis points down, so a positive torque turns the ship clockwise. `torque = (pos − com).cross(dir × force)`.
- No damping. Gravity stays off.
- STOP and Stop Spin change velocity directly (`move_toward` in `_integrate_forces`). They never add spin or side force.
- STOP strength = Σ max(0, dir̂·d̂) × force ÷ mass, where d̂ is the local direction opposite the drift.
- Stop Spin strength = Σ max(0, torque × −sign(ω)) × inverse_inertia.
- Buttons, touch layout, parking rules, ledger, levels and save file do not change.
- Test command: `bash .superpowers/sdd/2026-11-01-thruster-ships/t.sh`. Pass = `ALL TESTS PASSED`.

## Review Focus

- **Ship at rest when STOP is held.** The velocity is zero, so the direction is undefined. Expect no NaN and no flames.
- **Diagonal drift.** Retro and side thrusters both count, in proportion to the dot product. Expect no NaN.
- **Thruster `direction` not unit length in the Inspector.** It is normalised before use, so a typo can't change the force.
- **Parked or not-driven ships.** Expect no forces and no flames.
- **Opposite buttons held together** (Fwd + Back). Both sets fire; the result is whatever the physics gives. No crash.

---

### Task 1: ThrusterSpec and ship layouts

**Files:**
- Create: `scripts/core/ThrusterSpec.gd`
- Modify: `scripts/core/ShipSpec.gd`, `resources/ships/*.tres` (regenerated with a throwaway Godot script so the typed-array format is the engine's own)
- Test: `tests/test_thruster_spec.gd`

**Interfaces:**
- Produces: `class_name ThrusterSpec extends Resource` with these members:
  - `@export var position: Vector2`
  - `@export var direction: Vector2 = Vector2.UP`
  - `@export var force: float = 100.0`
  - `@export var actions: PackedStringArray`
  - `func push() -> Vector2` (normalised direction × force)
  - `func torque_about(com: Vector2) -> float`
  - `func push_along(dir: Vector2) -> float` (= max(0, dir̂·dir) × force; dir is a unit vector)
  - `func fires_for(held: PackedStringArray) -> bool`
- Produces: `ShipSpec` gains `@export var thrusters: Array[ThrusterSpec]` and `@export var center_of_mass: Vector2`. Its `thrust`, `strafe_thrust` and `torque` stay until Task 2.

Layouts. Positions are in px from the hull centre. Each row lists position → direction, force, [actions].

**Light scout** (com (0,0)):

| Thruster | Position | Direction | Force | Actions |
|---|---|---|---|---|
| Main | (0,30) | (0,−1) | 260 | thrust_forward |
| Retro ×2 | (±12,−30) | (0,1) | 90 each | thrust_back |
| Side | (−20,0) | (1,0) | 180 | strafe_right |
| Side | (20,0) | (−1,0) | 180 | strafe_left |
| Corner | (−20,−28) | (1,0) | 16 | rotate_right |
| Corner | (20,28) | (−1,0) | 16 | rotate_right |
| Corner | (20,−28) | (−1,0) | 16 | rotate_left |
| Corner | (−20,28) | (1,0) | 16 | rotate_left |

**Medium shuttle** (com (0,0)):

| Thruster | Position | Direction | Force | Actions |
|---|---|---|---|---|
| Main | (0,48) | (0,−1) | 650 | thrust_forward |
| Retro ×2 | (±18,−48) | (0,1) | 110 each | thrust_back |
| Side | (−30,3) | (1,0) | 380 | strafe_right |
| Side | (30,3) | (−1,0) | 380 | strafe_left |
| Corners | (±30,±46) | (same pattern as the scout) | 35 | rotate_right / rotate_left |

**Heavy freighter** (com (0,20)):

| Thruster | Position | Direction | Force | Actions |
|---|---|---|---|---|
| Engines ×2 | (±30,78) | (0,−1) | 500 each | thrust_forward |
| Retro ×2 | (±30,−78) | (0,1) | 200 each | thrust_back |
| Side, front | (−45,−50) | (1,0) | 300 | strafe_right |
| Side, rear | (−45,60) | (1,0) | 350 | strafe_right |
| Side, front | (45,−50) | (−1,0) | 300 | strafe_left |
| Side, rear | (45,60) | (−1,0) | 350 | strafe_left |
| Corners | (±45,±76) | (same pattern as the scout) | 60 | rotate_right / rotate_left |

- [ ] **Step 1: Write the failing tests** in `tests/test_thruster_spec.gd`:
  - `test_torque_about_origin`: thruster at (−20,−28), direction (1,0), force 16 → `torque_about(Vector2.ZERO) == 448`.
  - `test_torque_about_offset_com`: the same thruster about com (0,20) → 768.
  - `test_push_along`: direction (0,1), force 90 → 90 along (0,1), 0 along (0,−1), ≈0 along (1,0). A non-unit direction (0,5) also gives 90.
  - `test_fires_for`: actions ["thrust_back"] fires for ["thrust_back","rotate_left"] but not for ["thrust_forward"].
  - `test_layout_quirks`: for each ship resource, sum the thrusters by action and check:
    - every ship: thrust_forward and rotate_* net torque ≈ 0 (forward) / rotate_right > 0 > rotate_left
    - scout: strafe torque ≈ 0
    - shuttle and freighter: strafe_right torque ≠ 0
    - shuttle: thrust_back total force < 0.4 × thrust_forward total force
- [ ] **Step 2: Run** `t.sh`. Expected: FAIL (ThrusterSpec not declared).
- [ ] **Step 3: Implement** ThrusterSpec, add the ShipSpec fields, and regenerate the three `.tres` with the tables above.
- [ ] **Step 4: Run** `t.sh`. Expected: ALL TESTS PASSED.
- [ ] **Step 5: Commit** `feat: ThrusterSpec and thruster layouts for the three ships`.

### Task 2: Ship flies on thrusters

**Files:**
- Modify: `scripts/actors/Ship.gd`, `scripts/core/ShipSpec.gd` (remove `thrust`, `strafe_thrust`, `torque`), `resources/ships/*.tres` (drop those keys)
- Test: `tests/test_ship.gd`

**Interfaces:**
- Consumes: ThrusterSpec (Task 1).
- Produces: `Ship.firing: PackedInt32Array`, the indices into `spec.thrusters` that fired this physics frame (driving, STOP or Stop Spin). It is empty when the ship isn't driven.

- [ ] **Step 1: Write the failing tests** in `tests/test_ship.gd`. Keep all existing tests. Add:
  - `test_center_of_mass_from_spec`: freighter `center_of_mass == Vector2(0,20)`.
  - `test_off_centre_thruster_spins_ship`: a spec built in code with one thruster at (10,30), direction (0,−1), force 100, [thrust_forward]. After 20 frames of forward: `angular_velocity < 0` and the ship moves nose-first.
  - `test_thruster_fires_only_for_its_actions`: scout with strafe_right held. Every index in `firing` has strafe_right in its actions, `firing` is not empty, and `linear_velocity.x > 0`.
  - `test_weak_retro_brakes_forward_slower_than_sideways`: shuttle frames-to-stop from (0,−150) is greater than from (150,0).
  - `test_brake_flames_oppose_drift`: scout drifting (0,−150) with brake held. `firing` is not empty, and every fired thruster has `push_along(Vector2(0,1)) > 0`.
  - `test_brake_at_rest_is_quiet`: scout at rest with brake held for 10 frames. `firing` is empty and the velocity is still zero.
  - `test_not_driven_never_fires`: scout not driven with thrust_forward held. `firing` is empty.
- [ ] **Step 2: Run** `t.sh`. Expected: the new tests FAIL (`firing` missing).
- [ ] **Step 3: Implement:**
  - In `_ready`: `center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM` and `center_of_mass = spec.center_of_mass`.
  - In `_physics_process`, for each firing thruster: `apply_force(global_transform.basis_xform(t.push()), global_transform.basis_xform(t.position))`. Build `firing` from the held actions, plus the brake and spin thrusters while those are held (velocity > 0.5 px/s, |ω| > 0.01).
  - In `_integrate_forces`: brake and stop-spin strength as in Global Constraints. Call `queue_redraw()` when `firing` changes.
  - Remove the old spec fields.
- [ ] **Step 4: Run** `t.sh`. Expected: ALL TESTS PASSED, including the existing heavy-brakes-slower and stop-rotation tests.
- [ ] **Step 5: Commit** `feat: ships fly on thrusters; brakes use thruster layout`.

### Task 3: Flames, phone build

**Files:**
- Modify: `scripts/actors/Ship.gd` (`_draw`)
- Test: screenshot of a driven ship with flames (throwaway scene, `--write-movie`), and a 300-frame headless run of Level01 with no errors

- [ ] **Step 1:** In `_draw`, for each index in `firing`, draw a flame triangle from the thruster position pointing opposite `direction`. Length = clamp(force / 10, 12, 28) px, colour orange with a yellow core. Draw it whether or not the ship has a texture.
- [ ] **Step 2:** Take a screenshot of the scout with thrust_forward held. Expected: a flame behind the main engine.
- [ ] **Step 3:** Run `t.sh`. Expected: ALL TESTS PASSED. Then export with `--export-debug "Android" export/parkin-space.apk`. Expected: exit 0. Install with `adb` if a phone is connected.
- [ ] **Step 4: Commit** `feat: thruster flames`.
