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
- **Parked** = while you drive a ship that is wholly inside a valid green space and nearly stopped, the space turns orange; pressing Done then parks it and the customer pays. Ships never park by themselves.
- **Space sizes:** light, medium and heavy spaces. A ship can park in a space of its own class or larger, so wasting a big space on a small ship may leave a later heavy ship nowhere to go.
- **Arrivals:** customers arrive in a marked ARRIVALS bay at the entrance, sized for a heavy ship. The next customer only arrives once no part of any ship has been in the bay for 1 second, so move each arrival out to keep the queue flowing. Drifting asteroids block the bay too.
- **Dents:** light bumps are free. Impacts above a safe speed dent the ship and cost pay (more for harder hits).

**Lighting:** every lot is pitch black, like space, including everything beyond its walls. Floodlights light pools of the lot (each level places its own; every parking space sits under one; Level 1's are extra strong; two in every level flicker; each shift, every floodlight takes a random shade between green and blue). Each ship carries a headlight beam (randomly yellow, green, pink or cyan) and a soft glow. Markings the player must always read (parking spaces, radiation zones, the arrival bay, the exit, tier coins, ↩ and the wanted-back glow) ignore the dark and stay fully bright. Walls, the island, wrecks and asteroids show only when lit.

## 5. Level plan
**Shift length** is set by the difficulty chosen on Level Select, the same for every level: Easy 10:00, Normal 5:00 (default), Hard 2:30. Stars use the same earnings targets on every difficulty; the result screen names the difficulty played.

| Level | Goal shown on screen | What is new or harder |
|---|---|---|
| 1 – Starter Lot (tutorial) | "Park 4 ships before the shift ends" | Light and medium ships; one diagonal, one parallel, one perpendicular lane; on-screen hints |
| 2 – Blossom Lot | "Serve 6 customers" | Heavy ships; 10 spaces arranged like flower petals around a round island (3 heavy, 5 medium, 2 light; the 2 nearest the exit are gold spaces ★); **tip tiers** and **retrieval** requests; an EXIT pad on the right |
| 3 – Wreckage Lot | "Serve 7 customers" | Starter Lot layout filled with asteroids and wrecks; **radiation zones** slowly dent ships inside them. 9 spaces (2 heavy D1–D2, gold C1–C2), fixed wrecks and drifting asteroids, radiation dents ₵5 every 2 s inside |
| 4 – Gravity Well Lot | "Serve 7 customers" | A small black hole pulls every ship toward it; **orphaned ships** to eject. 11 rim spaces (3 heavy, 5 medium, 3 light; gold G1–G2 by the exit); its pull grows close in (20 px/s² at 300 px, capped at 80 px/s², weaker than any ship's thrust) and only moves ships you've taken in hand (never parked ones, nor ones resting inside a space); anything reaching the very centre is flung out the far side, spinning (300 px/s); 5 drifting asteroids that the hole also pulls and flings, so flung rocks become the danger; 4 big static boulders in the lanes |
| 5 – Gold Lounge Rush Hour | "Serve 9 customers" | Mostly gold customers; **special requests** ("I want space C2", which is occupied, so move that ship first). A calm lounge with no hazards: 12 sideways spaces in three rows (A1–A3 heavy, B1–B3 light, G1–G6 medium gold by the exit); tiers 60% gold / 30% silver / 10% bronze; an arrival every 6 s; 3 special requests (+₵20 in the named space); parked ships can be picked up and moved |

Ship quirks (saucer, junker) first appear in Levels 3–5.

**Tier cards (from Level 2):** every customer pays the ₵20 park fee. A coin above the ship shows its tier.

| Tier | Chance | Tip |
|---|---|---|
| Bronze | 30% | Patient; a 50% chance of a ₵10 tip |
| Silver (most common) | 50% | Always tips ₵15, minus ₵5 for each dent on their ship |
| Gold | 20% | ₵40 for the first 10 s of waiting, then ₵4 less every 5 s (gone at 60 s). Paid only if the ship is parked in a gold space ★ (the ones nearest the exit). The coin shows the tip still on offer. Only ships that fit a gold space can be gold customers (in Level 2, heavies never are). |

**Waiting** counts from arrival until parked, and again from a retrieval request until the ship is returned.

**Retrieval (from Level 2):**
- **Who:** 2 of the shift's customers want their ship back, 20–40 s after it parks. A request always leaves at least 30 s of the shift to finish it.
- **What you do:** the ship shows ↩ and a pulsing translucent glow around its outline until you pick it up, and can be driven again. Drive it onto the EXIT pad to hand it over.
- **Payment:** the fee is paid at parking. The tip, and the customer counting as served, come at the hand-over.
- **Served:** a customer is served when parked (if they stay) or returned (if they leave). The shift is won when everyone is served.

**Random customers:** a level can draw its customers at random from a pool. Each ship has a **spawn weight** (1 = normal; the Recon Drone is 0.25 and the Nostrom 0.5), and a draw never deals more ships of a class than the lot has spaces for.

**Special requests (Level 5):** 3 customers per shift (never ones who will want their ship back) arrive asking for a named space their ship fits, preferably one that's occupied right now; their badge shows "→ G4" and the space shows a pin. Parking them there pays a +₵20 request bonus on top of their tier tip; parking them anywhere else serves them for the fee only (no tip, no bonus). To make room, the valet can pick up any parked ship in Level 5 and re-park it for free (it's never served twice; a leaver's request timer keeps running).

**Orphaned ships (from Level 4):** an ownerless ship shows a countdown. Ejecting it through the far exit after the countdown pays a removal bonus; ejecting it early costs pay. 2 per shift appear parked in free spaces at random moments between 25% and 60% of the shift, only in spaces the shift's customers can spare. The countdown is 60 s; on time pays +₵25, early costs ₵15. Orphans don't count as served.

## 6. Unlocking rule
- Clearing level n unlocks level n+1. Progress and best stars are saved to `user://save.cfg`.
- **Stars** (by end-of-shift earnings): ★ = cleared; ★★ = earnings above the level's silver target; ★★★ = above the gold target.
- Online results do not affect offline unlocking.

## 7. Offline mode
Solo campaign: the 5 levels above, fully playable in airplane mode.

## 8. Online mode
- **Type:** 1-vs-1 competitive, real-time, same Wi-Fi (Godot High-level Multiplayer, `ENetMultiplayerPeer`). Mode Select → Online opens the Lobby: one phone taps Host and shows its Wi-Fi IP (the Lobby prefers the Wi-Fi address over virtual adapters) ("Hosting on <IP> — waiting for a rival…"); the other types that IP (remembered for next time) and taps Join.
- **Match length:** the host picks 3–20 minutes in 1-minute steps with the − 3:00 + stepper above Host (saved as the next default, 3:00 on first run). The guest is told the host's choice when it connects.
- **Match:** both phones load the symmetric duel lot, the host waits for the guest to load, then both count down 3-2-1. Host = cyan, guest = magenta; a driven ship is ringed in its driver's colour. Highest earnings when the clock runs out wins. Blocking and bumping the rival is allowed. Tiers & tips, darkness and floodlights as offline; no special requests or orphans.
- **Arrival bays:** two shared ARRIVALS bays at the top. Slot N has the same class and tier in both bays (models may differ), seeded so both deliver the same sequence. Each bay delivers a new ship every 10 s; a bay camped by a ship catches up once cleared. Each bay has ceil(minutes×6)+3 slots.
- **Black hole:** a black hole sits just below the bays (Level 4 rules, no asteroids).
- **Parked ships:** parked ships can be picked up and moved (Level 5 rule); only the first park pays.
- **Departure:** every ship leaves 20–30 s after its first park. The parker gets the fee; whoever drives it onto the EXIT gets the tier tip.
- **Blame:** taking the controls of a ship, or knocking an undriven one, marks it as yours. The mark passes along a knock chain and clears when the ship is parked. Driven vs driven: the faster ship pays (brake checks work; reversing into someone faster than you costs you). A knocked ship that hits a rival's driven ship while moving faster than it charges the rammer.
- **Authority:** the host runs all physics, scoring and customer assignment. The guest sends only its button presses and ship/Done requests; the host sends back ship positions, rotations, scores, events and the timer.
- **Rules:** a ship being driven is locked to its driver. Dents are charged by the blame rules above, not simply to the driver.
- **Pause:** online the menu doesn't stop the match; Restart is hidden and Quit becomes "Leave match", which asks "Leave the match?" (Yes / No).
- **Result:** "You win" / "You lose" / "Draw" with both scores. Rematch: when both players have tapped it ("Waiting for rival…" until then), the same pair reloads the lot with the same length and a new seed. Leave goes to Mode Select. Online results never touch offline unlocks or stars.
- **Errors:** 5-second join timeout → "Cannot reach host. Check that you are on the same Wi-Fi."; a different game version (protocol version 3) → "Your rival has a different version of the game." If either player leaves or the link drops (3 s of silence), the other phone shows "Your rival left the match" on Mode Select — from the lot, the countdown or the result screen.

## 9. Screens list
Title → Main Menu (Play, Settings, Credits) → Mode Select (Offline / Online, How to Play, Credits) → Level Select (lock icons) → Game (HUD: goal, shift timer, pay, customers left; lot view and driving view) → Pause (Resume, Restart, Sound on/off, CCTV Off/Light/Medium/Heavy, How to Play, Quit) → Result (earnings, stars, Retry / Next / Menu). Online: Mode Select → Lobby (− 3:00 + match length above Host, IP field, Join, status) → Duel lot (3-2-1 countdown; Pause has Sound, CCTV, How to Play and Leave match) → Online Result (You win / You lose / Draw, Rematch, Leave) → Rematch reloads the duel lot, Leave → Mode Select. How to Play is a six-page guide (Controls, Parking, Customers, Hazards, Online duel, Settings); from Pause it opens over the menu without leaving the level. Every screen has Back; Android back gesture also goes back.

## 10. Art and sound style; asset sources and licenses
- **Art:** bright, cartoony 2D top-down. Ships hand-drawn by the developer in Krita/LibreSprite (original). Asteroids, wrecks and lot props from Kenney space packs (CC0) or original. Parking spaces as pulsing green outlines, sized and labeled L / M / H.
- **Ship art pipeline:** pixel art at half scale (1 art pixel = 2×2 game pixels), nose up, transparent background. Max canvas per class: Light 20×32, Medium 30×50, Heavy 44×80 art px. Three designs per class; each design has its own folder `art/ships/<light|medium|heavy>/<Name>/` with up to four same-size PNGs named after the folder (plus any source file such as `.pdn`):
  - `<name>.png`: base art. Its outline becomes the collision shape and the shape used for parking checks.
  - `<name>_paint.png` (optional): paintable areas in greys, tinted with each customer's random paint colour.
  - `<name>_lights.png` (optional): glowing parts, drawn additively. On while driven, slow blink while waiting, dim when parked.
  - `<name>_thrusters.png`: markers read only by `tools/build_ships.gd`, which writes `resources/ships/<name>.tres`. Red `#FF0000` main engine (Fwd), blue `#0000FF` retro (Back), green `#00FF00` side thruster, yellow `#FFFF00` rotation thruster, magenta `#FF00FF` centre of mass (optional; default = centre of the opaque pixels). Touching same-colour pixels form one thruster. Green and yellow push away from the nearest edge of the outline along their row; green fires the strafe in that push direction; yellow fires the rotation its torque gives. Each class has a force budget per button (and a torque budget for rotation), shared between that button's thrusters by pixel count, so ships stay balanced and quirks come from placement. The build reports quirks and refuses layouts missing Fwd, Back, either strafe or either rotation.
- **App icon:** the Manipulator Drone (orange paint, lights on) scaled up with crisp pixels inside a glowing cyan hexagon on the game's dark navy. `tools/make_app_icon.gd` writes `assets/icon/` (512 px project icon, 192 px Android launcher icon, 432 px adaptive foreground and background); `project.godot` and the Android export preset point at them.
- **Sound:** effects from Kenney's CC0 Sci-Fi, Impact, Interface and Casino packs (thruster loop, soft bump, metal dent / crunch, chip sounds for fees, tips and bonuses, fling, radiation glitch, UI clicks). Music: five ccMixter tracks under CC BY-NC 3.0 (non-commercial use only); "Descent Mind Ascent" loops on menus, the other four play at random in levels. A Pause menu (HUD "II" button, or the back gesture) holds the Sound on/off toggle.
- **CCTV look:** every lot is shown as low-bitrate surveillance footage: a full-screen shader over the world (not the HUD) adds 8×8 blockiness in dark gradients, half-resolution smeared colour, banding in the floodlight falloff and flickering fuzz around sharp edges, plus faint scanlines, a vignette, a blinking "● REC CAM 03" and a ticking timestamp. The Pause menu's CCTV button cycles Off / Light / Medium / Heavy (saved; Medium by default); Off removes the overlay too.
- **Font:** Google Fonts (Open Font License), at least 28 px body text.
- Every non-original asset is listed in `docs/CREDITS.md` and on the Credits screen (Mode Select → Credits) (currently Kenney's Space Shooter Redux, CC0) and the in-game Credits screen.

## 11. Risks and simpler fallbacks
| Risk | Fallback |
|---|---|
| Rotating cockpit camera disorients players | Settings toggle for a fixed (north-up) camera; decide the default from playtest results |
| Too many systems for players to learn | One new system per level; first-time hint popup when each appears |
| Online physics sync between two phones | Host simulates everything; guest only sends inputs. If unstable: remove rival bumping (ships ghost through each other) |
| Drawing many ships takes too long | Start with one ship per class; quirky variants are recolors with different handling numbers |
| Parking detection is unreliable for odd shapes | Check a few sample points on each ship's outline against the space instead of exact shapes |
| Solo workload including the paper | Start the paper's related work and references in Week 3; feature freeze at the start of Week 5 |
