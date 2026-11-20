import 'package:flutter_test/flutter_test.dart';
import 'package:key_banana/data/dictionary_service.dart';
import 'package:key_banana/game/constraints/constraints_barrel.dart';
import 'package:key_banana/game/game_session.dart';

/// Every three-letter combination (17,576 words): big enough that rules pass
/// the "at least 100 matching words" check, small enough to be instant.
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

void main() {
  // ==========================================
  // 1. SUBMITTING WORDS
  // ==========================================
  group('submitWord rules', () {
    late DictionaryService dictionary;
    late GameSession session;

    setUp(() {
      dictionary = DictionaryService.fromWords({
        'cat',
        'bat',
        'dog',
        'apple',
        'tree',
      });
      session = GameSession.withConstraints(
        dictionary,
        List.generate(3, (_) => ConstraintContains('a')),
      );
    });

    test(
      'a valid word scores 10 per letter plus 2 per second, divided by 10',
      () {
        final r = session.submitWord('cat', 6);
        expect(r.outcome, RoundOutcome.valid);
        expect(r.points, closeTo((10 * 3 + 2 * 6) / 10, 1e-9));
      },
    );

    test('words are trimmed and lowercased', () {
      final r = session.submitWord('  CAT ', 5);
      expect(r.word, 'cat');
      expect(r.isValid, isTrue);
    });

    test('an empty word is recorded as empty and scores 0', () {
      final r = session.submitWord('   ', 0);
      expect(r.outcome, RoundOutcome.empty);
      expect(r.points, 0);
      expect(session.currentRound, 2);
    });

    test('a word not in the dictionary scores 0', () {
      final r = session.submitWord('qqqqqq', 8);
      expect(r.outcome, RoundOutcome.notAWord);
      expect(r.points, 0);
    });

    test('a dictionary word that breaks the rule scores 0', () {
      final r = session.submitWord('dog', 8);
      expect(r.outcome, RoundOutcome.breaksRule);
      expect(r.points, 0);
    });

    test('a word that already scored is a repeat and scores 0', () {
      session.submitWord('cat', 5);
      final r = session.submitWord('cat', 5);
      expect(r.outcome, RoundOutcome.repeated);
      expect(r.points, 0);
    });

    test('a repeat is detected regardless of case and whitespace', () {
      session.submitWord('cat', 5);
      final r = session.submitWord('  CAT ', 5);
      expect(r.outcome, RoundOutcome.repeated);
    });

    test('an invalid earlier attempt does not make a later word a repeat', () {
      final mixed = GameSession.withConstraints(dictionary, [
        ConstraintContains('o'),
        ConstraintContains('a'),
      ]);
      expect(mixed.submitWord('cat', 5).outcome, RoundOutcome.breaksRule);
      expect(mixed.submitWord('cat', 5).outcome, RoundOutcome.valid);
    });

    test('secondsLeft is clamped to 0..10', () {
      expect(session.submitWord('cat', 99).points, closeTo(5.0, 1e-9));
      expect(session.submitWord('bat', -4).points, closeTo(3.0, 1e-9));
    });

    // New: the clamped value is also what gets recorded.
    test('the recorded secondsLeft is the clamped value', () {
      expect(session.submitWord('cat', 99).secondsLeft, 10);
      expect(session.submitWord('bat', -4).secondsLeft, 0);
    });

    // New: NaN would otherwise poison the score.
    test('NaN seconds are treated as 0', () {
      final r = session.submitWord('cat', double.nan);
      expect(r.secondsLeft, 0);
      expect(r.points, closeTo(3.0, 1e-9)); // (10 * 3 + 2 * 0) / 10
    });

    // New: infinite values are clamped like any other out-of-range value.
    test('infinite seconds are clamped to the range', () {
      expect(session.submitWord('cat', double.infinity).secondsLeft, 10);
      expect(session.submitWord('bat', double.negativeInfinity).secondsLeft, 0);
    });

    test('the game finishes after the last round and then refuses input', () {
      session.submitWord('cat', 5);
      session.submitWord('bat', 5);
      expect(session.isFinished, isFalse);
      session.submitWord('apple', 5);
      expect(session.isFinished, isTrue);
      expect(() => session.submitWord('cat', 5), throwsStateError);
      expect(() => session.currentConstraint, throwsStateError);
    });

    test('finalScore is the sum of every round\'s points', () {
      final a = session.submitWord('cat', 5);
      final b = session.submitWord('dog', 5);
      final c = session.submitWord('apple', 5);
      expect(session.finalScore, closeTo(a.points + b.points + c.points, 1e-9));
    });

    // New: nothing has been played yet.
    test('finalScore is 0 before any round is played', () {
      expect(session.finalScore, 0);
    });
  });

  // ==========================================
  // 2. ROUND PROGRESS AND RESULTS
  // ==========================================
  group('round progress and results', () {
    late DictionaryService dictionary;
    late GameSession session;

    setUp(() {
      dictionary = DictionaryService.fromWords({
        'cat',
        'bat',
        'dog',
        'apple',
        'tree',
      });
      session = GameSession.withConstraints(
        dictionary,
        List.generate(3, (_) => ConstraintContains('a')),
      );
    });

    test('a new game starts on round 1 and is not finished', () {
      expect(session.currentRound, 1);
      expect(session.totalRounds, 3);
      expect(session.isFinished, isFalse);
      expect(session.results, isEmpty);
    });

    test('currentRound advances by one after every submission', () {
      session.submitWord('cat', 5);
      expect(session.currentRound, 2);
      session.submitWord('bat', 5);
      expect(session.currentRound, 3);
    });

    test('currentRound stays on the last round once the game is finished', () {
      session.submitWord('cat', 5);
      session.submitWord('bat', 5);
      session.submitWord('apple', 5);

      expect(session.isFinished, isTrue);
      expect(session.currentRound, session.totalRounds);
    });

    test('currentConstraint follows the rounds in order', () {
      final ordered = GameSession.withConstraints(dictionary, [
        ConstraintContains('a'),
        ConstraintStartsWith('t'),
      ]);

      expect(ordered.currentConstraint.description, 'Word must contain A');
      ordered.submitWord('cat', 5);
      expect(ordered.currentConstraint.description, 'Word must start with T');
    });

    test('results record the round, rule, word and seconds of each round', () {
      session.submitWord('cat', 6);

      final result = session.results.single;
      expect(result.round, 1);
      expect(result.constraint, 'Word must contain A');
      expect(result.word, 'cat');
      expect(result.secondsLeft, 6);
      expect(result.outcome, RoundOutcome.valid);
    });

    test('results cannot be modified from outside', () {
      session.submitWord('cat', 5);

      expect(
        () => session.results.add(
          const RoundResult(
            round: 99,
            constraint: 'fake',
            word: 'fake',
            outcome: RoundOutcome.valid,
            secondsLeft: 10,
            points: 100,
          ),
        ),
        throwsUnsupportedError,
      );
      expect(() => session.results.clear(), throwsUnsupportedError);
      expect(session.results, hasLength(1));
    });

    test('a results list read earlier does not change when play continues', () {
      session.submitWord('cat', 5);
      final snapshot = session.results;

      session.submitWord('bat', 5);

      expect(snapshot, hasLength(1));
      expect(session.results, hasLength(2));
    });

    test('only valid rounds count as valid results', () {
      session.submitWord('cat', 5);
      session.submitWord('dog', 5);

      expect(session.results[0].isValid, isTrue);
      expect(session.results[1].isValid, isFalse);
    });

    test('every outcome has a non-empty label for the results screen', () {
      for (final outcome in RoundOutcome.values) {
        expect(outcome.label, isNotEmpty);
      }
    });
  });

  // ==========================================
  // 3. BUILDING A SESSION FROM RULES
  // ==========================================
  group('withConstraints', () {
    late DictionaryService dictionary;

    setUp(() => dictionary = DictionaryService.fromWords({'cat'}));

    // New.
    test('an empty list of rules is rejected', () {
      expect(
        () => GameSession.withConstraints(dictionary, []),
        throwsArgumentError,
      );
    });

    // New.
    test('defaults to a practice game with date key 0', () {
      final session = GameSession.withConstraints(dictionary, [
        ConstraintContains('a'),
      ]);

      expect(session.isPractice, isTrue);
      expect(session.dateKey, 0);
    });

    // New.
    test('can be built as a daily game with a date key', () {
      final session = GameSession.withConstraints(
        dictionary,
        [ConstraintContains('a')],
        dateKey: 20261111,
        isPractice: false,
      );

      expect(session.isPractice, isFalse);
      expect(session.dateKey, 20261111);
    });

    // New: the session keeps its own copy of the rules.
    test('changing the original list later does not change the game', () {
      final rules = <Constraint>[
        ConstraintContains('a'),
        ConstraintContains('e'),
      ];
      final session = GameSession.withConstraints(dictionary, rules);

      rules.clear();

      expect(session.totalRounds, 2);
    });
  });

  // ==========================================
  // 4. CHALLENGE GENERATION
  // ==========================================
  group('challenge generation', () {
    late DictionaryService dictionary;

    setUp(() => dictionary = syntheticDictionary());

    List<String> descriptions(GameSession s) {
      final out = <String>[];
      // Reading the rules means walking the game, so submit empty rounds.
      while (!s.isFinished) {
        out.add(s.currentConstraint.description);
        s.submitWord('', 0);
      }
      return out;
    }

    test('the same seed gives the same seven rules', () async {
      final a = await GameSession.create(dictionary, seed: 20261111);
      final b = await GameSession.create(dictionary, seed: 20261111);
      expect(descriptions(a), descriptions(b));
    });

    test('rounds 1-4 are single rules and rounds 5-7 are combined', () async {
      final s = await GameSession.create(dictionary, seed: 20261111);
      final rules = descriptions(s);
      expect(rules, hasLength(7));
      for (var i = 0; i < 4; i++) {
        expect(rules[i], isNot(contains(' and ')));
      }
      for (var i = 4; i < 7; i++) {
        expect(rules[i], contains(' and '));
      }
    });

    test('30 consecutive daily seeds all generate without throwing', () async {
      final firstRules = <String>{};
      for (var day = 0; day < 30; day++) {
        final seed = 20261111 + day; // not a real calendar, just 30 seeds
        final s = await GameSession.create(dictionary, seed: seed);
        expect(s.totalRounds, 7);
        firstRules.add(s.currentConstraint.description);
      }
      // Consecutive seeds must not all start with the same rule (bug A1).
      expect(firstRules.length, greaterThan(5));
    });

    test('a seeded game is practice; its dateKey is the seed', () async {
      final s = await GameSession.create(dictionary, seed: 12345);
      expect(s.isPractice, isTrue);
      expect(s.dateKey, 12345);
    });

    // New: createPractice must work without touching the network.
    test('createPractice builds a seven-round practice game', () async {
      final s = await GameSession.createPractice(dictionary);

      expect(s.isPractice, isTrue);
      expect(s.totalRounds, GameSession.defaultRounds);
      expect(s.isFinished, isFalse);
    });

    // New: the seed is the clock reduced to 32 bits, as SeededRandom expects.
    test('createPractice uses a seed inside the 32-bit range', () async {
      final s = await GameSession.createPractice(dictionary);

      expect(s.dateKey, greaterThanOrEqualTo(0));
      expect(s.dateKey, lessThan(4294967296));
    });
  });
}
