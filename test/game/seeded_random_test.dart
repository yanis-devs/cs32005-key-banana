import 'package:flutter_test/flutter_test.dart';
import 'package:key_banana/game/seeded_random.dart';

/// Builds a generator from a fixed seed. Passing a seed never touches the
/// network, so these tests run offline.
Future<SeededRandom> seeded(int seed) => SeededRandom.create(seed: seed);

void main() {
  // ==========================================
  // 1. CREATION AND SEED
  // ==========================================
  group('create', () {
    test('remembers the seed it started from', () async {
      final rng = await seeded(20261111);

      expect(rng.initialSeed, 20261111);
    });

    test('initialSeed does not change as numbers are drawn', () async {
      final rng = await seeded(20261111);

      rng.getRandom(1, 100);
      rng.getRandom(1, 100);

      expect(rng.initialSeed, 20261111);
    });
  });

  // ==========================================
  // 2. DETERMINISM
  // ==========================================
  group('determinism', () {
    test('the same seed gives the same sequence', () async {
      final a = await seeded(20261111);
      final b = await seeded(20261111);

      final fromA = [for (var i = 0; i < 50; i++) a.getRandom(1, 100)];
      final fromB = [for (var i = 0; i < 50; i++) b.getRandom(1, 100)];

      expect(fromA, fromB);
    });

    test('different seeds give different sequences', () async {
      final a = await seeded(20261111);
      final b = await seeded(20261112);

      final fromA = [for (var i = 0; i < 20; i++) a.getRandom(1, 100)];
      final fromB = [for (var i = 0; i < 20; i++) b.getRandom(1, 100)];

      expect(fromA, isNot(fromB));
    });

    test('consecutive date seeds do not start with the same number', () async {
      // Without the warm-up, consecutive seeds gave near-identical first draws.
      final today = await seeded(20261111);
      final tomorrow = await seeded(20261112);

      expect(today.getRandom(1, 100), isNot(tomorrow.getRandom(1, 100)));
    });

    test(
      '30 consecutive date seeds produce all four first-rule slots',
      () async {
        // Rule kinds are picked with getRandom(0, 3), so over a month every
        // kind should appear as the first pick.
        final firstPicks = <int>{};
        for (var day = 0; day < 30; day++) {
          final rng = await seeded(20261111 + day);
          firstPicks.add(rng.getRandom(0, 3));
        }

        expect(firstPicks, {0, 1, 2, 3});
      },
    );
  });

  // ==========================================
  // 3. PINNED OUTPUTS
  // ==========================================
  //
  // These values are fixed on purpose. If one fails, the generator constants,
  // the warm-up or the scaling changed, and EVERY daily puzzle changes with
  // it. Only update them if that is truly intended.
  group('pinned outputs', () {
    test('raw values for seed 0', () async {
      final rng = await seeded(0);

      expect(
        [rng.generateRandom(), rng.generateRandom(), rng.generateRandom()],
        [3421909937, 3167820124, 2636375307],
      );
    });

    test('raw values for seed 1', () async {
      final rng = await seeded(1);

      expect(
        [rng.generateRandom(), rng.generateRandom(), rng.generateRandom()],
        [1075679462, 1814098701, 2536995080],
      );
    });

    test('raw values for the seed 20261111', () async {
      final rng = await seeded(20261111);

      expect(
        [rng.generateRandom(), rng.generateRandom(), rng.generateRandom()],
        [2239392212, 528796451, 2508731942],
      );
    });

    test('getRandom(1, 100) for seed 0', () async {
      final rng = await seeded(0);

      expect(
        [for (var i = 0; i < 5; i++) rng.getRandom(1, 100)],
        [80, 74, 62, 89, 1],
      );
    });

    test('getRandom(1, 100) for seed 20261111', () async {
      final rng = await seeded(20261111);

      expect(
        [for (var i = 0; i < 5; i++) rng.getRandom(1, 100)],
        [53, 13, 59, 39, 21],
      );
    });

    test('getRandom(1, 100) for seed 20261112', () async {
      final rng = await seeded(20261112);

      expect(
        [for (var i = 0; i < 5; i++) rng.getRandom(1, 100)],
        [98, 81, 57, 35, 44],
      );
    });

    test(
      'getRandom(0, 11), the letter picker range, for seed 20261111',
      () async {
        final rng = await seeded(20261111);

        expect(
          [for (var i = 0; i < 5; i++) rng.getRandom(0, 11)],
          [6, 1, 7, 4, 2],
        );
      },
    );
  });

  // ==========================================
  // 4. RAW VALUES
  // ==========================================
  group('generateRandom', () {
    test('stays inside 0 up to (not including) 2^32', () async {
      final rng = await seeded(20261111);

      for (var i = 0; i < 1000; i++) {
        final value = rng.generateRandom();
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThan(4294967296));
      }
    });

    test('does not repeat the same value twice in a row', () async {
      final rng = await seeded(20261111);

      var previous = rng.generateRandom();
      for (var i = 0; i < 1000; i++) {
        final next = rng.generateRandom();
        expect(next, isNot(previous));
        previous = next;
      }
    });
  });

  // ==========================================
  // 5. getRandom RANGE
  // ==========================================
  group('getRandom', () {
    test('always stays within min and max, inclusive', () async {
      final rng = await seeded(42);

      for (var i = 0; i < 2000; i++) {
        final value = rng.getRandom(1, 100);
        expect(value, inInclusiveRange(1, 100));
      }
    });

    test('works with a negative range', () async {
      final rng = await seeded(7);

      final values = [for (var i = 0; i < 2000; i++) rng.getRandom(-5, 5)];

      expect(values.every((v) => v >= -5 && v <= 5), isTrue);
      expect(values.reduce((a, b) => a < b ? a : b), -5);
      expect(values.reduce((a, b) => a > b ? a : b), 5);
    });

    test('returns min when min equals max', () async {
      final rng = await seeded(5);

      expect([for (var i = 0; i < 3; i++) rng.getRandom(7, 7)], [7, 7, 7]);
    });

    test('hits both ends of a small range', () async {
      final rng = await seeded(42);

      final seen = {for (var i = 0; i < 200; i++) rng.getRandom(0, 3)};

      expect(seen, {0, 1, 2, 3});
    });

    test('spreads values roughly evenly across a range', () async {
      final rng = await seeded(42);
      final counts = List<int>.filled(4, 0);

      for (var i = 0; i < 4000; i++) {
        counts[rng.getRandom(0, 3)]++;
      }

      // 1000 expected per slot. A wide margin keeps this stable.
      for (final count in counts) {
        expect(count, inInclusiveRange(800, 1200));
      }
    });

    test('throws when min is greater than max', () async {
      final rng = await seeded(42);

      expect(() => rng.getRandom(10, 1), throwsArgumentError);
    });

    test('a failed call does not advance the generator', () async {
      final a = await seeded(42);
      final b = await seeded(42);

      expect(() => a.getRandom(10, 1), throwsArgumentError);

      expect(a.getRandom(1, 100), b.getRandom(1, 100));
    });
  });
}
