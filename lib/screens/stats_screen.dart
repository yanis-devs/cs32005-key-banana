import 'package:flutter/material.dart';

import '../data/date_key.dart';
import '../data/game_database.dart';
import '../services/date_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_tile.dart';

/// Everything the stats screen needs, loaded together so the screen can
/// show a single loading state.
class _StatsData {
  const _StatsData(this.stats, this.history);

  /// Totals and streak.
  final GameStats stats;

  /// The most recent saved games, newest first.
  final List<SavedGame> history;
}

/// Totals, streak and the last 10 daily games, read from the local database.
/// The AppBar's back arrow returns to the home screen.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.database, this.todayKey});

  /// Saved game history to read from.
  final GameDatabase database;

  /// Today's yyyymmdd. If null, it is fetched here.
  final int? todayKey;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  /// The stats and history, loaded once when the screen opens.
  late final Future<_StatsData> _data = _load();

  /// Reads the stats and the 10 most recent games from the database.
  Future<_StatsData> _load() async {
    final todayKey = widget.todayKey ?? int.parse(await fetchDate());
    final stats = await widget.database.getStats(todayKey);
    final history = await widget.database.getHistory(limit: 10);
    return _StatsData(stats, history);
  }

  @override
  Widget build(BuildContext context) {
    final mutedStyle = Theme.of(context).textTheme.bodyLarge
        ?.copyWith(color: AppColors.inkMuted);

    return Scaffold(
      appBar: AppBar(title: const Text('My stats')),
      body: SafeArea(
        child: FutureBuilder<_StatsData>(
          future: _data,
          builder: (context, snapshot) {
            // Error, then loading, then empty history, then the real content.
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load your stats.',
                    textAlign: TextAlign.center,
                    style: mutedStyle,
                  ),
                ),
              );
            }

            final data = snapshot.data;
            if (data == null) {
              return Center(
                child: Semantics(
                  label: 'Loading',
                  child: const CircularProgressIndicator(),
                ),
              );
            }

            if (data.stats.gamesPlayed == 0) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No games yet. Play the daily challenge to start your '
                    'history.',
                    textAlign: TextAlign.center,
                    style: mutedStyle,
                  ),
                ),
              );
            }

            return _buildContent(context, data);
          },
        ),
      ),
    );
  }

  /// The stat tiles followed by the list of recent games.
  Widget _buildContent(BuildContext context, _StatsData data) {
    final stats = data.stats;
    final textTheme = Theme.of(context).textTheme;
    final lastScore = stats.lastScore;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Three equal columns.
        Row(
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
        ),
        // Last score sits centred underneath, in the middle column.
        if (lastScore != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: SizedBox.shrink()),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Last score',
                  value: lastScore.toStringAsFixed(1),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ],
        const SizedBox(height: 28),
        Semantics(
          header: true,
          child: Text('Recent games', style: textTheme.titleLarge),
        ),
        const SizedBox(height: 8),
        for (final game in data.history) _GameRow(game: game),
      ],
    );
  }
}

/// One past daily game: date on the left, score on the right.
class _GameRow extends StatelessWidget {
  const _GameRow({required this.game});

  /// The saved game to display.
  final SavedGame game;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final date = formatDateKey(game.dateKey);
    final score = game.score.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      // The row is read as a single item, e.g. "14 Nov 2026, score 42.3".
      child: Semantics(
        label: '$date, score $score',
        excludeSemantics: true,
        // Card colour and shape come from cardTheme in app_theme.dart.
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Expanded(child: Text(date, style: textTheme.titleMedium)),
                const SizedBox(width: 12),
                Text(score, style: textTheme.titleLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
