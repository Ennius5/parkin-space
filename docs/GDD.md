# Parkin' Space
Team: Ethan Campomanes (solo – pending instructor approval)   Platform: Android   Orientation: landscape

## 1. Pitch (one sentence)
A top-down zero-gravity valet game where the player parks and retrieves spaceships of every shape and size in chaotic space parking lots, without denting anything that comes out of their pay. Motto: "Anything that flies, I can."

## 2. Genre and target players
2D physics/precision puzzle with a comedy tone. Casual mobile players aged 10+; short shifts of 2–4 minutes.

## 3. Core mechanic and touch controls
**Every few seconds:** nudge a drifting ship with short thruster bursts to line it up with a parking space, then stop it inside the space.

**Physics:** zero gravity on a flat plane (`RigidBody2D`, gravity off, no damping). Ships keep drifting and spinning until the pilot brakes.

**Thrusters:** every ship is a mass (with its own centre of mass) pushed by thrusters placed on its hull. Each thruster has a position, a push direction, a force, and the buttons that fire it. A held button fires its thrusters, and each one pushes the ship at its own position. A thruster that isn't lined up with the centre of mass also turns the ship, so each ship's handling comes from its thruster layout. Firing thrusters show a flame.

**Brakes:** STOP and Stop Spin are automatic. STOP brakes at the combined force of the thrusters that point against the drift; Stop Spin uses the combined turning force of the rotation thrusters that turn against the spin, so a ship with weak rotation thrusters is slow to stop spinning as well as slow to start. Both stop the ship cleanly without adding new spin. A ship with weak retro thrusters takes longer to stop from full speed.

**Ship classes** (each class has its own size, mass and parking-space size; ships within a class can have quirks):
| Class | Size / handling | Example ships |
|---|---|---|
| Light | Small, responsive, easy to overshoot | Scout pod (all thrusters lined up: clean and predictable), courier |
| Medium | Balanced | Shuttle (strong main engine, weak retro thrusters, strafing swings the nose slightly), round saucer (spins fast) |
| Heavy | Long and wide, slow to start and stop | Freighter (cargo-heavy tail, weak rotation thrusters, strafing leaves a twist), lopsided junker (drifts to one side) |

**Two modes:**
- **Lot view (ship select):** fixed camera shows the whole lot. Tap a ship to take control. Waiting ships, retrieval requests and tier cards are shown here.
- **Driving:** the camera follows the ship and rotates with its cockpit, so "forward" is always up the screen.

| Input (driving) | Action |
|---|---|
| Left pad: ▲ ▼ ◀ ▶ | Thrust forward / backward, strafe left / right |
| Left pad centre: STOP (hold) | Brake: fire the thrusters that oppose the drift until the ship stops |
| Right: ⟲ ⟳ | Rotate left / right |
| Right: Stop Spin (hold) | Fire the thrusters that oppose the spin until the ship stops spinning |
| Done | Release the ship, return to lot view |
| Pause | Pause menu |

## 4. Goal, win condition, lose condition
- **Pay:** each shift starts with a base salary. Dents and penalties are taken out of it; tips are added on top.
- **Goal:** serve every customer on the level's list before the shift timer ends (park arrivals, return retrieval requests to the exit).
- **Win:** all customers served with pay above zero → result screen with earnings and stars.
- **Lose:** pay reaches zero ("You're fired!"), or the shift ends with customers still waiting.
- **Parked** = the whole ship is inside a valid green space, nearly stopped, for 1 second. The space flashes and the customer pays.
- **Space sizes:** light, medium and heavy spaces. A ship can park in a space of its own class or larger, so wasting a big space on a small ship may leave a later heavy ship nowhere to go.
- **Dents:** light bumps are free. Impacts above a safe speed dent the ship and cost pay (more for harder hits).

