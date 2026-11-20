import 'package:flutter_test/flutter_test.dart';
import 'package:key_banana/data/dictionary_service.dart';
import 'package:key_banana/game/constraints/constraints_barrel.dart';
import 'package:key_banana/game/game_session.dart';

/// Counts how often it is asked, and accepts every word. Used to check that
/// the validity scan stops as soon as it has found enough words.
class _CountingConstraint extends Constraint {
  int calls = 0;

  @override
  String get description => 'counting';

  @override
  bool checkConstraint(String word) {
    calls++;
    return true;
  }
}

/// [matching] words that contain "z", plus [other] words that do not.
DictionaryService dictionaryWith({required int matching, int other = 0}) {
  return DictionaryService.fromWords({
    for (var i = 0; i < matching; i++) 'zz$i',
    for (var i = 0; i < other; i++) 'aa$i',
  });
}

/// A yyyymmdd key for [days] days after 21 Nov 2026.
int dateKeyAfter(int days) {
  final date = DateTime.utc(2026, 11, 21).add(Duration(days: days));
  return date.year * 10000 + date.month * 100 + date.day;
}

void main() {
  // Needed for rootBundle, which loads assets/words.txt in the real-data tests.
  TestWidgetsFlutterBinding.ensureInitialized();

  // ==========================================
  // 1. isWordValid
  // ==========================================
  group('isWordValid', () {
    final dictionary = DictionaryService.fromWords({'cat', 'apple', 'tree'});

    test('accepts a word in the dictionary', () {
      expect(dictionary.isWordValid('apple'), isTrue);
    });

    test('rejects a word not in the dictionary', () {
      expect(dictionary.isWordValid('banana'), isFalse);
    });

    test('rejects an empty word', () {
      expect(dictionary.isWordValid(''), isFalse);
    });

    test('rejects a partial word', () {
      expect(dictionary.isWordValid('app'), isFalse);
    });

    // Pins current behaviour: the caller (GameSession) trims and lowercases
    // the word before asking, so the dictionary itself is exact.
    test('is exact: it does not trim or ignore case', () {
      expect(dictionary.isWordValid('Apple'), isFalse);
      expect(dictionary.isWordValid(' apple'), isFalse);
    });

    test('an empty dictionary accepts nothing', () {
      expect(DictionaryService.fromWords({}).isWordValid('cat'), isFalse);
    });
  });

  // ==========================================
  // 2. isChallengeValid
  // ==========================================
  group('isChallengeValid', () {
    final rule = ConstraintContains('z');

    test('is false with 99 matching words', () {
      expect(dictionaryWith(matching: 99).isChallengeValid(rule), isFalse);
    });

    test('is true with exactly 100 matching words', () {
      expect(dictionaryWith(matching: 100).isChallengeValid(rule), isTrue);
    });

    test('is true with more than 100 matching words', () {
      expect(dictionaryWith(matching: 101).isChallengeValid(rule), isTrue);
    });

    test('words that do not match are not counted', () {
      final dictionary = dictionaryWith(matching: 99, other: 500);

      expect(dictionary.isChallengeValid(rule), isFalse);
    });

    test('matching words are found among many that do not match', () {
      final dictionary = dictionaryWith(matching: 100, other: 500);

      expect(dictionary.isChallengeValid(rule), isTrue);
    });

    test('is false for an empty dictionary', () {
      expect(DictionaryService.fromWords({}).isChallengeValid(rule), isFalse);
    });

    test('is false when no word matches', () {
      final dictionary = dictionaryWith(matching: 0, other: 500);

      expect(dictionary.isChallengeValid(rule), isFalse);
    });

    test('a combined rule counts only words that satisfy both rules', () {
      final combined = CombinedConstraints([
        ConstraintContains('z'),
        ConstraintEndsWith('1'),
      ]);
      // zz0..zz199: only the 20 words ending in "1" match both rules.
      final dictionary = dictionaryWith(matching: 200);

      expect(dictionary.isChallengeValid(combined), isFalse);
    });

    test('a combined rule is valid once 100 words satisfy both rules', () {
      final combined = CombinedConstraints([
        ConstraintContains('z'),
        ConstraintEndsWith('1'),
      ]);
      // zz0..zz1999: 200 words end in "1".
      final dictionary = dictionaryWith(matching: 2000);

      expect(dictionary.isChallengeValid(combined), isTrue);
    });

    test('stops checking once 100 matching words are found', () {
      final counter = _CountingConstraint();
      final dictionary = dictionaryWith(matching: 1000);

      expect(dictionary.isChallengeValid(counter), isTrue);
      expect(counter.calls, 100);
    });

    test('checks every word when too few match', () {
      final counter = _CountingConstraint();
      final dictionary = dictionaryWith(matching: 50);

      expect(dictionary.isChallengeValid(counter), isFalse);
      expect(counter.calls, 50);
    });
  });

  // ==========================================
  // 3. THE REAL WORD LIST
  // ==========================================
  group('the real assets/words.txt', () {
    late DictionaryService dictionary;

    setUpAll(() async {
      dictionary = await DictionaryService.create();
    });

    test('loads and is not empty', () {
      expect(dictionary.words, isNotEmpty);
      expect(dictionary.words.length, greaterThan(1000));
    });

    test('contains ordinary words', () {
      for (final word in ['apple', 'tree', 'house', 'water']) {
        expect(dictionary.isWordValid(word), isTrue, reason: word);
      }
    });

    test('every word is lowercase letters a-z only', () {
      // The input box only allows letters, so any other word could never be
      // typed. Uppercase would never match, because input is lowercased.
      final valid = RegExp(r'^[a-z]+$');
      final offenders = dictionary.words
          .where((w) => !valid.hasMatch(w))
          .take(10)
          .toList();

      expect(offenders, isEmpty, reason: 'unplayable words: $offenders');
    });

    test('no word is longer than the input box allows', () {
      // The game screen limits input to 30 letters (kMaxWordLength).
      final tooLong = dictionary.words
          .where((w) => w.length > 30)
          .take(10)
          .toList();

      expect(tooLong, isEmpty, reason: 'too long to type: $tooLong');
    });

    test(
      'the fallback rules are valid, so generation can always fall back',
      () {
        expect(dictionary.isChallengeValid(ConstraintContains('e')), isTrue);
        expect(
          dictionary.isChallengeValid(
            CombinedConstraints([
              ConstraintContains('e'),
              ConstraintContains('t'),
            ]),
          ),
          isTrue,
        );
      },
    );

    test('every day of the next year gets seven different rules', () async {
      for (var day = 0; day < 365; day++) {
        final seed = dateKeyAfter(day);
        final session = await GameSession.create(dictionary, seed: seed);

        // Reading the rules means walking the game, so submit empty rounds.
        final rules = <String>[];
        while (!session.isFinished) {
          rules.add(session.currentConstraint.description);
          session.submitWord('', 0);
        }

        expect(
          rules,
          hasLength(GameSession.defaultRounds),
          reason: 'seed $seed',
        );
        expect(
          rules.toSet(),
          hasLength(rules.length),
          reason: 'seed $seed repeated a rule: $rules',
        );

        // A combined rule must not repeat itself ("end with W and end with W").
        for (final rule in rules) {
          final parts = rule.split(' and ');
          if (parts.length == 2) {
            expect(
              parts[0].replaceFirst('Word must ', ''),
              isNot(parts[1]),
              reason: 'seed $seed doubled a half: "$rule"',
            );
          }
        }
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
