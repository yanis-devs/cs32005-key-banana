import 'package:flutter_test/flutter_test.dart';
import 'package:key_banana/data/dictionary_service.dart';
import 'package:key_banana/game/challenge_generator.dart';

/// Letters the generator may use at difficulty 1 (the most common ones).
const _easyLetters = 'etaoinshrdlu';

/// Every three-letter combination (17,576 words): big enough that most rules
/// pass the "at least 100 matching words" check, small enough to be instant.
DictionaryService syntheticDictionary() {
  const letters = 'abcdefghijklmnopqrstuvwxyz';
  final words = <String>{};
  for (final a in letters.split('')) {
    for (final b in letters.split('')) {
      for (final c in letters.split('')) {
        words.add('$a$b$c');
      }
    }
  }
  return DictionaryService.fromWords(words);
}

/// The letter a single rule is about: "Word must contain E" gives "e".
String letterOf(String description) =>
    description.split(' ').last.toLowerCase();

void main() {
  late DictionaryService dictionary;

  setUp(() => dictionary = syntheticDictionary());

  Future<ChallengeGenerator> generatorFor(int seed) =>
      ChallengeGenerator.create(dictionary, seed: seed);

  // ==========================================
  // 1. DIFFICULTY 1 (SINGLE RULES)
  // ==========================================
  group('difficulty 1', () {
    test('gives a single rule, not a combined one', () async {
      final generator = await generatorFor(20261111);

      for (var i = 0; i < 50; i++) {
        expect(generator.getChallenge(1).description, isNot(contains(' and ')));
      }
    });

    test('only uses the common letters', () async {
      final generator = await generatorFor(20261111);

      for (var i = 0; i < 200; i++) {
        final letter = letterOf(generator.getChallenge(1).description);
        expect(_easyLetters, contains(letter));
      }
    });

    test('can produce all four kinds of rule', () async {
      final generator = await generatorFor(42);
      final kinds = <String>{};

      for (var i = 0; i < 200; i++) {
        final description = generator.getChallenge(1).description;
        for (final kind in ['contain', 'exclude', 'start with', 'end with']) {
          if (description.contains(kind)) kinds.add(kind);
        }
      }

      expect(kinds, {'contain', 'exclude', 'start with', 'end with'});
    });

    test('always returns a rule the dictionary can satisfy', () async {
      for (var seed = 1; seed <= 50; seed++) {
        final generator = await generatorFor(seed);

        expect(dictionary.isChallengeValid(generator.getChallenge(1)), isTrue);
      }
    });
  });

  // ==========================================
  // 2. DIFFICULTY 2 (COMBINED RULES)
  // ==========================================
  group('difficulty 2', () {
    test('gives a combined rule', () async {
      final generator = await generatorFor(20261111);

      for (var i = 0; i < 50; i++) {
        expect(generator.getChallenge(2).description, contains(' and '));
      }
    });

    test('the two halves of a rule are never identical', () async {
      for (var seed = 1; seed <= 200; seed++) {
        final generator = await generatorFor(seed);
        final parts = generator.getChallenge(2).description.split(' and ');

        expect(parts, hasLength(2));
        expect(
          parts[0].replaceFirst('Word must ', ''),
          isNot(parts[1]),
          reason: 'seed $seed doubled a half: $parts',
        );
      }
    });

    test('can use letters beyond the common ones', () async {
      final generator = await generatorFor(42);
      final letters = <String>{};

      for (var i = 0; i < 100; i++) {
        final description = generator.getChallenge(2).description;
        // "Word must contain Q and end with Z" -> letters are in the 2nd and
        // last word positions of each half.
        for (final half in description.split(' and ')) {
          letters.add(letterOf(half));
        }
      }

      expect(letters.any((l) => !_easyLetters.contains(l)), isTrue);
    });

    test('always returns a rule the dictionary can satisfy', () async {
      for (var seed = 1; seed <= 50; seed++) {
        final generator = await generatorFor(seed);

        expect(dictionary.isChallengeValid(generator.getChallenge(2)), isTrue);
      }
    });

    test('going back to difficulty 1 uses the common letters again', () async {
      final generator = await generatorFor(42);

      generator.getChallenge(2);

      for (var i = 0; i < 100; i++) {
        final letter = letterOf(generator.getChallenge(1).description);
        expect(_easyLetters, contains(letter));
      }
    });
  });

  // ==========================================
  // 3. UNSUPPORTED DIFFICULTIES
  // ==========================================
  group('unsupported difficulty', () {
    test('0 is rejected', () async {
      final generator = await generatorFor(1);

      expect(() => generator.getChallenge(0), throwsArgumentError);
    });

    test('3 is rejected', () async {
      final generator = await generatorFor(1);

      expect(() => generator.getChallenge(3), throwsArgumentError);
    });

    test('a negative difficulty is rejected', () async {
      final generator = await generatorFor(1);

      expect(() => generator.getChallenge(-1), throwsArgumentError);
    });
  });

  // ==========================================
  // 4. DETERMINISM
  // ==========================================
  group('determinism', () {
    List<String> challenges(ChallengeGenerator generator) => [
      for (var i = 0; i < 4; i++) generator.getChallenge(1).description,
      for (var i = 0; i < 3; i++) generator.getChallenge(2).description,
    ];

    test('the same seed gives the same challenges in the same order', () async {
      final a = await generatorFor(20261111);
      final b = await generatorFor(20261111);

      expect(challenges(a), challenges(b));
    });

    test('different seeds give different challenges', () async {
      final a = await generatorFor(20261111);
      final b = await generatorFor(20261112);

      expect(challenges(a), isNot(challenges(b)));
    });
  });

  // ==========================================
  // 5. DICTIONARY TOO SMALL
  // ==========================================
  group('dictionary too small', () {
    late ChallengeGenerator tiny;

    setUp(() async {
      // Fewer than 100 words, so no rule can ever be valid, not even the
      // fallback.
      tiny = await ChallengeGenerator.create(
        DictionaryService.fromWords({'cat', 'bat', 'dog'}),
        seed: 1,
      );
    });

    test('difficulty 1 throws instead of returning an invalid rule', () {
      expect(() => tiny.getChallenge(1), throwsStateError);
    });

    test('difficulty 2 throws instead of returning an invalid rule', () {
      expect(() => tiny.getChallenge(2), throwsStateError);
    });

    test('the error says how many attempts were made', () {
      expect(
        () => tiny.getChallenge(1),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('${ChallengeGenerator.maxAttempts} attempts'),
          ),
        ),
      );
    });
  });

  // ==========================================
  // 6. LETTER PICKER
  // ==========================================
  group('getLetter', () {
    test('returns one common letter by default', () async {
      final generator = await generatorFor(42);

      for (var i = 0; i < 200; i++) {
        final letter = generator.getLetter();
        expect(letter, hasLength(1));
        expect(_easyLetters, contains(letter));
      }
    });
  });
}
