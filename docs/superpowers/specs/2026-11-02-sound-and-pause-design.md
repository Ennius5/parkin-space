# Sound, pause menu and credits: design

Date: 2026-11-02. Implements GDD §9 (Pause) and §10 (sound, credits), with decisions made in chat on 2026-11-02.

## Goal

The game gets music, sound effects, a Pause menu with a Sound on/off toggle, and an in-game Credits screen. The look and the rules of play don't change.

## Assets

- **Sound effects:** Kenney's CC0 packs, provided by the user in `D:\SpecialTopics\lab5\audio\Audio`:
  - Sci-Fi Sounds
  - Impact Sounds
  - Interface Sounds
  - Casino Audio

  Only the files used are copied, into `assets/audio/sfx/`.
- **Music:** five ccMixter tracks provided by the user, all **CC BY-NC 3.0**, which allows attribution-only, non-commercial use:

  | Track | Artist | Page | Use |
  |---|---|---|---|
  | Descent Mind Ascent | Mr. Pepino | https://ccmixter.org/files/Mr_Pepino/58734 | menus |
  | Strange | Psykick | https://ccmixter.org/files/Psykick/52703 | levels |
  | Never Stop Rising (Attic Ella Remix) | Attic Ella | https://ccmixter.org/files/Levihica/64389 | levels |
  | squidgy | turkdirty | https://ccmixter.org/files/turkdirty/24695 | levels |
  | just not right | turkdirty | https://ccmixter.org/files/turkdirty/21587 | levels |

  - The tracks are converted with ffmpeg to OGG Vorbis at about 96 kbps (≈20 MB total) and stored in `assets/audio/music/`.
  - The file "Omar Hound (Summer 2024)" is not used.
- **Credits:** `docs/CREDITS.md` lists:
  - the Kenney art pack and the four Kenney audio packs (CC0)
  - each music track with its title, artist, page link and licence
  - a line saying the music's licence forbids commercial use of the game

## The Sound service

- **What it is:** a new autoload, `Sound` (`autoload/Sound.gd`), which owns all playback.
- **Buses:** "Music" and "SFX", both under Master.
- **Mute:** when `GameState.sound_on` is false, the Master bus is muted. Changing the setting takes effect at once and is saved, as `sound_on` already is.
- **Interface:**

  | Function | What it does |
  |---|---|
  | `play(name: String)` | plays a one-shot effect by name; unknown names are ignored with a warning |
  | `start_thruster()` / `stop_thruster()` | one looping thruster sound for the driven ship |
  | `play_menu_music()` | plays "Descent Mind Ascent", looping |
  | `play_level_music()` | plays a random level track; when it ends, the next random one follows, never the same twice in a row |
  | `set_sound_on(on: bool)` | sets GameState, saves, and mutes or unmutes Master |

- **Fades:** switching tracks or scenes fades the music out and in over 0.5 s. A menu screen that already has the menu track playing doesn't restart it.

## Which sound plays when

| Event | Effect name | Kenney file (variants picked at random where several exist) |
|---|---|---|
| Driven ship's thrusters fire | thruster (loop) | `thrusterFire_000` |
| Free bump (cost 0) | bump | `impactSoft_medium_*` |
| Dent under ₵15 | dent | `impactMetal_heavy_*` |
| Dent of ₵15 or more | crash | `explosionCrunch_*` |
| A space turns orange for the driven ship | ready | `tick_*` |
| Done parks a ship | park | `confirmation_*` |
| A fee is paid | fee | `chip-lay-*` |
| A tip above 0 is paid | tip | `chips-stack-*` |
| A bonus is paid (request or orphan) | bonus | `chips-handle-*` |
| A customer arrives | arrive | `bong_001` |
| A customer asks for their ship back | request | `question_*` |
| The black hole flings something | fling | `forceField_*` |
| Radiation dent | radiation | `glitch_*` |
| An orphan appears, or is ejected early | warning | `error_*` |
| A UI button is pressed | click | `click_*` |
| Pause opens / closes | open / close | `open_*` / `close_*` |
| The shift is won | win | `maximize_*` |
| Fired, or time runs out | lose | `lowFrequency_explosion_*` |

- Bump and dent sounds come from the existing `dented` path. A bump with cost 0 now also plays the bump sound, through a new `bumped` signal that the ship emits for impacts below the safe speed.
- The thruster loop plays only for the driven ship, and only while at least one thruster is firing.

## Pause menu

- **Opening:** a "II" pause button in the HUD, at the top right under the timer, sized for a thumb. Android's back gesture also opens Pause during a shift.
- **Behaviour:** opening it pauses the game (`get_tree().paused`) and shows a panel with:
  - Resume
  - Restart: reloads the level
  - Sound: On / Off, which toggles and shows the current state
  - Quit to Level Select
- **Unpausing:** the panel works while paused. Resume, or the back gesture again, unpauses.
- **Shift end:** the menu can't be opened once the shift has ended.

## Credits screen

- A **Credits** button on Mode Select opens a scrollable Credits screen with the same text as `docs/CREDITS.md`, and a Back button.
- The menu music keeps playing.

## Testing

- **Unit and scene tests:**
  - `Sound.play` with a known name starts a player on the SFX bus. An unknown name doesn't crash.
  - `set_sound_on(false)` mutes Master and saves; `true` unmutes it.
  - Level music never repeats the same track twice in a row (a pure `next_track` function with an injected RNG). Menu music is Descent Mind Ascent.
  - Event wiring:
    - parking via Done plays "park" and "fee"
    - a dent plays "dent" or "crash" by cost
    - a fling plays "fling"
    - the driven ship firing starts the thruster loop, and stopping stops it

    These use a recording hook on `Sound`, a list of played names, rather than real audio.
  - Pause:
    - the button pauses the tree
    - Resume unpauses
    - Sound toggles `GameState.sound_on`
    - Restart reloads
    - Quit goes to Level Select
    - it can't open after the shift ends
  - Credits: the screen lists every track's title and licence, and Back returns to Mode Select.
  - The export check and an exported-pack run play without errors (OGG files present).
- **Playtests:** desktop, and the user's phone, judging volumes and mix.

## Out of scope

Separate music and effects volume sliders (only on/off); online play; new art.
