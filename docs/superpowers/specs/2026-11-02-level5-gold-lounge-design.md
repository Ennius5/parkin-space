# Level 5 – Gold Lounge Rush Hour: design

Date: 2026-11-02. Implements GDD §5 Level 5, with decisions made in chat on 2026-11-02.

## Goal

Level 5 is the campaign finale: a calm, luxurious lot where the challenge is the crowd. It has no hazards; Level 4's black hole stays the "boss". It adds:

- **Mostly gold customers.**
- **Faster arrivals.**
- **Special requests:** some customers want a named space, often an occupied one.
- **Moving parked ships:** the player can pick up a parked ship to make room for a request.

Tip tiers, retrieval, the exit pad, the arrival bay, the darkness and floodlights, and shift length set by difficulty all carry over. Levels 1–4 play exactly as before.

## The lot

- **Size and walls:** 2400 × 1400, walled like the other levels. No island.
- **Entrance and exit:** the entrance is at (140, 700), facing right, with the arrival bay. The EXIT pad is at (2260, 700).
- **Spaces:** 12, in three vertical rows. Every space is rotated π/2, so it lies sideways and ships pull in from the lanes between rows.

  | Row | x | Spaces | Class | y centres |
  |---|---|---|---|---|
  | A | 650 | A1–A3 | heavy | 400, 700, 1000 |
  | B | 1150 | B1–B3 | light | 450, 700, 950 |
  | C (nearest the exit) | 1700 | G1–G6 | medium, **gold** ★ | 290, 470, 650, 830, 1010, 1190 |

  The total is 3 heavy, 6 medium and 3 light, with 6 gold. The positions are a starting point; the tests decide.
- **Floodlights:** over each row, the entrance and the exit. Every space centre lies within 75% of some floodlight's radius, which the existing lighting test checks. No space reaches under the HUD (world y ≥ 220).

## Customers

- **Count:** 9, drawn from all 10 ships with their spawn weights, using the usual fair draw.
- **Arrival interval:** 6 s. The bay still waits until it has been clear for 1 s.
- **Tier odds:** Level 5 uses Gold 60%, Silver 30%, Bronze 10%. Levels 2–4 keep the GDD odds of 20 / 50 / 30. The gold-fit rule still applies: only ships that fit a gold space can be gold, so heavies never are.
- **Retrievals:** 2 customers want their ship back, as in Levels 2–4.

## Special requests

- **Who:** 3 of the 9 customers, chosen at random at the start of the shift. They are never customers who want their ship back.
- **Which space:** chosen when the customer arrives, from the spaces their ship fits.
  - Prefer a space that's occupied at that moment, so the player has to make room.
  - If none is occupied, pick any fitting space.
- **Look:**
  - the customer's badge shows "→ G4"
  - the named space shows a small pin marker in that customer's tier colour, for as long as the request is open
  - the first request of the shift shows the hint "Special request: park them in their space"
- **Parking a request customer:**

  | Where they park | What happens |
  |---|---|
  | the named space | they are served, pay the ₵20 fee, and earn a **+₵20 request bonus** plus their usual tier tip (gold pays if it's a gold space) |
  | any other space | they are served and pay the ₵20 fee, but earn **no tip and no bonus** |

- **Closing:** the request closes when the customer first parks, and the pin disappears.

## Moving parked ships

- **Who can do it:** Level 5 only. It's a level setting, off in Levels 1–4.
- **How:** tapping a parked customer ship selects it.
  - It unparks and frees its space as soon as it no longer touches it.
  - Parking it again claims the new space.
- **Re-parking is free:** no fee, no tip and no second serve. The customer was already counted when they first parked.
- **Retrievals:** a ship whose owner will want it back can be moved. Its request countdown keeps running.
- **What can't be moved:** a requested ship (already drivable) and orphans (none in Level 5) are unaffected.

## Stars

The ₵100 base pay plus ₵180 in fees makes ₵280 before tips and bonuses. These targets will be retuned after playtesting:

| Stars | Earnings |
|---|---|
| ★ | cleared |
| ★★ | ₵360 |
| ★★★ | ₵420 |

Request bonuses use the ledger's bonuses and appear in the result screen's existing "Bonuses ₵N" line.

## Unlocking

Clearing Level 4 unlocks Level 5. Level Select shows Level 5 once its scene exists. Level 5 is the last level, so the result screen's Next stays disabled.

## Testing

- **Unit and scene tests:**
  - **Tier odds:** the custom weights produce about 60% gold over many rolls when a gold space fits, and the default odds are unchanged.
  - **Request picks:** exactly 3 request customers, never overlapping retrievals.
  - **Named space:** always fits the ship, and is an occupied fitting space whenever one exists.
  - **Parking a request customer:** in the named space they are served with the fee, +₵20 bonus and tier tip. Elsewhere they are served with the fee, but no tip and no bonus.
  - **Moving parked ships:**
    - only possible when the level allows it
    - frees the space when the ship leaves
    - re-parking costs no fee and doesn't serve twice
    - a moved leaver still gets its retrieval request
  - **Layout:** 12 spaces (3 heavy, 6 medium, 3 light), G1–G6 gold, the exit, every setting, floodlight coverage, and no space under the HUD or overlapping the bay or exit.
  - a Level 5 shift runs headless without errors
  - Level Select: Level 5 exists. Result: Next is disabled after Level 5.
- **Playtests:** desktop, and the user's phone.

## Out of scope

Online play; the pause menu; sound; hazards in Level 5.
