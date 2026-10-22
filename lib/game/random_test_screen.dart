import 'package:flutter/material.dart';
import 'seeded_random.dart'; // Make sure this points to your file

class RandomTestScreen extends StatefulWidget {
  const RandomTestScreen({super.key});

  @override
  State<RandomTestScreen> createState() => _RandomTestScreenState();
}

class _RandomTestScreenState extends State<RandomTestScreen> {
  // Declare a variable to hold our initialized class
  late Future<SeededRandom> _randomGeneratorFuture;
  SeededRandom? _seededRandom;
  int? _currentRandomNumber;

  @override
  void initState() {
    super.initState();
    // 1. Start loading the random generator when the widget opens
    _randomGeneratorFuture = SeededRandom.create();
  }

  void _generateNewNumber() {
    if (_seededRandom != null) {
      setState(() {
        // 2. Call your synchronous API method!
        _currentRandomNumber = _seededRandom!.getRandom(1, 100);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test SeededRandom')),
      body: Center(
        child: FutureBuilder<SeededRandom>(
          future: _randomGeneratorFuture,
          builder: (context, snapshot) {
            // While it's fetching the date/seed, show a loading spinner
            if (snapshot.connectionState == ConnectionState.waiting) {
              const CircularProgressIndicator();
            }
            
            // If something went wrong
            if (snapshot.hasError) {
              return Text('Error initializing: ${snapshot.error}');
            }

            // Once it's ready, save the instance and show the UI
            if (snapshot.hasData) {
              _seededRandom = snapshot.data;

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentRandomNumber == null 
                        ? 'Press the button to roll!' 
                        : 'Random Number: $_currentRandomNumber',
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _generateNewNumber,
                    child: const Text('Generate Random (1-100)'),
                  ),
                ],
              );
            }

            return const SizedBox();
          },
        ),
      ),
    );
  }
}