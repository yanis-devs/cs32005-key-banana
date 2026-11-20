import 'package:flutter_test/flutter_test.dart';
import 'package:key_banana/game/scoring.dart';

void main() {
  late Scoring scoring;

  setUp(() => scoring = Scoring());

  // ==========================================
  // 1. WORD SCORE
  // ==========================================
  group('calculateWordScore', () {
    test('is 10 per letter plus 2 per second remaining', () {
      // 3 letters * 10 + 6 seconds * 2 = 42
      expect(scoring.calculateWordScore('cat', 6), closeTo(42, 1e-9));
    });

    test('a full-time word gets the maximum time bonus', () {
      // 5 letters * 10 + 10 seconds * 2 = 70
      expect(scoring.calculateWordScore('apple', 10), closeTo(70, 1e-9));
    });

    test('with no time left only the letters count', () {
      expect(scoring.calculateWordScore('apple', 0), closeTo(50, 1e-9));
    });

    test('an empty word with no time left scores 0', () {
      expect(scoring.calculateWordScore('', 0), 0);
    });

    test('each extra letter adds exactly 10 points', () {
      final short = scoring.calculateWordScore('cat', 5);
      final long = scoring.calculateWordScore('cats', 5);

      expect(long - short, closeTo(10, 1e-9));
    });

    test('each extra second adds exactly 2 points', () {
      final slow = scoring.calculateWordScore('cat', 4);
      final fast = scoring.calculateWordScore('cat', 5);

      expect(fast - slow, closeTo(2, 1e-9));
    });

    test('fractional seconds are scored fractionally', () {
      // 3 * 10 + 2.5 * 2 = 35
      expect(scoring.calculateWordScore('cat', 2.5), closeTo(35, 1e-9));
    });

    test('a longer slow word beats a shorter fast word', () {
      final longSlow = scoring.calculateWordScore('banana', 0); // 60
      final shortFast = scoring.calculateWordScore('cat', 10); // 50

      expect(longSlow, greaterThan(shortFast));
    });

    // Pins current behaviour: Scoring does not clamp. GameSession clamps the
    // seconds to 0..10 before calling it.
    test('does not clamp out-of-range seconds itself', () {
      expect(scoring.calculateWordScore('cat', -5), closeTo(20, 1e-9));
      expect(scoring.calculateWordScore('cat', 50), closeTo(130, 1e-9));
    });
  });

  // ==========================================
  // 2. FINAL SCORE
  // ==========================================
  group('calculateFinalScore', () {
    test('no scores gives 0', () {
      expect(scoring.calculateFinalScore([]), 0);
    });

    test('divides a single word score by 10', () {
      expect(scoring.calculateFinalScore([42]), closeTo(4.2, 1e-9));
    });

    test('adds up the word scores after dividing each by 10', () {
      // 4.2 + 7.0 = 11.2
      expect(scoring.calculateFinalScore([42, 70]), closeTo(11.2, 1e-9));
    });

    test('zero-scoring rounds add nothing', () {
      expect(scoring.calculateFinalScore([0, 42, 0]), closeTo(4.2, 1e-9));
    });

    test('the order of the scores does not matter', () {
      final forward = scoring.calculateFinalScore([10, 20, 30]);
      final backward = scoring.calculateFinalScore([30, 20, 10]);

      expect(forward, closeTo(backward, 1e-9));
    });

    test('is the same as dividing the total by 10', () {
      const scores = <double>[42, 70, 33.5, 0, 58];
      final total = scores.reduce((a, b) => a + b);

      expect(scoring.calculateFinalScore(scores), closeTo(total / 10, 1e-9));
    });
  });

  // ==========================================
  // 3. HOW GAMESESSION USES THEM
  // ==========================================
  group('one round, as GameSession scores it', () {
    // GameSession passes a single word score to calculateFinalScore, so a
    // round is worth (10 * letters + 2 * seconds) / 10 points.
    test('a round is worth letters + 0.2 per second', () {
      final points = scoring.calculateFinalScore([
        scoring.calculateWordScore('cat', 6),
      ]);

      expect(points, closeTo(3 + 0.2 * 6, 1e-9));
    });
  });
}
