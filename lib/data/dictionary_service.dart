import 'package:flutter/services.dart';

import 'dart:convert';

import 'package:key_banana/game/constraints/constraint.dart';

/// The game's word list, loaded once at startup and used to validate
/// submitted words and generated challenges.
///
/// All words are stored lowercase and trimmed, so lookups expect lowercase
/// input.
class DictionaryService {
  /// Every valid word, lowercase.
  final Set<String> words;
  DictionaryService._(this.words);

  /// Builds a dictionary from an existing set of words, without touching the
  /// asset bundle. Used by tests. The words must already be lowercase.
  DictionaryService.fromWords(this.words);

  /// Loads the word list from `assets/words.txt` (one word per line).
  ///
  /// Words are lowercased and trimmed, and blank lines are skipped.
  static Future<DictionaryService> create() async {
    final raw = await rootBundle.loadString('assets/words.txt');
    Set<String> words = LineSplitter.split(raw)
        .map((word) => word.toLowerCase().trim())
        .where((word) => word.isNotEmpty)
        .toSet();
    return DictionaryService._(words);
  }

  /// Whether [word] is in the dictionary. [word] must already be lowercase.
  bool isWordValid(String word) => words.contains(word);

  /// Whether [constraint] is playable: at least 100 dictionary words satisfy
  /// it. Used to reject rules that are too hard or impossible.
  ///
  /// Stops counting as soon as the threshold is reached, so it rarely scans
  /// the whole list.
  bool isChallengeValid(Constraint constraint) {
    int wordCount = 0;
    int minSize = 100;

    for (String word in words) {
      if (constraint.checkConstraint(word)) wordCount++;
      if (wordCount == minSize) return true;
    }
    return false;
  }
}
