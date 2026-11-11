import 'constraint.dart';

class CombinedConstraints extends Constraint {

  final List<Constraint> constraints;

  CombinedConstraints(this.constraints);

  @override
  String get description {
    if (constraints.length != 2) return constraints.map((c) => c.description).join(' and ');

    final first = constraints[0].description;
    // Replace the prefix "Word must " with an empty string on the second rule
    final second = constraints[1].description.replaceFirst('Word must ', '');

    return '$first and $second';
  }

  @override
  bool checkConstraint(String word) {
    return constraints.every((c) => c.checkConstraint(word));
  }
}
