import 'package:flutter/material.dart';

import '../data/game_database.dart';
import '../game/game_session.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_tile.dart';
import '../widgets/definition_sheet.dart';

/// Final score at or above this gets the victory jingle.
const double kVictoryScore = 35;

/// Shown after the last round: total score, saved stats (daily games only)
/// and one row per round. Tapping a row looks the word up in an online
/// dictionary.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    super.key,
    required this.session,
    required this.audio,
    this.saveFailed = false,
    this.database,
  });

  /// The finished game whose results are shown.
  final GameSession session;

  /// Plays the victory or boring jingle, then brings the ambience back.
  final AudioService audio;

  /// True if saving a daily game to the database failed.
  final bool saveFailed;

  /// Used to read best score and streak. Null for practice games.
  final GameDatabase? database;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  /// Saved stats for the status area. Resolves to null for practice games,
  /// failed saves, or if the stats could not be read.
  late final Future<GameStats?> _stats;

  @override
  void initState() {
    super.initState();

    _playResultSound();

    final database = widget.database;
    _stats =
        (database == null || widget.session.isPractice || widget.saveFailed)
        ? Future.value(null)
        : _loadStats(database);
  }

  /// Victory or boring jingle straight away, then the ambience returns after
  /// a silence break. If the jingle is cut off (the player starts a new game)
  /// the ambience is not started.
  Future<void> _playResultSound() async {
    final audio = widget.audio;

    // Compare the score as displayed (1 decimal): a screen showing "35.0"
    // must get the victory jingle, not "34.96 < 35".
    final score = double.parse(widget.session.finalScore.toStringAsFixed(1));

    final finished = score >= kVictoryScore
        ? await audio.playVictory()
        : await audio.playBoring();

    if (finished) audio.startAmbience(delay: AudioService.silenceBreak);
  }

  /// Reads the stats from [database], or returns null if that fails so the
  /// results screen still shows.
  Future<GameStats?> _loadStats(GameDatabase database) async {
    try {
      return await database.getStats(widget.session.dateKey);
    } catch (e) {
      debugPrint('Could not load stats: $e');
      return null;
    }
  }

  /// Opens a bottom sheet with the definition of [word].
  void _showDefinition(String word) {
    // Colours, shape and drag handle come from bottomSheetTheme in
    // app_theme.dart.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DefinitionSheet(word: word),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final textTheme = Theme.of(context).textTheme;
    final score = session.finalScore.toStringAsFixed(1);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                children: [
                  // The heading and score are read as one item.
                  Semantics(
                    header: true,
                    label: 'Game over. Final score $score',
                    excludeSemantics: true,
                    child: Column(
                      children: [
                        Text('Game over!', style: textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        Text(score, style: textTheme.displayMedium),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildStatus(),
                  const SizedBox(height: 20),
                  for (final result in session.results)
                    _RoundRow(
                      result: result,
                      onLookUp: () => _showDefinition(result.word),
                    ),
                ],
              ),
            ),
            // Fixed at the bottom, outside the scrolling list.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('Back to home'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Practice note, save warning, or the three saved-stat cards.
  Widget _buildStatus() {
    if (widget.session.isPractice) {
      return const _Note('Practice game: not saved to your stats.');
    }
    if (widget.saveFailed) {
      return const _Note('Could not save this game to your history.');
    }
    return FutureBuilder<GameStats?>(
      future: _stats,
      builder: (context, snapshot) {
        final stats = snapshot.data;
        // Show nothing while loading, or if the stats could not be read.
        if (stats == null) return const SizedBox.shrink();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatTile(
                label: 'Best',
                value: stats.bestScore.toStringAsFixed(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Streak',
                value:
                    '${stats.currentStreak} '
                    '${stats.currentStreak == 1 ? 'day' : 'days'}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(label: 'Played', value: '${stats.gamesPlayed}'),
            ),
          ],
        );
      },
    );
  }
}

/// A centred, muted line of text for short status messages.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge
          ?.copyWith(color: AppColors.inkMuted),
    );
  }
}

/// One round: word, rule, outcome and points. Validity is shown as an icon
/// AND text, never by colour alone. Card colour and shape come from cardTheme
/// in app_theme.dart.
class _RoundRow extends StatelessWidget {
  const _RoundRow({required this.result, required this.onLookUp});

  /// The round to display.
  final RoundResult result;

  /// Called when the player taps the row to see the word's definition.
  final VoidCallback onLookUp;

  /// Only real dictionary words can be looked up.
  bool get _canLookUp =>
      result.outcome != RoundOutcome.empty &&
      result.outcome != RoundOutcome.notAWord;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final word = result.word.isEmpty ? '(no word)' : result.word;
    final status = result.isValid ? 'Valid' : result.outcome.label;
    final points = result.points.toStringAsFixed(1);
    final mutedStyle = textTheme.bodyMedium?.copyWith(
      color: AppColors.inkMuted,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      // One screen-reader node for the whole row, with the tap action given
      // here because the card's own semantics are excluded.
      child: Semantics(
        button: _canLookUp,
        excludeSemantics: true,
        onTap: _canLookUp ? onLookUp : null,
        label:
            'Round ${result.round}. ${result.constraint}. '
            '${result.word.isEmpty ? 'No word entered' : result.word}. '
            '$status. $points points.'
            '${_canLookUp ? ' Double tap for the definition.' : ''}',
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _canLookUp ? onLookUp : null,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(word, style: textTheme.titleLarge)),
                      const SizedBox(width: 12),
                      Text(
                        '$points pts',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(result.constraint, style: mutedStyle),
                  const SizedBox(height: 12),
                  _StatusBadge(isValid: result.isValid, text: status),
                  if (_canLookUp) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.menu_book_outlined,
                          size: 18,
                          color: AppColors.inkMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Tap for definition', style: mutedStyle),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White pill with a green tick or red cross plus the outcome text. White
/// keeps the green and red text above 4.5:1 contrast.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isValid, required this.text});

  /// Chooses the green tick or the red cross.
  final bool isValid;

  /// The outcome text shown beside the icon.
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = isValid ? AppColors.valid : AppColors.invalid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
