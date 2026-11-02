# Level 3 – Wreckage Lot: design

Date: 2026-11-02. Implements GDD §5 Level 3, with decisions made in chat on 2026-11-02.

## Goal

Level 3 is Level 1's lot filled with obstacles. It adds two things: **wreckage** (fixed wrecks and drifting asteroids) and **radiation zones** that slowly dent ships inside them. Everything from Level 2 carries over: tip tiers, retrieval, the exit pad and the arrival bay. Levels 1 and 2 play exactly as before.

## The lot

- **Base:** Level 1's lot, 2400 × 1400 and walled, with the same slanted island, entrance at (140, 700) and arrival bay.
- **Exit pad:** on the right at (2260, 700), as in Level 2.
- **Spaces:** Level 1's six keep their positions, classes and rotations:

  | Space | Class |
  |---|---|
  | A1, A2 | medium |
  | B1, B2 | light |
  | C1, C2 | medium, **gold** ★ (nearest the exit) |

  Three spaces are added:

  | Space | Class | Where |
  |---|---|---|
  | D1, D2 | heavy | side by side in the open bottom-left area |
  | E1 | medium | on the right, below the exit pad |

  The total is 9 spaces: 2 light, 5 medium and 2 heavy. The fair draw therefore never deals more than 2 heavies.
- **Level settings:**

  | Setting | Value |
  |---|---|
  | Level number | 3 |
  | Goal text | "Serve 7 customers" |
  | Random customers | 7 |
  | Shift | 3:00 |
  | Base pay | ₵100 |
  | Arrival interval | 10 s |
  | Tiers | on |
  | Retrievals | 2 |
  | Pool | all 10 drawn ships, each with its spawn weight |

## Radiation zones

- **Placement:** 2–3 circular zones sit on tempting shortcuts, such as the gaps between the island and the spaces. No part of a zone overlaps a space, the arrival bay or the exit pad.
- **Look:** a translucent green glow with a soft pulsing edge.
- **Damage:**
  - A ship with any hull point inside a zone takes a **₵5 dent every 2 s** it stays inside.
  - The first dent comes after 2 s of continuous exposure. Leaving a zone resets that ship's timer.
  - A radiation dent works exactly like a bump dent: it costs pay, counts toward the customer's dents (for silver tips) and shows the "-₵5 dent!" hint.
- **First-time hint:** "Radiation! It dents ships inside" shows once per shift, at the first radiation dent.
- **Who is affected:** every ship, whether driven, waiting, parked or requested. Zones are kept off spaces, so a parked ship is only exposed if a space is placed wrongly, and a test guards against that.

## Wreckage

- **Wrecks (3–4):**
  - Kenney ship sprites with a damage overlay, darkened, placed at fixed angles.
  - Static bodies, so they never move.
  - Hitting one hard dents the ship by the usual speed-based rule.
- **Asteroids (about 4 small ones):**
  - Kenney meteor sprites, as rigid bodies that drift slowly. Each starts with a small random velocity and a little spin.
  - Mass is between a light ship's and a medium ship's, so a ship can shove one.
  - A ship that bumps an asteroid at speed dents by the usual rule, using the relative speed.
  - Asteroids bounce off walls, the island and wrecks.
  - An asteroid can drift into a space. The player pushes it out to park there.
- **Arrival bay:** the bay counts as clear only when no ship **and no asteroid** has any point inside it. A customer never spawns on top of a rock.
- **Collision shapes:** traced from each sprite's opaque pixels, so the shape matches what the player sees.
- **Art source:** Kenney *Space Shooter Redux*, CC0.
  - Only the sprites used are copied, into `assets/art/kenney/`.
  - A new `docs/CREDITS.md` lists the pack, its author and the CC0 licence.
  - If the smooth vector style clashes with the pixel-art ships, the sprites are scaled with nearest-neighbour filtering. They can be replaced later without changing the level.

## Stars

The fees for 7 customers come to ₵140. These targets will be retuned after playtesting:

| Stars | Earnings |
|---|---|
| ★ | cleared |
| ★★ | ₵260 |
| ★★★ | ₵300 |

## Unlocking

Clearing Level 2 unlocks Level 3. Level Select shows Level 3 once its scene exists, and Level 4 shows "Coming soon".

## Testing

- **Unit and scene tests:**
  - `RadiationZone.touches(ship)`: true when any hull point is inside, false when the ship is clear
  - radiation exposure: one dent after 2 s inside, none before; the timer resets on leaving; each dent is charged to the ledger and counted on the customer
  - the arrival bay is not clear while an asteroid is inside it
  - Level 3's layout:
    - 9 spaces (2 light, 5 medium, 2 heavy)
    - C1 and C2 gold
    - an exit
    - no zone overlapping any space, the bay or the exit
    - the correct settings
  - a Level 3 shift runs headless without errors
  - Level Select: Level 3 exists and Level 4 shows "Coming soon"
- **Desktop playtest:** the user plays a Level 3 shift on desktop.

## Out of scope

The black hole and orphaned ships (Level 4); special requests (Level 5); online play; dent visuals; sound.
