# K-Banana: Issues and Known Limitations

This is a register of the defects, risks and limitations found in K-Banana, with what caused each one, what was done about it, and its current status.

**How it was compiled.** Individual milestone dates and an incident-by-incident log were not kept during development (see the project report). This register was assembled in the final phase from four sources: the author's recollection and code comments, an AI-assisted code review, the automated test suite, and manual testing on a physical Samsung Android phone. Each entry says which source found it. Entries are grouped by area, not by date.

## Key

**Severity**

| Level  |                         Meaning                           |
|------- |---------------------------------------------------------- |
| High   | Wrong results, lost player data, or a crash in normal use |
| Medium | A worse or less fair experience, but the game still works |
| Low    | Cosmetic, rare, or limited to developers                  |

**Status**

|  Status   |                         Meaning                           |
|---------- |---------------------------------------------------------- |
| Fixed     | Changed, and checked by a test or on a device             |
| Mitigated | Risk reduced and guarded, but not removed completely      |
| Open      | Found, not fixed. Impact explained in the entry           |
| Accepted  | A known limitation that was decided on, not overlooked    |

## Summary

|    ID   |                               Title                                |        Area       |Severity|   Status  |
|-------- |--------------------------------------------------------------------|------------------ |--------|-----------|
| BUG-01  | Consecutive dates gave almost the same first rule                  | Game logic        | Medium | Fixed     |
| BUG-02  | A rule could repeat within one game                                | Game logic        | Medium | Mitigated |
| BUG-03  | The same daily game could be played or saved twice                 | Persistence       | High   | Mitigated |
| BUG-04  | Timeout and Submit could both record the same round                | Game screen       | High   | Fixed     |
| BUG-05  | The last keystroke could be lost when time ran out                 | Game screen       | Medium | Fixed     |
| BUG-06  | The keyboard closed and reopened between rounds                    | Game screen       | Low    | Fixed     |
| BUG-07  | A whole word could be pasted into the box                          | Game screen       | Low    | Fixed     |
| BUG-08  | A failed time request could stop the daily game                    | Services          | High   | Fixed     |
| BUG-09  | A failed definition lookup looked like "no definition"             | Services          | Low    | Fixed     |
| BUG-10  | Any database open error deleted the player's history               | Persistence       | High   | Fixed     |
| BUG-11  | The clock and the audio disagreed when the app was interrupted     | Lifecycle & audio | Medium | Fixed     |
| BUG-12  | The ambience never restarted after a background interruption       | Audio             | Low    | Fixed     |
| BUG-13  | Reduced motion was respected on the home logo only                 | Accessibility     | Low    | Fixed     |
| BUG-14  | A hint line could overflow at the largest font size                | Layout            | Low    | Mitigated |
| BUG-15  | The lock screen test expected the wrong text                       | Tests             | Low    | Fixed     |
| BUG-16  | The date service test could fail at UTC midnight                   | Tests             | Low    | Fixed     |
| BUG-17  | The quit dialog opened between rounds did not stop the next clock  | Game screen       | Low    | Fixed     |
| BUG-18  | The countdown ran much faster when "remove animations" was on      | Game screen       | High   | Fixed     |
| BUG-19  | A slow time service delayed the start of the daily game            | Services          | Medium | Fixed     |
| OPEN-01 | Unreadable secure-storage key after a restore is not handled       | Persistence       | Medium | Open      |
| OPEN-02 | `checkConstraint` throws on an empty word                          | Game logic        | Low    | Open      |
| OPEN-03 | The opening sound volume is above the documented range             | Audio             | Low    | Open      |
| OPEN-04 | Some audio methods are never called                                | Audio             | Low    | Open      |

Known limitations that were decided on are listed at the end.

---

## Game logic

