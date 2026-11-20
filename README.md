# K-Banana

A daily word game for Android, built with Flutter. Every day brings one puzzle that is the same for every player: seven rounds, ten seconds each, and a new rule to follow in every round. Type a real word that obeys the rule, and type it fast.

- **Platform:** Android
- **Framework:** Flutter (Dart `^3.13.4`)
- **Version:** 1.0.0+1
- **Author:** Yanis Makhoukhi

## How to play

1. Tap the banana key on the intro screen.
2. Choose **Play today's challenge** (one attempt per day) or **Practice** (unlimited, never saved).
3. In each of the seven rounds you see a rule, such as "Word must start with C", and have **10 seconds** to type a word and press Submit. When the time runs out, whatever is in the box is submitted automatically.
4. After round seven, the results screen shows every round: your word, the rule, whether it counted and why, and the points. Tap a word to see its definition.

### The rules of a round

- Rounds 1 to 4 each have **one rule**: the word must *contain*, *exclude*, *start with* or *end with* a letter, chosen from the twelve most common English letters.
- Rounds 5 to 7 each **combine two rules**, and may use any letter.
- A word counts only if it is in the dictionary, follows the rule, and has not already scored earlier in the same game.
- No rule repeats within a game. A rule is only used if at least 100 dictionary words satisfy it, so no round is unwinnable.
- The game never tells you during play whether a word was right. Validity is shown on the results screen.

### Scoring

A valid word scores `(10 × letters + 2 × seconds left) / 10` points, so `cat` with 6 seconds left is worth `(30 + 12) / 10 = 4.2`. Invalid, empty, repeated and unknown words score 0. The game score is the sum of the seven rounds.

### The daily puzzle

The puzzle is generated from today's UTC date, so everyone gets the same seven rules on the same day. The date comes from a time API; if it cannot be reached, the device clock is used instead.

Only finished **daily** games are saved. The stats screen shows games played, best score, last score and your streak. A streak counts consecutive days played, and it is still alive if you last played today or yesterday.

### Interruptions

The countdown runs only while the app is in the foreground. A call, the notification shade, switching apps or locking the screen pauses it, and it carries on from the same moment when you return. The quit dialog pauses it too. Time between rounds is never charged to the player.

## Privacy and security

- **Device lock.** The app asks for your fingerprint, face, PIN, pattern or password once per launch, using the device's own screen lock. If the device has no screen lock, the app opens and says so on the home screen.
- **Encrypted history.** Game history is stored in a SQLCipher-encrypted database. Its random 32-byte passphrase is created on first launch and kept in the Android Keystore through `flutter_secure_storage`, never in the app's files or source code.
- **Recovery.** If the database file cannot be decrypted or is corrupt (for example after a restore without its key), it is recreated empty so the app still starts. Other database errors are never treated this way, so a temporary problem cannot erase your history.
- **No accounts, no analytics, no ads.** Everything stays on the device.
- **Android backup is turned off** for the app, because an encrypted database restored without its key cannot be read.
- **Network use.** Two requests leave the device: the date request to `timeapi.io`, and, only when you tap a word on the results screen, the word itself to `dictionaryapi.dev` for its definition. Successful definitions are cached in memory for the session.

## Accessibility

- Screen reader labels throughout. The rule and round are announced when they change, and the remaining time is announced at 5 and 3 seconds.
- Results are shown as an icon **and** text, never by colour alone.
- Layouts wrap or scale with large system font sizes, and were checked at the maximum Android font size.
- Animations are removed when the system "reduce motion" setting is on. The countdown itself still runs, because it carries information.
- A **mute button** on the home screen sets every sound to volume 0 and back to the default levels when turned off. It is not remembered between launches.

## Project structure

```
lib/
  main.dart          App start-up and lifecycle hooks for audio
  data/              Dictionary, encrypted database, streak and date-key helpers
  game/              Game rules: session, scoring, seeded random, challenge generator
    constraints/     One class per rule type, plus the combined rule
  screens/           Intro, lock gate, home, game, results, stats
  services/          Audio, biometric lock, date (time API), word definitions
  theme/             Colours, theme and the reduced-motion helper
  widgets/           Reusable pieces: stat tile, rule card, timer bar, definition sheet
test/                Mirrors lib/
tools/               Development-only Python utilities for various tasks
assets/              words.txt, fonts, images, sounds, launcher icon
```

The game logic in `lib/game/` is plain Dart with no Flutter dependencies, so it can be tested directly. The screen owns the clock and the UI; `GameSession` owns the rules and scoring. Services and the database are created once in `main()` and passed down through constructors.

### Design decisions worth knowing

- **Seeded random generator.** `SeededRandom` is a small linear congruential generator, seeded with the date. It discards its first ten outputs, because consecutive date seeds differ by one and would otherwise give nearly identical first rules. **Do not change its constants, warm-up or scaling after release: any change alters every daily puzzle.** A test pins known outputs to catch this.
- **Bounded retries.** Rule generation never loops forever. It retries a limited number of times, and if the fallback rule is also invalid it throws an error instead of returning an unplayable round.
- **Internal names.** The Dart package is `key_banana`, and the encrypted database file is `kbanana.db`.

## Getting started

### Requirements

- Flutter SDK with Dart `^3.13.4`
- An Android device or emulator. To see the lock screen, the device needs a screen lock set up.
- Internet access for the date and definitions. The game still starts offline, using the device clock, but definitions are unavailable.

### Run

```bash
flutter pub get
flutter run
```

### Checks

```bash
flutter analyze
flutter test
dart format lib test
```

### Build a release

```bash
flutter build apk --release        # installable APK
flutter build appbundle --release  # for Google Play
```

To regenerate the launcher icon after changing `assets/icon/kbanana_icon.png`:

```bash
dart run flutter_launcher_icons
```

## Tests

The `test/` folder mirrors `lib/`. The tests cover:

- Every rule type, and combined rules
- Game sessions: scoring, clamping, repeats, round progress, finishing, and building games from explicit rules
- Scoring formulas
- The seeded generator, including pinned outputs
- The challenge generator, including the "dictionary too small" failure
- Dictionary validation, the real word list, and a check that every day of the next year produces seven different rules
- Streak calculation and date formatting
- The date service and the definition service, using a fake HTTP client
- The biometric service and the lock gate, using fakes
- Which database errors are safe to recover from

**Not covered by automated tests:** the SQL in the encrypted database (it needs the native SQLCipher library, so it was checked on a real device), audio playback, and most screens. See [BUGS.md](BUGS.md) for known limitations.

## Known limitations

- Android only.
- Definitions need an internet connection.
- The word list is used as published and is not filtered for offensive terms.
- With no connection, the daily puzzle depends on the device clock.
- Because backup is off, history does not move to a new phone.

The full list is in [BUGS.md](BUGS.md). The development history and ideas for later are in [DEVLOG.md](DEVLOG.md).

## Credits

- **Word list:** `popular.txt` from [dolph/dictionary](https://github.com/dolph/dictionary/blob/master/popular.txt). See that repository for its licence.
- **Definitions:** the Free Dictionary API, [dictionaryapi.dev](https://dictionaryapi.dev).
- **Date:** [timeapi.io](https://timeapi.io).
- **Font:** Nunito, under the SIL Open Font License.
- **Sounds:** Generated using ElevenLabs (AI sound effects) under ElevenLabs' commercial/user-generated content terms.
- **Artwork and icon:** Concept, layout, and visual designs planned and sketched by the author, with final SVG/image assets generated using ChatGPT based on the author's detailed descriptions.

## Licence

All rights reserved.
