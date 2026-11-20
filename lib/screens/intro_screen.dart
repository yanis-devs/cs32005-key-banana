import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/audio_service.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';

/// Size of the banana key on screen.
const double kIntroButtonSize = 220;

/// How far the key shrinks while pressed (1.0 = no change).
const double kPressedScale = 0.9;

/// How long the shrink/grow animation takes.
const Duration kPressAnimation = Duration(milliseconds: 110);

/// Cross-fade between the intro and the home screen.
const Duration kIntroFade = Duration(milliseconds: 4000);

/// Shows the intro screen until the player taps the banana key, then swaps in
/// the real app ([builder]) and starts the opening jingle.
///
/// "Once per launch" comes for free: this widget lives inside [LockGate],
/// which is only unlocked once per launch, and [_introDone] is plain state
/// that survives the app going to the background. It only resets when the
/// app process is fully closed and started again.
class IntroGate extends StatefulWidget {
  const IntroGate({super.key, required this.audio, required this.builder});

  /// Plays the opening jingle and then the ambience once the player enters.
  final AudioService audio;

  /// Builds the real app (the home screen).
  final WidgetBuilder builder;

  @override
  State<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<IntroGate> {
  /// Whether the player has tapped through the intro.
  bool _introDone = false;

  /// Leaves the intro: starts the opening sound and swaps in the real app.
  /// Does nothing if the intro was already dismissed.
  void _enterApp() {
    if (_introDone) return;

    _playOpeningThenAmbience();
    setState(() => _introDone = true);
  }

  /// Opening, then a silence break, then the looping ambience. If the opening
  /// is cut off (the player taps Daily or Practice) it returns false and the
  /// ambience is NOT started.
  Future<void> _playOpeningThenAmbience() async {
    final audio = widget.audio;
    final finished = await audio.playOpening();
    if (finished) audio.startAmbience(delay: AudioService.silenceBreak);
  }

  @override
  Widget build(BuildContext context) {
    // The keys tell AnimatedSwitcher these are two different children, so it
    // cross-fades between them.
    return AnimatedSwitcher(
      duration: motionDuration(context, kIntroFade),
      child: _introDone
          ? KeyedSubtree(
              key: const ValueKey('app'),
              child: widget.builder(context),
            )
          : IntroScreen(key: const ValueKey('intro'), onEnter: _enterApp),
    );
  }
}

/// A single banana key in the centre of the screen. Pressing it shrinks it
/// slightly; tapping it calls [onEnter].
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onEnter});

  /// Called once when the player taps the key.
  final VoidCallback onEnter;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  /// Whether the key is currently drawn shrunk.
  bool _pressed = false;
  bool _entering = false; // stops a double tap running the entry twice

  /// Handles a tap: keeps the key shrunk and hands over to [onEnter]. Only
  /// the first tap counts.
  Future<void> _onTap() async {
    if (_entering) return;
    _entering = true;

    setState(() => _pressed = true);

    // Start the opening sound and cross-fade immediately.
    widget.onEnter();
  }

  /// Shrinks or restores the key while a finger is down or lifted off.
  void _setPressed(bool value) {
    if (_entering) return; // once tapped, the key stays shrunk
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Center(
          // One screen-reader node: a button named "Start K-Banana". The
          // picture is hidden from it. onTap is given here so TalkBack's
          // double tap works even though the gesture detector is excluded.
          child: Semantics(
            button: true,
            label: 'Start K-Banana',
            onTap: _onTap,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _setPressed(true),
              onTapCancel: () => _setPressed(false),
              onTap: _onTap,
              child: AnimatedScale(
                scale: _pressed ? kPressedScale : 1,
                duration: motionDuration(context, kPressAnimation),
                curve: Curves.easeOut,
                child: SvgPicture.asset(
                  'assets/images/banana_button.svg',
                  width: kIntroButtonSize,
                  height: kIntroButtonSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
