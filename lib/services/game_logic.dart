import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:bonus/services/trie.dart';
import 'package:bonus/models/bonus_info.dart';
import 'package:bonus/models/draggable_letter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/letter.dart';
import '../models/board_tile.dart';

class GameLogic extends ChangeNotifier {
  late List<Letter> _letterPool;
  final List<Letter> _player1Hand = [];
  final List<Letter> _player2Hand = [];
  late List<BoardTile?> _board;
  int _currentPlayer = 1;
  int _player1Score = 0;
  int _player2Score = 0;

  late final List<int> _bonusIndices;

  Timer? _timer;
  int _remainingTime = 600;

  late Trie _wordTrie;
  bool _wordsLoaded = false;
  final Set<int> _placedThisTurn = {};
  void Function(String)? onError;

  // Bonus tracking
  int _player1DoubleTurns = 0;
  int _player2DoubleTurns = 0;
  int _player1QuadTurns = 0;
  int _player2QuadTurns = 0;
  bool _player1ExtraMove = false;
  bool _player2ExtraMove = false;

  List<Letter> get player1Hand => _player1Hand;
  List<Letter> get player2Hand => _player2Hand;
  List<BoardTile?> get board => _board;
  int get currentPlayer => _currentPlayer;
  int get player1Score => _player1Score;
  int get player2Score => _player2Score;
  List<Letter> get letterPool => _letterPool;
  int get remainingTime => _remainingTime;
  bool get wordsLoaded => _wordsLoaded;

  GameLogic() {
    _initializeLetterPool();
    _loadWords().then((_) => startGame());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initializeLetterPool() {
    _letterPool = [];
    // 1 point
    _addLetters('ו', 1, 8);
    _addLetters('י', 1, 6);
    _addLetters('ת', 1, 6);
    _addLetters('ר', 1, 6);
    _addLetters('ה', 1, 6);
    // 2 points
    _addLetters('א', 2, 5);
    _addLetters('ל', 2, 5);
    _addLetters('מ', 2, 5);
    _addLetters('ש', 2, 5);
    // 3 points
    _addLetters('ב', 3, 3);
    _addLetters('ד', 3, 3);
    // 4 points
    _addLetters('נ', 4, 3);
    _addLetters('פ', 4, 3);
    // 5 points
    _addLetters('ח', 5, 3);
    _addLetters('כ', 5, 2);
    _addLetters('ק', 5, 2);
    // 8 points
    _addLetters('ע', 8, 2);
    _addLetters('ג', 8, 1);
    _addLetters('ז', 8, 1);
    _addLetters('ט', 8, 1);
    _addLetters('ס', 8, 1);
    _addLetters('צ', 8, 1);
    // 0 points (blank)
    _addLetters(' ', 0, 2); // Using space for blank
  }

  void _initializeBoard() {
    _board = List.generate(144, (index) => BoardTile());
    _bonusIndices = _generateBonusPositions();
    for (final index in _bonusIndices) {
      _board[index] = BoardTile(bonus: _createRandomBonus());
    }
  }

  BonusInfo _createRandomBonus() {
    final random = Random();
    final icons = [
      Icons.star,
      Icons.diamond_outlined,
      Icons.favorite,
      Icons.bolt
    ];
    final colors = [
      Colors.amber,
      Colors.cyan,
      Colors.pink,
      Colors.purple,
      Colors.green
    ];
    // Randomly select bonus type
    final bonusTypes = [
      BonusType.score,
      BonusType.futureDouble,
      BonusType.futureQuad,
      BonusType.extraMove,
      BonusType.wordGame,
    ];
    final type = bonusTypes[random.nextInt(bonusTypes.length)];
    int? scoreValue;
    if (type == BonusType.score) {
      final values = [25, 40, 100, 1];
      scoreValue = values[random.nextInt(values.length)];
    }
    return BonusInfo(
      icon: icons[random.nextInt(icons.length)],
      color: colors[random.nextInt(colors.length)],
      type: type,
      scoreValue: scoreValue,
    );
  }

  List<int> _selectPositions(Random random, List<int> available) {
    final chosen = <int>[];
    var currentAvailable = List<int>.from(available);
    for (int i = 0; i < 3; i++) {
      if (currentAvailable.isEmpty) break;
      final randIndex = random.nextInt(currentAvailable.length);
      final pos = currentAvailable[randIndex];
      chosen.add(pos);
      currentAvailable.removeWhere((p) => p >= pos - 1 && p <= pos + 1);
    }
    return chosen;
  }

  List<int> _generateBonusPositions() {
    final random = Random();
    final List<int> bonusIndices = [];

    Set<int> markUnavailable(Set<int> available, int pos, List<int> edgeIndices) {
      // Remove pos and all neighbors (including diagonals) from available
      int row = pos ~/ 12;
      int col = pos % 12;
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          int r = row + dr;
          int c = col + dc;
          if (r >= 0 && r < 12 && c >= 0 && c < 12) {
            int idx = r * 12 + c;
            if (edgeIndices.contains(idx)) {
              available.remove(idx);
            }
          }
        }
      }
      return available;
    }

