import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Owns every sound in the app. Plain class, no Flutter widgets: create one
/// in main(), call [init], and pass it down through constructors like the
/// dictionary and database.
///
/// Needs the `audioplayers` package, and the files in assets/sounds/ must be
/// listed in pubspec.yaml.
///
/// Rules this class enforces so the screens don't have to:
///  * The opening jingle plays at most once per app launch.
///  * Opening, ambience, gameplay SFX and result sounds each have their own
///    player, so one category can be stopped without touching the others.
///  * A delayed ambience start can be cancelled (the player taps "Play" during
///    the silence break and the music must not start behind them).
///  * Nothing here ever throws. A missing file or audio error is logged and
///    the app carries on silently.
///  * A mute flag sets every sound to volume 0 without changing any timing.
///
/// Create it AFTER `WidgetsFlutterBinding.ensureInitialized()`.
class AudioService {
  AudioService();

  // Asset paths

  // audioplayers adds the "assets/" prefix itself, so these are relative to
  // the assets/ folder: 'sounds/x.mp3' means assets/sounds/x.mp3.
  static const String _openingAsset = 'sounds/opening.mp3';
  static const String _ambienceAsset = 'sounds/ambience.mp3';
  static const String _clickAsset = 'sounds/click_play.mp3';
  static const String _tickAsset = 'sounds/tick.mp3';
  static const String _heartbeatAsset = 'sounds/heartbeat.mp3';
  static const String _victoryAsset = 'sounds/victory_banana.mp3';
  static const String _boringAsset = 'sounds/boring_banana.mp3';

  /// Every sound file, preloaded once in [init].
  static const List<String> _allAssets = [
    _openingAsset,
    _ambienceAsset,
    _clickAsset,
    _tickAsset,
    _heartbeatAsset,
    _victoryAsset,
    _boringAsset,
  ];

  // Volumes (0.0 to 1.0, the opening is boosted above 1.0). Change these to
  // adjust the mix.
  static const double _openingVolume = 1.4;
  static const double _ambienceVolume = 0.4; // sits under everything else
  static const double _clickVolume = 0.5;
  static const double _tickVolume = 0.5;
  static const double _heartbeatVolume = 0.6;
  static const double _resultVolume = 0.8;

  /// When true every sound plays at volume 0. Sounds still run (so timing, the
  /// looping ambience and "finished" callbacks behave exactly as normal); they
  /// are just silent. Not remembered between launches.
  bool _muted = false;

  bool get isMuted => _muted;

  /// The volume to actually use: [volume], or 0 while muted.
  double _vol(double volume) => _muted ? 0.0 : volume;

  /// The "short silence break" used between the opening and the ambience, and
  /// between the game ending and the ambience coming back.
  static const Duration silenceBreak = Duration(seconds: 1);

  // Players

  final AudioPlayer _openingPlayer = AudioPlayer(playerId: 'opening');
  final AudioPlayer _ambiencePlayer = AudioPlayer(playerId: 'ambience');
  // The click uses low-latency mode. Tick and heartbeat use the normal media
  // player so they can sound at the same time.
  final AudioPlayer _clickPlayer = AudioPlayer(playerId: 'click');
  final AudioPlayer _tickPlayer = AudioPlayer(playerId: 'tick');
  final AudioPlayer _heartbeatPlayer = AudioPlayer(playerId: 'heartbeat');
  // Victory / boring jingles: longer, so normal media-player mode.
  final AudioPlayer _resultPlayer = AudioPlayer(playerId: 'result');

  // State

  /// Set on the first call to [init], so repeat calls do nothing.
  bool _initialised = false;

  /// Set by [dispose]. Once true, every method returns without doing anything.
  bool _disposed = false;

  /// Whether the opening jingle has already been started this launch.
  bool _openingPlayedThisLaunch = false;

  // Each completer below is non-null only while its sound is audible, and
  // completes with true (ended naturally) or false (cut off or replaced).
  Completer<bool>? _openingCompleter;
  StreamSubscription<void>? _openingCompleteSub;
  Completer<bool>? _resultCompleter;
  StreamSubscription<void>? _resultCompleteSub;
  Completer<bool>? _clickCompleter;
  StreamSubscription<void>? _clickCompleteSub;

