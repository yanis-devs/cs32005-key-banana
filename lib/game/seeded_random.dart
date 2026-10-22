
import 'date_service.dart';
import 'dart:math';

class SeededRandom {
    int? _currentState;
    int? _previousState;
    final modulus = pow(2, 32).toInt();

    
    SeededRandom._int(int seed) {
        _previousState = seed;
    }

    
    static Future<SeededRandom> create() async {
        int seed;
        try {
            final stringDate = await fetchDate();
            seed = int.parse(stringDate);
        } catch (e) {
            seed = DateTime.now().millisecondsSinceEpoch % 1000000;
        }

        return SeededRandom._int(seed);
    }

    int generateRandom() {
        final multiplier = 1664525;
        final increment = 1013904223;

        _currentState = (multiplier * _previousState! + increment) % modulus;
        _previousState = _currentState;

        return _currentState!;
    }

    int cleanRandom(int random, int min, int max) {
        int targetRange = max - min + 1;
        int acceptanceLimit = modulus - (modulus % targetRange);

        if (random >= acceptanceLimit) {
            return -1;
        }

        return min + (random % targetRange);
    }

    
    int getRandom(int min, int max) {
        int result = cleanRandom(generateRandom(), min, max);

        while (result == -1) {
            result = cleanRandom(generateRandom(), min, max);
        }

        return result;
    }
}