### BUG-01: Consecutive dates gave almost the same first rule
- **Area:** `SeededRandom`
- **Severity:** Medium
- **Status:** Fixed
- **Found by:** Author, during development (referred to as "bug A1" in a test comment)
- **Symptom:** The daily puzzle is seeded with the date (20261111, 20261112, and so on). The first rule of the game was nearly identical from one day to the next.
- **Cause:** The generator is a linear congruential generator. After one step, seeds that differ by 1 give outputs that differ by only about 0.04% of the range, so scaling them down to a small range picks the same rule.
- **Fix:** The generator discards its first ten outputs after seeding (`_warmUpDraws`).
- **Verification:** A test requires that 30 consecutive daily seeds produce more than five different first rules. A second test pins exact generator outputs, so any later change to the constants, the warm-up or the scaling fails loudly. Changing them would silently change every daily puzzle.

### BUG-02: A rule could repeat within one game
- **Area:** `GameSession.create`, `ChallengeGenerator`
- **Severity:** Medium
- **Status:** Mitigated
- **Found by:** Author, during development (guard code and a dedicated test exist for it)
- **Symptom:** Every pick is random, so the same rule could appear twice in seven rounds, and a combined rule could double up ("end with W and end with W").
- **Cause:** Rule picks are independent random draws.
- **Fix:** The session retries up to 10 times to avoid a rule already used in the game, and the generator retries up to 5 times to avoid two identical halves. The retries are bounded so generation can never loop forever. If they run out, a duplicate would be accepted. This is the reason the status is Mitigated.
- **Verification:** A test checks 300 seeds on a synthetic dictionary. A second test checks every daily puzzle for the next 365 days on the real word list, and none repeats a rule or doubles up a half.

---

## Persistence

### BUG-03: The same daily game could be played or saved twice
- **Area:** Home screen, `GameDatabase`
- **Severity:** High
- **Status:** Mitigated
- **Found by:** Author, during development (guards are described in code comments)
- **Symptom:** A player could start the daily game again after finishing it, which would distort the stats and streak.
- **Cause:** One layer alone is not enough: the UI could be stale, and a game could be saved after a race.
- **Fix:** Three layers. The home screen hides the daily button once today's game is played. Starting a session re-checks the saved games for that date. The database has a `UNIQUE` constraint on the date key, so a second save fails.
- **Verification:** Reviewed in code. The SQL itself could not be unit-tested (see "Testing limits" below).

### BUG-10: Any database open error deleted the player's history
- **Area:** `GameDatabase.open`
- **Severity:** High
- **Status:** Fixed
- **Found by:** AI-assisted code review, raised by the author
- **Symptom:** If opening the database failed for any reason, the file was deleted and recreated empty.
- **Cause:** A catch-all `catch (e)`. It was meant for a database restored without its encryption key, but it also caught errors that can hit a healthy file: a locked database, an I/O error, a full disk, or a failed future migration.
- **Fix:** Recovery now runs only when the error means the file cannot be decrypted or is corrupt (`GameDatabase.isUnreadableError`, matching "not a database", `SQLITE_NOTADB`, "malformed" and `SQLITE_CORRUPT`). Every other error is rethrown and the history is kept. Non-database errors are never treated as unreadable.
- **Verification:** Unit tests cover the classifier with both kinds of message. On the test phone, the wrong-key case recreated the database and the normal case kept existing history. Android backup was also turned off, because restoring an encrypted database without its key was the main way this case arose.

---

## Game screen

### BUG-04: Timeout and Submit could both record the same round
- **Area:** Game screen
- **Severity:** High
- **Status:** Fixed
- **Found by:** Author, during development (described in the project report)
- **Symptom:** If the timer ended at the same moment as a tap on Submit, the round could be recorded twice.
- **Cause:** Two independent triggers ran the same round-ending code.
- **Fix:** The screen changes phase as soon as the first submission starts (`playing` to `transitioning`), and both entry points return immediately unless the phase is `playing`. The Submit button is greyed out at the same moment.
- **Verification:** Manual testing. The race is timing-dependent and has no automated test.

