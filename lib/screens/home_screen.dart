import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/date_key.dart';
import '../data/dictionary_service.dart';
import '../data/game_database.dart';
import '../services/date_service.dart';
import '../game/game_session.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_tile.dart';
import 'game_screen.dart';
import 'stats_screen.dart';

/// Maximum vertical distance the logo moves from its resting position.
const double kHomeLogoFloatAmplitude = 6.0;

/// Time for one complete up-and-down cycle.
const Duration kHomeLogoFloatPeriod = Duration(milliseconds: 2400);

/// Minimum time the loading screen stays up after tapping "Play today's
/// challenge", so the click sound can play before the game starts.
/// Set it to the length of click_play.mp3 plus a small margin.
const Duration kDailyStartDelay = Duration(milliseconds: 1400);

/// Entry screen: the K-Banana logo, today's challenge date (from the time
/// API), saved stats, and buttons for the daily game, practice and the stats
/// screen.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.dictionary,
    required this.database,
    required this.audio,
    this.lockEnabled = true,
  });

  /// The word list, passed on to each new game.
  final DictionaryService dictionary;

  /// Saved game history, used for the stats and the "already played" check.
  final GameDatabase database;

  /// Plays the click, ambience and other sounds.
  final AudioService audio;

  /// False when the device has no screen lock, so the app is unprotected.
  final bool lockEnabled;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  /// True until the first attempt to load the date and stats finishes.
  bool _loadingInfo = true;

  /// True while a game is being set up, so a second tap is ignored.
  bool _starting = false;

  /// Drives the logo's floating animation.
  late final AnimationController _logoFloatController;

  /// The logo's current vertical offset, from the controller.
  late final Animation<double> _logoFloat;

  /// Last known "disable animations" setting, used to react only when it
  /// changes.
  bool? _logoAnimationsDisabled;

  int? _dateKey; // today's yyyymmdd, from the time API (or device fallback)
  GameStats? _stats;
  SavedGame? _todayGame; // set once today's daily game has been played

  @override
  void initState() {
    super.initState();

    // The controller only covers half a cycle; repeat(reverse: true) plays it
    // back and forth to make one full up-and-down period.
    _logoFloatController = AnimationController(
      vsync: this,
      duration: Duration(
        microseconds: kHomeLogoFloatPeriod.inMicroseconds ~/ 2,
      ),
    );

    _logoFloat =
        Tween<double>(
          begin: -kHomeLogoFloatAmplitude,
          end: kHomeLogoFloatAmplitude,
        ).animate(
          CurvedAnimation(
            parent: _logoFloatController,
            curve: Curves.easeInOut,
          ),
        );

    _loadInfo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final disableAnimations = MediaQuery.of(context).disableAnimations;

    if (disableAnimations == _logoAnimationsDisabled) return;

    _logoAnimationsDisabled = disableAnimations;

    // Respect the system "reduce motion" setting: hold the logo at its
    // resting position (0.5 is the midpoint of the tween) instead of floating.
    if (disableAnimations) {
      _logoFloatController
        ..stop()
        ..value = 0.5;
    } else {
      _logoFloatController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _logoFloatController.dispose();
    super.dispose();
  }

  /// Loads the date, stats and today's saved game. After a game, pass
  /// [refetchDate] false to skip the network and reuse the date already shown.
  Future<void> _loadInfo({bool refetchDate = true}) async {
    try {
      final key = (!refetchDate && _dateKey != null)
          ? _dateKey!
          : int.parse(await fetchDate());
      final stats = await widget.database.getStats(key);
      final todayGame = await widget.database.getDailyGame(key);

      if (!mounted) return;
      setState(() {
        _dateKey = key;
        _stats = stats;
        _todayGame = todayGame;
        _loadingInfo = false;
      });
    } catch (e) {
      debugPrint('Could not load home info: $e');
      if (mounted) setState(() => _loadingInfo = false);
    }
  }

  /// Shows [text] in a snackbar, replacing any one already showing.
  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Starts a practice game or today's daily game, then refreshes the stats
  /// when the player comes back. Ignored if a game is already starting.
  ///
  /// The daily game is blocked if it was already played today.
  Future<void> _start({required bool practice}) async {
    if (_starting) return;
    setState(() => _starting = true);

    if (!practice) unawaited(widget.audio.playClick()); // daily mode only
    final minWait = practice ? null : Future<void>.delayed(kDailyStartDelay);

    // Silent focus for the game: cut the opening, pause the ambience.
    unawaited(widget.audio.stopOpening());
    unawaited(widget.audio.stopResults());
    unawaited(widget.audio.pauseAmbience());

    try {
      // Building the session fetches the date and pre-generates all 7 rules.
      final session = practice
          ? await GameSession.createPractice(widget.dictionary)
          : await GameSession.create(widget.dictionary);

      // Second line of defence: the home screen already hides the daily button
      // once played, but the date is re-checked against the saved games.
      if (!practice) {
        final played = await widget.database.getDailyGame(session.dateKey);
        if (played != null) {
          if (!mounted) return;
          _showMessage(
            "You've already played today's challenge "
            '(score ${played.score.toStringAsFixed(1)}). '
            'Try practice mode, or come back tomorrow.',
          );
          await _loadInfo(refetchDate: false);
          return;
        }

        await minWait; // hold here until the minimum time has passed
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GameScreen(
            session: session,
            database: practice ? null : widget.database,
            audio: widget.audio,
          ),
        ),
      );

      // Back from the game: refresh stats and today's status.
      await _loadInfo(refetchDate: false);
    } catch (e) {
      debugPrint('Could not start the game: $e');
      if (mounted) {
        _showMessage('Could not start the game. Please try again.');
      }
    } finally {
      // Bring the ambience back, unless a result jingle is still playing
      // (it starts the ambience itself when it ends).
      if (!widget.audio.isResultPlaying) {
        widget.audio.startAmbience(delay: AudioService.silenceBreak);
      }

      if (mounted) setState(() => _starting = false);
    }
  }

  /// Opens the stats screen. If the opening jingle was still playing it is
  /// cut off and the ambience starts instead.
  void _openStats() {
    final openingWasPlaying = widget.audio.isOpeningPlaying;

    unawaited(widget.audio.stopOpening());

    if (openingWasPlaying) {
      widget.audio.startAmbience(delay: AudioService.silenceBreak);
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            StatsScreen(database: widget.database, todayKey: _dateKey),
      ),
    );
  }

  void _toggleMute() {
    unawaited(widget.audio.setMuted(!widget.audio.isMuted));
    setState(() {}); // isMuted is already updated, so the icon redraws
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mute toggle button positioned top-right above the logo
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      iconSize: 30,
                      tooltip: widget.audio.isMuted
                          ? 'Turn sound on'
                          : 'Turn sound off',
                      icon: Icon(
                        widget.audio.isMuted
                            ? Icons.volume_off
                            : Icons.volume_up,
                      ),
                      onPressed: _toggleMute,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // The logo is the screen's heading. One screen-reader node
                  // reading "K-Banana"; the picture itself is hidden from it.
                  Semantics(
                    header: true,
                    label: 'K-Banana',
                    excludeSemantics: true,
                    child: AnimatedBuilder(
                      animation: _logoFloat,
                      child: SvgPicture.asset(
                        'assets/images/kbanana.svg',
                        height: 128,
                        fit: BoxFit.contain,
                      ),
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _logoFloat.value),
                          child: child,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDateLine(),
                  const SizedBox(height: 28),
                  _buildStats(),
                  _buildActions(),
                  // Warn when the device has no screen lock.
                  if (!widget.lockEnabled) ...[
                    const SizedBox(height: 24),
                    Text(
                      "No screen lock is set on this device, so the app isn't "
                      'locked. Set one in Android settings to protect your '
                      'history.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
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

  /// "Today's challenge: [date]", a checking message while loading, or
  /// nothing if the date could not be loaded.
  Widget _buildDateLine() {
    final String text;
    if (_dateKey != null) {
      text = "Today's challenge: ${formatDateKey(_dateKey!)}";
    } else if (_loadingInfo) {
      text = "Checking today's date…";
    } else {
      text = '';
    }

    return Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge
          ?.copyWith(color: AppColors.inkMuted),
    );
  }

  /// Best score, streak and games played. Hidden until at least one game has
  /// been saved.
  Widget _buildStats() {
    final stats = _stats;
    if (stats == null || stats.gamesPlayed == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          StatTile(label: 'Best', value: stats.bestScore.toStringAsFixed(1)),
          StatTile(
            label: 'Streak',
            value:
                '${stats.currentStreak} '
                '${stats.currentStreak == 1 ? 'day' : 'days'}',
          ),
          StatTile(label: 'Played', value: '${stats.gamesPlayed}'),
        ],
      ),
    );
  }

  /// The buttons for the daily game, practice and stats, or a loading
  /// spinner while a game is starting.
  Widget _buildActions() {
    if (_starting) {
      return Center(
        child: Semantics(
          label: 'Loading',
          child: const CircularProgressIndicator(),
        ),
      );
    }

    final todayGame = _todayGame;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main action: solid banana yellow. Replaced by a "complete" card
        // once today's game has been played.
        if (todayGame != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.yellowSoft,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.gold, width: 1.5),
            ),
            child: Text(
              "Today's challenge complete\n"
              'Score: ${todayGame.score.toStringAsFixed(1)}\n'
              'Come back tomorrow for a new one!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          )
        else
          ElevatedButton(
            onPressed: () => _start(practice: false),
            child: const Text("Play today's challenge"),
          ),
        const SizedBox(height: 16),
        // Secondary actions: pale fill, golden outline (OutlinedButton is
        // styled that way in app_theme.dart).
        OutlinedButton(
          onPressed: () => _start(practice: true),
          child: const Text('Practice'),
        ),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: _openStats, child: const Text('My stats')),
      ],
    );
  }
}
