import 'constraint.dart';

/// A rule requiring a word to contain a given letter, e.g. "Word must contain E".
class ConstraintContains extends Constraint {
  /// The letter the word must contain.
  final String letter;

  ConstraintContains(this.letter);

  /// The rule as shown to the player, with [letter] trimmed and uppercased.
  @override
  String get description => "Word must contain ${letter.trim().toUpperCase()}";

  /// True if [word] contains [letter] (ignoring case and surrounding spaces).
  @override
  bool checkConstraint(String word) {
    return word.contains(letter.trim().toLowerCase());
  }
}