### BUG-05: The last keystroke could be lost when time ran out
- **Area:** Game screen
- **Severity:** Medium
- **Status:** Fixed
- **Found by:** Author, during development (described in the project report)
- **Symptom:** A word typed in the final fraction of a second could be missing or incomplete in the recorded round.
- **Cause:** When the countdown reaches zero, the keyboard may not have committed its last character to the text field yet.
- **Fix:** On timeout the screen waits `kAutoSubmitDelay` (300 ms) before reading the box.
- **Verification:** Manual testing.

### BUG-06: The keyboard closed and reopened between rounds
- **Area:** Game screen
- **Severity:** Low
- **Status:** Fixed
- **Found by:** Author, during development (explained in a code comment)
- **Symptom:** The on-screen keyboard slid away and back up on every round change.
- **Cause:** Blocking typing between rounds by making the field read-only or disabled makes it lose focus.
- **Fix:** An input formatter rejects typing while the screen is not in the `playing` phase, so the field keeps focus.
- **Verification:** Manual testing.

### BUG-07: A whole word could be pasted into the box
- **Area:** Game screen
- **Severity:** Low
- **Status:** Fixed
- **Found by:** Author, during development (formatter and comment)
- **Symptom:** Pasting a word would enter it in one action, bypassing the typing the game is about. Non-letter characters and very long text were also possible.
- **Cause:** A default text field accepts pasted text.
- **Fix:** Input formatters accept letters only, reject any single insertion of more than one character, and limit length to 30 (`kMaxWordLength`). The context menu is also disabled.
- **Verification:** Manual testing.

### BUG-17: The quit dialog opened between rounds did not stop the next clock
- **Area:** Game screen
- **Severity:** Low
- **Status:** Fixed
- **Found by:** AI-assisted code review
- **Symptom:** Opening the quit dialog stopped the clock only when a round was already in progress. If the dialog was opened during the short pause between rounds, the next round's clock started behind the dialog.
- **Cause:** `_finishRound` started the next round's clock after `kRoundPause` without checking whether the quit dialog was open, and `_confirmQuit` only resumed the clock when the round was already in the `playing` phase.
- **Fix:** Added a `_resumeNextRoundAfterQuit` flag. If the between-round pause completes while `_quitDialogOpen` is true, starting the next clock is deferred until the player taps "Keep playing" (and cleared if the player quits or the game finishes).
- **Verification:** Checked on the test device by opening the quit dialog during the between-round pause and confirming the next clock stays paused until "Keep playing" is selected.

### BUG-18: The countdown ran much faster when "remove animations" was on
- **Area:** Game screen
- **Severity:** High
- **Status:** Fixed
- **Found by:** Author, while testing reduced-motion support on the test phone
- **Symptom:** With the system "remove animations" setting on, a 10-second round ended after only a few seconds, so the game was close to unplayable for players who rely on that setting.
- **Cause:** The countdown is an `AnimationController`. By default Flutter shortens a controller's duration when the system asks for reduced motion, because it assumes the animation is decorative. The countdown is the game's clock.
- **Fix:** The controller is created with `animationBehavior: AnimationBehavior.preserve`, so it keeps its full duration. Decorative animations still follow the setting (BUG-13).
- **Verification:** Manual testing with the setting on and off: the round lasts the full 10 seconds either way.

---

## Services

### BUG-08: A failed time request could stop the daily game
- **Area:** `fetchDate`
- **Severity:** High
- **Status:** Fixed
- **Found by:** Author, during development (described in the project report)
- **Symptom:** With no connection, a slow server, an error status or a malformed answer, the game would have no date and so no daily seed.
- **Cause:** The date comes from a web service.
- **Fix:** A two-second (originally five seconds, shortened to two in BUG-18), a check that the answer really is an eight-digit date, and a fallback to the device's UTC date. The function never throws. It also accepts an optional HTTP client, so it can be tested.
- **Verification:** Tests with a fake client cover a normal answer, a non-200 status, invalid JSON, JSON that is not an object, a missing or non-string field, a malformed date and a thrown error. The two-second timeout itself is not tested, because the test would take five seconds.
- **Remaining risk:** See LIM-01 (clock manipulation).

