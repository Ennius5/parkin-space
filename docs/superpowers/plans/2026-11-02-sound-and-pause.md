# Sound, Pause Menu and Credits Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add music and sound effects through a `Sound` autoload, a Pause menu with a Sound on/off toggle, and an in-game Credits screen.

**Architecture:**
- **`Sound` autoload:**
  - owns an SFX player pool, one thruster loop player and a music player, on the "Music" and "SFX" buses (created at runtime under Master)
  - mutes Master from `GameState.sound_on`
  - records every effect name in `played: Array[String]`, so tests can assert on the wiring without hearing audio
- **Game code** calls `Sound.play("name")` at the events in the spec's table.
- **Pause:** a new `PauseMenu` CanvasLayer scene added by Level.gd.
- **Credits:** a new screen opened from Mode Select.

**Tech Stack:** Godot 4.7.2, typed GDScript, ffmpeg 9 (at `C:/Users/Ethan Campomanes/AppData/Local/Microsoft/WinGet/Links/ffmpeg.exe`) for music conversion, the project's test runner.

**Spec:** `docs/superpowers/specs/2026-11-02-sound-and-pause-design.md`

## Global Constraints

- **Effect names and source files** are exactly the spec's table. Each name maps to one or more `assets/audio/sfx/<kenney file>.ogg`, and one variant is picked at random.
- **Music:**
  - `assets/audio/music/descent_mind_ascent.ogg` is the menu track
  - the level tracks are `strange.ogg`, `never_stop_rising.ogg`, `squidgy.ogg` and `just_not_right.ogg`
  - converted with `ffmpeg -i <mp3> -vn -c:a libvorbis -q:a 2 <ogg>` (about 96 kbps)
  - the menu track loops, and level tracks advance at random, never repeating the previous one
- **Fades:** 0.5 s.
- **Mute:** `GameState.sound_on == false` ⇒ Master bus muted, set at startup and on every change.
- **Pause copy:**
  - buttons `"Resume"`, `"Restart"`, `"Sound: On"` / `"Sound: Off"`, `"Quit to Level Select"`
  - HUD button text `"II"`, at least 100×100 px
- **Credits:**
  - `docs/CREDITS.md` and the Credits screen list every track as `Title – Artist (ccMixter link), CC BY-NC 3.0`
  - the Kenney packs as CC0
  - the line `"The music is licensed for non-commercial use only."`
- **Assets:** never copy the Omar Hound file. Copy only the sfx files used.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Test command:** `bash .superpowers/sdd/2026-11-01-ship-art-pipeline/t.sh`. Pass = `ALL TESTS PASSED`.

## Review Focus

1. **Sound off at startup:** a saved `sound_on = false` mutes everything from the first frame. Covered by `test_saved_mute_applies_at_start` (Task 1).
2. **Thruster loop leaking:** the loop must stop when the ship is released, parked, despawned or the shift ends. Covered by `test_thruster_stops_when_ship_is_let_go` (Task 3).
3. **Pausing mid-flight:** physics, timers and the thruster loop freeze. Resume continues the shift without losing time. Covered by `test_pause_freezes_the_shift_clock` (Task 4).
4. **The back gesture during a shift opens Pause instead of quitting,** and closes it again. Covered by `test_back_toggles_pause` (Task 4).
5. **Effect spam:** many dents in one frame must not stack dozens of players. The pool has a fixed size (8), and the oldest player is reused. Covered by `test_effect_pool_is_bounded` (Task 1).

---

### Task 1: Assets and the Sound autoload

**Files:**
- Create:
  - `assets/audio/sfx/*.ogg`, the files the spec's table names; for multi-variant names, copy every variant listed in the source folder
  - `assets/audio/music/*.ogg`, the 5 converted tracks
  - `autoload/Sound.gd`
- Modify: `project.godot` (autoload `Sound="*res://autoload/Sound.gd"`, after GameState), `docs/CREDITS.md`
- Test: `tests/test_sound.gd`

**Interfaces:**
- Produces:
  - `Sound` autoload
    - `const EFFECTS: Dictionary`, effect name → `Array[String]` of `res://assets/audio/sfx/...` paths
    - `const MENU_TRACK: String`, `const LEVEL_TRACKS: Array[String]`
    - `const POOL_SIZE := 8`
    - `var played: Array[String]`, every effect name passed to `play`, in order. Tests clear it.
    - `func play(effect: String) -> void`
    - `func start_thruster() -> void`, `func stop_thruster() -> void`, `func thruster_on() -> bool`
    - `func play_menu_music() -> void`, `func play_level_music() -> void`, `func current_track() -> String`
    - `static func next_track(tracks: Array[String], previous: String, rng: RandomNumberGenerator) -> String`
    - `func set_sound_on(on: bool) -> void`, which sets and saves GameState and applies the mute
    - `func apply_mute() -> void`
  - The players use `process_mode = PROCESS_MODE_ALWAYS` for music only, so music keeps playing while paused. The SFX pool and thruster pause with the tree.

