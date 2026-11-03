# Paper outline – Parkin' Space (IEEE conference format)

Working outline for the ITSD 85 Lab 5 paper (35% of the grade). Requirements from the lab handout:
- **Template and length:** IEEE two-column conference template, 5–7 pages including figures and references; the appendix doesn't count.
- **References:** IEEE numbered style, at least 12, at least 6 from the last 5 years (2021+).
- **Writing rules:** third person, past tense for methods and results.
- **Likert reporting:** each item as M, SD and n.
- **Screenshots:** at most 2 in the body.

Write it in the IEEE template on Overleaf (`IEEEtran`), or in the IEEE Word template. Final file: `ITSD85_Lab5_<Section>_CampomanesE_Paper.pdf`, also saved as `docs/paper.pdf`.

Blanks marked **[DATA]** are filled after the playtest (see `docs/playtest/playtest-kit.md`).

---

## Title
**Design and Player Evaluation of *Parkin' Space*: A Physics-Based Mobile Parking Game with Level Progression and Host-Authoritative Online Multiplayer Built with Open-Source Tools**

Shorter option: *Parkin' Space: Designing and Playtesting a Zero-Gravity Valet Parking Game for Android with Offline and Online Play*

## Author block
Ethan Campomanes, BSIT 4C, College of Information Sciences and Computing, Central Mindanao University, <email>

## Abstract (150–250 words; write last)
Cover these in order:
1. **Problem:** casual mobile games either lack depth or rely on network infrastructure students can't afford.
2. **Concept:** top-down zero-gravity valet parking, where each ship is a mass pushed by thrusters placed on its hull, so ships handle differently.
3. **Build:** Godot 4.7 and GDScript; five levels, each adding one mechanic; an offline campaign; a LAN 1-vs-1 duel with the host deciding everything.
4. **Method:** **[DATA: n]** testers outside the team, a think-aloud session, and the handout's 15-item 5-point Likert form.
5. **Results:** **[DATA: overall M, SD; two strongest and weakest items; completion rate for Levels 1–3]**. Then the three fixes made and the retest outcome.
6. **Conclusion:** one sentence.

## Index Terms
mobile game, level design, physics-based gameplay, multiplayer networking, playtesting, Godot

---

## I. Introduction
- **Motivation:** precision and physics puzzles (parking games, lunar landers) are a lasting casual genre. Zero-gravity drift makes the familiar parking task new: a ship keeps moving until the pilot brakes.
- **Problem:** student teams must deliver a complete game for ₱0 (only free, open-source tools) in 5 weeks, with level progression, offline play and real-time online play on real phones.
- **Research questions** (from the handout):
  - **RQ1:** Does the level-unlocking system motivate players to continue? (Form items 5 and 14, plus per-level completion rates.)
  - **RQ2:** How usable are the offline and online modes on a real phone? (Items 3, 7, 8, 9, 12, 13.)
  - **RQ3:** Which design changes did playtest feedback lead to, and did they improve the retest results?
- **Contributions:**
  1. A thruster-marker pipeline. An artist paints thruster positions in one marker image beside the ship's art, and handling follows automatically within each class's force budget.
  2. A host-authoritative LAN duel for a physics game: snapshots at 20 Hz, inputs at 30 Hz, a 100 ms interpolation delay, and a disconnect watchdog. It uses Godot's built-in ENet with no server.
  3. A playtest evaluation with **[DATA: n]** testers, plus the fixes it drove.

## II. Related Work (6–10 sources, synthesized by theme, not one source after another)
1. **Motivation and difficulty:**
   - Self-determination theory in games: competence, autonomy and relatedness [Ryan et al. 2006]. BANGS, a recent measure of need satisfaction and frustration [Ballou et al. 2024].
   - Flow and the challenge–skill balance [Csikszentmihalyi 1990].
   - Difficulty curves [Rao Fernandes et al. 2022] and dynamic difficulty adjustment [Robb & Zhang 2022].
   - How this game differs: fixed, hand-made levels that each introduce one mechanic, instead of adaptive difficulty. Difficulty modes only change the shift length.
2. **Mobile touch controls:**
   - Virtual buttons perform worse than physical controls because they give no tactile feedback; studies of on-screen gamepad design [Baldauf et al. 2015].
   - Our design response: large hexagonal buttons, automatic STOP and Stop Spin braking, and a lot view where the player taps to pick a ship.
3. **Online multiplayer:**
   - Client–server latency compensation [Bernier 2001]; a recent survey and taxonomy of latency-compensation techniques [Liu, Xu & Claypool 2022].
   - Networked physics: why the host simulates and clients interpolate [Fiedler 2014].
   - Our choice: entity interpolation (rendering 100 ms in the past) with no client-side prediction, which is acceptable on a LAN.
