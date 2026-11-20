/// Calculates points for individual words and the total score for a game.
class Scoring {
  /// Points earned for a valid [word] with [secondsRemaining] on the clock.
  ///
  /// Awards 10 points per letter plus 2 points for every second left.
  double calculateWordScore(String word, double secondsRemaining) =>
      (10 * word.length) + (2 * secondsRemaining);

  /// Combines all round [wordScores] into the final game score.
  ///
  /// Each round's score is divided by 10 before summing.
  double calculateFinalScore(List<double> wordScores) =>
      wordScores.fold(0.0, (sum, score) => sum + (score / 10));
}
