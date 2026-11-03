# Online Duel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A same-Wi-Fi 1-vs-1 valet duel in a new symmetric lot. The host is authoritative and the guest mirrors snapshots. The host picks the length (3–20 min).

**Architecture:**
- Ships read their buttons from a `ShipPilot`, which is local touch or network bits.
- `Level` holds a list of `Valet`s (offline has exactly one).
- `DuelLevel` extends `Level`. It runs the real shift on the host, or a physics-free mirror on the guest.
- A `NetSession` node wraps ENet, the handshake and the watchdog. The autoload `Net` is one instance, and tests make two.
- `NetProtocol` and `SnapshotBuffer` are pure, testable units.

**Tech Stack:** Godot 4.7.2, typed GDScript, `ENetMultiplayerPeer` + `SceneMultiplayer` RPCs, and the project's headless test runner.

**Spec:** `docs/superpowers/specs/2026-11-02-online-duel-design.md`

## Global Constraints
- Port **24557**. `NetSession.PROTOCOL_VERSION := 1`. Host colour `HexStyle.CYAN`, guest `HexStyle.MAGENTA`.
- Match length is 3–20 minutes in 1-minute steps, 3 by default. Saved as `settings/duel_minutes`. The last join IP is saved as `settings/last_ip`.
- Customer pool = `ceili(minutes * 60 / 6.0) + 5`. Retrievals = `roundi(minutes * 4 / 3.0)`. `arrival_interval = 6.0`. `use_tiers = true`.
- Rates and timings:
  - input 30 Hz, snapshot 20 Hz
  - guest renders at now − 100 ms
  - join timeout 5 s, silence watchdog 3 s, countdown 3 s
- **Duel score:** starts at ₵0. Fees and tips add. Dents subtract and may go negative. No firing and no early win.
- **Copy (exact):**
  - "Cannot reach host. Check that you are on the same Wi-Fi."
  - "Your rival has a different version of the game."
  - "Your rival left the match"
  - "Hosting on %s — waiting for a rival…"
  - "Leave the match?"
  - "You win" / "You lose" / "Draw"
  - "Waiting for rival…"
  - "You ₵%d · Rival ₵%d"
- **Offline behaviour must not change.** All 309 existing tests stay green after every task.
- Test runner: `bash .superpowers/sdd/2026-11-01-ship-art-pipeline/t.sh`. Pass = `ALL TESTS PASSED` in the log's summary.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never commit `export/` or keystores.

## Review Focus
1. **The rival's ship on the host must not steal the host's camera or play the host's thruster sound.** Only local pilots take the camera and drive sound (Task 2 test).
2. **Customer draw in a duel must not use `fits_lot`.** 35–205 customers never fit 22 spaces, and `draw_customers` with space classes would stop early. A duel must draw without space classes (Task 7 test: pool size equals the formula).
3. **A guest disconnect mid-drive must free its ship on the host.** The ship is released, so the host can tap it, and no ring is left (Task 8 test).
4. **The two levels in the loopback test share one physics world.** The guest mirror must zero every collision layer and mask, or its walls collide with the host's ships (Task 9 test).
5. **Both players requesting the same ship.** The host's first-processed request wins, and the loser's request is ignored without error (Task 8 test).

---

### Task 1: Duel ledger and rammer-pays rule

**Files:**
- Modify: `scripts/core/ShiftLedger.gd`, `scripts/actors/Ship.gd` (`_pays_for_collision_with`)
- Test: `tests/test_shift_ledger.gd`, `tests/test_ship.gd`

**Interfaces:**
- Produces:
  - `ShiftLedger.duel(seconds: float) -> ShiftLedger`: pay 0, `endless = true`
  - `var endless := false`: when true, `add_dent` lets `pay` go negative and never sets FIRED, and `serve_customer` never sets WON. Only `tick` ends it, with TIMEOUT.