4. **Engines:** Godot's growing role in indie development [Holfeld 2023]; Godot's high-level multiplayer API [Godot docs].
5. **Playtesting methods:**
   - Games user research methods [Desurvire & El-Nasr 2013; Drachen et al. 2018].
   - The think-aloud protocol and its newer Play Aloud variant [Pellicone et al. 2022].
   - Analysing Likert data [Boone & Boone 2012].

## III. Game Design
- **Core loop:**
  - Arrivals appear in the bay. The player taps a ship, drives it with thrusters into a space of its class or larger (the space turns orange), and presses Done to park it.
  - Retrieval requests send ships back to the EXIT pad.
  - Pay starts at a base salary. Dents and penalties are subtracted, and fees and tips are added.
- **Win/lose:**
  - Win: serve every customer before the shift ends, with pay above zero.
  - Lose: pay reaches zero ("You're fired!"), or the shift ends with customers still waiting.
  - **Stars** are based on earnings against the level's silver and gold targets.
- **Ships:** 10 original ships in 3 classes (4 light, 3 medium, 3 heavy). Handling comes from thruster placement (Section IV).
- **Table I – Level plan** (from GDD §5):

  | Level | Goal on screen | New element |
  |---|---|---|
  | 1 Starter Lot | Park 4 ships | Basic driving; three lane angles; hints |
  | 2 Blossom Lot | Serve 6 customers | Heavy ships, tip tiers, retrievals, EXIT |
  | 3 Wreckage Lot | Serve 7 customers | Wrecks, drifting asteroids, radiation zones |
  | 4 Gravity Well | Serve 7 customers | Black hole pull and fling, orphaned ships |
  | 5 Gold Lounge | Serve 9 customers | 60% gold customers, special requests, moving parked ships |

- **Difficulty:** Easy 10:00, Normal 5:00, Hard 2:30 per shift.
- **Unlocking:** clearing level *n* unlocks *n*+1. Online results don't affect offline unlocking.
- **Offline mode:** the solo campaign, fully playable in airplane mode.
- **Online mode:** a LAN 1-vs-1 duel on a symmetric lot.
  - Two seeded arrival bays deal the same class and tier in matching slots.
  - Every ship leaves 20–30 s after it is first parked. The fee goes to whoever parked it, the tip to whoever delivers it to the EXIT.
  - Dent blame follows the last player to control a ship; when two driven ships collide, the faster one pays.
  - The host picks the match length, 3–20 min.
- **Fig. 1 – Screen flow:** Title → Mode Select (Offline / Online / How to Play / Credits) → Level Select or Lobby → Level / Duel → Result / Online Result. Include the pause menu and the connection-error branch back to Mode Select. Draw it in draw.io and make sure it reads in black and white.

## IV. Implementation
- **Tools:**
  - Godot 4.7.2 (MIT license), GDScript with static types, Compatibility renderer, landscape orientation.
  - Git and GitHub; Android export with OpenJDK 17 and the Android SDK.
  - Art drawn in Paint.NET; audio from Kenney (CC0) and ccMixter (CC BY-NC 3.0); Orbitron font (SIL OFL).
- **Structure:**
  - Three autoloads: `GameState` (progress and settings), `Sound`, and `Net` (`NetSession`).
  - A shared `Level` base script, with `DuelLevel` for online play.
  - Small components: `ShipPilot` / `LocalPilot` / `NetPilot`, `ParkingRules`, `ShiftLedger`, `Customer`, `ParkTracker`.
  - About 6,900 lines of GDScript outside tests, checked by **33 automated test files (437 tests)** that run headless.
  - **Fig. 2 – Architecture** diagram: autoloads, the level scene, and the host and guest sides of a duel.
- **Thruster pipeline:**
  - Next to each ship's PNG, a marker PNG paints its thrusters by colour: red = forward, blue = retro, green = side, yellow = rotation, magenta = centre of mass.
  - `tools/build_ships.gd` turns these into a `ShipSpec` resource. Each class has a force budget per button, shared among that button's thrusters by pixel count.
  - Off-centre thrusters produce torque, so each ship's quirks come from where its thrusters are drawn.
- **Save and unlock:** progress lives in `user://save.cfg` (Godot `ConfigFile`) in the app's private storage. Listing 1 (from `autoload/GameState.gd`, 12 lines):
  ```gdscript
  func is_unlocked(level: int) -> bool:
      return level <= unlocked_level

  func complete_level(level: int, stars: int) -> void:
      best_stars[level] = maxi(stars, best_stars.get(level, 0))
      if level == unlocked_level and level < TOTAL_LEVELS:
          unlocked_level = level + 1
      save_progress()

  func save_progress() -> void:
      var cfg := ConfigFile.new()
      cfg.set_value("progress", "unlocked_level", unlocked_level)
      cfg.set_value("progress", "best_stars", best_stars)
      cfg.save(save_path)   # user://save.cfg
  ```
