# Parkin' Space – ITSD 85 Lab 5
Team: Ethan Campomanes (solo developer)   Section: _TBD_   Platform: Android

## About the game
A top-down zero-gravity valet game: park and retrieve spaceships of every shape and size in chaotic space parking lots without denting anything, because damage comes out of your pay. Screenshots: _to be added_.

## How to play
- Tap a ship to drive it. Left buttons: thrust forward/back and strafe left/right. Right buttons: rotate. **Done** returns to the lot view.
- Stop the whole ship inside a green space of its size class (L / M / H) or larger, and hold still for 1 second to park it.
- Light bumps are free; hard hits dent the ship and cost pay. Pay at zero = fired.
- Serve every customer before the shift ends to clear the level and unlock the next one.

## Offline and online modes
Offline: solo campaign, works in airplane mode. Online: _coming in Week 4_.

## How to build
1. Install **Godot 4.7** (standard, not .NET) and open `project.godot`.
2. Editor → Manage Export Templates → Download and Install.
3. Install **OpenJDK 17** and the **Android SDK** command-line tools (see Godot's "Exporting for Android" page), then set both paths in Editor Settings → Export → Android.
4. Project → Export → Add → Android. Unique name `com.itsd85.ecampomanes.parkinspace`, orientation Landscape, permissions Internet and Access Network State.
5. Export Project → `export/parkin-space.apk` and install it on the phone.

Run the automated tests (headless):
```bash
godot --headless --path . --import
godot --headless --path . res://tests/TestRunner.tscn   # last line: ALL TESTS PASSED
```

## Download
_Link to the v1.0 release APK – added at submission._

## Playtest results
_Top 3 findings and fixes – added in Week 5._

## Credits
See [docs/CREDITS.md](docs/CREDITS.md) (_to be added_).

## Paper
[docs/paper.pdf](docs/paper.pdf) (_to be added_).
