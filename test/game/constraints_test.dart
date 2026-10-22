
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_app/game/constraints/constraints_barrel.dart';


void main() {
  // ==========================================
  // 1. CONSTRAINT STARTS WITH
  // ==========================================
  group('ConstraintStartsWith', () {
    test('accepts a word starting with the required letter', () {
      final constraint = ConstraintStartsWith('A');

      expect(constraint.isAccepted('apple'), isTrue);
    });

    test('rejects a word starting with a different letter', () {
      final constraint = ConstraintStartsWith('A');

      expect(constraint.isAccepted('banana'), isFalse);
    });

    test('accepts uppercase and lowercase input', () {
      final constraint = ConstraintStartsWith('a');

      expect(constraint.isAccepted('Apple'), isTrue);
    });

    test('rejects an empty word', () {
      final constraint = ConstraintStartsWith('A');

      expect(constraint.isAccepted(''), isFalse);
    });

    test('handles surrounding whitespace in the word', () {
      final constraint = ConstraintStartsWith('A');

      expect(constraint.isAccepted('  apple  '), isTrue);
    });
  });

  // ==========================================
  // 2. CONSTRAINT CONTAINS
  // ==========================================
  group('ConstraintContains', () {
    test('accepts a word containing the required letter', () {
      final constraint = ConstraintContains('p');

      expect(constraint.isAccepted('apple'), isTrue);
    });

    test('rejects a word without the required letter', () {
      final constraint = ConstraintContains('z');

      expect(constraint.isAccepted('apple'), isFalse);
    });

    test('accepts uppercase and lowercase input', () {
      final constraint = ConstraintContains('A');

      expect(constraint.isAccepted('banana'), isTrue);
    });

    test('rejects an empty word', () {
      final constraint = ConstraintContains('a');

      expect(constraint.isAccepted(''), isFalse);
    });

    test('accepts a required letter at the beginning', () {
      final constraint = ConstraintContains('a');

      expect(constraint.isAccepted('apple'), isTrue);
    });

    test('accepts a required letter at the end', () {
      final constraint = ConstraintContains('e');

      expect(constraint.isAccepted('apple'), isTrue);
    });
  });

  // ==========================================
  // 3. CONSTRAINT ENDS WITH
  // ==========================================
  group('ConstraintEndsWith', () {
    test('accepts a word ending with the required letter', () {
      final constraint = ConstraintEndsWith('e');

      expect(constraint.isAccepted('apple'), isTrue);
    });

    test('rejects a word ending with a different letter', () {
      final constraint = ConstraintEndsWith('e');

      expect(constraint.isAccepted('apples'), isFalse);
    });

    test('accepts uppercase and lowercase input', () {
      final constraint = ConstraintEndsWith('E');

      expect(constraint.isAccepted('apple'), isTrue);
    });

    test('rejects an empty word', () {
      final constraint = ConstraintEndsWith('e');

      expect(constraint.isAccepted(''), isFalse);
    });

    test('accepts a single-letter word when it matches', () {
      final constraint = ConstraintEndsWith('a');

      expect(constraint.isAccepted('a'), isTrue);
    });
  });

  // ==========================================
  // 4. CONSTRAINT EXCLUDES
  // ==========================================
  group('ConstraintExcludes', () {
    test('accepts a word that excludes the forbidden letter', () {
      final constraint = ConstraintExcludes('z');

      expect(constraint.isAccepted('apple'), isTrue);
    });

    test('rejects a word containing the forbidden letter', () {
      final constraint = ConstraintExcludes('z');

      expect(constraint.isAccepted('zebra'), isFalse);
    });

    test('ignores letter case when checking the word', () {
      final constraint = ConstraintExcludes('a');

      expect(constraint.isAccepted('Apple'), isFalse);
    });

    test('rejects an empty word', () {
      final constraint = ConstraintExcludes('z');

      expect(constraint.isAccepted(''), isFalse);
    });

    test('accepts a word containing other letters', () {
      final constraint = ConstraintExcludes('x');

      expect(constraint.isAccepted('banana'), isTrue);
    });
  });

  // ==========================================
  // 5. CONSTRAINT LENGTH
  // ==========================================
  group('ConstraintLength', () {
    test('accepts a word with the required length', () {
      final constraint = ConstraintLength(5);

      expect(constraint.isAccepted('apple'), isTrue);
    });

    test('rejects a word that is too short', () {
      final constraint = ConstraintLength(5);

      expect(constraint.isAccepted('pear'), isFalse);
    });

    test('rejects a word that is too long', () {
      final constraint = ConstraintLength(5);

      expect(constraint.isAccepted('bananas'), isFalse);
    });

    test('rejects an empty word', () {
      final constraint = ConstraintLength(5);

      expect(constraint.isAccepted(''), isFalse);
    });

    test('accepts a single-letter word when length is one', () {
      final constraint = ConstraintLength(1);

      expect(constraint.isAccepted('a'), isTrue);
    });

    test('ignores surrounding whitespace when measuring length', () {
      final constraint = ConstraintLength(5);

      expect(constraint.isAccepted('  apple  '), isTrue);
    });
  });

  // ==========================================
  // 6. CONSTRAINT COMBINED
  // ==========================================
  //
  // See the note below before adding this group.
}
