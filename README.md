# Parkin' Space – ITSD 85 Lab 5
Team: Ethan Campomanes (solo developer: design, code, art, testing)   Section: BSIT 4C   Platform: Android (landscape)

## About the game
A top-down zero-gravity valet parking game: park and retrieve spaceships of every shape and size in pitch-black space parking lots without denting anything, because damage comes out of your pay. Every ship is a mass pushed by thrusters drawn on its hull, so each one handles differently. Five levels each add one new idea (tips and retrievals, wrecks and radiation, a black hole, a gold-customer rush hour), and a LAN duel lets two phones compete on the same lot. Screenshots: _to be added in `docs/screenshots/`_.

## How to play
- **Lot view:** tap a ship to take control (if several are under your finger, pick one from the list).
- **Driving:** left pad thrusts forward/back and strafes left/right; hold the centre **STOP** to brake. Right buttons rotate; hold **Stop Spin** to stop turning.
- **Parking:** stop the whole ship inside a space of its class (L / M / H) or larger; the space turns orange; press **Done** to park and get paid.
- **Customers:** arrivals wait in the ARRIVALS bay; retrieval requests must be driven onto the EXIT pad. Tip tiers (bronze/silver/gold) pay extra; gold customers only tip in gold ★ spaces.
- **Pay:** light bumps are free, hard hits dent the ship and cost pay. Pay at zero = fired.
- **Levels:** serve every customer before the shift ends to clear a level and unlock the next one. Stars depend on earnings. Progress is saved on the phone.
- **How to Play** (Mode Select or the pause menu) explains every element with pictures.

## Offline and online modes
- **Offline:** the 5-level solo campaign; works fully in airplane mode. Difficulty sets the shift length (Easy 10:00, Normal 5:00, Hard 2:30).
- **Online (same Wi-Fi, no server):** Mode Select → Online. One phone sets the match length (3–20 min) and taps **Host**; its Wi-Fi IP appears. The other phone types that IP and taps **Join**. The host runs the match and decides the winner. If the host can't be reached, or the rival disconnects, the game shows a message and returns to Mode Select.
  - Hosting from a Windows PC on a "Public" Wi-Fi profile: allow Godot through Windows Firewall.

## How to build
1. Install **Godot 4.7** (standard, not .NET) and open `project.godot`.
2. Editor → Manage Export Templates → Download and Install.
3. Install **OpenJDK 17** and the **Android SDK** command-line tools (see Godot's "Exporting for Android" page), then set both paths in Editor Settings → Export → Android.
4. Project → Export → Android preset (`com.itsd85.ecampomanes.parkinspace`, landscape, permissions Internet and Access Network State) → Export Project → `export/parkin-space.apk`.
5. Install on the phone (copy the APK and allow "Install unknown apps", or `adb install -r export/parkin-space.apk`).

Run the automated tests (headless):
```bash
godot --headless --path . --import
godot --headless --path . res://tests/TestRunner.tscn   # summary line: ALL TESTS PASSED
```

## Download
_Link to the v1.0 release APK – added at submission._

## Playtest results
_Top 3 findings and fixes – added after the Week 5 playtest. Kit: [docs/playtest/playtest-kit.md](docs/playtest/playtest-kit.md)._

## Credits
See [docs/CREDITS.md](docs/CREDITS.md) (Kenney CC0 art and sound, ccMixter CC BY-NC 3.0 music, Orbitron SIL OFL font; ships and all other art original).

## Paper
[docs/paper.pdf](docs/paper.pdf) (_in progress – outline in [docs/paper/outline.md](docs/paper/outline.md)_).