### BUG-09: A failed definition lookup looked like "no definition"
- **Area:** `fetchDefinition`
- **Severity:** Low
- **Status:** Fixed
- **Found by:** Author, during development (described in the project report)
- **Symptom:** A network failure and a word with no entry could look the same to the player, and a failure could not be retried.
- **Cause:** Both outcomes had no definition to show.
- **Fix:** Three distinct results: found, not found, and unavailable. Unavailable can be retried. Successful answers are cached for the session and failures are not, so a retry really asks again. Words with unsafe characters are rejected before any request is made.
- **Verification:** Tests with a fake client cover the URL, a 404, a 500, a network error, unsafe input and the cache.

### BUG-19: A slow time service delayed the start of the daily game
- **Area:** `fetchDate`, home screen, `GameSession`
- **Severity:** Medium
- **Status:** Fixed
- **Found by:** Author, during final device testing
- **Symptom:** Tapping "Play today's challenge" took about five seconds to start the game.
- **Cause:** The time service (timeapi.io) was returning 502 Bad Gateway or stalling. Starting a daily game asks it for the date, and each stalled request waited the full five-second timeout before falling back to the device clock.
- **Fix:** The request timeout was cut to two seconds. The fallback to the device's UTC date was already in place, so a stalled service now delays the start by about two seconds at most, and the puzzle is unchanged as long as the device clock is correct.
- **Verification:** On the test phone, the daily game starts in about two seconds while the service is failing. The timeout value itself is not covered by an automated test.
- **Remaining risk:** The date is still requested twice (once when the home screen loads and once when a daily game starts). A stalled service can still add up to two seconds each time, and a wrong device clock gives a different puzzle (LIM-01). Reusing the home screen's date for a short period is listed in future work.

---

## Lifecycle and audio

### BUG-11: The clock and the audio disagreed when the app was interrupted
- **Area:** Game screen, `AudioService`
- **Severity:** Medium
- **Status:** Fixed
- **Found by:** AI-assisted code review
- **Symptom:** The game screen had no lifecycle handling. When the app lost focus, audio paused, but the countdown behaved by accident:
  - During `inactive` (an incoming call, the notification shade), the clock kept running and the tick and heartbeat sounds kept firing.
  - During `hidden` and `paused` (Home, switching apps, screen lock), the bar froze but real time passed, so the round could already be over on return. That would also have played a burst of tick and heartbeat sounds just before the timeout.
- **Cause:** The countdown is an animation measured in wall-clock time, and only `main.dart` and `AudioService` knew about lifecycle states.
- **Fix:** The game screen observes the lifecycle. The clock runs only while the app is `resumed`. It stops in any other state and carries on from the same moment when the app returns. A round that begins while the app is away starts its clock on return. The quit dialog already behaved this way. Audio pausing is left to `AudioService`, to avoid a stopped player replaying a stray sound.
- **Verification:** Manual device testing. Pausing the clock does allow a player to look a word up. See LIM-02.

### BUG-12: The ambience never restarted after a background interruption
- **Area:** `AudioService.resumeForAppForeground`
- **Severity:** Low
- **Status:** Fixed
- **Found by:** AI-assisted code review
- **Symptom:** If the one-second silence before the ambience ended while the app was in the background, the music stayed silent until another screen restarted it.
- **Cause:** The delayed start was recorded in `_ambiencePendingWhileBackground`, but on return the flag was cleared without starting the sound. A comment in the code said "restart it here if needed" and nothing did.
- **Fix:** On return, a pending start is now begun immediately.
- **Verification:** Manual device testing.

---

## Accessibility and layout

### BUG-13: Reduced motion was respected on the home logo only
- **Area:** Intro, game screen, theme
- **Severity:** Low
- **Status:** Fixed
- **Found by:** Author (noted in the project report) and confirmed by AI-assisted code review
- **Symptom:** With the system's reduced-motion setting on, the home logo stopped floating, but the intro cross-fade, the key press animation, the rule-card change and the "word captured" pulse still animated.
- **Cause:** Only one animation checked the setting.
- **Fix:** A small helper (`motionDuration`) returns zero when the system asks for reduced motion, and the animations above use it. The countdown number and bar keep moving, because they carry information.
- **Verification:** A unit test covers the helper, and the screens were checked on the test phone with system animations turned off.
- **Remaining gap:** Page transitions use the platform default. See LIM-06.

