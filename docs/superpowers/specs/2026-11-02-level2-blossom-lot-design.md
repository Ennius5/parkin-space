# Level 2 – Blossom Lot: design

Date: 2026-11-02. Implements GDD §5 Level 2 and the GDD tier cards, with decisions made in chat on 2026-11-02.

## Goal

Level 2 is where heavy ships appear. It also adds two systems: **tip tiers** (bronze, silver and gold customers) and **retrieval requests** (some customers come back for their ship, and you drive it out of an exit). Level 1 plays exactly as before.

## The lot

- **Size and walls:** 2400 × 1400, walled like Level 1.
- **Island:** a round island of radius 160 at the centre (1200, 700). It blocks ships.
- **Spaces:** 10 spaces sit in a ring around the island like petals. Each space's centre is 300 px from the island's centre, with its long side pointing at the centre. They are spaced every 36°, starting at 18°, so no space points straight at the entrance or the exit.
- **Space classes:** 3 heavy, 5 medium and 2 light.
- **Gold spaces:** the two mediums nearest the exit, at 18° and 342°, are marked as gold spaces.
- **Entrance and exit:** the entrance is on the left at (140, 700), facing right. A new **exit pad** sits on the right at about (2260, 700). It's drawn on the floor as an "EXIT" gate.
- **Level settings:**

  | Setting | Value |
  |---|---|
  | Goal text | "Serve 6 customers" |
  | Shift | 3:00 |
  | Base pay | ₵100 |
  | Arrival interval | 10 s (heavies need longer to clear the entrance) |

## Customers

- **Pool:** the heavy ships (AgriShip and the heavy_freighter template) plus every Level 1 ship, each keeping its spawn weight. Each shift draws 6 customers, and repeats are allowed (the same draw as Level 1).
- **Fair draws:** the draw never deals a shift that can't be parked. A new pick is only allowed if every ship drawn so far, plus this one, still fits the lot's spaces, counting a bigger space as usable by a smaller ship. The check treats every customer as staying.
  - Example: Level 2 has 3 heavy spaces, so a shift never has more than 3 heavies.
  - The check is general, so a level with no heavy spaces never draws a heavy.
- **Tiers:** each customer gets a tier at spawn:

  | Tier | Chance |
  |---|---|
  | Bronze | 30% |
  | Silver | 50% |
  | Gold | 20% |

  A level setting turns tiers on. Level 1 leaves them off: everyone pays the fee and no tip.
- **Retrieval:** 2 of the 6 customers, chosen at random at the start of the shift, will want their ship back.

## Tips

Every customer still pays the **₵20 park fee when their ship parks**. The tip depends on the tier:

| Tier | Tip |
|---|---|
| Bronze | 50% chance, decided at spawn, of a ₵10 tip |
| Silver | ₵15, minus ₵5 for each dent on that ship during its whole visit (never below 0) |
| Gold | ₵40 for the first 10 s of waiting, then ₵4 less each second (0 at 20 s of waiting). **No tip unless the ship parked in a gold space.** |

- **Waiting** (gold) counts the seconds the customer is waiting on you: from arrival until parked, plus, if they asked for their ship back, from the request until it's returned.
- **When the tip is paid:**
  - A customer who stays is paid their tip when the ship parks.
  - A customer who leaves is paid it when the ship is returned through the exit, so dents made while retrieving still count.
- Tips add to `earned`, like fees. The result screen shows tips as their own line.

## Retrieval

- **When the request comes:** a customer marked for retrieval asks for their ship back 20–40 s after it parks (a random delay). If fewer than 30 s of the shift are left, they ask straight away, so a request never arrives too late to be finished.
- **On a request:**
  - The ship is no longer parked. You can select and drive it again, and its space frees up as soon as the ship has left it.
  - The ship shows a return icon, and the hint "Return it to the EXIT" appears once per shift.
- **Returning the ship:** a requested ship whose centre reaches the exit pad is handed over. It leaves the lot (despawns), any tip owed is paid, and that customer counts as served.
- A ship without a request that drives onto the exit pad: nothing happens.

## Winning

- **Served:** a customer is served when their job is done. That means parked for a customer who stays, and returned for one who leaves.
- **Win:** the shift is won when all 6 customers are served.
- **Losing:** being fired (pay reaches 0) or running out of time works as before.
- **HUD:** shows served / 6.

## What the player sees

- **Tier coin:** each ship in a tiered level shows a small coin in its tier colour beside it. The coin stays upright as the ship turns.
  - A gold coin also shows the tip still on offer, for example "₵32".
  - The ship picker's rows show the same coin colour.
- **Return icon:** a requested ship shows a pulsing ↩ icon.
- **Gold spaces** show a gold star beside their label.
- **Exit pad:** drawn on the floor, labelled EXIT.

## Stars

The fees for 6 customers come to ₵120. The table shows the star targets; they'll be retuned after playtesting:

| Stars | Earnings |
|---|---|
| ★ | cleared |
| ★★ | ₵240 |
| ★★★ | ₵280 |

## Unlocking

Clearing Level 1 already unlocks Level 2. Level Select shows Level 2 once its scene exists; it doesn't say "Coming soon".

## Testing

- **Unit tests** (pure logic):
  - the fair draw (class fit, larger spaces taking smaller ships)
  - each tier's tip, with gold's waiting time and gold-space rule
  - retrieval request timing, including the "fewer than 30 s left" rule
  - the ledger's served and win rules with retrievals
- **Scene tests:**
  - Level 2 loads with 10 spaces (3 heavy, 2 gold), an exit and the correct settings
  - a requested ship returned to the exit despawns, counts as served and pays its tip
  - Level 1 is unchanged: no tiers, no retrievals
- **Desktop playtest:** the user plays a Level 2 shift on desktop.

## Out of scope

Radiation, black holes, orphaned ships and special requests (Levels 3–5); online play; dent visuals.
