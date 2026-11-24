# K-Banana: Development Log

A record of how K-Banana was built, the decisions made along the way, and what was left for later.

**Period:** 3 October to 21 November 2026 (seven weeks), developed solo.

**How this log was compiled.** Individual milestone dates were not recorded while the work was happening, so the first four phases below are a reconstruction, grouped by the stages in the project report, and carry no day-by-day dates. The final cleanup phase happened on 20 and 21 November and is dated. Issues found along the way are in [BUGS.md](BUGS.md) and are referred to here by ID.

## Timeline

|         Phase        |        When       |                                       Focus                                     |
| -------------------- | ----------------- | ------------------------------------------------------------------------------- |
| 1. Foundations       | Early October     | Project setup, dictionary, core game logic, deterministic challenges            |
| 2. Screens           | Mid-October       | Home, gameplay and results flows, theme, reusable widgets, navigation           |
| 3. Data and services | Late October      | Date and definition APIs, encrypted database, statistics, device lock           |
| 4. Polish            | November          | Audio, app lifecycle, accessibility, automated tests, device testing, packaging |
| 5. Final cleanup     | 20 to 21 November | Tidying, extra tests, robustness fixes, documentation                           |

---

## Phase 1: Foundations (early October)

**Built**
- Flutter project setup and the first version of the folder structure.
- Dictionary loading from `assets/words.txt`, a list of about 25,000 common English words.
- The rule types (contains, excludes, starts with, ends with), the game session and the scoring formula.
- A deterministic random generator, so that a given date always produces the same puzzle.

**Decisions**
- Keep the game logic in plain Dart, with no Flutter dependencies. Scoring, rules and date logic can then be tested without any user interface.
- Use a small seeded generator, not Dart's `Random`, so that the puzzle for a date is identical on every device.
- A rule is only used if at least 100 dictionary words satisfy it, and a validated fallback rule exists, so no round is unwinnable.

**Issues** BUG-01 (consecutive dates gave almost the same first rule) was found and fixed here. BUG-02 (repeated rules) was guarded here.

## Phase 2: Screens (mid-October)

**Built**
- The home, gameplay and results screens, the visual theme and the reusable widgets (stat tile, rule card).
- Navigation. It is deliberately flat: the home screen offers the daily challenge, practice and statistics directly, to keep a quick-play game simple.

**Decisions**
- **Seven rounds, not ten.** The first concept was a ten-round game. Play showed ten high-pressure rounds in a row were tiring, so the game was cut to seven. The longest game is about 70 seconds of round time.
- **No feedback during play.** The screen does not say whether a word was right until the results screen, which keeps the pace up and avoids a distraction between rounds.
- **A neutral "word captured" cue** that looks the same for every word.
- **Visual identity:** banana yellow, cream and dark brown, with the Nunito typeface and rounded cards.

**Issues** BUG-04, BUG-05, BUG-06 and BUG-07 (submission race, lost last keystroke, keyboard flicker and pasted words) came out of the work on countdown, keyboard and round transitions. This was the most demanding part of the project.

## Phase 3: Data and services (late October)

**Built**
- The UTC date service (timeapi.io) with a two-second timeout and a fallback to the device clock.
- The definition service (dictionaryapi.dev) with HTTPS, a timeout, response checks and session caching.
- The local encrypted database, statistics, history and streak calculation.
- The device-authentication gate.

**Decisions**
- **SQLite with SQLCipher, no cloud backend.** Structured local records without an account system or a server, with encryption at rest.
- **The passphrase is generated, not hard-coded.** A random 32-byte value is created on first launch and kept in the Android Keystore through `flutter_secure_storage`.
- **Only finished daily games are saved.** Practice games never touch the database.
- **The online leaderboard was dropped.** Suitable free backend options were limited, and reliable offline play mattered more than a global ranking.
- **Use the system authentication prompt.** It includes the device PIN, pattern or password as a fallback, so a failed fingerprint never locks a player out. If the device has no screen lock, the app opens and tells the player the lock is off, and does not imply the history is protected.

**Issues** BUG-03 (daily game played twice), BUG-08 (failed time request) and BUG-09 (failed definition lookup) were handled here.

## Phase 4: Polish (November)

**Built**
- Audio: separate players for the opening jingle, the looping ambience, gameplay cues and result jingles, so each can be controlled independently.
- App lifecycle handling for audio.
- Accessibility: screen reader labels, live regions announcing round changes and the time at 5 and 3 seconds, results shown as icon and text, and large touch targets.
- The reduced-motion setting on the home logo.
- The automated test suite, and testing on a physical Samsung Android phone. Two other people also tried the game.
- Launcher icon and release packaging.

**Decisions**
- Result validity is shown as text and an icon, never by colour alone.
- Separate audio players so overlapping sounds (ticks, heartbeats and the ambience) do not cut each other off.

## Phase 5: Final cleanup (20 to 21 November)

The last two days were spent preparing the project for submission. An AI assistant helped review the code and draft tests and documents (see "Use of AI" below). All decisions below were made by the author.

**Removed**
- 16 files that were unused or empty, and the empty `game/demon/` and `state/` folders.
- The unused length rule (`ConstraintLength`) and its tests.
- Two sound files the app never played, the `words/` placeholder folder, the unused `cupertino_icons` package, and the bundling of the launcher icon into the app.

**Reorganised**
- The `test/` folder was restructured to mirror `lib/`.
- The date service moved from `game/` to `services/`, because it makes a network call.
- The timer bar and definition sheet were extracted from large screen files into `widgets/`.
- The Python tooling moved to a root `tools/` folder.

