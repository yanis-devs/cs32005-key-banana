import 'package:flutter/material.dart';
import 'game/random_test_screen.dart'; // Import your test screen file

void main() {
  // Required for Flutter bindings if doing any async work before runApp
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seeded Random Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // Set the RandomTestScreen as the starting screen
      home: const RandomTestScreen(),
    );
  }
}