  /// Safety net: if the "finished" event never arrives, stop waiting.
  static const Duration _clickTimeout = Duration(seconds: 4);

  /// Pending delayed start of the ambience, if any.
  Timer? _ambienceTimer;

  // App lifecycle tracking

  /// False while the app is in the background.
  bool _appInForeground = true;

  /// Only players that were playing when the app lost focus.
  /// Intentionally paused players are not resumed.
  final List<AudioPlayer> _lifecyclePausedPlayers = [];

  /// An ambience start whose delay expired while the app was in the background.
  bool _ambiencePendingWhileBackground = false;

  /// Every player, for actions that apply to all of them.
  List<AudioPlayer> get _allPlayers => [
    _openingPlayer,
    _ambiencePlayer,
    _clickPlayer,
    _tickPlayer,
    _heartbeatPlayer,
    _resultPlayer,
  ];

  /// True once the opening jingle has been started in this app launch.
  bool get hasPlayedOpening => _openingPlayedThisLaunch;

  /// True while the opening jingle is audible.
  bool get isOpeningPlaying => _openingCompleter != null;

  /// True while a victory or boring jingle is audible.
  bool get isResultPlaying => _resultCompleter != null;

  // Setup

  /// Prepares the players and loads every file. Safe to call more than once.
  Future<void> init() async {
    if (_initialised || _disposed) return;
    _initialised = true;

    // Let our players overlap (tick + heartbeat + ambience) without Android
    // audio focus pausing one when another starts.
    final ctx = AudioContextConfig(
      focus: AudioContextConfigFocus.mixWithOthers,
    ).build();

    try {
      await AudioPlayer.global.setAudioContext(ctx);
    } catch (e) {
      debugPrint('Could not set the global audio context: $e');
    }

    // Apply to each player too: they were created before the global call.
    for (final p in _allPlayers) {
      await _safe(() => p.setAudioContext(ctx));
    }

    try {
      await AudioCache.instance.loadAll(_allAssets);
    } catch (e) {
      debugPrint('Could not preload sounds: $e');
    }

    // The click uses low-latency mode. Tick and heartbeat use the normal media
    // player so they can sound at the same time.
    await _safe(() => _clickPlayer.setPlayerMode(PlayerMode.lowLatency));
    await _safe(() => _tickPlayer.setPlayerMode(PlayerMode.mediaPlayer));
    await _safe(() => _heartbeatPlayer.setPlayerMode(PlayerMode.mediaPlayer));

    // ReleaseMode.stop keeps the file loaded after it ends, so replaying it
    // is instant. The ambience loops seamlessly.
    for (final p in [
      _openingPlayer,
      _clickPlayer,
      _tickPlayer,
      _heartbeatPlayer,
      _resultPlayer,
    ]) {
      await _safe(() => p.setReleaseMode(ReleaseMode.stop));
    }
    await _safe(() => _ambiencePlayer.setReleaseMode(ReleaseMode.loop));

    // Natural end of the opening jingle (a manual stop does not fire this).
    _openingCompleteSub = _openingPlayer.onPlayerComplete.listen(
      (_) => _finishOpening(true),
    );
    _resultCompleteSub = _resultPlayer.onPlayerComplete.listen(
      (_) => _finishResult(true),
    );
    _clickCompleteSub = _clickPlayer.onPlayerComplete.listen(
      (_) => _finishClick(true),
    );
  }

  // 1. Intro (opening.mp3)

  /// Plays the opening jingle once per app launch.
  ///
  /// Completes with `true` when the jingle ended on its own (or could not be
  /// played, so the caller carries on to the ambience), and with `false` when
  /// it was cut off by [stopOpening] or was already played earlier this
  /// launch. Typical use:
  ///
  ///     if (await audio.playOpening()) audio.startAmbience(delay: AudioService.silenceBreak);
  Future<bool> playOpening() async {
    if (_disposed || _openingPlayedThisLaunch) return false;
    _openingPlayedThisLaunch = true;
    final completer = Completer<bool>();
    _openingCompleter = completer;
    try {
      await _openingPlayer.play(
        AssetSource(_openingAsset),
        volume: _vol(_openingVolume),
      );
    } catch (e) {
      debugPrint('Could not play the opening: $e');
      _finishOpening(true);
    }
    return completer.future;
  }

