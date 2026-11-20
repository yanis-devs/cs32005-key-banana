import '../data/dictionary_service.dart';
import 'constraints/constraints_barrel.dart';
import 'seeded_random.dart';

/// Builds the rule for each round of a game.
///
/// Uses a [SeededRandom], so the same seed always produces the same rules in
/// the same order. Every candidate is checked against the dictionary, so the
/// player is never given a rule with too few valid words.
class ChallengeGenerator {
  /// How many random candidates to try before using the fallback rule.
  static const int maxAttempts = 20;

  /// Letters that rules can use. Reset by [getChallenge] for each difficulty.
  String _letters = 'etaoinshrdlu';

  /// The seeded random source. Also exposes the seed the game started from.
  final SeededRandom gen;

  /// Used to check that a generated rule has enough matching words.
  final DictionaryService dictionary;

  ChallengeGenerator._(this.gen, this.dictionary);

  /// Creates a generator. With no [seed] it uses today's UTC date (daily
  /// game); pass a [seed] for practice mode or deterministic tests.
  static Future<ChallengeGenerator> create(
    DictionaryService dictionary, {
    int? seed,
  }) async {
    final rng = await SeededRandom.create(seed: seed);
    return ChallengeGenerator._(rng, dictionary);
  }

  /// The kinds of single rule that can be generated. Each entry builds one
  /// rule with a fresh random letter.
  ///
  /// Do not reorder or add entries after release: [createChallenge] picks by
  /// index, so any change alters every daily puzzle.
  late final List<Constraint Function()> pool = [
    () => ConstraintContains(getLetter()),
    () => ConstraintExcludes(getLetter()),
    () => ConstraintStartsWith(getLetter()),
    () => ConstraintEndsWith(getLetter()),
  ];

  /// Picks a random letter from the current letter set.
  String getLetter() {
    return _letters[gen.getRandom(0, _letters.length - 1)];
  }

  /// Returns a valid rule for the given [difficulty].
  ///
  /// - 1: a single rule using common letters.
  /// - 2: two rules combined, using any letter.
  ///
  /// Throws an [ArgumentError] for any other difficulty.
  Constraint getChallenge(int difficulty) {
    switch (difficulty) {
      case 1:
        _letters = 'etaoinshrdlu';

        return _createValidChallenge(
          createChallenge,
          () => ConstraintContains('e'),
        );

      case 2:
        _letters = 'abcdefghijklmnopqrstuvwxyz';

        return _createValidChallenge(
          _createCombinedChallenge,
          () => CombinedConstraints([
            ConstraintContains('e'),
            ConstraintContains('t'),
          ]),
        );

      default:
        throw ArgumentError.value(
          difficulty,
          'difficulty',
          'Difficulty must be 1 or 2.',
        );
    }
  }

  /// Returns the first candidate from [buildCandidate] that the dictionary
  /// accepts, trying up to [maxAttempts] times. If none pass, returns the rule
  /// from [buildFallback], which is also validated.
  ///
  /// Throws a [StateError] if the fallback is invalid too.
  Constraint _createValidChallenge(
    Constraint Function() buildCandidate,
    Constraint Function() buildFallback,
  ) {
    // Try at most maxAttempts randomly generated candidates.
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final candidate = buildCandidate();

      if (dictionary.isChallengeValid(candidate)) {
        return candidate;
      }
    }

    // All random candidates failed validation.
    // Check the fallback rather than silently returning an invalid one.
    final fallback = buildFallback();

    if (!dictionary.isChallengeValid(fallback)) {
      throw StateError(
        'Could not generate a valid challenge after '
        '$maxAttempts attempts, and the fallback is also invalid.',
      );
    }

    return fallback;
  }

  /// Builds a rule made of two different single rules.
  Constraint _createCombinedChallenge() {
    final first = createChallenge();
    var second = createChallenge();
    // Avoid "end with W and end with W". Bounded, so it can never loop forever.
    for (var i = 0; i < 5 && second.description == first.description; i++) {
      second = createChallenge();
    }
    return CombinedConstraints([first, second]);
  }

  /// Builds one random single rule from [pool]. Not checked against the
  /// dictionary; [getChallenge] does that.
  Constraint createChallenge() {
    final random = gen.getRandom(0, pool.length - 1);
    final picked = pool[random];

    return picked();
  }
}
