import 'constraint.dart';

class ConstraintStartsWith extends Constraint {

  final String letter;

  ConstraintStartsWith(this.letter);

  @override
  String get description => "Word must start with $letter";

  @override
  bool checkConstraint(String word){
    return word[0] == letter.trim().toLowerCase();
  }
}
