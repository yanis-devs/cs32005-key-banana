import 'constraint.dart';

/// A rule made of several rules at once. A word passes only if it satisfies
/// every one of them, e.g. "Word must start with C and end with T".
class CombinedConstraints extends Constraint {
  /// The rules that must all be satisfied.
  final List<Constraint> constraints;

  CombinedConstraints(this.constraints);

  /// The rules' descriptions joined with "and".
  ///
  /// For exactly two rules the repeated "Word must " prefix is dropped from
  /// the second, so the text reads as one sentence.
  @override
  String get description {
    if (constraints.length != 2) {
      return constraints.map((c) => c.description).join(' and ');
    }

    final first = constraints[0].description;
    // Drop the repeated "Word must " prefix from the second rule.
    final second = constraints[1].description.replaceFirst('Word must ', '');

    return '$first and $second';
  }

  /// True only if [word] satisfies every rule in [constraints].
  @override
  bool checkConstraint(String word) {
    return constraints.every((c) => c.checkConstraint(word));
  }
}
