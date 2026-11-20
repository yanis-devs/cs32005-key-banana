import 'package:flutter_test/flutter_test.dart';
import 'package:key_banana/data/streak.dart';

void main() {
  group('computeStreak', () {
    test('no games gives 0', () {
      expect(computeStreak([], 20261111), 0);
    });

    test('only today gives 1', () {
      expect(computeStreak([20261111], 20261111), 1);
    });

    test('three consecutive days ending today gives 3', () {
      expect(computeStreak([20261109, 20261110, 20261111], 20261111), 3);
    });

    test('order of the input does not matter', () {
      expect(computeStreak([20261111, 20261109, 20261110], 20261111), 3);
    });

    test('a gap ends the streak at the most recent run', () {
      expect(computeStreak([20261111, 20261108, 20261107], 20261111), 1);
    });

    test('not played yet today but yesterday counts: streak is alive', () {
      expect(computeStreak([20261109, 20261110], 20261111), 2);
    });

    test('last played two days ago resets to 0', () {
      expect(computeStreak([20261108, 20261109], 20261111), 0);
    });

    test('works across a month boundary', () {
      expect(computeStreak([20261130, 20261201], 20261201), 2);
    });

    test('works across a year boundary', () {
      expect(computeStreak([20261231, 20270101], 20270101), 2);
    });

    test('duplicate dates are counted once', () {
      expect(computeStreak([20261111, 20261111, 20261110], 20261111), 2);
    });
  });
}
