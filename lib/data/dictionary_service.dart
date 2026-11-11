import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:pantry_app/game/constraints/constraint.dart';

class DictionaryService {

    final Set<String> words;
    DictionaryService._(this.words);

    static Future<DictionaryService> create() async {
        final raw = await rootBundle.loadString('assets/words.txt');
        Set<String> words = LineSplitter.split(raw)
        .map((word) => word.toLowerCase().trim())
        .where((word) => word.isNotEmpty)
        .toSet();
        return DictionaryService._(words);
    }

    bool isWordValid(String word) => words.contains(word);
    
    bool isChallengeValid(Constraint constraint){
        int wordCount = 0;
        int minSize = 100;

        for (String word in words){
            if(constraint.isAccepted(word)) wordCount++;
            if(wordCount == minSize) return true;
        }
        return false;
    }
}