- [ ] **Step 1: Write the failing tests**
  - `test_duel_ledger_starts_at_zero_and_goes_negative`:
    - `var l := ShiftLedger.duel(180.0)`, then `l.add_dent(30)`
    - `assert_eq(l.earnings(), -30)` and `assert_eq(l.outcome, ShiftLedger.Outcome.PLAYING)`
  - `test_duel_ledger_never_wins_early`:
    - after 100 calls to `serve_customer()`, outcome is still PLAYING
    - after `tick(180.0)`, outcome is TIMEOUT
  - `test_faster_driven_ship_pays`:
    - two Ships, both `is_driven = true`, with `_prev_velocity` of (300,0) and (50,0)
    - `assert_true(fast._pays_for_collision_with(slow))` and `assert_false(slow._pays_for_collision_with(fast))`
    - equal speeds fall back to the lower instance id
- [ ] **Step 2: Run the suite.** Expected: the 3 new tests FAIL (`duel` not found).
- [ ] **Step 3: Implement.**
  - Add `endless` and `static func duel(seconds)`.
  - In `_pays_for_collision_with`, when both ships are driven, compare `_prev_velocity.length()`. Ties go to the lower id.
- [ ] **Step 4: Run the suite.** Expected: ALL TESTS PASSED (312).
- [ ] **Step 5: Commit** `feat: duel ledger and rammer-pays collisions`

### Task 2: ShipPilot

**Files:**
- Create: `scripts/core/ShipPilot.gd` (`class_name ShipPilot extends RefCounted`), `scripts/core/LocalPilot.gd`, `scripts/core/NetPilot.gd` (both extend ShipPilot)
- Modify: `scripts/actors/Ship.gd`
- Test: `tests/test_ship.gd`

**Interfaces:**
- Produces:
  - `ShipPilot.is_pressed(action: StringName) -> bool` (base: false)
  - `LocalPilot`: reads `Input.is_action_pressed`
  - `NetPilot`:
    - `var bits: int`
    - `const ACTIONS: Array[StringName]`: `Ship.DRIVE_ACTIONS` followed by `&"brake"` and `&"stop_rotation"`. Bit i = ACTIONS[i].
    - `static func bits_from_input() -> int`: packs the local `Input` state
  - `Ship.pilot: ShipPilot` (default `LocalPilot.new()`)
  - `Ship.set_driven(on: bool, local := true)`: only a local drive takes the drive camera and plays thruster sound
  - `Ship.last_driver := -1`: valet id, set by Level in Task 3

- [ ] **Step 1: Write the failing tests**
  - `test_net_pilot_drives_ship`:
    - a Ship in the tree with `pilot = NetPilot.new()`, bits for `ACTIONS.find(&"thrust_forward")` (the real name is `DRIVE_ACTIONS[0]`) set
    - `set_driven(true, false)`, then 10 physics frames
    - `linear_velocity.length() > 0`
  - `test_remote_drive_keeps_camera`:
    - the current camera before `set_driven(true, false)` is still current after
  - `test_bits_round_trip`:
    - `NetPilot.ACTIONS.size() <= 16`
    - setting bit for "brake" makes `is_pressed(&"brake")` true and the others false
- [ ] **Step 2: Run.** Expected: FAIL (NetPilot not declared).
- [ ] **Step 3: Implement.**
  - Replace every `Input.is_action_pressed` in `Ship.gd` with `pilot.is_pressed`.
  - Gate `_drive_camera.make_current()` and `Sound.start_thruster/stop_thruster` on a `_local_drive` flag that `set_driven` stores.
- [ ] **Step 4: Run.** Expected: ALL TESTS PASSED.
- [ ] **Step 5: Commit** `refactor: ships read buttons through a pilot`

### Task 3: Valets in Level

**Files:**
- Create: `scripts/core/Valet.gd`
- Modify: `scripts/Level.gd`
- Test: `tests/test_level.gd`

**Interfaces:**
- Produces:
  - `Valet` (RefCounted):
    - `id: int`, `ship: Ship`, `ledger: ShiftLedger`, `pilot: ShipPilot`, `local: bool`
    - `released_at_msec := -Level.RESELECT_DELAY_MS`
  - `Level.valets: Array[Valet]`: one local valet is made in `_ready` before anything else.
    - `driven_ship`, `ledger` and `_released_at_msec` become properties that get and set `valets[0]`'s fields, so existing tests and code keep working.
  - `Level.valet_of(ship: Ship) -> Valet`: the valet driving it, else the valet with `id == ship.last_driver`, else `valets[0]`.
  - `select_ship(ship, valet: Valet = null)`, `release_ship(valet: Valet = null)` and `press_done(valet: Valet = null)`. `null` means `valets[0]`. `_on_done_pressed` calls `press_done()`.
  - Rules:
    - a ship already driven by any valet can't be selected
    - parking, exit hand-over, tips and dents credit `valet_of(ship).ledger`
    - `_check_parking` lights a space for every valet's ship
    - `select_ship` sets `ship.pilot = valet.pilot`, `ship.last_driver = valet.id`, and `ship.set_driven(true, valet.local)`
    - controls and camera change only for local valets
  - `Level.new_ledger() -> ShiftLedger`: a virtual, offline returns the current `ShiftLedger.new(...)`

