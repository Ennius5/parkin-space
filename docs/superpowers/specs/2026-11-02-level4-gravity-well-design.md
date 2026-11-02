# Level 4 – Gravity Well Lot: design

Date: 2026-11-02. Implements GDD §5 Level 4 and the GDD's orphaned-ship rule, with decisions made in chat on 2026-11-02.

## Goal

Level 4 adds two systems. A **black hole** at the centre of the lot pulls every ship that isn't parked. **Orphaned ships** appear abandoned in spaces and pay a bonus when ejected at the right time. Everything from Levels 2–3 carries over: tip tiers, retrieval, the exit pad, the arrival bay, the darkness and floodlights, and shift length set by difficulty. Levels 1–3 play exactly as before.

## The lot

- **Size and walls:** 2400 × 1400, walled like the other levels.
- **Entrance and exit:** the entrance is at (140, 700), facing right, with the arrival bay as in every level. The EXIT pad is at (2260, 700).
- **Black hole:** at the centre, (1200, 700).
- **Spaces:** 11 spaces along the walls, facing inwards (rotation 0 on the top row, π on the bottom row), so every route between the entrance, the spaces and the exit curves around the hole.

  | Spaces | Class | Centre |
  |---|---|---|
  | T1, T5 | heavy | (450, 138), (1130, 138) |
  | T2, T4 | medium | (640, 106), (940, 106) |
  | T3, T6 | light | (790, 88), (1300, 88) |
  | U1 | heavy | (450, 1262) |
  | U2 | medium | (640, 1294) |
  | U3 | light | (790, 1312) |
  | G1, G2 | medium, **gold** ★ | (2000, 250), (2000, 1150) |

  The total is 3 heavy, 5 medium and 3 light. The positions are a starting point; tests decide the final layout.
- **Floodlights:** over the top row, the bottom row, each gold space, the entrance and the exit. As in every level, each space's centre lies within 75% of some floodlight's radius.
- **Level settings:**

  | Setting | Value |
  |---|---|
  | Level number | 4 |
  | Goal text | "Serve 7 customers" |
  | Random customers | 7 |
  | Base pay | ₵100 |
  | Arrival interval | 10 s |
  | Tiers | on |
  | Retrievals | 2 |
  | Orphans | 2 |
  | Pool | all 10 drawn ships, each with its spawn weight |

## The black hole

- **Core (revised after review, 2026-11-02):** not solid. A ship whose centre comes within 30 px of the centre is flung out the far side at 450 px/s, the way it was going, spinning at 6 rad/s. A ship that arrives nearly still is thrown in a random direction. A flung ship can't be flung again for 1 s. The fling itself is free; whatever the ship hits next dents as usual.
- **Pull:**
  - Every ship the valet has taken in hand since it arrived or left its space, and that isn't parked, accelerates towards the hole's centre. Untouched ships (waiting arrivals, ships wanted back that haven't been picked up yet, orphans in their spaces) feel no pull. (Revised after review, 2026-11-02.)
  - A ship resting fully inside a free space it fits, or the space holding it, is shielded from the pull, so it can always settle and park.
  - The acceleration is `min(MAX_PULL, PULL_K / d²)`, where d is the distance to the centre in pixels:
    - `PULL_K = 1 800 000`, so the pull is 20 px/s² at 300 px and 2 px/s² at 950 px.
    - `MAX_PULL = 80` px/s², reached at 150 px.
  - The cap is below every ship's forward acceleration (the weakest is a heavy, at 1000 / 6 ≈ 167 px/s²), so the pull is always escapable.
  - The force is applied as `mass × acceleration` at the ship's centre of mass, so it never spins a ship.
- **Parked ships:** they are frozen and unaffected.
- **Asteroids:** 5 drifting asteroids (as in Level 3), immune to the hole: it neither pulls nor flings them.
- **Look:**
  - a black disc with a swirling, glowing accretion ring, plus a faint purple PointLight2D
  - the disc and ring ignore the dark, like the other markers, so the hole is always visible

## Orphaned ships

- **Count:** 2 per shift.
- **When they appear:** each one at its own random moment between 25% and 60% of the shift's length, so the timing scales with difficulty.
- **Where they appear:** parked in a random free space. A space is allowed only if every customer of the shift (all 7, treated as staying) still fits the remaining spaces, using `ParkingRules.fits_lot`. Orphans never make a shift impossible.
  - If no allowed space is free when an orphan is due, it tries again each second.
  - It gives up when the shift ends.
- **Which ship:** a random ship from the pool that fits the chosen space (its class or smaller).
- **Look:**
  - unpainted (a grey tint), with its lights layer hidden
  - a grey badge showing the countdown, starting at "1:00"
  - when the countdown ends, the badge turns green and reads "EJECT ✓"
- **Countdown:** 60 s from the moment the orphan appears.
- **Driving:** tapping an orphan selects it even though it is parked. It unparks and frees its space as soon as it leaves, just like a requested ship.
- **Ejecting:**

  | When its centre reaches the EXIT pad | What happens |
  |---|---|
  | after its countdown | the ship leaves the lot and earns a **+₵25** removal bonus |
  | before its countdown ends | the ship leaves the lot and costs **₵15** of pay |

  - The bonus adds to earnings.
  - The penalty comes off pay, like a dent, and can get the player fired.
- **Served:** orphans don't count towards the 7 served. The shift can be won with orphans still in the lot.
- **First-time hint:** "Orphaned ship! Eject it at the EXIT after its timer", once per shift, when the first orphan appears.
- **Dents:** dents to an orphan cost pay as usual, but they belong to no customer.

## Stars

The fees for 7 customers come to ₵140, and the 2 orphan bonuses add up to ₵50. These targets will be retuned after playtesting:

| Stars | Earnings |
|---|---|
| ★ | cleared |
| ★★ | ₵280 |
| ★★★ | ₵330 |

The result screen shows a "Bonuses ₵N" line when bonuses are above 0.

## Unlocking

Clearing Level 3 unlocks Level 4. Level Select shows Level 4 once its scene exists, and Level 5 shows "Coming soon".

## Testing

- **Unit and scene tests:**
  - **Pull:**
    - pull(d) equals 20 at 300 px and 80 at 150 px or closer, and never exceeds MAX_PULL
    - parked ships get no pull
    - a free ship at rest 400 px away starts moving towards the hole
  - **Core:** a ship can't overlap the core, because a collision body exists at the centre with radius 60
  - **Orphans:**
    - both appear within 25–60% of the shift
    - each sits in an allowed space, and never one that would make the 7 customers unfittable
    - the orphan ship fits its space
    - a parked orphan can be selected
    - the countdown runs for 60 s
    - ejecting after the countdown adds ₵25 to earnings, and ejecting early takes ₵15 off pay
    - ejecting doesn't change served
    - the shift can be won with an orphan still present
  - **Layout:**
    - 11 spaces (3 heavy, 5 medium, 3 light)
    - G1 and G2 gold
    - the hole at (1200, 700)
    - floodlight coverage
    - no space overlapping the core's pull cap zone (150 px) or the bay or the exit
    - the correct settings
  - a Level 4 shift runs headless without errors
  - Level Select: Level 4 exists and Level 5 shows "Coming soon"
- **Playtests:** desktop, and an install on the user's phone.

## Out of scope

Special requests (Level 5); online play; sound.
