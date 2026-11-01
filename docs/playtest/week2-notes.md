# Week 2 playtest notes

**Date:** 2026-11-01
**Build:** `export/parkin-space.apk` (debug, version 0.1), installed with `adb install`
**Device:** Huawei LYA-L29, Android 10
**Tester:** the developer

## Result
The game works well on the phone. It installed, launched to the game with no Godot errors in logcat, and played through.

## Observations
- The layout fits the landscape screen. The HUD, the movement pad and the right-hand buttons are all visible and nothing is cut off.
- A white strip shows on the left edge where the camera notch is. The game does not draw into the cutout yet. Cosmetic only.
- Floating chat bubbles (Messenger chat heads) can cover Stop Spin. That's outside the game; close them while playing.

## Feedback acted on
- "The ships are too simple." Next step: ships become a mass pushed by thrusters placed on the hull, so each ship handles differently (thruster design, option A: each button fires a fixed set of thrusters per ship).