## 5. Level plan
| Level | Goal shown on screen | What is new or harder | Shift limit |
|---|---|---|---|
| 1 – Starter Lot (tutorial) | "Park 4 ships before the shift ends" | Light and medium ships; one diagonal, one parallel, one perpendicular lane; on-screen hints | 3:00 |
| 2 – Blossom Lot | "Serve 6 customers" | Heavy ships; spaces arranged like flower petals; **tip tiers** and **retrieval** requests | 3:00 |
| 3 – Wreckage Lot | "Serve 7 customers" | Starter Lot layout filled with asteroids and wrecks; **radiation zones** slowly dent ships inside them | 3:00 |
| 4 – Gravity Well Lot | "Serve 7 customers" | A small black hole pulls every ship toward it; **orphaned ships** to eject | 3:30 |
| 5 – Gold Lounge Rush Hour | "Serve 9 customers" | Mostly gold customers; **special requests** ("I want space C2", which is occupied, so move that ship first); everything above | 4:00 |

Ship quirks (saucer, junker) first appear in Levels 3–5.

**Tier cards (from Level 2):**
- **Bronze:** patient; 50% chance to tip.
- **Silver (most common):** always tips; the tip shrinks with each dent.
- **Gold:** large tip that shrinks quickly after 10 seconds of waiting. Gold customers expect the space nearest the exit.

**Orphaned ships (from Level 4):** an ownerless ship shows a countdown. Ejecting it through the far exit after the countdown pays a removal bonus; ejecting it early costs pay.

## 6. Unlocking rule
- Clearing level n unlocks level n+1. Progress and best stars are saved to `user://save.cfg`.
- **Stars** (by end-of-shift earnings): ★ = cleared; ★★ = earnings above the level's silver target; ★★★ = above the gold target.
- Online results do not affect offline unlocking.

## 7. Offline mode
Solo campaign: the 5 levels above, fully playable in airplane mode.

## 8. Online mode
- **Type:** 1-vs-1 competitive, real-time, same Wi-Fi (Godot High-level Multiplayer, `ENetMultiplayerPeer`). One phone hosts and shows its IP; the other joins.
- **Match:** both players valet in the same lot with a shared customer queue during a 3-minute shift. Highest earnings wins. Blocking and bumping the rival is allowed.
- **Authority:** the host runs all physics, scoring and customer assignment. The guest sends only its button presses; the host sends back ship positions, rotations, scores and timer.
- **Rules:** a ship being driven is locked to its driver. Each player pays for dents to the ship they are driving.
- **Errors:** 5-second join timeout → "Cannot reach host. Check that you are on the same Wi-Fi." If either player leaves → message and return to Mode Select.

## 9. Screens list
Title → Main Menu (Play, Settings, Credits) → Mode Select (Offline / Online) → Level Select (lock icons) → Game (HUD: goal, shift timer, pay, customers left; lot view and driving view) → Pause (Resume, Restart, Sound on/off, Quit) → Result (earnings, stars, Retry / Next / Menu). Online: Lobby (Host, IP field, Join, status) → Online Match → Online Result → Mode Select. Every screen has Back; Android back gesture also goes back.

## 10. Art and sound style; asset sources and licenses
- **Art:** bright, cartoony 2D top-down. Ships hand-drawn by the developer in Krita/LibreSprite (original). Asteroids, wrecks and lot props from Kenney space packs (CC0) or original. Parking spaces as pulsing green outlines, sized and labeled L / M / H.
- **Sound:** jazzy lounge music; thruster puffs, soft bump, crunchy dent, cash-register tip. Effects made in jsfxr/Audacity; music from OpenGameArt (CC0 preferred).
- **Font:** Google Fonts (Open Font License), at least 28 px body text.
- Every non-original asset is listed in `docs/CREDITS.md` and the in-game Credits screen.

## 11. Risks and simpler fallbacks
| Risk | Fallback |
|---|---|
| Rotating cockpit camera disorients players | Settings toggle for a fixed (north-up) camera; decide the default from playtest results |
| Too many systems for players to learn | One new system per level; first-time hint popup when each appears |
| Online physics sync between two phones | Host simulates everything; guest only sends inputs. If unstable: remove rival bumping (ships ghost through each other) |
| Drawing many ships takes too long | Start with one ship per class; quirky variants are recolors with different handling numbers |
| Parking detection is unreliable for odd shapes | Check a few sample points on each ship's outline against the space instead of exact shapes |
| Solo workload including the paper | Start the paper's related work and references in Week 3; feature freeze at the start of Week 5 |