- **Networking:**
  - Transport: `ENetMultiplayerPeer` on port 24557, Option A from the handout (same Wi-Fi, no server).
  - **The host is authoritative:** it runs all physics, scoring and the timer.
  - The guest sends input bits at 30 Hz. The host sends state snapshots at 20 Hz.
  - The guest's ships are frozen mirrors, drawn 100 ms in the past by interpolating between snapshots.
  - A protocol version check runs in the handshake.
  - A silence watchdog ends the match after 3 s with no messages (10 s while a scene loads).
  - **The winner is decided by the host** and sent to both phones.
- **Phone build:**
  - Debug-signed APK, about 84 MB.
  - Tested on a Huawei LYA-L29 (Android 10) and **[DATA: phone 2]**; see the phone test matrix.

## V. Evaluation Method
- **Participants:** **[DATA]** n testers from outside the team. **Table II** gives their profile: age range and how often they play mobile games.
- **Procedure:**
  - A one-sentence think-aloud brief, with no explanation of controls or goal.
  - Levels 1–3 offline, then one 3-minute online duel against the developer.
  - The developer observed silently and helped only after 2 minutes stuck, recording any help.
- **Instrument:** the handout's 15-item, 5-point Likert form plus 6 open questions; an observation sheet recording attempts, time to clear, sticking points, quotes and bugs.
- **Analysis:**
  - M and SD for each item, interpreted with the handout's bands.
  - Completion rate and mean attempts per level.
  - Open answers coded into themes: controls, difficulty, clarity, bugs, online, art/sound.
- **Ethics:**
  - Written consent from every tester; parental consent for anyone under 18.
  - Testers identified only by codes T1…Tn; no names, faces or phone numbers collected, in line with RA 10173.
  - All responses reported, including negative ones.

## VI. Results
- **Table III:** M, SD and n for all 15 items. **[DATA]**
- **Fig. 3:** completion rate per level, as a bar chart readable in black and white. **[DATA]**
- **Themes:** counts per theme, with short quotes tagged by tester code (e.g. T3). **[DATA]**
- **Table IV, the action plan:** issue, number of reporters, severity, fix and commit, retest result, with at least 3 fixes and at least 2 new retest testers. **[DATA]**

## VII. Discussion
- Answer RQ1–RQ3 with the numbers above.
- Compare with related work. For example, whether a curve of one new mechanic per level was rated fair (item 4) against the difficulty-curve literature; and whether 100 ms interpolation felt responsive on a LAN (item 9) against latency-compensation findings.
- **Limitations:**
  - A small sample of classmates as testers.
  - One platform (Android) and two phone models.
  - A single developer.
  - LAN-only online play (no internet matchmaking or Nakama).
  - A short session, which can't show long-term motivation.

## VIII. Conclusion and Future Work
- **Conclusion:** the main finding in two sentences.
- **Future work:**
  - Internet play through Nakama (Option B).
  - Client-side prediction for the guest.
  - An accessibility pass (a colour-blind-safe palette for the neon cues).
  - A larger study over several sessions.

## Acknowledgment
- The instructor, Rinante M. Buntod.
- The playtesters (by code only).
- The AI tools used and what for, which the handout requires. State plainly that Claude (Anthropic) was used as a coding assistant in Claude Code, and say what for (e.g. implementation help, tests, documentation drafting), plus any help with the paper itself.

---

## References (candidates)
Check every entry's details in Zotero against the publisher page before citing. Entries marked † are recent (2021 or later; 7 of them, so the "at least 6 recent" rule is met). Entries marked (verify) had details I couldn't fully confirm.

