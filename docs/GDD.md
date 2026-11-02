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
- **Lot view (ship select):** fixed camera shows the whole lot. Tap near a ship to take control: with one ship within a thumb-sized circle it's selected straight away; with several, a list of them opens beside the finger (paint swatch, name, class), numbered to match badges drawn around the tap, and the player taps the row they want. Waiting ships, retrieval requests and tier cards are shown here.
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
| 2 – Blossom Lot | "Serve 6 customers" | Heavy ships; 10 spaces arranged like flower petals around a round island (3 heavy, 5 medium, 2 light; the 2 nearest the exit are gold spaces ★); **tip tiers** and **retrieval** requests; an EXIT pad on the right | 3:00 |
| 3 – Wreckage Lot | "Serve 7 customers" | Starter Lot layout filled with asteroids and wrecks; **radiation zones** slowly dent ships inside them | 3:00 |
| 4 – Gravity Well Lot | "Serve 7 customers" | A small black hole pulls every ship toward it; **orphaned ships** to eject | 3:30 |
| 5 – Gold Lounge Rush Hour | "Serve 9 customers" | Mostly gold customers; **special requests** ("I want space C2", which is occupied, so move that ship first); everything above | 4:00 |

Ship quirks (saucer, junker) first appear in Levels 3–5.

**Tier cards (from Level 2):** every customer pays the ₵20 park fee. A coin above the ship shows its tier.

| Tier | Chance | Tip |
|---|---|---|
| Bronze | 30% | Patient; a 50% chance of a ₵10 tip |
| Silver (most common) | 50% | Always tips ₵15, minus ₵5 for each dent on their ship |
| Gold | 20% | ₵40 for the first 10 s of waiting, then ₵4 less each second. Paid only if the ship is parked in a gold space ★ (the ones nearest the exit). The coin shows the tip still on offer. |

**Waiting** counts from arrival until parked, and again from a retrieval request until the ship is returned.

**Retrieval (from Level 2):**
- **Who:** 2 of the shift's customers want their ship back, 20–40 s after it parks. A request always leaves at least 30 s of the shift to finish it.
- **What you do:** the ship shows ↩ and can be driven again. Drive it onto the EXIT pad to hand it over.
- **Payment:** the fee is paid at parking. The tip, and the customer counting as served, come at the hand-over.
- **Served:** a customer is served when parked (if they stay) or returned (if they leave). The shift is won when everyone is served.

**Random customers:** a level can draw its customers at random from a pool. Each ship has a **spawn weight** (1 = normal; the Recon Drone is 0.25 and the Nostrom 0.5), and a draw never deals more ships of a class than the lot has spaces for.

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
- **Ship art pipeline:** pixel art at half scale (1 art pixel = 2×2 game pixels), nose up, transparent background. Max canvas per class: Light 20×32, Medium 30×50, Heavy 44×80 art px. Three designs per class; each design has its own folder `art/ships/<light|medium|heavy>/<Name>/` with up to four same-size PNGs named after the folder (plus any source file such as `.pdn`):
  - `<name>.png`: base art. Its outline becomes the collision shape and the shape used for parking checks.
  - `<name>_paint.png` (optional): paintable areas in greys, tinted with each customer's random paint colour.
  - `<name>_lights.png` (optional): glowing parts, drawn additively. On while driven, slow blink while waiting, dim when parked.
  - `<name>_thrusters.png`: markers read only by `tools/build_ships.gd`, which writes `resources/ships/<name>.tres`. Red `#FF0000` main engine (Fwd), blue `#0000FF` retro (Back), green `#00FF00` side thruster, yellow `#FFFF00` rotation thruster, magenta `#FF00FF` centre of mass (optional; default = centre of the opaque pixels). Touching same-colour pixels form one thruster. Green and yellow push away from the nearest edge of the outline along their row; green fires the strafe in that push direction; yellow fires the rotation its torque gives. Each class has a force budget per button (and a torque budget for rotation), shared between that button's thrusters by pixel count, so ships stay balanced and quirks come from placement. The build reports quirks and refuses layouts missing Fwd, Back, either strafe or either rotation.
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
