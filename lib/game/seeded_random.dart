import '/services/date_service.dart';

/// Deterministic random generator (a linear congruential generator).
///
/// Seeded with the UTC date (yyyymmdd), so every player gets the same
/// sequence on the same day. Do not change the constants, the warm-up or the
/// scaling in `getRandom` after release: any change alters every daily puzzle.
class SeededRandom {
  /// Standard LCG constants (the Numerical Recipes pair).
  static const int _multiplier = 1664525;
  static const int _increment = 1013904223;
  static const int _modulus = 4294967296; // 2^32

  /// Outputs discarded right after seeding. Consecutive date seeds
  /// (20261111, 20261112, ...) differ by 1, and after a single LCG step the
  /// outputs still differ by only ~0.04% of the range. Without this warm-up
  /// the first rule would be nearly identical every day.
  static const int _warmUpDraws = 10;

  /// The seed this generator started from. The game session uses it as the
  /// date key for "played today" checks and stored history.
  final int initialSeed;

  /// The current internal value, advanced by every call to [generateRandom].
  int _state;

  SeededRandom._(int seed) : initialSeed = seed, _state = seed {
    // Skip the first few outputs so nearby seeds diverge (see _warmUpDraws).
    for (var i = 0; i < _warmUpDraws; i++) {
      generateRandom();
    }
  }

  /// Creates a generator.
  ///
  /// With no [seed], it uses today's UTC date from `fetchDate()` (daily game).
  /// Pass a [seed] for practice mode and for deterministic tests.
  static Future<SeededRandom> create({int? seed}) async {
    final resolvedSeed = seed ?? int.parse(await fetchDate());
    return SeededRandom._(resolvedSeed);
  }

  /// Advances the generator and returns the next raw value in [0, 2^32).
  int generateRandom() {
    _state = (_multiplier * _state + _increment) % _modulus;
    return _state;
  }

  /// Returns an integer in [min, max], inclusive.
  ///
  /// Scales the whole 32-bit value instead of using `%`, because the low bits
  /// of an LCG are much less random than the high bits.
  ///
  /// Throws an [ArgumentError] if [min] is greater than [max].
  int getRandom(int min, int max) {
    if (min > max) {
      throw ArgumentError('min cannot be greater than max');
    }

    final int targetRange = max - min + 1;
    return min + (generateRandom() * targetRange ~/ _modulus);
  }
}