1. R. M. Ryan, C. S. Rigby, and A. Przybylski, "The motivational pull of video games: A self-determination theory approach," *Motivation and Emotion*, vol. 30, no. 4, pp. 347–363, 2006.
2. † N. Ballou, A. Denisova, R. M. Ryan, C. S. Rigby, and S. Deterding, "The Basic Needs in Games Scale (BANGS): A new tool for investigating positive and negative video game experiences," *Computers in Human Behavior*, vol. 144, Art. 107158, 2023/2024 (verify year).
3. M. Csikszentmihalyi, *Flow: The Psychology of Optimal Experience*. New York: Harper & Row, 1990.
4. † S. Rao Fernandes et al., "Difficulty pacing impact on player motivation," 2022 (HAL hal-03847459; verify venue, likely ICEC 2022).
5. † J. Robb and J. Zhang, "Performance-based dynamic difficulty adjustment and player experience in a 2D digital game: A controlled experiment," *Acta Ludologica*, vol. 5, no. 1, 2022 (verify authors and pages).
6. † S. Liu, X. Xu, and M. Claypool, "A survey and taxonomy of latency compensation techniques for network computer games," *ACM Computing Surveys*, vol. 54, no. 11s, Art. 243, 2022, doi: 10.1145/3519023.
7. Y. W. Bernier, "Latency compensating methods in client/server in-game protocol design and optimization," in *Proc. Game Developers Conference*, 2001.
8. G. Fiedler, "Networked physics," *Gaffer On Games*, 2014–2015. [Online]. (Web source; check the exact article title and URL.)
9. † C. Holfeld, "On the relevance of the Godot Engine in the indie game development industry," arXiv:2401.01909, 2023/2024.
10. Godot Engine contributors, "High-level multiplayer," *Godot Engine documentation* (4.x). [Online]. Accessed: <date>.
11. H. Desurvire and M. Seif El-Nasr, "Methods for game user research: Studying player behavior to enhance game design," *IEEE Computer Graphics and Applications*, vol. 33, no. 4, pp. 82–87, 2013.
12. A. Drachen, P. Mirza-Babaei, and L. Nacke, Eds., *Games User Research*. Oxford: Oxford Univ. Press, 2018.
13. † B. Pellicone et al., "Playing aloud: Leveraging game commentary culture for playtesting," 2022 (IGI Global journal article 296705; verify journal and authors).
14. M. Baldauf, P. Fröhlich, F. Adegeye, and S. Suette, "Investigating on-screen gamepad designs for smartphone-controlled video games," *ACM Trans. Multimedia Comput. Commun. Appl.*, vol. 12, no. 1s, 2015 (verify).
15. H. N. Boone and D. A. Boone, "Analyzing Likert data," *Journal of Extension*, vol. 50, no. 2, 2012.
16. † M. Smeddinck et al., "Enemy within: Long-term motivation effects of deep player behavior models for dynamic difficulty adjustment," CHI 2020/2022? (verify year and venue; drop it if it isn't 2021+ or doesn't check out).
17. J. Schell, *The Art of Game Design: A Book of Lenses*, 3rd ed. Boca Raton, FL: CRC Press, 2019.

## Appendix (doesn't count toward the page limit)
- A: the GDD (`docs/GDD.md`)
- B: anonymized feedback forms and observation sheets (`docs/playtest/data/*.csv`)
- C: the phone test matrix
- D: the action plan (`docs/playtest/action-plan.md`)
- E: answers to the guide questions (drafts below)
- F: links to the repository, the v1.0 release and the demo video

### E. Guide-question answers (drafts)
1. **How does the unlocking system decide which levels are open, and where is it stored?**
   - `GameState` keeps `unlocked_level`, the highest level the player may open. A level is open when its number is ≤ `unlocked_level` (`is_unlocked`).
   - Clearing level *n* while *n* is the frontier raises `unlocked_level` to *n*+1. Best stars are kept per level.
   - Both are written immediately to `user://save.cfg` (a Godot `ConfigFile` in the app's private storage on the phone), so progress survives a force-close.
2. **What happens if the connection drops mid-match?**
   - Each phone runs a silence watchdog. If nothing arrives from the rival for 3 s (10 s while a scene is loading), the session closes.
   - The match ends with "Your rival left the match" and returns to Mode Select. The game doesn't crash or freeze.
   - A guest that can't reach the host within the join timeout sees "Cannot reach host. Check that you are on the same Wi-Fi." A version mismatch is reported in the handshake.
3. **Why should the host decide the winner?**
   - If each phone judged its own result, latency and differences in physics between the phones would make them disagree.
   - A modified client could also report a fake score.
   - The host runs the only authoritative simulation. The guest just sends inputs and draws snapshots, so there is exactly one truth, and the host announces the result to both phones.
4. **Most surprising playtest finding:** **[DATA]**
5. **Lowest-scoring statement, and what one more week would buy:** **[DATA]**
6. **Android vs iOS:**
   - Android needed only a Windows PC, the free Android SDK and a debug keystore.
   - APKs could be sideloaded onto any number of test phones, and `adb install` gave a fast loop for installing and playtesting.
   - iOS would have needed a Mac, Xcode and 7-day re-signing with a free Apple ID.
   - The cost of Android: different screen sizes and cutouts (the camera notch area) to test, and a "public network" firewall prompt when hosting from a Windows PC.
