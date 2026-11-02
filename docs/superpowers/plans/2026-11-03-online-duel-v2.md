# Online Duel v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the duel fair and lively: two paired seeded arrival bays, a black hole near the entrance, moving parked ships, every ship leaving 20–30 s after parking, blame that follows whoever knocked a ship, and the right LAN IP in the Lobby.

**Architecture:**
- All rule changes live in `DuelLevel` (host), `GuestMirror` (guest display) and `Duel.tscn`.
- Blame marking goes in `Ship`'s collision handler.
- The Lobby IP fix is a pure static helper on `NetSession`.
- Offline levels must not change.

**Tech Stack:** Godot 4.7.2, typed GDScript, the existing duel networking (NetSession/NetSync/NetProtocol/SnapshotBuffer), and the headless test runner.

**Spec:** `docs/superpowers/specs/2026-11-03-online-duel-v2-design.md`. It builds on `docs/superpowers/specs/2026-11-02-online-duel-design.md`.

## Global Constraints
- **Bays:** `BAY_INTERVAL = 10.0` s per bay. Slots per bay = `ceili(minutes * 6) + 3` (21 at 3:00, 123 at 20:00). The bays are the existing `Entrance` (left) plus a new `EntranceR` (right), mirrored about x = 1200. Both are shared.
- **Pairing:** slot N has the same class and tier in both bays. The model is drawn separately per bay (spawn weights). A bay behind the other spawns as soon as it's clear (no interval) and never skips a slot.
- **Leaving:** every duel customer wants retrieval. The request comes 20–30 s (uniform, seeded `_rng`) after the **first** park. Fee goes to the first parker, the tier tip to whoever drives it onto the EXIT.
- **Moving parked ships:** `allow_moving_parked = true` in the duel. Re-parking pays nothing (first-park-only stays).
- **Black hole:** one `BlackHole` on x = 1200 between and just below the bays. Level 4 rules. No asteroids. The host simulates it; the guest only draws it.
- **Blame:** a driven ship hitting an undriven, unparked ship sets that ship's `last_driver` to the driver's valet. Undriven against undriven: the struck ship takes the mark of the faster (pre-impact) ship, if that ship has a mark. Parking clears the mark (-1). Dents are still charged to `valet_of(ship)`. Driven against driven: the faster ship pays (unchanged).
- **Lobby IP:** prefer Wi-Fi or Ethernet. Skip interface names containing (case-insensitive) VMware, VirtualBox, vEthernet, Hyper-V, Radmin, Hamachi, ZeroTier, Tailscale or VPN. Fall back to `private_ip`.
- **Protocol:** any change to RPCs or payloads bumps `NetSession.PROTOCOL_VERSION` to 3. The handshake RPC ids stay lowest (see the comment in NetSession.gd).
- **Layout:** lanes ≥160 px. Everything stays within the HUD-safe band, world y 300–1320 (`test_duel_layout_clear_of_hud`). The straight route from either bay to the EXIT is blocked by a pillar.
- **Process:** offline behaviour must not change. The full suite stays green after every task. Runner: `bash .superpowers/sdd/2026-11-01-ship-art-pipeline/t.sh`.

## Review Focus
1. **A camped bay must catch up without double-spawning.** The catch-up spawn waits for `ARRIVAL_CLEAR_SECONDS` of clear bay each time, so ships don't stack on top of each other (Task 4 test).
2. **Blame race.** Both ships get `body_entered` in the same physics step, in either order. The mark must come from pre-collision state, or the result depends on order (Task 2 test runs both orders).
3. **The guest mirror must not run the black hole's pull or fling.** Its ships are frozen anyway, but a stray `apply_central_force` or velocity write on a frozen body is a bug (Task 4 test).
4. **The ship list's new `bay` field changes the payload.** The protocol version must bump, or a v2 APK would misparse v3 messages (Task 4 test pins the version).
5. **Moving a parked leaver keeps its request timer.** Re-parking a moved ship that has already been requested must not reset the request or pay again (Task 3 test).

---

### Task 1: Lobby picks the Wi-Fi address

**Files:**
- Modify: `scripts/net/NetSession.gd`
- Test: `tests/test_net_session.gd`