### BUG-14: A hint line could overflow at the largest font size
- **Area:** Results screen
- **Severity:** Low
- **Status:** Mitigated
- **Found by:** AI-assisted code review
- **Symptom:** The "Tap for definition" line, and the "Looking up…" line in the definition sheet, were plain text next to an icon in a row. On a narrow screen at the largest font, that is wider than the card.
- **Cause:** Text in a `Row` that is not flexible cannot wrap.
- **Fix:** The text is now wrapped in `Expanded`.
- **Verification:** The layouts were checked at the maximum Android font size on the test phone, and nothing broke. That check did not reproduce the overflow even before the change, so this was a preventive fix.
- **Related design choice:** The stat tiles scale their text down instead of overflowing, so at the largest font setting their text can end up smaller than the player asked for.

---

## Tests

### BUG-15: The lock screen test expected the wrong text
- **Area:** `lock_gate_test.dart`
- **Severity:** Low
- **Status:** Fixed
- **Found by:** AI-assisted code review
- **Symptom:** One test looked for "Word Game is locked", but the screen shows "K-Banana is locked". The app had been renamed and the test had not.
- **Fix:** The test was rewritten with the correct text and expanded to cover success, failure, retry, no screen lock, an unmounted screen and the spinner label.

### BUG-16: The date service test could fail at UTC midnight
- **Area:** `date_service_test.dart`
- **Severity:** Low
- **Status:** Fixed
- **Found by:** AI-assisted code review
- **Symptom:** The old test called the real server and compared the result with the device clock, so it could fail when UTC midnight passed between the two. Offline, it only exercised the fallback and never the parsing.
- **Fix:** `fetchDate` accepts an optional client, and the tests use a fake one. The fallback tests read the clock before and after the call, so they cannot fail at midnight.

---

## Open items

### OPEN-01: An unreadable secure-storage key after a restore is not handled
- **Area:** `GameDatabase.open`, `flutter_secure_storage`
- **Severity:** Medium
- **Status:** Open
- **Description:** BUG-10 covers a database that cannot be opened with its key. It does not cover the key itself being unreadable. If secure storage throws while reading the passphrase after a restore or a changed device state, `open()` fails before the database is touched, and the app may not start.
- **Why it is only Medium and not High:** Android backup is turned off for the app, which removes the common route to this state. Reaching it would take an unusual restore or Keystore reset.
- **Suggested fix:** Catch a read failure, treat it as a lost key, delete the unreadable database, clear the stored key and create a new one. A start-up error screen in `main.dart` with a retry button would also stop a blank screen if `open()` rethrows.

### OPEN-02: `checkConstraint` throws on an empty word
- **Area:** `ConstraintStartsWith`, `ConstraintEndsWith`
- **Severity:** Low
- **Status:** Open
- **Description:** These read the first or last character directly, so calling `checkConstraint('')` raises a range error. `isAccepted` guards against empty input, and the game and dictionary code never pass an empty word, so no player can hit it.
- **Suggested fix:** Return false for an empty word inside `checkConstraint`, so the rule classes are safe by themselves.

### OPEN-03: The opening sound volume is above the documented range
- **Area:** `AudioService`
- **Severity:** Low
- **Status:** Open
- **Description:** `_openingVolume` is 1.4, but `audioplayers` documents volume as 0.0 to 1.0. The jingle plays, so the plugin appears to clamp or tolerate it, but behaviour may differ between devices and plugin versions.
- **Suggested fix:** Use 1.0 and, if the jingle is too quiet, raise the loudness in the audio file.