- [ ] **Step 1: Write the failing tests**
  - `test_level_has_one_local_valet`: Level01 has `valets.size() == 1`, `valets[0].local`, and `level.ledger == level.valets[0].ledger`.
  - `test_second_valet_cannot_take_a_driven_ship`:
    - add a `Valet` (id 1, non-local, own ledger) to `level.valets`
    - valet 0 selects the arrival; `select_ship(ship, v1)` leaves `ship` with valet 0
  - `test_park_credits_the_driving_valet`:
    - valet 1 drives the arrival into a fitting space (place it at the space's position with zero velocity, as existing park tests do)
    - `press_done(v1)`
    - `v1.ledger.earned > 0` and `level.ledger.earned == 0`
- [ ] **Step 2: Run.** Expected: FAIL (`valets` not found).
- [ ] **Step 3: Implement** the refactor per Interfaces. Keep each method's offline path identical.
- [ ] **Step 4: Run.** Expected: ALL TESTS PASSED, including all 309 original tests.
- [ ] **Step 5: Commit** `refactor: Level drives through a list of valets`

### Task 4: NetProtocol and SnapshotBuffer

**Files:**
- Create: `scripts/net/NetProtocol.gd`, `scripts/net/SnapshotBuffer.gd`
- Test: `tests/test_net_protocol.gd`

**Interfaces:**
- Produces:
  - **Snapshot dictionary:**
    ```
    {
      tick: int, time_left: float,
      scores: PackedInt32Array[2], lit: PackedInt32Array (per space index: -1 or valet id),
      ships: Array of {id, pos: Vector2, rot: float, driver: int (-1/0/1), parked: bool, glowing: bool, firing: int bitmask}
    }
    ```
  - **`NetProtocol` (static):**
    - `pack_snapshot(s: Dictionary) -> PackedByteArray` and `unpack_snapshot(b: PackedByteArray) -> Dictionary`. Fixed binary layout via `StreamPeerBuffer`: ids u16, floats f32, flags u8, firing u16.
    - `pack_ship_list(ships: Array) -> PackedByteArray` and `unpack_ship_list(b) -> Array`. Each entry: `{id, spec_path: String, paint: int, headlight: int, tier: int, wants_retrieval: bool}`.
  - **`SnapshotBuffer`** (RefCounted):
    - `push(s: Dictionary, at_sec: float)`
    - `sample(now_sec: float) -> Dictionary`: the state at `now_sec - 0.1`, with ship pos/rot lerped by id (rotation via `lerp_angle`), and other fields from the newer snapshot.
    - Before the first two snapshots, or past the newest one, it returns the newest snapshot unchanged (holds).
    - Keeps at most 10.

- [ ] **Step 1: Write the failing tests**
  - `test_snapshot_round_trip`: two ships; every field equal after pack/unpack (floats within 0.01).
  - `test_snapshot_size`: 30 ships pack to < 600 bytes.
  - `test_ship_list_round_trip`
  - `test_buffer_interpolates`:
    - push x=0 at t=1.0 and x=100 at t=1.1
    - `sample(1.15).ships[0].pos.x` ≈ 50
  - `test_buffer_holds_when_starved`: `sample(5.0)` returns the newest x=100.
  - `test_buffer_drops_old`: after 15 pushes, size ≤ 10.
- [ ] **Step 2: Run.** Expected: FAIL (script missing).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: ALL TESTS PASSED.
- [ ] **Step 5: Commit** `feat: duel network messages and snapshot smoothing`

### Task 5: NetSession and the Net autoload

**Files:**
- Create: `scripts/net/NetSession.gd`
- Modify: `project.godot` (autoload `Net="*res://scripts/net/NetSession.gd"`)
- Test: `tests/test_net_session.gd`

**Interfaces:**
- Produces:
  - **`NetSession extends Node`:**
    - consts: `PORT := 24557`, `PROTOCOL_VERSION := 1`, `JOIN_TIMEOUT := 5.0`, `SILENCE_LIMIT := 3.0`
    - `var port := PORT` (tests may change it)
    - `host() -> Error`, `join(ip: String) -> Error`, `close()`
    - `is_host() -> bool`, `is_active() -> bool`
    - `static func private_ip(addresses: PackedStringArray) -> String`: the first in 192.168/16, 10/8 or 172.16/12, else `""`
    - `local_ip() -> String`: `private_ip(IP.get_local_addresses())`
    - `heard()`: resets the watchdog; called by NetSync on every received message
    - `var duel_minutes := 3`: the host's choice, sent in the handshake
  - **Signals:** `connected` (both sides, after the version handshake succeeds), `join_failed(reason: String)` (timeout or version text), `rival_left`.
  - **Handshake RPCs on the session node itself:**
    - `_hello(version)` guest→host
    - `_welcome(minutes)` host→guest
    - `_reject()` host→guest
  - Uses `multiplayer` (whatever API the tree assigns to its path), so tests can give each session its own `SceneMultiplayer`.

- [ ] **Step 1: Write the failing tests**
  - `test_private_ip_filter`:
    - `["127.0.0.1","fe80::1","192.168.1.7"]` → "192.168.1.7"
    - `["10.0.0.4"]` → "10.0.0.4"
    - `["172.20.1.1"]` → "172.20.1.1"
    - `["172.40.1.1","8.8.8.8"]` → ""
  - `test_loopback_connects`:
    - build `/root/H` and `/root/G` Nodes, each with its own `SceneMultiplayer` via `tree.set_multiplayer(api, path)`, and a `NetSession` child
    - use port 24600; host, then guest `join("127.0.0.1")`
    - await up to 120 process frames, polling
    - both emit `connected`, and the guest's `duel_minutes` equals the host's (set host to 7)
  - `test_join_timeout`:
    - join 127.0.0.1 on an unused port with `JOIN_TIMEOUT` overridden to 0.3 (make it a var `join_timeout`)
    - `join_failed` arrives with the exact spec message
  - `test_rival_left_on_close`: after connecting, `guest.close()` → the host emits `rival_left` within 120 frames
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
  - On a version mismatch, the host calls `_reject` then disconnects that peer and keeps listening. The guest emits `join_failed` with the version message.
- [ ] **Step 4: Run.** Expected: ALL TESTS PASSED.
- [ ] **Step 5: Commit** `feat: LAN session with handshake, timeout and watchdog`

### Task 6: Saved duel settings

**Files:**
- Modify: `autoload/GameState.gd`
- Test: `tests/test_game_state.gd`

**Interfaces:**
- Produces:
  - `GameState.duel_minutes := 3` and `GameState.last_ip := ""`, both saved and loaded (bad values: minutes outside 3..20 or not an int → 3; a non-String ip → "")
  - `const DUEL_MIN := 3`, `const DUEL_MAX := 20`
  - `static func duel_customers(minutes: int) -> int` and `static func duel_retrievals(minutes: int) -> int` (formulas in Global Constraints)

- [ ] **Step 1: Failing tests**
  - `test_duel_settings_saved`
  - `test_bad_duel_minutes_fall_back` (25 → 3)
  - `test_duel_counts`:
    - customers(3)=35, customers(20)=205
    - retrievals(3)=4, retrievals(20)=27
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: ALL TESTS PASSED.
- [ ] **Step 5: Commit** `feat: saved duel length and last join address`

### Task 7: The duel lot scene

**Files:**
- Create: `scenes/levels/Duel.tscn`, generated by a scratch Python script (as for Levels 3–5) in the scratchpad, not committed. Also create `scripts/DuelLevel.gd`, at this point only `class_name DuelLevel extends Level` plus the overrides below.
- Test: `tests/test_duel.gd`

**Interfaces:**
- Produces:
  - **`Duel.tscn`:**
    - root `DuelLevel`, with Floor 2400×1400, Walls, `Spaces`, `Pillars` (StaticBody2D children, each with Polygon2D + CollisionPolygon2D), Floodlights (2 with `flicker = true`), Ships, `Entrance` at (1200, 90) facing down, `Exit` ExitPad at (1200, 1310), LotCamera (1200,700) zoom 0.5, HUD, Controls and ShipPicker
    - exports: `use_tiers = true`, `arrival_interval = 6.0`, and `customer_queue` = all 10 ship specs (the pool)
  - **Spaces:** 22 in total.
    - Per side: L L M M along the top band, L L M M along the bottom band, one H at the outer middle, and one gold M at the outer middle.
    - Left x mirrors right x about 1200 with the same y. Names L1..L11 and R1..R11.
  - **Pillars:** 6 irregular polygons (5–8 vertices) in the band x 700–1700, y 450–950. Each left pillar mirrors a right one. At least 160 px gaps.
  - **`DuelLevel`:**
    - `var minutes := 3`
    - `new_ledger()` returns `ShiftLedger.duel(minutes * 60.0)`
    - `_ready()` overrides the queue draw: `customer_queue = draw_customers(pool, GameState.duel_customers(minutes), _rng)` with **no** space classes, and `retrieval_count = GameState.duel_retrievals(minutes)`
    - `end_level()` does not touch GameState progress
    - in this task `DuelLevel` runs as a local single-valet level (used by layout tests; Tasks 8–9 add the modes)

- [ ] **Step 1: Failing tests**
  - `test_duel_lot_layout`:
    - 22 spaces: 8 light, 8 medium, 4 heavy; 2 gold (medium)
    - for every space named Lk there's an Rk at `Vector2(2400 - x, y)` (±1 px) with the same class and gold flag
    - Exit and Entrance exist
    - ≥5 pillars
  - `test_duel_pillars_mirrored`: each pillar's centroid has a partner at a mirrored centroid (±2 px).
  - `test_duel_queue_follows_minutes`:
    - instantiate with `minutes = 4` before adding to the tree
    - queue size == `duel_customers(4)`
    - `ledger.endless`, and `ledger.time_left == 240`
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** Generate the scene, then screenshot it with `--write-movie` and look at the frame.
- [ ] **Step 4: Run.** Expected: ALL TESTS PASSED.
- [ ] **Step 5: Commit** `feat: symmetric duel lot with irregular pillars`

### Task 8: DuelLevel host mode

**Files:**
- Create: `scripts/net/NetSync.gd` (a Node named `NetSync`, child of the DuelLevel, holding all match RPCs)
- Modify: `scripts/DuelLevel.gd`, `scripts/actors/Floodlight.gd`, `scripts/actors/Ship.gd` (driver ring), `scripts/ui/HUD.gd`
- Test: `tests/test_duel.gd`

**Interfaces:**
- Consumes: `NetSession` (Task 5), `NetProtocol` (Task 4), `Valet` (Task 3), `NetPilot` (Task 2).
- Produces:
  - **`DuelLevel`** fields:
    - `enum Role { HOST, GUEST }`, `var role := Role.HOST`
    - `var session: NetSession` (defaults to the `Net` autoload)
    - `var match_seed := 0`
    - `signal match_ended(my_score: int, rival_score: int)`
  - **Host mode:**
    - On `_ready`:
      - adds valet 1 (non-local, `NetPilot`, its own duel ledger)
      - seeds `_rng` and the lighting from `match_seed`
      - sends `match_start(seed, minutes, ship list so far)` and waits for `loaded`
      - then sends `go` and runs a 3 s countdown (HUD hint "3", "2", "1"), with shift ticking and arrivals paused until it ends
    - Every physics frame it applies the newest guest input bits to valet 1's pilot.
    - **Sending:**
      - snapshots every 1/20 s
      - `ship_added` when a ship spawns, `ship_removed` when one leaves at the exit
      - guest-facing `event(name)` for park, tip, fee, dent, crash, ready and request, credited to valet 1
    - **Requests:**
      - `select(id)` → `select_ship(ship, valet1)`
      - `done()` → `press_done(valet1)`
    - **End:** at TIMEOUT it sends `match_end(host_score, guest_score)` and emits `match_ended` locally.
    - **When `session.rival_left` fires:** release valet 1's ship and set `var rival_gone := true`. Task 10 adds the scene change to Mode Select.
  - **Floodlight:**
    - `recolor(rng: RandomNumberGenerator)` sets the colour from the rng
    - `var clock_zero_msec := 0`, so `energy_at` uses time since the match started
  - **Ship:**
    - `var ring_color := Color.TRANSPARENT`, drawn as a 3 px unlit ring around the hull while it's not transparent
    - `paint_index` and `headlight_index` ints that the level sets, so the ship list can send them
  - **HUD:** `set_duel_scores(mine: int, rival: int)` shows "You ₵%d · Rival ₵%d" in the Pay label, and hides the Customers label.

- [ ] **Step 1: Failing tests** (host DuelLevel with a fake session: a `NetSession` that isn't connected, with NetSync's send calls recorded to an array instead of RPC when `session.is_active()` is false)
  - `test_host_adds_remote_valet`: 2 valets, and valet 1 is not local with a NetPilot.
  - `test_guest_select_and_done_credit_guest`:
    - call `NetSync._on_select(ship_id)` and `_on_done()` directly
    - valet 1 earns, valet 0 doesn't
  - `test_same_ship_first_request_wins`:
    - host selects the arrival, then guest `select` on it
    - still the host's, and no error
  - `test_rival_left_releases_ship`:
    - guest drives, then `session.rival_left.emit()`
    - the ship is undriven, `ring_color` is transparent, and `rival_gone`
  - `test_seeded_lighting_matches`: two Duel instances with the same `match_seed` → equal floodlight colours.
  - `test_countdown_holds_the_clock`: during the first 2.9 s after `go`, `ledger.time_left` doesn't drop.
  - `test_driver_rings`: the host-driven ship has a CYAN ring, the guest-driven one MAGENTA.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** Send-or-record seam: `NetSync.send(method: StringName, args: Array)` calls `rpc_id(1 or peer, ...)` when active, else appends to `sent`.
- [ ] **Step 4: Run.** Expected: ALL TESTS PASSED.
- [ ] **Step 5: Commit** `feat: duel host runs the shared shift for two valets`

### Task 9: DuelLevel guest mirror and loopback match

**Files:**
- Modify: `scripts/DuelLevel.gd`, `scripts/net/NetSync.gd`
- Test: `tests/test_duel_loopback.gd`

**Interfaces:**
- Produces:
  - **Guest mode** (`role = GUEST`):
    - **On `_ready`:** no customer draw or spawn, no ledger ticking, and `set_physics_process(false)` for the level's rules. Every `CollisionObject2D` in the lot gets layer 0 and mask 0.
    - **Ships:**
      - `match_start` and `ship_added` build ships from the ship list: spec loaded by path, paint and headlight by index.
      - They're added frozen, with layers and masks 0 and `contact_monitor = false`.
      - `ship_removed` frees them.
    - **Every frame:**
      - `SnapshotBuffer.sample(now)` places the ships and sets `firing`, rings, glow and parked look
      - the HUD shows the guest's own score first, plus the time
      - lit spaces are drawn with `ready_for` set to the mirrored ship
    - **Input:**
      - every 1/30 s it sends `input(NetPilot.bits_from_input())`
      - a lot tap on a ship sends `select(id)`, and Done sends `done`
      - the guest's controls show when the snapshot says the guest drives a ship, and its drive camera follows that mirror ship
    - **Events:** `event(name)` plays `Sound.play(name)`, and hints for those names reuse the offline text.
    - **`match_end`:** emits `match_ended(guest_score, host_score)`.
  - Every received NetSync message calls `session.heard()`.

- [ ] **Step 1: Failing test** `test_loopback_match` (two roots with separate SceneMultiplayer as in Task 5; port 24601; `minutes = 3`):
  - The guest receives the ship list, and its first mirror ship exists with the same `spec.resource_path` as the host's.
  - The guest selects that ship via its NetSync, and the host's ship gets `last_driver == 1`.
  - With the guest's NetSync sending bits for forward thrust for 30 frames, the host ship moves > 5 px, and the guest's mirror of it is within 40 px of the host ship after 20 more frames.
  - Park it via the host API (teleport into the fitting space, zero velocity, `press_done(valet1)`). Within 60 frames the guest HUD's score text contains the guest's earned amount.
  - The guest's walls have `collision_layer == 0`.
  - `guest_session.close()` → host `rival_gone` within 120 frames.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: ALL TESTS PASSED (if the loopback timing flakes, raise frame budgets, not tolerances).
- [ ] **Step 5: Commit** `feat: guest mirrors the duel and drives through the host`

### Task 10: Lobby, Mode Select, online Pause and the Online Result screen

**Files:**
- Create: `scenes/ui/Lobby.tscn` + `scripts/ui/Lobby.gd`, and `scenes/ui/OnlineResult.tscn` + `scripts/ui/OnlineResult.gd`. Build their nodes in code, like PauseMenu and Credits.
- Modify:
  - `scripts/ui/ModeSelect.gd` + `.tscn`: remove the "coming soon" note and wire Online
  - `scripts/ui/PauseMenu.gd`: `set_online(on)` hides Restart and makes Quit "Leave match" with a Yes/No confirm
  - `scripts/DuelLevel.gd`: scene changes
  - `scripts/Level.gd`: online pause doesn't set `tree.paused`
  - `docs/GDD.md`
- Test: `tests/test_ui_flow.gd`, `tests/test_pause.gd`

**Interfaces:**
- Produces:
  - **`Lobby`:**
    - `%Minutes` label with `%Less`/`%More` buttons, clamped 3..20 and saved
    - `%Host`, `%Ip` LineEdit (prefilled `GameState.last_ip`), `%Join`, `%Status` label, `%Back`
    - `back_target()` returns ModeSelect, and Back closes `Net`
    - on `Net.connected` it changes to `Duel.tscn` with the role set through `GameState.duel_role` (add `var duel_role := ""` to GameState, not saved)
    - status copy is exactly as in the spec
  - **`OnlineResult`:**
    - shows "You win"/"You lose"/"Draw" and both scores, from `GameState.duel_result := {mine, rival}`
    - `%Rematch`: sends rematch, shows "Waiting for rival…", and when both have asked, reloads Duel with the same roles
    - `%Leave`: sends leave, closes, goes to Mode Select
  - **`Net.rival_left`** during the duel, countdown or result → `GameState.notice = "Your rival left the match"` and go to ModeSelect, which shows `GameState.notice` once in its note label, then clears it.
  - The duel's `match_ended` → stores `GameState.duel_result` and changes to OnlineResult.
- [ ] **Step 1: Failing tests**
  - `test_mode_select_online_opens_lobby`
  - `test_lobby_minutes_clamped_and_saved`: Less at 3 stays 3; More ×20 stops at 20; the value is saved
  - `test_lobby_back_closes_session`
  - `test_online_pause_does_not_pause`: Duel with `role = HOST`, fake session; `open_pause()` → `tree.paused == false`; Restart hidden; Quit text "Leave match"
  - `test_online_result_texts`: mine 50 / rival 20 → "You win"; equal → "Draw"
  - `test_rival_left_notice_shows_once`
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** Screenshot the Lobby and Result screens and check them.
- [ ] **Step 4: Run.** Expected: ALL TESTS PASSED.
- [ ] **Step 5: Commit** `feat: lobby, online pause and online result screens`

### Task 11: Build, export check and PC-vs-phone playtest

**Files:**
- Modify: `docs/GDD.md` §8 (final values), `tools/check_export_pack.gd` if it lists scenes
- Test: the export check

- [ ] **Step 1:** Run the full suite. Expected: ALL TESTS PASSED.
- [ ] **Step 2:** Run the export check (`--export-pack "Android"`, then `tools/check_export_pack.gd`). Expected: it passes, with Duel.tscn, Lobby and OnlineResult inside.
- [ ] **Step 3:** Build the debug APK and install it on the phone. Run the PC windowed (`Godot_v4.7.2-stable_win64_console.exe --path . res://scenes/ui/Title.tscn`). The user plays phone-host vs PC-guest and then the reverse, including Wi-Fi off mid-match.
- [ ] **Step 4: Commit** `docs: online duel in the GDD`