**Interfaces:**
- Produces: `static func pick_lan_ip(interfaces: Array) -> String`. Entries have the shape `IP.get_local_interfaces()` returns (`{name, friendly, index, addresses}`). `local_ip()` returns `pick_lan_ip(IP.get_local_interfaces())`, falling back to `private_ip(IP.get_local_addresses())` when that's empty.

- [ ] **Step 1: Failing test** `test_pick_lan_ip_skips_virtual_adapters`:
  - interfaces `[{friendly:"VMware Network Adapter VMnet8", addresses:["192.168.200.1"]}, {friendly:"Radmin VPN", addresses:["26.5.116.168"]}, {friendly:"Wi-Fi", addresses:["fe80::1","192.168.18.226"]}]` → "192.168.18.226"
  - only a VMware adapter → ""
  - an "Ethernet" adapter with 10.0.0.4 → "10.0.0.4"
  - Match on both `name` and `friendly`.
- [ ] **Step 2: Run.** Expected: FAIL (`pick_lan_ip` missing).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: ALL TESTS PASSED.
- [ ] **Step 5: Commit** `fix: lobby shows the Wi-Fi address, not virtual adapters`

### Task 2: Blame follows the knocker

**Files:**
- Modify: `scripts/actors/Ship.gd` (`_on_body_entered`, `set_parked`)
- Test: `tests/test_ship.gd`, `tests/test_duel.gd`

