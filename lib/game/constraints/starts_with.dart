import 'constraint.dart';

/// A rule requiring a word to start with a given letter, e.g. "Word must start with C".
class ConstraintStartsWith extends Constraint {
  /// The letter the word must start with.
  final String letter;

  ConstraintStartsWith(this.letter);

  /// The rule as shown to the player, with [letter] trimmed and uppercased.
  @override
  String get description =>
      "Word must start with ${letter.trim().toUpperCase()}";

  /// True if [word] starts with [letter] (ignoring case and surrounding spaces).
  @override
  bool checkConstraint(String word) {
    return word[0] == letter.trim().toLowerCase();
  }
}
