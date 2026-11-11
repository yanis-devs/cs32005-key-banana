
import 'date_service.dart';
import 'dart:math';

class SeededRandom {
    int? _currentState;
    int? _previousState;
    final modulus = pow(2, 32).toInt();
    // debug part
    final int initialSeed;
    bool debug = false;

    SeededRandom._int(int seed) : initialSeed = seed {
      _previousState = seed;
    }

    // Lets main inspect the state without advancing the RNG.
    int get state => _previousState ?? initialSeed;
    //debug part ends
    

    //this is the original, commented out
    /*
    SeededRandom._int(int seed) {
        _previousState = seed;
    }
    */

    
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

    //debug
    int getRandom(int min, int max) {
      if (min > max) {
        throw ArgumentError('min cannot be greater than max');
      }

      final int targetRange = max - min + 1;
      final int raw = generateRandom();

      // Scale the entire random value instead of using its weakest bits.
      final int result = min + (raw * targetRange ~/ modulus);

      if (debug) {
        print(
          '[RNG] raw=$raw | range=[$min, $max] | output=$result'
        );
      }

      return result;
    }
    //debug ends

    //this is original
    /*
    int getRandom(int min, int max) {
        int result = cleanRandom(generateRandom(), min, max);

        while (result == -1) {
            result = cleanRandom(generateRandom(), min, max);
        }

        return result;
    }
    */
}