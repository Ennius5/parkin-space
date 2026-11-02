# Online Duel v2 — Design

**Date:** 2026-11-03 · **Status:** approved in chat, awaiting spec review · **Branch:** `feature/online-duel`
**Builds on:** `docs/superpowers/specs/2026-11-02-online-duel-design.md`. Everything there still holds unless this document replaces it.

## Why
After the first PC-vs-phone playtest, three problems showed up:
- A single arrivals bay turns into a tapping race, and the faster player can camp it.
- A player can park a light ship in a heavy space to block their rival.
- The duel needed more going on near the entrance.

Players are also pushing ships into each other as a bumper-car tactic. That is kept, but it must punish the attacker, not the victim.

## 1. Two paired arrival bays (replaces spec §2 "Arrivals bay")
- **Two bays,** named `EntranceL` and `EntranceR`, sit at the top of the lot, mirrored left and right of the centre line. Each has its own `ArrivalBay`. Both bays are shared: either player may take a ship from either bay.
- **Seeded slot list.** At match start the host draws a list of **slot pairs** from the match seed.
  - Slot N has the same **ship class** and **tier** in both bays.
  - The **model** is drawn separately for each bay from the ships of that class, using spawn weights.
  - Both bays get the same `wants_retrieval` flag (always true; see §4).
- **Spawning per bay.** Each bay has its own index into the slot list and its own timer.
  - It spawns its next slot when the bay is clear (`ARRIVAL_CLEAR_SECONDS`, as offline) and its interval has passed.
  - A bay that **fell behind** the other bay (index lower) ignores the interval. It spawns its next slot as soon as it is clear, so it catches up.
  - Neither bay ever skips a slot.
- **Interval:** `BAY_INTERVAL = 10.0` s per bay.
- **Slots per bay:** `ceili(minutes * 6) + 3`, for example 21 at 3:00 and 123 at 20:00. This replaces `duel_customers` for the duel.
- **Ship list and ids:** the guest still builds ships from `match_start` / `ship_added`. Each ship-list entry gains a `bay` field (0 = L, 1 = R).

## 2. Black hole (new)
- **Placement:** one `BlackHole`, as in Level 4, on the centre line between and just below the two bays.
- **Rules (Level 4 unchanged):**
  - It pulls ships that have been taken in hand since they were last free (`driven_since_free`).
  - It never pulls a ship resting in a space it fits; spaces shelter.
  - Its core is not solid and flings ships out spinning, with the fling cooldown.
- **No asteroids** in the duel.
- **Host only:** the host simulates the pull and the fling, and the guest sees the result through snapshots. Make the black hole visible on the guest (draw it), without running its pull there.
- **Layout:** the pillars move down as far as needed to keep ≥160 px lanes around the black hole. The centre pillar must still block the straight route from both bays to the EXIT.

## 3. Moving parked ships (Level 5 rule)
- `allow_moving_parked = true` in the duel. Either player can select any parked customer ship and re-park it.
- A rival can't select a ship the other player is driving (unchanged lock).
- **First-park-only pay (unchanged):** re-parking a ship already parked once pays nothing and calls no ledger functions.
- A leaver's request timer keeps running while it is moved.

## 4. Every ship leaves
- **Every** duel customer wants their ship back. The request comes **20–30 s** (uniform, seeded `_rng`) after the ship is **first** parked.
- **Pay:**
  - Whoever presses Done to park it first gets the ₵20 fee.
  - Whoever drives it onto the EXIT gets the tier tip (the existing retrieval rules).
- The `duel_retrievals` formula is no longer used by the duel.

## 5. Blame ("last controlled by")
- Taking the controls sets `ship.last_driver` = that valet (unchanged).
- **New:** when a **driven** ship collides with an **undriven, unparked** ship, the undriven ship's `last_driver` becomes the driver's valet id. Undriven ships that collide with each other pass the mark on: the struck ship takes the mark of the ship that hit it, if the hitter has one.
- **The mark clears** (`last_driver = -1`) when the ship is parked. It is replaced when someone drives it.
- **Who pays:** dents are still charged to `valet_of(ship)` (driver, then `last_driver`, then valet 0). Driven against driven keeps "faster pays".
- **Intended outcome:** ramming a rival's ship into others charges the rammer.

## 6. Lobby IP fix
- `NetSession.local_ip()` prefers addresses on Wi-Fi or Ethernet interfaces, using `IP.get_local_interfaces()`. It skips interfaces whose name contains "VMware", "VirtualBox", "vEthernet", "Hyper-V", "Radmin", "Hamachi", "ZeroTier", "Tailscale" or "VPN" (case-insensitive).
- It falls back to the existing first-private-address rule.
- Add a pure static helper `pick_lan_ip(interfaces: Array) -> String` so it can be tested.

## Testing
- **Slot list:**
  - The two bays agree on class and tier per slot, and are reproducible from the seed.
  - Slot counts follow the formula.
  - A camped bay catches up: after its blocker leaves, it spawns its missed slots back to back with no interval wait.
- **Black hole:**
  - It exists in Duel.tscn on the centre line.
  - It pulls a duel ship that is driven.
  - The guest mirror has the black hole and runs no pull.
- **Moving parked ships:** moving a parked ship in a duel pays nothing, and its request timer keeps counting.
- **Every ship leaves:** every parked duel ship gets a request within 20–30 s.
- **Blame:**
  - A driven ship knocking an undriven ship sets its `last_driver`.
  - A chain passes the mark on.
  - Parking clears it.
  - A crash of the knocked ship charges the knocker.
- **Lobby IP:** `pick_lan_ip` prefers Wi-Fi over a VMware adapter and falls back correctly.
- **Loopback match:** still green, with ships from both bays mirrored.
- **Layout:** two bays, the black hole, and pillars clear of the HUD. A straight route from either bay to the EXIT is blocked.
