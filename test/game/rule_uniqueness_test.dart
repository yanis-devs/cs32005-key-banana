import 'package:flutter_test/flutter_test.dart';
import 'package:key_banana/data/dictionary_service.dart';
import 'package:key_banana/game/game_session.dart';

void main() {
  // Every 3-letter combination: far more than the 100 matching words any rule
  // needs to pass the validity check, so no round falls back to a default.
  const alphabet = 'abcdefghijklmnopqrstuvwxyz';
  final letters = alphabet.split('');
  final dictionary = DictionaryService.fromWords({
    for (final a in letters)
      for (final b in letters)
        for (final c in letters) '$a$b$c',
  });

  test('no rule repeats in a game and no combined rule doubles up', () async {
    for (var seed = 1; seed <= 300; seed++) {
      final session = await GameSession.create(dictionary, seed: seed);

      final rules = <String>[];
      while (!session.isFinished) {
        rules.add(session.currentConstraint.description);
        session.submitWord('', 0); // moves on to the next round
      }

      expect(rules.length, GameSession.defaultRounds);
      expect(
        rules.toSet().length,
        rules.length,
        reason: 'seed $seed repeated a rule: $rules',
      );

      for (final rule in rules) {
        final parts = rule.split(' and ');
        if (parts.length == 2) {
          expect(
            parts[0].replaceFirst('Word must ', ''),
            isNot(parts[1]),
            reason: 'seed $seed doubled a half: "$rule"',
          );
        }
      }
    }
  });

  test('the same seed always gives the same rules', () async {
    Future<List<String>> rulesFor(int seed) async {
      final session = await GameSession.create(dictionary, seed: seed);
      final rules = <String>[];
      while (!session.isFinished) {
        rules.add(session.currentConstraint.description);
        session.submitWord('', 0);
      }
      return rules;
    }

    expect(await rulesFor(20261115), await rulesFor(20261115));
  });
}
