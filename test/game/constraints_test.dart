import 'package:flutter_test/flutter_test.dart';
import 'package:key_banana/game/constraints/constraints_barrel.dart';

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
  // 5. CONSTRAINT COMBINED
  // ==========================================
  group('CombinedConstraints', () {
    test('two rules read as one sentence, dropping the second "Word must"', () {
      final constraint = CombinedConstraints([
        ConstraintContains('e'),
        ConstraintContains('t'),
      ]);

      expect(constraint.description, 'Word must contain E and contain T');
    });

    test('works with different rule types in the description', () {
      final constraint = CombinedConstraints([
        ConstraintStartsWith('c'),
        ConstraintEndsWith('t'),
      ]);

      expect(constraint.description, 'Word must start with C and end with T');
    });

    test('with other than two rules, full descriptions are joined', () {
      // The game only builds pairs. This pins the current fallback behaviour.
      final constraint = CombinedConstraints([
        ConstraintContains('e'),
        ConstraintContains('t'),
        ConstraintStartsWith('s'),
      ]);

      expect(
        constraint.description,
        'Word must contain E and Word must contain T and '
        'Word must start with S',
      );
    });

    test('accepts a word that satisfies every rule', () {
      final constraint = CombinedConstraints([
        ConstraintContains('e'),
        ConstraintContains('t'),
      ]);

      expect(constraint.isAccepted('tree'), isTrue);
    });

    test('rejects a word that satisfies only the first rule', () {
      final constraint = CombinedConstraints([
        ConstraintContains('e'),
        ConstraintContains('t'),
      ]);

      expect(constraint.isAccepted('apple'), isFalse);
    });

    test('rejects a word that satisfies only the second rule', () {
      final constraint = CombinedConstraints([
        ConstraintContains('e'),
        ConstraintContains('t'),
      ]);

      expect(constraint.isAccepted('cat'), isFalse);
    });

    test('rejects a word that satisfies neither rule', () {
      final constraint = CombinedConstraints([
        ConstraintContains('e'),
        ConstraintContains('t'),
      ]);

      expect(constraint.isAccepted('banana'), isFalse);
    });

    test('rule order does not change the result', () {
      final forward = CombinedConstraints([
        ConstraintStartsWith('a'),
        ConstraintEndsWith('e'),
      ]);
      final backward = CombinedConstraints([
        ConstraintEndsWith('e'),
        ConstraintStartsWith('a'),
      ]);

      for (final word in ['apple', 'apples', 'banana', 'axe']) {
        expect(forward.isAccepted(word), backward.isAccepted(word));
      }
    });

    test('combines a start rule and an end rule', () {
      final constraint = CombinedConstraints([
        ConstraintStartsWith('a'),
        ConstraintEndsWith('e'),
      ]);

      expect(constraint.isAccepted('apple'), isTrue);
      expect(constraint.isAccepted('apples'), isFalse);
      expect(constraint.isAccepted('eagle'), isFalse);
    });

    test('combines an exclude rule with a contain rule', () {
      final constraint = CombinedConstraints([
        ConstraintContains('a'),
        ConstraintExcludes('e'),
      ]);

      expect(constraint.isAccepted('banana'), isTrue);
      expect(constraint.isAccepted('apple'), isFalse);
    });

    test('ignores case and surrounding whitespace in the word', () {
      final constraint = CombinedConstraints([
        ConstraintContains('e'),
        ConstraintContains('t'),
      ]);

      expect(constraint.isAccepted('  TREE '), isTrue);
    });

    test('rejects an empty word', () {
      final constraint = CombinedConstraints([
        ConstraintContains('e'),
        ConstraintContains('t'),
      ]);

      expect(constraint.isAccepted(''), isFalse);
    });
  });
}
