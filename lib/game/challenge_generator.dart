
import '../data/dictionary_service.dart';
import 'constraints/constraints_barrel.dart';
import 'seeded_random.dart';

class ChallengeGenerator {
  static const int maxAttempts = 20;

  String _letters = 'etaoinshrdlu';

  final SeededRandom gen;
  final DictionaryService dictionary;

  ChallengeGenerator._(this.gen, this.dictionary);

  static Future<ChallengeGenerator> create(
    DictionaryService dictionary,
  ) async {
    final rng = await SeededRandom.create();
    return ChallengeGenerator._(rng, dictionary);
  }

  late final List<Constraint Function()> pool = [
    () => ConstraintContains(getLetter()),
    () => ConstraintExcludes(getLetter()),
    () => ConstraintStartsWith(getLetter()),
    () => ConstraintEndsWith(getLetter()),
  ];

  String getLetter() {
    return _letters[gen.getRandom(0, _letters.length - 1)];
  }

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

  Constraint _createCombinedChallenge() {
    // Create a fresh list for every combination.
    return CombinedConstraints([
      createChallenge(),
      createChallenge(),
    ]);
  }

  Constraint createChallenge() {
    final random = gen.getRandom(0, pool.length - 1);
    final picked = pool[random];

    return picked();
  }
}
