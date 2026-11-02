# Online Duel — Design

**Date:** 2026-11-02 · **Status:** approved in chat, awaiting spec review · **Branch:** `feature/online-duel`

## Goal
Two players on the same Wi-Fi play a real-time 1-vs-1 valet shift in one shared lot. Whoever has the higher
score after 3:00 wins. This meets the lab's online-multiplayer requirement (GDD §8). The design favours
something we can test automatically over network cleverness.

## Decisions (from brainstorming)
- **Testing setup:** the user's Windows PC (windowed Godot run) and their Android phone. An automated loopback test runs a host and a guest in one process.
- **Lot:** one new symmetric duel lot. The offline levels are not played online.
- **Mechanics in a duel:** tiers & tips, retrievals, darkness & floodlights.
- **Not in a duel:** special requests, orphans, moving parked ships, hazards.
- **Sync:** host-authoritative with hand-built snapshots (approach A). The guest sends inputs and requests; the host sends snapshots and events.

## 1. Match flow and screens
- **Mode Select → Online** opens a new **Lobby** screen (`scenes/ui/Lobby.tscn`):
  - **Host:** shows "Hosting on <IP> — waiting for a rival…" with the Wi-Fi IP in large text.
  - **Join:** an IP field (the last IP is saved in `save.cfg`) and a Join button.
    - If the host can't be reached within **5 s**: "Cannot reach host. Check that you are on the same Wi-Fi."
    - If the versions differ: "Your rival has a different version of the game."
  - **Back** (and the Android back gesture) closes any connection and returns to Mode Select.
- **When the guest connects,** both phones load the duel lot. The host waits for the guest's **Loaded** message, then both show a **3-2-1 countdown** and the shift starts. The shift is **3:00** whatever difficulty is set.
- **HUD in a duel:**
  - "You ₵X · Rival ₵Y", the shared timer and the queue.
  - **Host = cyan, guest = magenta.** A ship being driven gets a ring in its driver's colour.
- **The Pause menu online doesn't pause.** It keeps Sound and CCTV. Restart is hidden. "Quit" becomes **Leave match**, which asks "Leave the match?" with Yes and No.
- **Online Result screen** (`scenes/ui/OnlineResult.tscn`):
  - You win / You lose / Draw, with both scores.
  - **Rematch:** when both players have tapped it, the same pair reloads the lot and counts down again. The screen says "Waiting for rival…" after you tap.
  - **Leave:** goes to Mode Select.
- **Disconnects:** if either player leaves or the link drops, the other phone shows "Your rival left the match" and goes to Mode Select. This works from the lot, the countdown and the result screen.
- Online results never touch offline unlocks, stars or `last_result`.

## 2. The duel lot (`scenes/levels/Duel.tscn`)
- **Size:** 2400×1400, the same as Level 2, with LotCamera at the centre and zoom 0.5. The layout is mirrored left to right.
- **Arrivals bay:** top centre, shared. Customers only arrive while it is clear, as offline.
- **EXIT pad:** bottom centre.
- **Spaces: 22 in total, 11 per side.**
  - 8 light, 8 medium, 4 heavy and 2 gold medium.
  - Per side: two blocks of L L M M along the top and bottom edges, plus one H and one gold M at the outer middle. Either player may use any space.
- **Middle:** 5–6 **irregular pillars**. These are jagged solid polygons (StaticBody2D + Polygon2D) scattered across the centre band and mirrored left to right. They block the straight route from the bay to the exit.
- **Customers:**
  - random draws with the usual tier odds (`use_tiers = true`)
  - `arrival_interval = 6.0`
  - a pool large enough for the shift (about 30)
  - about **4 retrievals**
- **Lighting:** pitch black, floodlights with 2 flickering, and headlights. The host chooses an **RNG seed** and sends it at match start. Floodlight colours, flicker and headlight colours come from that seed, so both phones look identical. The CCTV filter follows each phone's own setting.
- Exact coordinates are set when the scene is built. The user may tweak them in the editor later.

## 3. Rules and scoring
- **Score:**
  - Each player starts at **₵0**, with no salary and no firing.
  - Fees and tips add. Dent costs subtract, and the score can go negative.
- **End:** only when the 3:00 runs out. Higher score wins; an equal score is a draw.
- **Credit:**
  - The player who presses **Done** to park a ship gets its fee and tier tip.
  - The player who drives a returning ship onto the **EXIT** gets the retrieval payout.
- **Locks:**
  - A driven ship belongs to its driver, and the rival can't select it.
  - Parked ships can't be picked up.
  - When both players request the same ship, the first request the host processes wins.
- **Dents:**
  - **Driven ship against an undriven or parked ship:** the driver pays (unchanged).
  - **Two driven ships collide:** the **faster one pays**, comparing pre-impact speeds. An exact tie falls back to the lower instance id.
  - Offline rules are unchanged.