    List<int> selectEdgeBonuses(List<int> edgeIndices, int count) {
      Set<int> available = Set.from(edgeIndices);
      List<int> chosen = [];
      while (chosen.length < count && available.isNotEmpty) {
        int idx = available.elementAt(random.nextInt(available.length));
        chosen.add(idx);
        available = markUnavailable(available, idx, edgeIndices);
      }
      return chosen;
    }

    // Top row (row 0, cols 2-9)
    final topEdge = [for (int c = 2; c <= 9; c++) c];
    bonusIndices.addAll(selectEdgeBonuses(topEdge, 3));
    // Bottom row (row 11, cols 2-9)
    final bottomEdge = [for (int c = 2; c <= 9; c++) 12 * 11 + c];
    bonusIndices.addAll(selectEdgeBonuses(bottomEdge, 3));
    // Left col (col 0, rows 2-9)
    final leftEdge = [for (int r = 2; r <= 9; r++) 12 * r];
    bonusIndices.addAll(selectEdgeBonuses(leftEdge, 3));
    // Right col (col 11, rows 2-9)
    final rightEdge = [for (int r = 2; r <= 9; r++) 12 * r + 11];
    bonusIndices.addAll(selectEdgeBonuses(rightEdge, 3));

    return bonusIndices;
  }

  void _addLetters(String letter, int score, int count) {
    for (int i = 0; i < count; i++) {
      _letterPool.add(Letter(letter, score));
    }
    notifyListeners();
  }

  void startGame() {
    _player1Hand.clear();
    _player2Hand.clear();
    _player1Score = 0;
    _player2Score = 0;
    _currentPlayer = 1;
    _initializeLetterPool();
    _initializeBoard();
    _letterPool.shuffle();

    _drawLetters(_player1Hand, 8);
    _drawLetters(_player2Hand, 8);
    _startTurnTimer();

    notifyListeners();
  }

  void _drawLetters(List<Letter> hand, int count) {
    for (int i = 0; i < count; i++) {
      if (_letterPool.isNotEmpty) {
        hand.add(_letterPool.removeAt(0));
      }
    }
  }

  Future<void> endTurn() async {
    if (_placedThisTurn.isEmpty) {
      _showErrorDialog('No words placed, turn passed.');
      _timer?.cancel();
      _currentPlayer = (_currentPlayer == 1) ? 2 : 1;
      _startTurnTimer();
      notifyListeners();
      return;
    }
    if (!_validatePlacement()) {
      _showErrorDialog('All placed tiles must be in a single row or column and contiguous.');
      return;
    }
    if (!await _validateWords()) {
      _showErrorDialog('All words must be valid.');
      return;
    }
    _addScoreForTurn();
    _timer?.cancel();
    _makePlacedLettersPermanent();
    _placedThisTurn.clear();
    List<Letter> currentHand =
        (_currentPlayer == 1) ? _player1Hand : _player2Hand;
    int lettersToDraw = 8 - currentHand.length;
    if (lettersToDraw > 0) {
      _drawLetters(currentHand, lettersToDraw);
    }
    if (isGameOver()) {
      // Handle game over logic
    } else {
      bool extraMove = _currentPlayer == 1 ? _player1ExtraMove : _player2ExtraMove;
      if (extraMove) {
        if (_currentPlayer == 1) {
          _player1ExtraMove = false;
        } else {
          _player2ExtraMove = false;
        }
        // Do not switch player, just start timer for same player
        _startTurnTimer();
      } else {
        _currentPlayer = (_currentPlayer == 1) ? 2 : 1;
        _startTurnTimer();
      }
    }
    notifyListeners();
  }

  void _addScoreForTurn() {
    final words = _extractWordsForPlacedTilesWithBonuses();
    int total = 0;
    bool extraMove = false;
    for (final wordData in words) {
      final word = wordData['word'] as String;
      final bonus = wordData['bonus'] as BonusInfo?;
      int wordScore = 0;
      for (final ch in word.characters) {
        wordScore += _letterScore(ch);
      }
      // Apply score bonus
      if (bonus != null && bonus.type == BonusType.score && bonus.scoreValue != null) {
        wordScore += bonus.scoreValue!;
      }
      // Apply future bonuses
      if (bonus != null && bonus.type == BonusType.futureDouble) {
        if (_currentPlayer == 1) {
          _player1DoubleTurns += 2;
        } else {
          _player2DoubleTurns += 2;
        }
      }
      if (bonus != null && bonus.type == BonusType.futureQuad) {
        if (_currentPlayer == 1) {
          _player1QuadTurns += 1;
        } else {
          _player2QuadTurns += 1;
        }
      }
      // Apply extra move
      if (bonus != null && bonus.type == BonusType.extraMove) {
        extraMove = true;
      }
      // Word game bonus: no logic for now
      total += wordScore;
    }
    // Apply future bonuses if active
    if (_currentPlayer == 1) {
      if (_player1QuadTurns > 0) {
        total *= 4;
        _player1QuadTurns--;
      } else if (_player1DoubleTurns > 0) {
        total *= 2;
        _player1DoubleTurns--;
      }
      _player1Score += total;
      _player1ExtraMove = extraMove;
    } else {
      if (_player2QuadTurns > 0) {
        total *= 4;
        _player2QuadTurns--;
      } else if (_player2DoubleTurns > 0) {
        total *= 2;
        _player2DoubleTurns--;
      }
      _player2Score += total;
      _player2ExtraMove = extraMove;
    }
  }

  int _letterScore(String ch) {
    // Find the first matching letter in the pool or on the board
    for (final l in _letterPool) {
      if (l.letter == ch) return l.score;
    }
    for (final tile in _board) {
      if (tile?.letter?.letter == ch) return tile!.letter!.score;
    }
    return 0;
  }

  bool isGameOver() {
    if (_letterPool.isEmpty) {
      if (_player1Hand.isEmpty || _player2Hand.isEmpty) {
        return true;
      }
    }
    return false;
  }

  void _makePlacedLettersPermanent() {
    for (final tile in _board) {
      if (tile?.letter != null) {
        tile?.isPermanent = true;
      }
    }
  }

  void moveLetter(DraggableLetter draggableLetter, int toIndex) {
    if (_board[toIndex]?.isPermanent == true) return;

    if (draggableLetter.origin == LetterOrigin.board) {
      if (_board[draggableLetter.fromIndex!]?.isPermanent == true) return;
      _board[draggableLetter.fromIndex!]!.letter = null;
      _placedThisTurn.remove(draggableLetter.fromIndex!);
    } else {
      // If the letter comes from the hand, remove it from the hand.
      if (_currentPlayer == 1) {
        _player1Hand.remove(draggableLetter.letter);
      } else {
        _player2Hand.remove(draggableLetter.letter);
      }
    }

    // Place the letter in the new position on the board.
    _board[toIndex]!.letter = draggableLetter.letter;
    _placedThisTurn.add(toIndex);
    notifyListeners();
  }

  void returnLetterToHand(DraggableLetter draggableLetter) {
    if (draggableLetter.origin != LetterOrigin.board) return;
    if (_board[draggableLetter.fromIndex!]?.isPermanent == true) return;

    // Remove the letter from the board.
    _board[draggableLetter.fromIndex!]!.letter = null;

    // Add the letter back to the current player's hand.
    final currentHand =
        _currentPlayer == 1 ? _player1Hand : _player2Hand;
    currentHand.add(draggableLetter.letter);

    notifyListeners();
  }

  bool isPlayableTile(int index) {
    final row = index ~/ 12;
    final col = index % 12;

    final isOuterRing = row == 0 || row == 11 || col == 0 || col == 11;

    if (isOuterRing) {
      return _bonusIndices.contains(index);
    }
    return true;
  }

  void _startTurnTimer() {
    _remainingTime = 600;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        _remainingTime--;
        notifyListeners();
      } else {
        endTurn();
      }
    });
  }

  Future<void> _loadWords() async {
    _wordTrie = Trie();
    final wordsString = await rootBundle.loadString('assets/Acceptable_Words.txt');
    for (final word in wordsString.split('\n')) {
      final w = word.trim();
      if (w.isNotEmpty) _wordTrie.insert(w);
    }
    _wordsLoaded = true;
    notifyListeners();
  }

  bool _validatePlacement() {
    if (_placedThisTurn.isEmpty) return true;
    // Check that all placed tiles are connected (directly or via existing tiles)
    final visited = <int>{};
    final queue = <int>[];
    queue.add(_placedThisTurn.first);
    visited.add(_placedThisTurn.first);
    while (queue.isNotEmpty) {
      final idx = queue.removeLast();
      final neighbors = <int>[];
      int row = idx ~/ 12, col = idx % 12;
      if (col > 0) neighbors.add(idx - 1);
      if (col < 11) neighbors.add(idx + 1);
      if (row > 0) neighbors.add(idx - 12);
      if (row < 11) neighbors.add(idx + 12);
      for (final n in neighbors) {
        if (_board[n]?.letter != null && !visited.contains(n)) {
          visited.add(n);
          queue.add(n);
        }
      }
    }
    // All placed tiles must be in the connected group
    if (!visited.containsAll(_placedThisTurn)) return false;
    // New: Check that every placed tile is part of a word of length >= 2
    for (final idx in _placedThisTurn) {
      if (!_isPartOfWord(idx)) return false;
    }
    return true;
  }

  bool _isPartOfWord(int idx) {
    // Check horizontal
    int row = idx ~/ 12;
    int col = idx % 12;
    int left = col, right = col;
    while (left > 0 && _board[row * 12 + (left - 1)]?.letter != null) left--;
    while (right < 11 && _board[row * 12 + (right + 1)]?.letter != null) right++;
    if (right - left + 1 >= 2) return true;
    // Check vertical
    int up = row, down = row;
    while (up > 0 && _board[(up - 1) * 12 + col]?.letter != null) up--;
    while (down < 11 && _board[(down + 1) * 12 + col]?.letter != null) down++;
    if (down - up + 1 >= 2) return true;
    return false;
  }

  Future<bool> _validateWords() async {
    final words = _extractWordsForPlacedTilesWithBonuses();
    for (final wordData in words) {
      final word = wordData['word'] as String;
      final normalized = _normalizeFinalForm(word);
      if (word.length > 1 && !_wordTrie.contains(normalized)) {
        return false;
      }
    }
    return true;
  }

  List<Map<String, dynamic>> _extractWordsForPlacedTilesWithBonuses() {
    Set<String> seen = {};
    List<Map<String, dynamic>> words = [];
    for (final idx in _placedThisTurn) {
      // Horizontal word
      int row = idx ~/ 12;
      int col = idx % 12;
      int left = col, right = col;
      while (left > 0 && _board[row * 12 + (left - 1)]?.letter != null) left--;
      while (right < 11 && _board[row * 12 + (right + 1)]?.letter != null) right++;
      if (right - left + 1 > 1) {
        String w = '';
        BonusInfo? bonus;
        for (int c = right; c >= left; c--) {
          final tile = _board[row * 12 + c];
          final letter = tile?.letter?.letter;
          if (letter != null && letter.isNotEmpty) w += letter;
          if (tile?.bonus != null && _placedThisTurn.contains(row * 12 + c)) {
            bonus ??= tile!.bonus;
          }
        }
        if (w.length > 1 && !seen.contains(w)) {
          words.add({'word': w, 'bonus': bonus});
          seen.add(w);
        }
      }
      // Vertical word
      int up = row, down = row;
      while (up > 0 && _board[(up - 1) * 12 + col]?.letter != null) up--;
      while (down < 11 && _board[(down + 1) * 12 + col]?.letter != null) down++;
      if (down - up + 1 > 1) {
        String w = '';
        BonusInfo? bonus;
        for (int r = up; r <= down; r++) {
          final tile = _board[r * 12 + col];
          final letter = tile?.letter?.letter;
          if (letter != null && letter.isNotEmpty) w += letter;
          if (tile?.bonus != null && _placedThisTurn.contains(r * 12 + col)) {
            bonus ??= tile!.bonus;
          }
        }
        if (w.length > 1 && !seen.contains(w)) {
          words.add({'word': w, 'bonus': bonus});
          seen.add(w);
        }
      }
    }
    return words;
  }

  String _normalizeFinalForm(String word) {
    if (word.isEmpty) return word;
    print(word);
    final finals = {
      'מ': 'ם',
      'צ': 'ץ',
      'כ': 'ך',
      'פ': 'ף',
      'נ': 'ן',
    };
    final last = word.characters.last;
    if (finals.containsKey(last)) {
      print(word.characters.take(word.characters.length - 1).join() + finals[last]!);
      return word.characters.take(word.characters.length - 1).join() + finals[last]!;
    }
    return word;
  }

  void _showErrorDialog(String message) {
    if (onError != null) {
      onError!(message);
    } else {
      print('ERROR: ' + message);
    }
  }

  Future<List<Map<String, dynamic>>> validateWordsWithStatus() async {
    final words = _extractWordsForPlacedTilesWithBonuses();
    List<Map<String, dynamic>> results = [];
    for (final wordData in words) {
      final word = wordData['word'] as String;
      final bonus = wordData['bonus'] as BonusInfo?;
      final normalized = _normalizeFinalForm(word);
      final isValid = word.length > 1 && _wordTrie.contains(normalized);
      results.add({'word': word, 'isValid': isValid, 'bonus': bonus});
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> wordsWithScoresForTurn() async {
    final words = _extractWordsForPlacedTilesWithBonuses();
    List<Map<String, dynamic>> results = [];
    for (final wordData in words) {
      final word = wordData['word'] as String;
      final bonus = wordData['bonus'] as BonusInfo?;
      final normalized = _normalizeFinalForm(word);
      final isValid = word.length > 1 && _wordTrie.contains(normalized);
      int score = 0;
      for (final ch in word.characters) {
        score += _letterScore(ch);
      }
      if (bonus != null && bonus.type == BonusType.score && bonus.scoreValue != null) {
        score += bonus.scoreValue!;
      }
      results.add({'word': word, 'isValid': isValid, 'score': score, 'bonus': bonus});
    }
    return results;
  }
} 