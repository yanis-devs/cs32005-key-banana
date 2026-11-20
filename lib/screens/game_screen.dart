import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../data/game_database.dart';

import '../game/game_session.dart';
import '../services/audio_service.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';

import '../widgets/constraint_card.dart';
import '../widgets/timer_bar.dart';

import 'results_screen.dart';

/// Longest word the box accepts. Input validation: stops absurd input.
const int kMaxWordLength = 30;

/// How long the neutral "word captured" cue plays.
const Duration kCaptureCue = Duration(milliseconds: 450);

/// Total pause between rounds, measured from the moment the word is captured.
/// The new timer only starts after this, so the pause never costs player time.
const Duration kRoundPause = Duration(milliseconds: 1200);

/// Delay before reading the box after the timer hits zero, so the keyboard can
/// commit the final keystroke.
const Duration kAutoSubmitDelay = Duration(milliseconds: 300);

/// Seconds left at which a screen reader announces the time. The start of the
/// round is covered by the round announcement.
const Set<int> kTimeAnnouncements = {5, 3};

/// Heartbeat volume (0.0 to 1.0) at each whole second left. One beat per
/// second, from 6 down to 1. Seconds not listed have no heartbeat.
const Map<int, double> kHeartbeatVolumes = {
  6: 0.05, // faint
  5: 0.35, // a bit more audible
  4: 0.40, // clearly audible
  3: 0.50, // slightly below default
  2: 0.60, // default
  1: 0.72, // slightly above default
};

/// Whether the player can currently type, or the screen is between rounds.
enum _RoundPhase { playing, transitioning }