### OPEN-04: Some audio methods are never called
- **Area:** `AudioService`
- **Severity:** Low
- **Status:** Open
- **Description:** `stopAll()`, `dispose()` and `hasPlayedOpening` have no callers. In particular the players are never released, because `dispose()` is never called. This is harmless while the audio service lives as long as the app does.

---

## Known limitations (accepted)

  - **LIM-01 — Offline clock manipulation:** A player who changes the device clock while **offline** can get a different puzzle and replay the daily game on a different date.
  - **Why it is accepted:** There is no server to give a trusted date. Online, the time service is used. This is listed in the project report as the main fairness limitation.
  
  - **LIM-02 — Pausing to look up words:** Pausing the clock (by leaving the app, or with the quit dialog) lets a player look up a word.
  - **Why it is accepted:** Scores are local only and there is no leaderboard. It would matter if a leaderboard were added.
  
  - **LIM-03 — Device lock checked once per launch:** The device lock is checked once per launch, not each time the app returns from the background.
  - **Why it is accepted:** A deliberate choice, described in the code.
  
  - **LIM-04 — Online-only definitions:** Definitions need an internet connection.
  - **Why it is accepted:** They come from `dictionaryapi.dev`. The failure is shown and can be retried.
  
  - **LIM-05 — Unfiltered word list:** The word list is used as published and is not filtered for offensive terms; words in it are valid answers and can be looked up.
  - **Why it is accepted:** A decision made for this version.
  
  - **LIM-06 — Default page transitions under reduced motion:** Page transitions are not changed by the reduced-motion setting.
  - **Why it is accepted:** They use the platform default.
  
  - **LIM-07 — Mute state not persisted:** The mute setting is not remembered between launches.
  - **Why it is accepted:** Kept simple.
  
  - **LIM-08 — Local-only history across devices:** History does not transfer to a new phone.
  - **Why it is accepted:** Android backup is off, because the encrypted database cannot be read without its Keystore key.
  
  - **LIM-09 — No voice input:** There is no voice input, so rapid typing may remain a barrier for some players.
  - **Why it is accepted:** Listed in the project report as a possible improvement.
  
  - **LIM-10 — Android only:** The app targets Android only.
  - **Why it is accepted:** iOS was not part of the scope.
  
  - **LIM-11 — No online leaderboard:** The online leaderboard from the original concept was removed.
  - **Why it is accepted:** Suitable free backend options were limited, and offline reliability was the priority.
  
  - **LIM-12 — Third-party dictionary accuracy, coverage, and homograph ambiguity:** Word definitions depend on `dictionaryapi.dev`, which is outside the app's control and may return incomplete, inaccurate, or missing entries, or show an unexpected sense for homographs (words spelled the same with different meanings/origins, such as looking up *found* as the past tense of *find* when an entry for the verb *to found* appears).
  - **Why it is accepted:** The app relies on a free external dictionary lookup rather than bundling an offline lexical database or disambiguating senses/parts of speech, keeping the app lightweight within project scope.

  - **LIM-13 — Screen-reader usability in a fast-timed game:** Although basic screen-reader semantics are present, gameplay relies heavily on rapid visual scanning and direct typing against a short timer. Linear text-to-speech takes longer to convey the round constraint, character feedback, and submission actions—costing precious clock time and making screen-reader play impractical.
  - **Why it is accepted:** Slowing down or pausing the game clock for screen-reader speech would change the core timed mechanic and the scoring system, and building a specialized accessible/non-visual accessible gameplay mode was not feasible within the project deadline.

## Testing limits

- **Automated:** the 15 test files pass under `flutter test` and `flutter analyze` reports no issues. The database's SQL (saving, reading, the unique date constraint, transactions) cannot run in a plain `flutter test`, because it needs the native SQLCipher library, so it was checked by hand on a device. Audio playback and most screens are also checked by hand and not automated.
- **Devices:** manual testing was done on one physical Samsung Android phone. No emulator, other manufacturers or other Android versions were part of the recorded verification, and neither was a second screen size. Two testers played the game and gave positive feedback.
- **Not measured:** the exact number of individual test cases, and the phone's screen dimensions, were not recorded.
