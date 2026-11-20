/// A rule a word must satisfy, e.g. "Word must start with C".
///
/// Subclasses supply the player-facing [description] and the check itself in
/// [checkConstraint]. A [CombinedConstraints] joins several of these into one.
abstract class Constraint {
  /// The rule as shown to the player, e.g. "Word must start with C".
  String get description;

  /// Cleans [word] (trimmed, lowercased) and then checks it against the rule.
  /// An empty word is never accepted.
  ///
  /// Use this for raw player input. [checkConstraint] expects a word that is
  /// already clean.
  bool isAccepted(String word) {
    String cleanedWord = word.trim().toLowerCase();

    if (cleanedWord.isEmpty) return false;

    return checkConstraint(cleanedWord);
  }

  /// Whether [word] satisfies this rule. [word] must already be lowercase and
  /// non-empty, because some rules index into it directly.
  bool checkConstraint(String word);
}