  /// Cuts the opening off immediately. No-op if it isn't playing.
  Future<void> stopOpening() async {
    _finishOpening(false); // tell any waiting caller it was interrupted
    await _safe(_openingPlayer.stop);
  }

  /// Completes the pending [playOpening] future, if any, and marks the
  /// opening as no longer playing.
  void _finishOpening(bool finishedNaturally) {
    final completer = _openingCompleter;
    _openingCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(finishedNaturally);
    }
  }

  // 2. Ambience (ambience.mp3, looping)

  /// Starts (or resumes) the looping ambience, after an optional [delay]
  /// (pass [silenceBreak] for the gap after the opening or after a game).
  ///
  /// Calling it again replaces any pending delayed start. If the ambience is
  /// already playing, nothing happens.
  void startAmbience({Duration delay = Duration.zero}) {
    if (_disposed) return;
    _ambienceTimer?.cancel();
    if (delay <= Duration.zero) {
      _ambienceTimer = null;
      unawaited(_beginAmbience());
      return;
    }
    _ambienceTimer = Timer(delay, () {
      _ambienceTimer = null;
      unawaited(_beginAmbience());
    });
  }

  /// Starts or resumes the ambience right now, unless the app is in the
  /// background, in which case it is only noted as pending.
  Future<void> _beginAmbience() async {
    if (_disposed) return;

    if (!_appInForeground) {
      _ambiencePendingWhileBackground = true;
      return;
    }
    _ambiencePendingWhileBackground = false;

    switch (_ambiencePlayer.state) {
      case PlayerState.playing:
        return;
      case PlayerState.paused:
        await _safe(_ambiencePlayer.resume); // carry on where it left off
      case PlayerState.stopped:
      case PlayerState.completed:
      case PlayerState.disposed:
        await _safe(
          () => _ambiencePlayer.play(
            AssetSource(_ambienceAsset),
            volume: _vol(_ambienceVolume),
          ),
        );
    }
  }

  /// Pauses the ambience and cancels any pending delayed start. Use when a
  /// game begins. [startAmbience] picks it up again.
  Future<void> pauseAmbience() async {
    _ambienceTimer?.cancel();
    _ambienceTimer = null;
    _ambiencePendingWhileBackground = false;

    if (_ambiencePlayer.state == PlayerState.playing) {
      await _safe(_ambiencePlayer.pause);
    }
  }

  /// Stops the ambience and rewinds it. Cancels any pending delayed start.
  Future<void> stopAmbience() async {
    _ambienceTimer?.cancel();
    _ambiencePendingWhileBackground = false;
    _ambienceTimer = null;
    await _safe(_ambiencePlayer.stop);
  }

  // 3. Gameplay SFX (click_play, tick, heartbeat)

  /// The "Play Daily" click. Completes with true when it has played to its
  /// end (or couldn't play), false if it was restarted or stopped. Callers
  /// that don't need to wait can ignore the result.
  Future<bool> playClick() async {
    if (_disposed) return true;
    _finishClick(false); // an earlier click, if any, is replaced
    final completer = Completer<bool>();
    _clickCompleter = completer;
    try {
      await _clickPlayer.stop();
      await _clickPlayer.play(
        AssetSource(_clickAsset),
        volume: _vol(_clickVolume),
      );
    } catch (e) {
      debugPrint('Could not play the click: $e');
      _finishClick(true);
    }
    return completer.future.timeout(
      _clickTimeout,
      onTimeout: () {
        _finishClick(true);
        return true;
      },
    );
  }

  /// Completes the pending [playClick] future, if any.
  void _finishClick(bool finishedNaturally) {
    final completer = _clickCompleter;
    _clickCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(finishedNaturally);
    }
  }

  /// One timer tick. The game screen calls this once per second, 9 down to 1.
  Future<void> playTick() =>
      _restart(_tickPlayer, _tickAsset, _vol(_tickVolume));

  /// One heartbeat thump. [volume] (0.0 to 1.0) overrides the default so the
  /// game screen can make the beat grow as time runs out.
  Future<void> playHeartbeat({double? volume}) => _restart(
    _heartbeatPlayer,
    _heartbeatAsset,
    _vol((volume ?? _heartbeatVolume).clamp(0.0, 1.0).toDouble()),
  );

  /// Silences tick and heartbeat. Deliberately does NOT touch the click, so
  /// it always plays to its end.
  Future<void> stopGameplaySfx() async {
    await _safe(_tickPlayer.stop);
    await _safe(_heartbeatPlayer.stop);
  }

  // 4. Results SFX (victory_banana, boring_banana)

  /// Plays the high-score jingle. Completes with true when it ended on its
  /// own (or couldn't play), false if it was stopped or replaced.
  Future<bool> playVictory() => _playResult(_victoryAsset);

  /// Plays the low-score jingle. Same return value as [playVictory].
  Future<bool> playBoring() => _playResult(_boringAsset);

  /// Stops whichever result jingle is playing.
  Future<void> stopResults() async {
    _finishResult(false);
    await _safe(_resultPlayer.stop);
  }

  /// Plays [asset] on the result player, replacing any jingle already playing.
  Future<bool> _playResult(String asset) async {
    if (_disposed) return false;
    _finishResult(false); // an earlier jingle, if any, was cut off
    final completer = Completer<bool>();
    _resultCompleter = completer;
    try {
      await _resultPlayer.stop();
      await _resultPlayer.play(AssetSource(asset), volume: _vol(_resultVolume));
    } catch (e) {
      debugPrint('Could not play $asset: $e');
      _finishResult(true);
    }
    return completer.future;
  }

  /// Completes the pending result-jingle future, if any, and marks the jingle
  /// as no longer playing.
  void _finishResult(bool finishedNaturally) {
    final completer = _resultCompleter;
    _resultCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(finishedNaturally);
    }
  }

  // Global controls

  /// Mutes or unmutes every sound. Sounds already playing change right away;
  /// anything played later picks the setting up through [_vol].
  Future<void> setMuted(bool muted) async {
    if (_disposed || _muted == muted) return;
    _muted = muted;

    await _safe(() => _ambiencePlayer.setVolume(_vol(_ambienceVolume)));
    await _safe(() => _openingPlayer.setVolume(_vol(_openingVolume)));
    await _safe(() => _resultPlayer.setVolume(_vol(_resultVolume)));
  }

  /// Silences everything and cancels pending starts.
  Future<void> stopAll() async {
    await stopOpening();
    await stopAmbience();
    await stopGameplaySfx();
    _finishClick(false);
    await _safe(_clickPlayer.stop);
    await stopResults();
  }

  /// Pause every currently playing sound when the app loses focus.
  /// Playback position is preserved.
  Future<void> pauseForAppBackground() async {
    if (_disposed || !_appInForeground) return;

    _appInForeground = false;
    _lifecyclePausedPlayers.clear();

    // Remember which players were playing, so only those are resumed later.
    for (final player in _allPlayers) {
      if (player.state == PlayerState.playing) {
        _lifecyclePausedPlayers.add(player);
        await _safe(player.pause);
      }
    }
  }

  /// Resume only sounds that were playing before the app lost focus.
  Future<void> resumeForAppForeground() async {
    if (_disposed || !_appInForeground) return;

    _appInForeground = true;

    for (final player in List.of(_lifecyclePausedPlayers)) {
      await _safe(player.resume);
    }
    _lifecyclePausedPlayers.clear();

    // A delayed ambience start expired while the app was away. This clears
    // the flag and starts the music now.
    if (_ambiencePendingWhileBackground) {
      unawaited(_beginAmbience());
    }
  }

  /// Releases the players. Call once when the app is torn down.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _ambienceTimer?.cancel();
    _ambienceTimer = null;
    _finishOpening(false);
    _finishResult(false);
    _finishClick(false);
    await _openingCompleteSub?.cancel();
    await _resultCompleteSub?.cancel();
    await _clickCompleteSub?.cancel();
    for (final p in _allPlayers) {
      await _safe(p.dispose);
    }
  }

  // Helpers

  /// Plays [asset] from the start, even if the same player is still playing
  /// the previous play of it.
  Future<void> _restart(AudioPlayer player, String asset, double volume) async {
    if (_disposed) return;
    try {
      await player.stop();
      await player.play(AssetSource(asset), volume: volume);
    } catch (e) {
      debugPrint('Could not play $asset: $e');
    }
  }

  /// Runs an audio call and swallows (but logs) any error.
  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }
}