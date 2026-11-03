# Parkin' Space – Playtest Kit (Phase 8)

Everything needed to run one playtest session, following the ITSD 85 Lab handout (Phase 8 and the paper's Ethics section). Print this, or copy Parts 2–4 into a Google Form.

**Target:** at least 5 testers from outside the team, then at least 2 *new* testers for the retest after fixes.
**Time:** 15–20 minutes per tester.
**Data rule:** never write a tester's name, face or phone number in the shared data. Use codes **T1, T2, …** (retest testers continue the numbering, e.g. T6, T7). Names appear only on the paper consent slips, which stay with the developer and never go in the repository (RA 10173, Data Privacy Act of 2012).

---

## 0. Before the session (checklist)

- [ ] Phone 1: fresh install of the playtest APK (or *Settings → Apps → Parkin' Space → Clear data*), charged, sound on, brightness up.
- [ ] Phone 2: same APK, on the **same Wi-Fi** as phone 1, for the online match (played against the developer).
- [ ] Difficulty left at the default (**Normal**, 5:00 shifts).
- [ ] This kit printed (one consent slip + one feedback form per tester), plus the observation sheet.
- [ ] A timer (phone stopwatch) for "time to clear".

## 1. Consent (read and sign before playing)

> I agree to play a test version of the student game *Parkin' Space* for about 15–20 minutes and to answer a short feedback form. I understand that:
> - taking part is voluntary and I can stop at any time without giving a reason;
> - my name will not be recorded with my answers; I will be identified only by a code (e.g. T3);
> - my anonymous answers, and short quotes of what I say while playing, may appear in a student research paper for ITSD 85 at Central Mindanao University;
> - no photos, video of my face, or contact details will be collected.
>
> Tester code: ______ Date: __________
> Signature: ____________________
> If under 18 – parent/guardian name and signature: ____________________

## 2. Procedure (the facilitator follows this exactly)

1. **Brief in one sentence only:** *"Please play as you normally would and say out loud what you are thinking."* Do **not** explain the controls, the goal or the guide – the game must do that. (If they open *How to Play* by themselves, that is fine; note it.)
2. **Play offline:** Mode Select → Offline → Level 1, then Level 2, then Level 3. A level counts as an *attempt* each time it is started; record attempts and the time of the clearing attempt.
3. **Play online:** one duel against the developer on phone 2 (developer hosts, tester joins by typing the IP shown). Match length 3:00.
4. **Observe silently** and fill in the observation sheet. Help only if the tester has been stuck for **more than 2 minutes**, and write "HELPED: <what>" in the sheet.
5. **Hand over the feedback form** right after playing (Part 4).

## 3. Observation sheet (filled in by the developer)

One row per tester per level. Copy into `docs/playtest/data/observations.csv`.

| Tester | Level | Attempts to clear | Cleared? (Y/N) | Time to clear (m:ss) | Where they got stuck or confused | Quotes said out loud | Bugs seen | Helped? |
|---|---|---|---|---|---|---|---|---|
| T1 | 1 | | | | | | | |
| T1 | 2 | | | | | | | |
| T1 | 3 | | | | | | | |
| T1 | Online | – | Win/Lose/Draw | | | | | |

## 4. Player evaluation feedback form (filled in by the tester)

**Tester code:** ______
**Age range:** □ under 18 □ 18–24 □ 25+
**How often do you play mobile games?** □ Daily □ Weekly □ Rarely

### Part A – Rate each statement
1 = Strongly disagree, 2 = Disagree, 3 = Neutral, 4 = Agree, 5 = Strongly agree

| # | Statement | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| 1 | The game was fun to play. | | | | | |
| 2 | I understood the goal of each level without help. | | | | | |
| 3 | The touch controls were easy and responsive. | | | | | |
| 4 | Each level felt a little harder than the last, but fair. | | | | | |
| 5 | Unlocking the next level made me want to keep playing. | | | | | |
| 6 | The win/lose result screen clearly showed how I did. | | | | | |
| 7 | Offline mode worked smoothly. | | | | | |
| 8 | Joining an online match was easy. | | | | | |
| 9 | The online match felt responsive (little or no lag). | | | | | |
| 10 | The graphics were clear and attractive. | | | | | |
| 11 | The sound and music fit the game. | | | | | |
| 12 | Text and buttons were easy to read and tap. | | | | | |
| 13 | The game ran without crashes or freezes. | | | | | |
| 14 | I would play this game again. | | | | | |
| 15 | I would recommend this game to a friend. | | | | | |

### Part B – Open questions
1. What did you like most about the game?
2. What was the most frustrating or confusing moment?
3. Which level was too easy or too hard? Why?
4. Did anything not work as you expected (bugs, glitches)?
5. If you could change one thing, what would it be?
6. Overall rating: ☆ ☆ ☆ ☆ ☆ (1–5 stars)

---

## 5. After all sessions (analysis, Step 8.4)

1. Enter every form into `docs/playtest/data/feedback.csv` (one row per tester) and every observation row into `observations.csv`.
2. Per Likert item: **mean (M), standard deviation (SD), n**. Any item with **M < 3.5** is a problem area.
   Interpretation (handout): 4.20–5.00 strongly agree · 3.40–4.19 agree · 2.60–3.39 neutral · 1.80–2.59 disagree · 1.00–1.79 strongly disagree.
3. Per level: **completion rate** (cleared ÷ tried) and **average attempts**. A level cleared by < 60% of testers, or needing > 4 attempts on average, is probably too hard (Level 5 excepted).
4. Group Part B answers into themes – **controls, difficulty, clarity, bugs, online, art/sound** – and count how many testers mentioned each.
5. Fill the action plan (`docs/playtest/action-plan.md`): fix the highest-severity, most-mentioned issues first (**at least 3 fixes**), then retest with **at least 2 new testers**.
   Severity: **Critical** = crash, lost progress, cannot finish a level · **Major** = confusing goal, unfair difficulty, online fails often · **Minor** = cosmetic, typos, small sound issues.