## 4. Network and code structure
**Transport:**
- Godot `ENetMultiplayerPeer` on **port 24557**, with up to 1 guest.
- The host's IP comes from `IP.get_local_addresses()`, filtered to the private IPv4 ranges (192.168/16, 10/8, 172.16/12). The first match is shown.
- The game version for the handshake is a constant `Net.PROTOCOL_VERSION`.

**Messages** (RPCs on the duel's `NetSync` node; payloads packed by `NetProtocol`):

| Message | Direction | Mode | Content |
|---|---|---|---|
| hello | guest→host | reliable | protocol version |
| match_start | host→guest | reliable | seed, ship list (id → spec name, tier, customer flags) |
| loaded / go | both | reliable | the countdown handshake |
| input | guest→host | unreliable_ordered, 30 Hz | bit flags: thrust actions, brake, stop_rotation |
| select / done | guest→host | reliable | ship id / — |
| snapshot | host→guest | unreliable_ordered, 20 Hz | tick; per ship: id, x, y, rotation, flags (driver 0/1/2, parked, glowing, firing thrusters bitmask); both scores; time left; lit-space owner per space |
| ship_added / ship_removed | host→guest | reliable | ships appearing at the bay / leaving at the exit |
| event | host→guest | reliable | sound or hint for the guest (park, dent, tip, ready…) |
| match_end | host→guest | reliable | final scores |
| rematch / leave | both | reliable | — |

**New and changed code:**
- **`autoload/Net.gd`:**
  - functions: `host()`, `join(ip)`, `close()`, `is_host()`, `local_ip()`
  - signals: `connected`, `join_failed(reason)`, `rival_left`
  - a **3 s silence watchdog**, plus ENet's `peer_disconnected`
- **`scripts/net/NetProtocol.gd`:** static, pure functions to pack and unpack each payload. Round-trip tested.
- **`scripts/net/SnapshotBuffer.gd`:** keeps recent snapshots and returns the state interpolated at "now − 100 ms". It holds the last snapshot when no newer one has arrived.
- **`ShipPilot`:** `Ship` asks `pilot.is_pressed(action)` instead of calling `Input` directly.
  - The default `LocalPilot` reads `Input`, so offline behaviour is unchanged.
  - `NetPilot` holds the latest remote bit flags.
- **`Valet`** (`scripts/core/Valet.gd`): id, driven ship, score (via ledger), pilot, release time.
  - `Level` holds `valets`. Offline has exactly one, and `driven_ship` and `ledger` remain as shortcuts to valet 0.
  - Parking, Done, dents and exit hand-overs credit the valet driving the ship.
- **`scripts/DuelLevel.gd`** (extends `Level`, used by `Duel.tscn`):
  - **Host mode:** two valets, with valet 1's pilot a `NetPilot`. It handles guest select/done requests, sends snapshots, ship add/remove messages and events, and ends at 3:00 with `match_end`.
  - **Guest mirror mode:** no physics process, spawning or scoring.
    - Ships are built from the ship list and frozen with collisions off, positioned from the `SnapshotBuffer`.
    - Flames, rings and glows come from the flags, and the HUD comes from the snapshot.
    - Local taps send `select`, Done sends `done`, and the buttons stream `input`.
    - Sounds and hints come from events.
- **Screens:**
  - **Lobby:** a new screen.
  - **ModeSelect:** an Online button.
  - **PauseMenu:** online variant.
  - **OnlineResult:** a new screen.
  - **HUD:** a duel score line.

## 5. Errors
| Case | Behaviour |
|---|---|
| Join gets no answer in 5 s | Lobby message: "Cannot reach host. Check that you are on the same Wi-Fi." |
| Version mismatch | Both sides close. Guest: "Your rival has a different version of the game." Host goes back to waiting. |
| Peer disconnects or 3 s silence | "Your rival left the match" → Mode Select |
| Leave match / Leave on the result screen | Send `leave`, close, go to Mode Select. The rival sees "Your rival left the match". |
| Host taps Back while waiting | Close the server, go to Mode Select |

## 6. Testing
- **Unit tests:**
  - NetProtocol round-trips (input, snapshot, ship list)
  - SnapshotBuffer interpolation and holding
  - rammer-pays collision rule
  - duel scoring (starts at 0, can go negative, credit goes to the right valet)
  - Valet refactor keeps offline single-valet behaviour (the whole existing suite stays green)
  - duel lot layout (22 spaces with the right class counts, mirrored, bay and exit present)
  - private-IP filter
- **Loopback integration test:** host and guest in one process on 127.0.0.1 (separate `SceneMultiplayer` roots).
  - The guest connects, both load, the guest's thrust input moves its ship on the host, and the guest's mirror ship follows within tolerance.
  - Both sides see the same scores after a park.
  - Leave triggers `rival_left`.
- **Manual:** PC (windowed) against phone on the user's Wi-Fi, including Wi-Fi off mid-match.

## Out of scope
Internet play beyond the LAN, matchmaking, more than 2 players, spectators, online versions of Levels 1–5,
reconnecting after a drop, and any change to offline rules.
