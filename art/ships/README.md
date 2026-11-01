# Ship art guide

Put each design in the folder for its class: `light/`, `medium/` or `heavy/`. Then run the build (see the end of this guide) and the ship appears as `resources/ships/<name>.tres`.

## Canvas

Draw pixel art at **half scale**: one art pixel shows as 2×2 game pixels. Draw the **nose pointing up**, on a **transparent background**, with the canvas cropped tight around the ship.

| Class | Max canvas (art px) |
|---|---|
| Light | 20 × 32 |
| Medium | 30 × 50 |
| Heavy | 44 × 80 |

Designs can be smaller than the maximum and don't need to be symmetrical.

## Layers

All layers are the **same canvas size** and line up exactly. Export each one as its own PNG:

| File | What to draw | Required |
|---|---|---|
| `<name>.png` | The ship. Its outline becomes the collision shape and the shape used for parking checks. | Yes |
| `<name>_paint.png` | Paintable areas in **greys**. White becomes the customer's full paint colour; darker greys become shaded paint. Each customer gets a random colour. | No |
| `<name>_lights.png` | Glowing parts (windows, nav lights, engine glow) in full colour. On while driven, a slow blink while waiting, dim when parked. | No |
| `<name>_thrusters.png` | Thruster markers (below). The build reads this layer; the game never shows it. | Yes |

Example: `light/scout_a.png`, `light/scout_a_paint.png`, `light/scout_a_lights.png`, `light/scout_a_thrusters.png`.

## Thruster markers

Use these exact colours. Touching pixels of the same colour count as one thruster, and a bigger blob gets a bigger share of that button's power.

| Colour | Hex | Thruster | Direction |
|---|---|---|---|
| Red | `#FF0000` | Main engine (Fwd) | Pushes toward the nose |
| Blue | `#0000FF` | Retro (Back) | Pushes toward the tail |
| Green | `#00FF00` | Side thruster (strafe) | Fires out of the nearest edge of the ship on its row, pushing the ship the other way |
| Yellow | `#FFFF00` | Rotation thruster | Fires out of the nearest edge on its row. Rot L or Rot R is chosen from where it sits relative to the centre of mass |
| Magenta | `#FF00FF` | Centre of mass (optional) | Not a thruster. A 2×2 block marks the point where its four pixels meet (the exact centre of an even-sized canvas). Without it, the centre of mass is the middle of the solid pixels |

Every ship needs at least one red, one blue, green on both sides, and yellow that turns both ways. Otherwise the build refuses it and says what's missing.

**Tips:**
- **Side thrusters** (green) close to the centre-of-mass row strafe cleanly. Further away, strafing also turns the ship. The build warns when the turn is strong and names the row to aim for.
- **Rotation thrusters** (yellow) work best far from the centre of mass, near the nose and tail.
- **An off-centre main engine** makes Fwd turn the ship. That's a fine quirk for a junker.
- Any other colour in the thruster layer is ignored, with a warning. Turn off anti-aliasing for this layer.

## Build

From the project folder (the `parkin-space` folder that holds `project.godot`):

```
godot --headless --path . --import
godot --headless --path . -s res://tools/build_ships.gd
```

For each ship it reports the centre of mass in art pixels, each button's force, and any side effects, such as "Left … also turns right". If something blocks a ship, it prints an ERROR and doesn't write that ship.

To use a ship in a level, add its `.tres` to the level's **Customer Queue** in the Inspector.