- [ ] **Step 1: Copy and convert the assets.**
  - Copy the sfx files from `D:/SpecialTopics/lab5/audio/Audio/`.
  - Convert the 5 tracks from `D:/SpecialTopics/lab5/audio/Music/` with the ffmpeg command in Global Constraints.
  - Run `--import`.
  - Write `docs/CREDITS.md` with the exact credit lines.
- [ ] **Step 2: Write the failing tests** in `tests/test_sound.gd`:
  - `test_every_effect_file_exists`: every path in `Sound.EFFECTS`, `MENU_TRACK` and `LEVEL_TRACKS` passes `ResourceLoader.exists`.
  - `test_play_records_and_uses_the_sfx_bus`: `Sound.played.clear()`, `Sound.play("park")` → `played == ["park"]`, and some pool player has `bus == "SFX"` and a stream.
  - `test_unknown_effect_is_ignored`: `play("nope")` doesn't crash, and `played` doesn't contain it.
  - `test_effect_pool_is_bounded`: 30 `play("dent")` calls → the pool child count is ≤ `POOL_SIZE`.
  - `test_next_track_never_repeats`: 100 calls of `next_track(LEVEL_TRACKS, prev, rng)`, each different from the previous.
  - `test_menu_music_is_descent_mind_ascent`: after `play_menu_music()`, `current_track() == MENU_TRACK`.
  - `test_sound_off_mutes_master`:
    - `set_sound_on(false)` → `AudioServer.is_bus_mute(0)`, and `GameState.sound_on == false`
    - `set_sound_on(true)` → unmuted
    - use the test save path the way `test_ui_flow` does
  - `test_saved_mute_applies_at_start`: set `GameState.sound_on = false`, call `Sound.apply_mute()` → Master is muted, then restore.
- [ ] **Step 3: Run the suite.** Expected: FAIL (no `Sound`).
- [ ] **Step 4: Implement** per the Interfaces block. Create the buses in `_ready` if they're missing.
- [ ] **Step 5: Run the suite.** Expected: `ALL TESTS PASSED`.
- [ ] **Step 6: Commit:** `feat: Sound service with Kenney effects and ccMixter music`.

### Task 2: Music on every screen

**Files:**
- Modify: `scripts/ui/Title.gd`, `ModeSelect.gd`, `LevelSelect.gd`, `Result.gd` (`Sound.play_menu_music()` in `_ready`), `scripts/Level.gd` (`Sound.play_level_music()` in `_ready`)
- Test: `tests/test_sound.gd`

- [ ] **Step 1: Write the failing tests:**
  - `test_level_plays_a_level_track`: instantiate Level 1 (not ending scenes) → `Sound.current_track() in Sound.LEVEL_TRACKS`.
  - `test_level_select_plays_menu_music`: open LevelSelect → `current_track() == MENU_TRACK`.
  - `test_menu_track_isnt_restarted_between_menus`: `play_menu_music()`, note the music player's playback position after a few frames, call `play_menu_music()` again → the same stream, and the position didn't go back to 0.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement. `play_menu_music` returns early when the menu track is already playing.
- [ ] **Step 4:** Run → `ALL TESTS PASSED`.
- [ ] **Step 5: Commit:** `feat: menu and level music`.

### Task 3: Effects at game events

**Files:**
- Modify:
  - `scripts/actors/Ship.gd`: `signal bumped(ship: Ship)`, emitted in `_on_body_entered` when the cost is 0 and the relative speed is above 20 px/s, so resting contacts stay silent. Also thruster start/stop: in `_physics_process`, if `is_driven` and `firing` isn't empty, `Sound.start_thruster()`, else stop.
  - `scripts/actors/Ship.gd` `set_driven(false)`, `set_parked()`, `_exit_tree`: when this ship was driven, `Sound.stop_thruster()`.
  - `scripts/Level.gd`: plays at each event in the spec's table. Fee, tip and bonus play when their ledger call adds money (`fee` for `add_fee`/`serve_customer` with fee > 0, `tip` when the tip is > 0, `bonus` for `add_bonus`). Also "ready" when a space newly turns orange, "win"/"lose" in `end_level`, "arrive" in `spawn_next_customer`, "request", "fling", "radiation" and "warning".
  - `scripts/ui/*.gd`: every Button's `pressed` also plays "click". Add a helper `Sound.wire_clicks(root: Node)` that connects every Button under root.
- Test: `tests/test_sound.gd`, using `Sound.played`.

