import 'constraint.dart';

/// A rule requiring a word not to contain a given letter, e.g. "Word must exclude Z".
class ConstraintExcludes extends Constraint {
  /// The letter the word must not contain.
  final String letter;

  ConstraintExcludes(this.letter);

  /// The rule as shown to the player, with [letter] trimmed and uppercased.
  @override
  String get description => "Word must exclude ${letter.trim().toUpperCase()}";

  /// True if [word] does not contain [letter] (ignoring case).
  @override
  bool checkConstraint(String word) {
    return !word.contains(letter.toLowerCase());
  }
}
