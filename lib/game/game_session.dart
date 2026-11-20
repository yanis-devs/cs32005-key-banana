import '../data/dictionary_service.dart';
import 'challenge_generator.dart';
import 'constraints/constraints_barrel.dart';
import 'scoring.dart';

/// What happened to a submitted word. Stored in the database by name, so do
/// not rename the values after release.
enum RoundOutcome {
  /// The word is in the dictionary, follows the rule and was not used before.
  valid('Valid word'),

  /// Nothing was entered, e.g. the timer ran out with an empty box.
  empty('No word entered'),

  /// The word is not in the dictionary.
  notAWord('Not in the dictionary'),

  /// The word is real but does not satisfy the round's rule.
  breaksRule('Does not follow the rule'),

  /// The word already scored in an earlier round of this game.
  repeated('Already used this game');

  const RoundOutcome(this.label);

  /// Plain-text explanation for the results screen. Shown as text, never by
  /// colour alone, so it works for screen readers and colour-blind players.
  final String label;
}

/// The recorded result of one round.
class RoundResult {
  const RoundResult({
    required this.round,
    required this.constraint,
    required this.word,
    required this.outcome,
    required this.secondsLeft,
    required this.points,
  });

  /// 1-based round number.
  final int round;

  /// The rule text shown to the player, e.g. "Word must start with C".
  final String constraint;

  /// The submitted word, trimmed and lowercased ("" if nothing was entered).
  final String word;

  /// Why the word was accepted or rejected.
  final RoundOutcome outcome;

  /// Seconds left when the word was submitted, clamped to 0..roundSeconds.
  final double secondsLeft;

  /// This round's contribution to the final score (0 for invalid rounds).
  final double points;

  /// Whether the word was accepted and scored.
  bool get isValid => outcome == RoundOutcome.valid;
}

/// Rules and state of one game. Plain Dart: no Flutter, no timers.
///
/// The screen owns the clock and the UI. It reads [currentConstraint], then
/// calls [submitWord] once per round with the seconds left.
class GameSession {
  /// Number of rounds in a normal game.
  static const int defaultRounds = 7;

  /// Rounds 1..[easyRounds] use difficulty 1, the rest use difficulty 2.
  static const int easyRounds = 4;

  /// Time allowed per round, in seconds.
  static const double roundSeconds = 10;

  GameSession._(
    this._dictionary,
    this._constraints,
    this.dateKey,
    this.isPractice,
  );

  /// Builds a game and pre-generates every round's rule, so nothing heavy
  /// runs between rounds. Show a loading state while this runs.
  ///
  /// With no [seed], this is today's daily game (seeded by the UTC date).
  /// With a [seed], it is a practice game that must not be saved to stats.
  static Future<GameSession> create(
    DictionaryService dictionary, {
    int? seed,
  }) async {
    final generator = await ChallengeGenerator.create(dictionary, seed: seed);

    final constraints = <Constraint>[];
    for (var i = 0; i < defaultRounds; i++) {
      final difficulty = i < easyRounds ? 1 : 2;
      var candidate = generator.getChallenge(difficulty);
      // Avoid showing the same rule twice in one game (bounded retries).
      for (
        var t = 0;
        t < 10 &&
            constraints.any((c) => c.description == candidate.description);
        t++
      ) {
        candidate = generator.getChallenge(difficulty);
      }
      constraints.add(candidate);
    }

    return GameSession._(
      dictionary,
      List.unmodifiable(constraints),
      generator.gen.initialSeed,
      seed != null,
    );
  }

  /// A practice game with a different puzzle every time.
  ///
  /// The seed comes from the current time, wrapped to 32 bits to match the
  /// range of [SeededRandom].
  static Future<GameSession> createPractice(DictionaryService dictionary) {
    return create(
      dictionary,
      seed: DateTime.now().millisecondsSinceEpoch % 4294967296,
    );
  }

  /// Builds a game from explicit rules. Used by tests.
  factory GameSession.withConstraints(
    DictionaryService dictionary,
    List<Constraint> constraints, {
    int dateKey = 0,
    bool isPractice = true,
  }) {
    if (constraints.isEmpty) {
      throw ArgumentError('A game needs at least one round.');
    }
    return GameSession._(
      dictionary,
      List.unmodifiable(constraints),
      dateKey,
      isPractice,
    );
  }

  final DictionaryService _dictionary;

  /// One rule per round, in play order.
  final List<Constraint> _constraints;
  final Scoring _scoring = Scoring();

  /// Results of the rounds played so far.
  final List<RoundResult> _results = [];

  /// The seed used: the date as yyyymmdd for a daily game (e.g. 20261111).
  final int dateKey;

  /// Practice games are never saved to history or stats.
  final bool isPractice;

  /// Number of rounds in this game.
  int get totalRounds => _constraints.length;

  /// Whether every round has been played.
  bool get isFinished => _results.length >= totalRounds;

  /// 1-based number of the round being played (stays at the last round once
  /// the game is finished).
  int get currentRound => isFinished ? totalRounds : _results.length + 1;

  /// The rule for the round being played.
  ///
  /// Throws a [StateError] if the game is finished.
  Constraint get currentConstraint {
    if (isFinished) throw StateError('The game is finished.');
    return _constraints[_results.length];
  }

  /// Results of the rounds played so far, in order. The list cannot be
  /// modified.
  List<RoundResult> get results => List.unmodifiable(_results);

  /// Sum of every round's points so far.
  double get finalScore => _results.fold(0.0, (sum, r) => sum + r.points);

  /// Records the player's word for the current round and moves to the next.
  ///
  /// [secondsLeft] comes from the screen's timer; it is clamped to
  /// 0..[roundSeconds]. A timeout with an empty box is recorded as an empty
  /// round. Invalid words score 0.
  ///
  /// Throws a [StateError] if the game is finished.
  RoundResult submitWord(String rawWord, double secondsLeft) {
    if (isFinished) throw StateError('The game is finished.');

    final constraint = currentConstraint;
    final word = rawWord.trim().toLowerCase();
    // Guard against NaN, which clamp would pass through unchanged.
    final seconds = secondsLeft.isNaN
        ? 0.0
        : secondsLeft.clamp(0.0, roundSeconds).toDouble();

    final outcome = _judge(word, constraint);

    // Scoring.calculateFinalScore divides each word score by 10, so passing a
    // single score gives this round's contribution to the final total.
    final points = outcome == RoundOutcome.valid
        ? _scoring.calculateFinalScore([
            _scoring.calculateWordScore(word, seconds),
          ])
        : 0.0;

    final result = RoundResult(
      round: _results.length + 1,
      constraint: constraint.description,
      word: word,
      outcome: outcome,
      secondsLeft: seconds,
      points: points,
    );

    _results.add(result);
    return result;
  }

  /// Decides the outcome for [word] (already trimmed and lowercased).
  ///
  /// Cheapest checks first. A word only counts as a repeat if it scored
  /// earlier in this game.
  RoundOutcome _judge(String word, Constraint constraint) {
    if (word.isEmpty) return RoundOutcome.empty;
    if (!_dictionary.isWordValid(word)) return RoundOutcome.notAWord;
    if (!constraint.checkConstraint(word)) return RoundOutcome.breaksRule;
    if (_results.any((r) => r.isValid && r.word == word)) {
      return RoundOutcome.repeated;
    }
    return RoundOutcome.valid;
  }
}
