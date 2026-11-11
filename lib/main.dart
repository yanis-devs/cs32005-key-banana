import 'package:flutter/material.dart';
import 'game/random_test_screen.dart'; // Import your test screen file
import 'data/dictionary_service.dart';
import 'game/challenge_generator.dart';

import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/mock_round_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Word Game',
      theme: AppTheme.light,
      home: const MockRoundScreen(),
    );
  }
}