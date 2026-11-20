import 'dart:async';

import 'package:flutter/material.dart';

import 'data/dictionary_service.dart';
import 'data/game_database.dart';
import 'screens/home_screen.dart';
import 'screens/intro_screen.dart';
import 'screens/lock_gate.dart';
import 'services/audio_service.dart';
import 'services/biometric_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loaded once at startup and passed down through constructors.
  final dictionary = await DictionaryService.create();
  final database = await GameDatabase.open();

  final audio = AudioService();
  await audio.init();

  runApp(
    MyApp(
      dictionary: dictionary,
      database: database,
      biometrics: BiometricService(),
      audio: audio,
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    required this.dictionary,
    required this.database,
    required this.biometrics,
    required this.audio,
  });

  final DictionaryService dictionary;
  final GameDatabase database;
  final BiometricService biometrics;
  final AudioService audio;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.audio.resumeForAppForeground());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(widget.audio.pauseForAppBackground());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'K-Banana',
      theme: AppTheme.light,
      // The whole app sits behind the device lock, checked once per launch.
      home: LockGate(
        service: widget.biometrics,
        builder: (context, lockEnabled) => IntroGate(
          audio: widget.audio,
          builder: (context) => HomeScreen(
            dictionary: widget.dictionary,
            database: widget.database,
            audio: widget.audio,
            lockEnabled: lockEnabled,
          ),
        ),
      ),
    );
  }
}