**Interfaces:**
- Produces: `Ship.blame_from(other: Ship) -> void`, which applies the marking rule using the pre-collision state (`_prev_velocity`, `is_driven`, `last_driver` as they were before this step's marks). `set_parked()` sets `last_driver = -1`. Offline: `last_driver` changes have no effect, because offline has one valet.

- [ ] **Step 1: Failing tests**
  - `test_driven_ship_marks_struck_ship` (test_ship): A is driven with `last_driver = 1`; B is undriven with `last_driver = -1`. After `B.blame_from(A)`, `B.last_driver == 1`.
  - `test_blame_chain_order_independent`: X is undriven, carrying mark 1 and moving fast; Y is undriven with mark 0 and slow. Calling `X.blame_from(Y); Y.blame_from(X)` and the reverse order (on fresh ships) both end with Y.last_driver == 1 and X.last_driver == 1.
  - `test_parking_clears_blame`
  - `test_knocked_ship_crash_charges_knocker` (test_duel, host DuelLevel with a fake session):
    - Valet 1 drives ship A. Ship B (parked once by valet 0, then requested, so it's undriven and unparked) is marked by A (call `B.blame_from(A)`).
    - Emitting `B.dented.emit(B, 20)` charges valet 1's ledger, not valet 0's.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** Call `blame_from(other)` at the top of `_on_body_entered` when `other is Ship`, before the payer logic. To be order-independent, compare the pre-step marks: snapshot `last_driver` into `_mark_before` in `_physics_process` (alongside `_prev_velocity`), and read the other ship's `_mark_before`.
- [ ] **Step 4: Run.** Expected: ALL TESTS PASSED.
- [ ] **Step 5: Commit** `feat: crashes are charged to whoever knocked the ship`

### Task 3: Moving parked ships and every ship leaves

**Files:**
- Modify: `scripts/DuelLevel.gd`, and `scenes/levels/Duel.tscn` (`allow_moving_parked = true`) if it isn't set in code
- Test: `tests/test_duel.gd`

**Interfaces:**
- Produces: every duel customer has `wants_retrieval = true`. After the first park, `request_in = _rng.randf_range(20.0, 30.0)` (a DuelLevel override of the delay; offline keeps `Customer.request_delay`). `allow_moving_parked` is true in the duel.

- [ ] **Step 1: Failing tests**
  - `test_every_duel_ship_leaves`: each of the first 5 spawned customers has `wants_retrieval`. Parking one sets `request_in` in [20, 30].
  - `test_moving_parked_pays_nothing`:
    - valet 1 parks a ship (fee once)
    - valet 0 selects the parked ship and re-parks it elsewhere: neither ledger changes
    - the ship's `request_in` keeps counting down (it isn't reset)
  - `test_rival_cannot_take_driven_parked_move`: while valet 0 drives a ship it took from a space, valet 1's select is ignored.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** Put the delay override behind a Level virtual, e.g. `func retrieval_delay() -> float`, which offline returns `Customer.request_delay(_rng, ledger.time_left)` (the same call as today).
- [ ] **Step 4: Run.** Expected: ALL TESTS PASSED.
- [ ] **Step 5: Commit** `feat: duel ships all leave, parked ships can be moved`

### Task 4: Two paired bays and the black hole

**Files:**
- Modify:
  - `scenes/levels/Duel.tscn` (regenerate with a scratch Python script, or hand-edit: add `EntranceR`, move `Entrance` left, add a `BlackHole` instance, move the pillars)
  - `scripts/DuelLevel.gd` (slot list, per-bay spawning; consider a small helper `scripts/net/BaySlots.gd` for the pure slot-list logic)
  - `scripts/net/NetProtocol.gd` (ship list `bay` field)
  - `scripts/net/GuestMirror.gd` (place ships at the right bay; draw the black hole without simulating it)
  - `scripts/net/NetSession.gd` (`PROTOCOL_VERSION := 3`)
  - `scripts/Level.gd`, only if a virtual seam is needed for per-bay spawning (offline unchanged)
- Test: `tests/test_duel.gd`, `tests/test_net_protocol.gd`, `tests/test_duel_loopback.gd`

**Interfaces:**
- Produces:
  - `BaySlots.build(pool: Array[ShipSpec], count: int, rng, gold_allowed: Callable, use_tiers: bool, tier_weights: Dictionary) -> Array`. Each entry is `[{spec, tier}, {spec, tier}]` with the same class and tier.
  - `DuelLevel.slots_per_bay(minutes) -> int`
  - Ship-list entries gain `bay: int` (0/1).
  - The guest builds ships at `Entrance`/`EntranceR` from it.
  - `DuelLevel` spawns per bay. Each bay has its own index, interval timer and clear timer. A bay with an index below the other's ignores the interval but still needs `ARRIVAL_CLEAR_SECONDS` of clear bay. Both bays start after the countdown.
  - The black hole sits at x = 1200, between and below the bays. Pillars are shifted so lanes stay ≥160 px. The HUD band y 300–1320 is respected.

- [ ] **Step 1: Failing tests**
  - `test_bay_slots_pair_class_and_tier`: 30 slots with a seeded rng. Each pair has equal `ship_class` and tier, and the same seed gives the same list.
  - `test_slots_per_bay`: 3 → 21, 20 → 123.
  - `test_camped_bay_catches_up`:
    - block bay R (hold a ship in it) while bay L spawns 3 slots
    - free bay R: it then spawns its missed slots, each after only `ARRIVAL_CLEAR_SECONDS` clear, until its index equals L's
    - no two ships spawn within `ARRIVAL_CLEAR_SECONDS` in one bay
  - `test_duel_has_two_bays_and_black_hole`: `EntranceR.x == 2400 - Entrance.x` (±1), same y. The BlackHole is at x 1200 (±1) and below the bays' y.
  - `test_duel_black_hole_pulls_driven_ship` (host): a driven ship near the hole gets pulled toward it over 30 frames.
  - `test_guest_mirror_does_not_simulate_black_hole`: in the guest role, a mirror ship near the hole keeps exactly the snapshot position.
  - `test_ship_list_bay_round_trip` (test_net_protocol), and `PROTOCOL_VERSION == 3` (update the existing handshake test).
  - Existing layout tests: still green. Update `test_duel_pillars_block_straight_route` to check both bays → EXIT.
  - Loopback: still green, with at least one ship mirrored from each bay.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** Screenshot the lot (`--write-movie`, no `--headless`) and check the HUD clearance and lanes.
- [ ] **Step 4: Run** the suite 3 times. Expected: ALL TESTS PASSED each time.
- [ ] **Step 5: Commit** `feat: two paired seeded arrival bays and a black hole in the duel`

### Task 5: Docs, APK and playtest

**Files:**
- Modify: `docs/GDD.md` §8 (the v2 rules)

- [ ] **Step 1:** Update the GDD. Run the full suite. Expected: ALL TESTS PASSED.
- [ ] **Step 2:** Run the export check. Expected: EXPORT CHECK PASSED.
- [ ] **Step 3:** Build the debug APK, install it on the phone, and run the PC windowed. The user playtests both directions.
- [ ] **Step 4: Commit** `docs: duel v2 in the GDD`
