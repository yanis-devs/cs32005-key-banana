class Scoring {
  double calculateWordScore(String word, double secondsRemaining) =>
      (10 * word.length) + (2 * secondsRemaining);

  double calculateFinalScore(List<double> wordScores) =>
      wordScores.fold(0.0, (sum, score) => sum + (score / 10));
}