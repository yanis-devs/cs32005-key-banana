
abstract class Constraint {

  // A description to display to the player.
    String get description;

    bool isAccepted(String word){
        String cleanedWord = word.trim().toLowerCase();

        if (cleanedWord.isEmpty) return false;
        
        return checkConstraint(cleanedWord);
    }

  // Checks whether a word satisfies this constraint.
    bool checkConstraint(String word);


}
