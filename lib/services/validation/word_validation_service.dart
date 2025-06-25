import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:bonus/services/trie.dart';
import 'package:characters/characters.dart';

class WordValidationService {
  late final Trie _wordTrie;
  bool _wordsLoaded = false;

  bool get wordsLoaded => _wordsLoaded;

  WordValidationService() {
    _wordTrie = Trie();
  }

  Future<void> loadWords() async {
    if (_wordsLoaded) return;
    final wordsString = await rootBundle.loadString('assets/Acceptable_Words.txt');
    for (final word in wordsString.split('\n')) {
      final w = word.trim();
      if (w.isNotEmpty) _wordTrie.insert(w);
    }
    _wordsLoaded = true;
  }

  bool isValidWord(String word) {
    if (!_wordsLoaded || word.length <= 1) return false;
    final normalized = _normalizeFinalForm(word);
    return _wordTrie.contains(normalized);
  }

  String _normalizeFinalForm(String word) {
    if (word.isEmpty) return word;
    final finals = {
      'מ': 'ם',
      'צ': 'ץ',
      'כ': 'ך',
      'פ': 'ף',
      'נ': 'ן',
    };
    final last = word.characters.last;
    if (finals.containsKey(last)) {
      return word.characters.take(word.characters.length - 1).join() + finals[last]!;
    }
    return word;
  }
} 