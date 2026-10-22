import 'constraint.dart';

class ConstraintLength extends Constraint {

  final int length;

  ConstraintLength(this.length);

  @override
  String get description => "Word must have $length letters";

  @override
  bool checkConstraint(String word){
    return word.length == length;
  }
}
