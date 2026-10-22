import 'constraint.dart';

class ConstraintEndsWith extends Constraint {

  final String letter;

  ConstraintEndsWith(this.letter);

  @override
  String get description => "Word must end with $letter";

  @override
  bool checkConstraint(String word){
    return word[word.length - 1] == letter.trim().toLowerCase();
  }
}
