import 'constraint.dart';

class ConstraintContains extends Constraint {

  final String letter;

  ConstraintContains(this.letter);

  @override
  String get description => "Word must contain $letter";

  @override
  bool checkConstraint(String word){
    return word.contains(letter.trim().toLowerCase());
  }
}
