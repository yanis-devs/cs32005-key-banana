import 'constraint.dart';

class ConstraintExcludes extends Constraint {

  final String letter;

  ConstraintExcludes(this.letter);

  @override
  String get description => "Word must exclude $letter";

  @override
  bool checkConstraint(String word){
    return !word.contains(letter.toLowerCase());
  }
}
