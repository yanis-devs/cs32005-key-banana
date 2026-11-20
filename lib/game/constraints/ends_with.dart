import 'constraint.dart';

/// A rule requiring a word to end with a given letter, e.g. "Word must end with T".
class ConstraintEndsWith extends Constraint {
  /// The letter the word must end with.
  final String letter;

  ConstraintEndsWith(this.letter);

  /// The rule as shown to the player, with [letter] trimmed and uppercased.
  @override
  String get description => "Word must end with ${letter.trim().toUpperCase()}";

  /// True if [word] ends with [letter] (ignoring case and surrounding spaces).
  @override
  bool checkConstraint(String word) {
    return word[word.length - 1] == letter.trim().toLowerCase();
  }
}
