// Suggested location: lib/screens/mock_round_screen.dart
//
// A visual-only prototype of the in-round screen. It uses fake constraints and
// stores words locally, so it does not depend on GameSession.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

// ---- Tuning knobs: change these to adjust the feel -------------------------
const int kTotalRounds = 7;
const double kRoundSeconds = 10;

/// How long the neutral "word captured" cue plays.
const Duration kCaptureCue = Duration(milliseconds: 450);

/// Total pause between rounds, measured from the moment the word is captured.
/// The new timer only starts after this, so the pause never costs player time.
const Duration kRoundPause = Duration(milliseconds: 1200);

/// Delay before reading the box after the timer hits zero, so the keyboard can
/// commit the final keystroke.
const Duration kAutoSubmitDelay = Duration(milliseconds: 300);
// -----------------------------------------------------------------------------

const List<String> _mockConstraints = [
  'Word must start with C',
  'Word must have 5 letters',
  'Word must contain Z',
  'Word must end with T',
  'Word must exclude E',
  'Word must start with B',
  'Word must have 7 letters',
];

enum RoundPhase { playing, transitioning }

class _RoundRecord {
  _RoundRecord(this.constraint, this.word, this.secondsLeft);
  final String constraint;
  final String word;
  final double secondsLeft;
}

class MockRoundScreen extends StatefulWidget {
  const MockRoundScreen({super.key});

  @override
  State<MockRoundScreen> createState() => _MockRoundScreenState();
}

class _MockRoundScreenState extends State<MockRoundScreen>
    with SingleTickerProviderStateMixin {
  // Runs from 1.0 (full) down to 0.0 (time up). value * kRoundSeconds is the
  // fractional number of seconds remaining, so the bar moves smoothly.
  late final AnimationController _timer;

  final TextEditingController _wordController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  RoundPhase _phase = RoundPhase.playing;
  int _round = 1;
  bool _captured = false; // drives the neutral "captured" cue
  final List<_RoundRecord> _records = [];

  bool get _isPlaying => _phase == RoundPhase.playing;

  String get _constraint =>
      _mockConstraints[(_round - 1) % _mockConstraints.length];

  @override
  void initState() {
    super.initState();
    _timer = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (kRoundSeconds * 1000).round()),
      value: 1,
    );
    _timer.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) _onTimeout();
    });
    _timer.reverse();
  }

  @override
  void dispose() {
    _timer.dispose();
    _wordController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---- Round flow ----------------------------------------------------------

  /// Manual submit. The guard plus the immediate phase change means a second
  /// submission (button + timeout) is impossible, whatever the timing.
  void _submit() {
    if (!_isPlaying) return;
    setState(() => _phase = RoundPhase.transitioning);
    _timer.stop();
    _finishRound(_timer.value * kRoundSeconds);
  }

  Future<void> _onTimeout() async {
    if (!_isPlaying) return;
    // Button greys out and typing is blocked immediately.
    setState(() => _phase = RoundPhase.transitioning);
    await Future.delayed(kAutoSubmitDelay);
    if (!mounted) return;
    _finishRound(0);
  }

  Future<void> _finishRound(double secondsLeft) async {
    _records.add(
      _RoundRecord(_constraint, _wordController.text.trim(), secondsLeft),
    );

    // Neutral cue, identical for every word: no right/wrong judgement.
    setState(() => _captured = true);
    await Future.delayed(kCaptureCue);
    if (!mounted) return;

    if (_round >= kTotalRounds) {
      await _showResults();
      return;
    }

    // Swap in the next round while the timer sits full and still.
    setState(() {
      _round++;
      _captured = false;
      _wordController.clear();
    });
    _timer.value = 1;

    await Future.delayed(kRoundPause - kCaptureCue);
    if (!mounted) return;

    setState(() => _phase = RoundPhase.playing);
    _timer.reverse();
  }

  void _restart() {
    setState(() {
      _records.clear();
      _round = 1;
      _captured = false;
      _wordController.clear();
      _phase = RoundPhase.playing;
    });
    _timer.value = 1;
    _timer.reverse();
  }

  // ---- Dialogs -------------------------------------------------------------

  Future<void> _confirmQuit() async {
    final wasPlaying = _isPlaying;
    if (wasPlaying) _timer.stop(); // pause the clock while the dialog is open

    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
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

    if (!mounted) return;
    if (quit == true) {
      Navigator.of(context).maybePop();
      return;
    }
    if (wasPlaying && _isPlaying) _timer.reverse();
  }

  Future<void> _showResults() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Game over (mock results)'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final r in _records)
                ListTile(
                  dense: true,
                  title: Text(r.word.isEmpty ? '(empty)' : r.word),
                  subtitle: Text(r.constraint),
                  trailing: Text('${r.secondsLeft.toStringAsFixed(1)}s'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Play again'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _restart();
  }

  // ---- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Scaffold shrinks the body when the keyboard opens, so the content below
    // is centred in the space above the keyboard automatically.
    return Scaffold(
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
    );
  }

  Widget _buildTopBar(BuildContext context) {
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
                constraints: const BoxConstraints(maxWidth: 240),
                child: AnimatedBuilder(
                  animation: _timer,
                  builder: (context, _) {
                    final seconds = (_timer.value * kRoundSeconds).ceil();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$seconds',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _timer.value,
                            minHeight: 12,
                            color: AppColors.yellow,
                            backgroundColor: AppColors.yellowSoft,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Round $_round / $kTotalRounds',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    );
                  },
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

  Widget _buildPlayArea(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final maxBoxWidth = MediaQuery.of(context).size.width - 48;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Constraint text, directly above the box so it stays visible.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              _constraint,
              key: ValueKey(_round),
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 28),

          // Word box: pulses while the word is "captured".
          AnimatedScale(
            scale: _captured ? 0.94 : 1,
            duration: const Duration(milliseconds: 150),
            child: AnimatedOpacity(
              opacity: _captured ? 0.55 : 1,
              duration: const Duration(milliseconds: 150),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: 160, maxWidth: maxBoxWidth),
                // IntrinsicWidth makes the box grow with the word length.
                child: IntrinsicWidth(
                  child: TextField(
                    controller: _wordController,
                    focusNode: _focusNode,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: textTheme.displaySmall,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.none,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(hintText: 'type here'),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                      // Blocks typing between rounds WITHOUT readOnly/disabled.
                      // Those would drop focus and make the keyboard slide
                      // down and back up every round.
                      TextInputFormatter.withFunction(
                        (oldValue, newValue) =>
                            _isPlaying ? newValue : oldValue,
                      ),
                    ],
                    // onEditingComplete (not onSubmitted) keeps focus, so the
                    // keyboard stays open after pressing its enter key.
                    onEditingComplete: _submit,
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