**Tests added or rewritten**
- Combined rules, game-session edge cases, scoring formulas, the seeded generator (with pinned outputs), the challenge generator, the dictionary (including a check of the real word list and of every day in the next year), the biometric service, the lock gate, the date service (rewritten with a fake client) and the database error classifier.
- The suite grew to 15 test files, and all pass under `flutter test` with no issues from `flutter analyze`.

**Robustness changes**
- **Database recovery made selective** (BUG-10). The database is recreated only when it cannot be decrypted or is corrupt. Any other error is rethrown, so a temporary failure cannot erase a player's history.
- **The clock now pauses when the app is not in the foreground** (BUG-11), and a deferred ambience start now happens on return (BUG-12).
- **Reduced motion extended** to the intro, the key press and the in-game animations (BUG-13).
- **A hint line made flexible** so it cannot overflow at large font sizes (BUG-14).
- **Quit dialog clock handling fixed between rounds** (BUG-17), so opening the quit dialog during the short pause between rounds defers starting the next round's clock until "Keep playing" is chosen.
- **Countdown duration preserved under "remove animations"** (BUG-18), using `AnimationBehavior.preserve` so reduced motion does not speed up the round timer.
- **Android backup turned off**, so an encrypted database is never restored without its key.
- **The time-service timeout was cut to two seconds**, so a stalled service delays the daily game by at most about two seconds (BUG-19).

**Features added**
- A **mute button** on the home screen. It sets every sound to volume 0 and back to its default, and does not stop the sounds, so timing and playback logic are untouched.

**Checks**
- `flutter analyze` and `flutter test` pass.
- Max-font-size layout check and device checks of the database recovery, the lifecycle behaviour and the mute button on the test phone.

---

## Decisions at a glance

- **Seven rounds**
  - **Alternatives considered:** Ten rounds
  - **Reason:** Ten consecutive timed rounds were tiring

- **No leaderboard**
  - **Alternatives considered:** Online global ranking
  - **Reason:** No suitable free backend, and offline reliability mattered more

- **Local encrypted database**
  - **Alternatives considered:** Plain SQLite, or a cloud service
  - **Reason:** Privacy, no accounts, no server to run

- **Seeded generator with a ten-draw warm-up**
  - **Alternatives considered:** Dart's `Random`, or no warm-up
  - **Reason:** Same puzzle for everyone, and different first rules on consecutive days

- **Pause the clock when the app is not in the foreground**
  - **Alternatives considered:** Keep it running in real time
  - **Reason:** A call or screen lock should not cost a round in a once-a-day game, and the quit dialog already paused it

- **Selective database recovery**
  - **Alternatives considered:** Delete on any error
  - **Reason:** Ordinary errors must not destroy history

- **Mute by setting volume to 0**
  - **Alternatives considered:** Stopping and restarting the players
  - **Reason:** No change to timing, completion callbacks or lifecycle code

- **Android backup off**
  - **Alternatives considered:** Allow backup
  - **Reason:** The database is unreadable without its Keystore key

- **Word list used as published**
  - **Alternatives considered:** Filtering the list
  - **Reason:** A decision for this version, recorded as LIM-05 in BUGS.md

## Testing summary

- **Automated:** 15 test files covering date formatting, dictionary loading and validation, streaks, challenge generation, constraints, game sessions, scoring, seeded randomness, API parsing, the biometric service, the lock gate, reduced motion and database error classification.
- **Manual:** one physical Samsung Android phone, covering gameplay, the lock, the database, interruptions, audio, large fonts and reduced motion. No emulator or other devices.
- **Not automated:** the database SQL (it needs native SQLCipher), audio playback and most screens.

## Use of AI

ChatGPT, Claude and Gemini were used as learning and productivity aids throughout development, as acknowledged in the project report. Assistance covered explaining Dart syntax and Flutter/plugin APIs; reviewing the codebase and drafting improvements (including countdown lifecycle handling, selective database recovery, reduced-motion helpers and mute controls); drafting substantial portions of the 15 automated test files from author-specified scenarios; and structuring `README.md`, [BUGS.md](BUGS.md) and `DEVLOG.md` from developer-supplied information. In addition, ChatGPT image generation (DALL-E) was used to produce final visual assets from the author's sketches and descriptions, and ElevenLabs was used to generate sound effects.

The project concept, feature scope, requirements and final design decisions remained the author's responsibility. All AI-suggested code and tests were manually reviewed against real package APIs, checked with `flutter analyze` and `flutter test`, and verified on a physical Android phone, treating AI output as a proposal to evaluate rather than proof that a feature worked. Where an AI review surfaced an issue, [BUGS.md](BUGS.md) records it as found by an "AI-assisted code review".

## Lessons learned

- Separating game logic from the screens made the rules, scoring and date logic easy to test, and kept the awkward asynchronous parts (clock, keyboard, audio, navigation) in one place.
- A plausible answer is not evidence that something works. Package behaviour and lifecycle behaviour needed checking on a real phone.
- Defaults matter: a catch-all error handler that was meant to help (BUG-10) was the biggest risk in the project.
- Recording issues as they happen would have saved time at the end. Dates and an incident log were reconstructed.

## Future work

**Robustness**
- Handle an unreadable secure-storage key (OPEN-01), and show a start-up error screen instead of a blank screen if the database cannot open.
- Make the empty-word guard part of the rule classes (OPEN-02).
- Tidy the opening volume constant and the unused audio methods (OPEN-03, OPEN-04).
- Reuse the date already fetched on the home screen when starting a daily game, if it is only a few minutes old, so starting needs no network call

**Fairness**
- Stronger protection against device-clock changes while offline (LIM-01).

**Features**
- Voice input, an online leaderboard, additional themes, and remembering the mute setting. Per-sound volume controls are a further possible extension.

**Testing**
- An integration test on a device for the database, widget tests for the stat tile, rule card, timer bar and stats screen, and testing on more phones, Android versions and screen sizes.