/// The in-round screen for one game.
///
/// The rules and scoring live in [GameSession]; this screen owns the clock
/// (the single timer in the app), the keyboard and the animations. Pass a
/// [database] for a daily game so the result is saved; leave it null for
/// practice.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.session,
    required this.audio,
    this.database,
  });

  /// The game being played.
  final GameSession session;

  /// Where a finished daily game is saved. Null for practice games.
  final GameDatabase? database;

  /// Plays the tick and heartbeat sounds during the round.
  final AudioService audio;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// The round clock. Runs from 1.0 (full) down to 0.0 (time up), so
  /// value * roundSeconds is the fractional number of seconds remaining and
  /// the bar moves smoothly.
  late final AnimationController _timer;

  final TextEditingController _wordController = TextEditingController();

  final FocusNode _focusNode = FocusNode();

  _RoundPhase _phase = _RoundPhase.playing;

  /// 1-based number of the round shown on screen.
  int _round = 1;

  /// The rule text shown on the constraint card for the current round.
  late String _constraintText;

  bool _captured = false; // drives the neutral "captured" cue

  bool _quitDialogOpen = false;
  
  bool _resumeNextRoundAfterQuit = false;

  /// False while the app is not in the foreground (a call, another app, a
  /// locked screen). The countdown only runs while this is true.
  bool _appActive = true;

  /// True when the clock should start again once the app returns: it was
  /// running when the app left, or a round began while the app was away.
  bool _clockWaitingForForeground = false;

  /// Whole seconds left at the last timer update. Used so screen-reader
  /// announcements fire once per second, and only at the seconds in
  /// [kTimeAnnouncements], not on every tick.
  int _lastSecond = GameSession.roundSeconds.toInt();

  // Half-seconds left at the last timer update (20 = 10.0s, a full round).
  // Used to detect when the clock crosses a tick or heartbeat moment.
  int _lastHalf = (GameSession.roundSeconds * 2).toInt();

  /// Text for the screen-reader time announcement. Empty until the first
  /// announcement of the round, and cleared again between rounds.
  String _timeAnnouncement = '';

  GameSession get _session => widget.session;

  bool get _isPlaying => _phase == _RoundPhase.playing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _round = _session.currentRound;
    _constraintText = _session.currentConstraint.description;
    _timer = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (GameSession.roundSeconds * 1000).round(),
      ),
      value: 1,
      // The countdown is the game's clock, not decoration. Without this,
      // Flutter runs it much faster when the system "remove animations"
      // setting is on.
      animationBehavior: AnimationBehavior.preserve,
    );

    // The clock reaching zero is the timeout.
    _timer.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) _onTimeout();
    });

    _timer.addListener(_onTick);
    _startClock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.stopGameplaySfx();
    _timer.dispose();
    _wordController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Pauses the clock whenever the app is not fully in the foreground and
  /// carries on from the same moment when it returns. Same rule as the audio
  /// in main.dart: only [resumed] counts as active.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;

    if (_appActive) {
      if (!_clockWaitingForForeground) return;
      _clockWaitingForForeground = false;
      // With the quit dialog open, the dialog decides when the clock restarts.
      if (_isPlaying && !_quitDialogOpen) _timer.reverse();
    } else if (_timer.isAnimating) {
      _timer.stop(); // keeps its value, like the quit dialog does
      _clockWaitingForForeground = true;
    }
  }

  /// Starts the countdown from where it is, or, if the app is away, as soon
  /// as it returns.
  void _startClock() {
    if (_appActive) {
      _timer.reverse();
    } else {
      _clockWaitingForForeground = true;
    }
  }

  /// Runs on every animation frame: updates the sounds, then sets the
  /// screen-reader announcement when a whole second has passed.
  void _onTick() {
    _updateSounds(_timer.value * GameSession.roundSeconds);

    final second = (_timer.value * GameSession.roundSeconds).ceil();
    if (second == _lastSecond) return;
    _lastSecond = second;

    if (_isPlaying && kTimeAnnouncements.contains(second)) {
      setState(() => _timeAnnouncement = '$second seconds left');
    }
  }

  /// Fires a tick each time the clock passes 9, 8 ... 1 seconds left (never
  /// at 0), and a heartbeat at each second listed in [kHeartbeatVolumes],
  /// at that second's volume. Checks every boundary crossed since the last
  /// update, so a dropped frame can't skip a sound. Plays each sound at most
  /// once per call.
  void _updateSounds(double secondsLeft) {
    final half = (secondsLeft * 2).ceil();
    final previous = _lastHalf;
    _lastHalf = half;

    // Only count down while playing. Resetting the bar to full (half goes up)
    // between rounds just updates _lastHalf above.
    if (!_isPlaying || half >= previous) return;

    var tick = false;
    double? beatVolume;
    for (var h = previous - 1; h >= half; h--) {
      if (!h.isEven) continue; // odd = a half-second mark, no sound
      final second = h ~/ 2;
      if (second >= 1 && second <= 9) tick = true;
      final volume = kHeartbeatVolumes[second];
      if (volume != null) beatVolume = volume;
    }

    if (tick) widget.audio.playTick();
    if (beatVolume != null) widget.audio.playHeartbeat(volume: beatVolume);
  }

  // Round flow

  /// Manual submit. The guard plus the immediate phase change means a second
  /// submission (button + timeout) is impossible, whatever the timing.
  /// An empty box is ignored so a stray tap can't burn the round; only the
  /// timeout records an empty round.
  void _submit() {
    if (!_isPlaying) return;

    if (_wordController.text.trim().isEmpty) return;

    setState(() => _phase = _RoundPhase.transitioning);

    _timer.stop();

    _finishRound(_timer.value * GameSession.roundSeconds);
  }

  /// Called when the clock reaches zero. Records whatever is in the box (an
  /// empty round if nothing was typed) with 0 seconds left.
  Future<void> _onTimeout() async {
    if (!_isPlaying) return;

    // Button greys out and typing is blocked immediately.
    setState(() => _phase = _RoundPhase.transitioning);

    await Future.delayed(kAutoSubmitDelay);

    if (!mounted) return;

    _finishRound(0);
  }

  /// Records the word, plays the "captured" cue, then either ends the game or
  /// sets up the next round and restarts the clock.
  Future<void> _finishRound(double secondsLeft) async {
    // The session validates and scores. The screen deliberately shows no
    // right/wrong feedback: validity only appears on the results screen.
    _session.submitWord(_wordController.text, secondsLeft);

    // Neutral cue, identical for every word.
    setState(() => _captured = true);

    await Future.delayed(kCaptureCue);

    if (!mounted) return;

    if (_session.isFinished) {
      await _finishGame();
      return;
    }

    // Swap in the next round while the timer sits full and still.
    setState(() {
      _round = _session.currentRound;
      _constraintText = _session.currentConstraint.description;
      _captured = false;
      _timeAnnouncement = '';
      _wordController.clear();
    });

    _timer.value = 1;
    _lastHalf = (GameSession.roundSeconds * 2).toInt();

    // The rest of the pause, so the total matches kRoundPause.
    await Future.delayed(kRoundPause - kCaptureCue);

    if (!mounted) return;

    if (_quitDialogOpen) {
      _resumeNextRoundAfterQuit = true;
      return;
    }

    setState(() => _phase = _RoundPhase.playing);

    _startClock();
  }

  /// Saves a daily game (once), then replaces this screen with the results.
  /// A failed save never blocks the results screen; it is reported there.
  Future<void> _finishGame() async {
    var saveFailed = false;

    final database = widget.database;

    if (!_session.isPractice && database != null) {
      try {
        if (!await database.hasPlayedDaily(_session.dateKey)) {
          await database.saveGame(_session);
        }
      } catch (e) {
        debugPrint('Could not save the game: $e');
        saveFailed = true;
      }
    }

    if (!mounted) return;

    // If the quit dialog is open, close it first so the replacement below
    // swaps this screen and not the dialog.
    if (_quitDialogOpen) {
      _resumeNextRoundAfterQuit = false;
      Navigator.of(context).pop(false);
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ResultsScreen(
          session: _session,
          saveFailed: saveFailed,
          database: database,
          audio: widget.audio,
        ),
      ),
    );
  }

  // Dialogs

  /// Asks the player to confirm quitting. The clock is paused while the
  /// dialog is open and resumed if they keep playing.
  Future<void> _confirmQuit() async {
    if (_quitDialogOpen) return;

    _quitDialogOpen = true;

    final wasPlaying = _isPlaying;

    if (wasPlaying) {
      _timer.stop(); // pause the clock while the dialog is open
      widget.audio.stopGameplaySfx();
    }

    // Colours and shape come from dialogTheme in app_theme.dart.
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quit game?'),
        content: const Text('Your progress this game will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep playing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quit'),
          ),
        ],
      ),
    );

    _quitDialogOpen = false;

    if (!mounted) return;

    if (quit == true) {
      _resumeNextRoundAfterQuit = false;
      // pop() directly: the PopScope below only intercepts back gestures.
      Navigator.of(context).pop();
      return;
    }

    if (_resumeNextRoundAfterQuit) {
      _resumeNextRoundAfterQuit = false;
      setState(() => _phase = _RoundPhase.playing);
      _startClock();
      return;
    }

    // Resume only if the round is still live (the timeout may have fired while
    // the dialog was open).
    if (wasPlaying && _isPlaying) _startClock();
  }

  // UI

  @override
  Widget build(BuildContext context) {
    // Back button and back gesture ask for confirmation instead of silently
    // abandoning the game.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmQuit();
      },
      // Scaffold shrinks the body when the keyboard opens, so the content
      // below is centred in the space above the keyboard automatically.
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(child: _buildPlayArea(context)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Quit button, countdown number and bar, round counter and mode badge.
  Widget _buildTopBar(BuildContext context) {
    final seconds = GameSession.roundSeconds.toInt();
    final modeLabel = _session.isPractice ? 'Practice' : 'Daily';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            iconSize: 30,
            icon: const Icon(Icons.close),
            tooltip: 'Quit',
            onPressed: _confirmQuit,
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                // One screen-reader node for the whole timer. Its label only
                // changes at 5 and 3 seconds, and as a live region that
                // change is announced. The visual ticking is hidden from
                // screen readers.
                child: Semantics(
                  liveRegion: true,
                  label: _timeAnnouncement.isEmpty
                      ? '$modeLabel game. $seconds seconds per round'
                      : _timeAnnouncement,
                  child: ExcludeSemantics(
                    child: AnimatedBuilder(
                      animation: _timer,
                      builder: (context, _) {
                        final left = (_timer.value * GameSession.roundSeconds)
                            .ceil();
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$left',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TimerBar(fraction: _timer.value),
                            const SizedBox(height: 10),
                            // Wrap, so a large system font size flows onto a
                            // second line instead of overflowing.
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'Round $_round / ${_session.totalRounds}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                                _ModeBadge(isPractice: _session.isPractice),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Balances the X button so the timer stays truly centred.
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  /// The rule card, the word box and the Submit button.
  Widget _buildPlayArea(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final maxBoxWidth = MediaQuery.of(context).size.width - 48;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The rule, directly above the box so it stays visible.
          // A live region: a screen reader reads the new round and rule
          // whenever it changes. The card itself is visual only.
          Semantics(
            liveRegion: true,
            label: 'Round $_round of ${_session.totalRounds}. $_constraintText',
            child: ExcludeSemantics(
              child: AnimatedSwitcher(
                duration: motionDuration(
                  context,
                  const Duration(milliseconds: 250),
                ),
                child: ConstraintCard(
                  key: ValueKey(_round),
                  text: _constraintText,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Word box: pulses while the word is "captured".
          AnimatedScale(
            scale: _captured ? 0.94 : 1,
            duration: motionDuration(
              context,
              const Duration(milliseconds: 150),
            ),
            child: AnimatedOpacity(
              opacity: _captured ? 0.55 : 1,
              duration: motionDuration(
                context,
                const Duration(milliseconds: 150),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 160,
                  maxWidth: maxBoxWidth,
                ),
                // IntrinsicWidth makes the box grow with the word length.
                child: IntrinsicWidth(
                  child: Semantics(
                    label: 'Your word',
                    child: TextField(
                      controller: _wordController,
                      focusNode: _focusNode,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: textTheme.displaySmall,
                      // Turn off everything that could help the player type:
                      // autocorrect, suggestions, selection and the paste menu.
                      autocorrect: false,
                      enableSuggestions: false,
                      enableInteractiveSelection: false,
                      contextMenuBuilder: (context, editableTextState) {
                        return const SizedBox.shrink();
                      },
                      textCapitalization: TextCapitalization.none,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(hintText: 'type here'),
                      // Formatters run in order: letters only, no paste,
                      // length cap, then the between-rounds lock.
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                        // Reject pasted or otherwise inserted multi-character text.
                        // Single-character typing and deletion remain allowed.
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          final selection = oldValue.selection;
                          final selectedLength = selection.isValid
                              ? selection.end - selection.start
                              : 0;
                          final insertedLength =
                              newValue.text.length -
                              (oldValue.text.length - selectedLength);
                          return insertedLength > 1 ? oldValue : newValue;
                        }),
                        LengthLimitingTextInputFormatter(kMaxWordLength),
                        // Blocks typing between rounds WITHOUT
                        // readOnly/disabled. Those would drop focus and make
                        // the keyboard slide down and back up every round.
                        TextInputFormatter.withFunction(
                          (oldValue, newValue) =>
                              _isPlaying ? newValue : oldValue,
                        ),
                      ],
                      // onEditingComplete (not onSubmitted) keeps focus, so
                      // the keyboard stays open after pressing its enter key.
                      onEditingComplete: _submit,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Greys out as soon as the timer ends or a word is submitted.
          ElevatedButton(
            onPressed: _isPlaying ? _submit : null,
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

/// Small pill showing whether this is the daily game or practice.
class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.isPractice});

  final bool isPractice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),

      decoration: BoxDecoration(
        color: isPractice ? AppColors.yellowSoft : AppColors.yellow,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: AppColors.gold, width: 1.5),
      ),

      child: Text(
        isPractice ? 'Practice' : 'Daily',

        style: const TextStyle(
          fontSize: 13,

          fontWeight: FontWeight.w800,

          color: AppColors.ink,
        ),
      ),
    );
  }
}