- [ ] **Step 1: Write the failing tests:**
  - `test_parking_plays_park_and_fee`: Level 1, drive the first ship into A1, `_check_parking`, `Sound.played.clear()`, `_on_done_pressed()` → contains "park" and "fee".
  - `test_space_turning_orange_ticks`: after `_check_parking` with the ship valid → "ready" once. A second `_check_parking` → not again.
  - `test_dent_sounds_by_cost`: `_on_ship_dented(ship, 5)` → "dent". `_on_ship_dented(ship, 20)` → "crash".
  - `test_fling_plays_fling`: hole + rock at the centre → after 2 frames, "fling".
  - `test_thruster_stops_when_ship_is_let_go`: select a ship, press `thrust_forward` (`Input.action_press`), wait 2 physics frames → `Sound.thruster_on()`. Release the action and `release_ship()`, wait 2 frames → off. Repeat with the ship despawned via `_return` → off.
  - `test_buttons_click`: open ModeSelect, `Sound.played.clear()`, emit `%Offline.pressed` → contains "click".
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run → `ALL TESTS PASSED`.
- [ ] **Step 5: Commit:** `feat: sound effects for driving, parking, money and hazards`.

### Task 4: Pause menu

**Files:**
- Create: `scenes/ui/PauseMenu.tscn` + `scripts/ui/PauseMenu.gd`
  - a CanvasLayer (layer 20) with `process_mode = PROCESS_MODE_ALWAYS`
  - a dimmed full-screen ColorRect
  - a centred VBox of buttons: `%Resume`, `%Restart`, `%SoundToggle`, `%Quit`
  - hidden by default
- Modify:
  - `scenes/ui/HUD.tscn` + `HUD.gd`: a `%PauseButton` ("II", 100×100, top right under `%Time`), and `signal pause_pressed`
  - `scripts/Level.gd`: instantiate PauseMenu in `_ready`, connect `hud.pause_pressed` → `open_pause()`. `func open_pause()` does nothing if `_ended`. `func close_pause()`. `_notification(NOTIFICATION_WM_GO_BACK_REQUEST)` toggles pause, and so does `_unhandled_input` with `ui_cancel` on desktop.
  - `project.godot`: `application/config/quit_on_go_back=false`
- Test: `tests/test_pause.gd`

**Interfaces:**
- Produces:
  - `PauseMenu`
    - `signal resume_pressed`, `restart_pressed`, `quit_pressed`
    - `func open()`, `func close()`, `func is_open() -> bool`
    - `func refresh_sound_label()`
  - The sound toggle calls `Sound.set_sound_on(not GameState.sound_on)` and refreshes the label.
  - Level handles restart with `get_tree().reload_current_scene()` after unpausing, and quit with a change to `res://scenes/ui/LevelSelect.tscn` after unpausing. When `change_scene_on_end` is false (tests), it only records `last_pause_action`.

- [ ] **Step 1: Write the failing tests:**
  - `test_pause_button_pauses_the_game`: Level 1, emit HUD `pause_pressed` → `tree.paused`, and the menu is open. Resume → not paused, and the menu is closed.
  - `test_pause_freezes_the_shift_clock`: note `ledger.time_left`, open pause, wait 30 frames → `time_left` unchanged, within 0.001. Resume, wait 30 → it decreased.
  - `test_sound_toggle_in_pause`: open pause, emit `%SoundToggle.pressed` → `GameState.sound_on` flipped and the label reads "Sound: Off" / "Sound: On". Restore afterwards.
  - `test_back_toggles_pause`: `level._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)` → paused. Again → unpaused.
  - `test_no_pause_after_the_shift_ends`: `end_level()`, then `open_pause()` → not paused.
  - `test_restart_and_quit_actions`: with `change_scene_on_end = false`, Restart → `last_pause_action == "restart"` and unpaused. Quit → `"quit"`.
  - Every test must leave `tree.paused = false`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run → `ALL TESTS PASSED`.
- [ ] **Step 5: Commit:** `feat: pause menu with sound toggle`.

### Task 5: Credits screen, GDD, export and playtests

**Files:**
- Create: `scenes/ui/Credits.tscn` + `scripts/ui/Credits.gd` (a ScrollContainer with a Label filled from one `const CREDITS_TEXT` that matches `docs/CREDITS.md`, and `%Back`)
- Modify: `scenes/ui/ModeSelect.tscn` + `ModeSelect.gd` (`%Credits` button above Back), `docs/GDD.md` (§9 Credits screen location, §10 sound sources)
- Test: `tests/test_ui_flow.gd`

- [ ] **Step 1: Write the failing tests:**
  - `test_credits_lists_every_track`: open Credits → the text contains each of the 5 track titles, "CC BY-NC 3.0", "Kenney", and the non-commercial line.
  - `test_mode_select_has_credits`: ModeSelect has `%Credits`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement and update the GDD.
- [ ] **Step 4:** Run → `ALL TESTS PASSED`.
- [ ] **Step 5:** Export check, run the pack headless with no errors, check the APK size, then a desktop run and a phone install (keep a background `adb nodaemon server`).
- [ ] **Step 6: Commit:** `feat: credits screen`.
