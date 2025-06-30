import 'package:bonus/models/board_tile.dart';
import 'package:bonus/models/bonus_info.dart';
import 'package:bonus/models/letter.dart';
import 'package:bonus/services/validation/word_validation_service.dart';
import 'package:characters/characters.dart';

class ScoreService {
  final WordValidationService _wordValidationService;

  ScoreService(this._wordValidationService);

  int _letterScore(String ch, List<Letter> letterPool, List<BoardTile?> board) {
    for (final l in letterPool) {
      if (l.letter == ch) return l.isWildcard ? 0 : l.score;
    }
    for (final tile in board) {
      if (tile?.letter?.letter == ch) {
        if (tile!.letter!.isWildcard) return 0;
        return tile.letter!.score;
      }
    }
    return 0;
  }

  List<Map<String, dynamic>> extractWordsForPlacedTilesWithBonuses({
    required List<BoardTile?> board,
    required Set<int> placedThisTurn,
  }) {
    Set<String> seen = {}; // Will store joined indices as unique key
    List<Map<String, dynamic>> words = [];
    for (final idx in placedThisTurn) {
      // Horizontal word
      int row = idx ~/ 12;
      int col = idx % 12;
      int left = col, right = col;
      while (left > 0 && board[row * 12 + (left - 1)]?.letter != null) left--;
      while (right < 11 && board[row * 12 + (right + 1)]?.letter != null)
        right++;
      if (right - left + 1 > 1) {
        String w = '';
        BonusInfo? bonus;
        List<int> indices = [];
        for (int c = right; c >= left; c--) {
          final tile = board[row * 12 + c];
          final letter = tile?.letter?.letter;
          if (letter != null && letter.isNotEmpty) {
            w += letter;
            indices.add(row * 12 + c);
          }
          if (tile?.bonus != null && placedThisTurn.contains(row * 12 + c)) {
            bonus ??= tile!.bonus;
          }
        }
        final indicesKey = indices.reversed.join(',');
        if (w.length > 1 && !seen.contains(indicesKey)) {
          words.add({
            'word': w,
            'bonus': bonus,
            'indices': indices.reversed.toList()
          });
          seen.add(indicesKey);
        }
      }
      // Vertical word
      int up = row, down = row;
      while (up > 0 && board[(up - 1) * 12 + col]?.letter != null) up--;
      while (down < 11 && board[(down + 1) * 12 + col]?.letter != null) down++;
      if (down - up + 1 > 1) {
        String w = '';
        BonusInfo? bonus;
        List<int> indices = [];
        for (int r = up; r <= down; r++) {
          final tile = board[r * 12 + col];
          final letter = tile?.letter?.letter;
          if (letter != null && letter.isNotEmpty) {
            w += letter;
            indices.add(r * 12 + col);
          }
          if (tile?.bonus != null && placedThisTurn.contains(r * 12 + col)) {
            bonus ??= tile!.bonus;
          }
        }
        final indicesKey = indices.join(',');
        if (w.length > 1 && !seen.contains(indicesKey)) {
          words.add({'word': w, 'bonus': bonus, 'indices': indices});
          seen.add(indicesKey);
        }
      }
    }
    return words;
  }

  Future<TurnScoreResult> calculateTurnScore({
    required List<BoardTile?> board,
    required Set<int> placedThisTurn,
    required List<Letter> letterPool,
    required int activeDoubleTurns,
    required int activeQuadTurns,
    List<String>? acceptedInvalidWords,
  }) async {
    final wordList = extractWordsForPlacedTilesWithBonuses(
      board: board,
      placedThisTurn: placedThisTurn,
    );

    int totalScore = 0;
    bool extraMoveGained = false;
    int futureDoubleTurnsGained = 0;
    int futureQuadTurnsGained = 0;
    int letterScore = 0;
    int bonusScore = 0;

    for (final wordData in wordList) {
      final word = wordData['word'] as String;
      final isAccepted = acceptedInvalidWords?.contains(word) ?? false;
      if (!_wordValidationService.isValidWord(word) && !isAccepted) {
        continue;
      }

      int score = 0;
      final indices = wordData['indices'] as List<int>;
      for (final idx in indices) {
        final tile = board[idx];
        if (tile != null && tile.letter != null) {
          score += tile.letter!.isWildcard ? 0 : tile.letter!.score;
        }
      }
      letterScore += score;

      final bonus = wordData['bonus'] as BonusInfo?;
      if (bonus != null) {
        switch (bonus.type) {
          case BonusType.score:
            final bScore = bonus.scoreValue ?? 0;
            score += bScore;
            bonusScore += bScore;
            break;
          case BonusType.extraMove:
            extraMoveGained = true;
            break;
          case BonusType.futureDouble:
            futureDoubleTurnsGained += 2;
            break;
          case BonusType.futureQuad:
            futureQuadTurnsGained += 1;
            break;
          // case BonusType.wordGame:
          //   // TODO: Implement word game logic
          // break;
        }
      }
      totalScore += score;
    }

    final baseScore = totalScore;
    int multiplier = 1;
    if (activeQuadTurns > 0) {
      totalScore *= 4;
      multiplier = 4;
    } else if (activeDoubleTurns > 0) {
      totalScore *= 2;
      multiplier = 2;
    }

    return TurnScoreResult(
      score: totalScore,
      baseScore: baseScore,
      letterScore: letterScore,
      bonusScore: bonusScore,
      multiplier: multiplier,
      extraMoveGained: extraMoveGained,
      futureDoubleTurnsGained: futureDoubleTurnsGained,
      futureQuadTurnsGained: futureQuadTurnsGained,
    );
  }
}

class TurnScoreResult {
  final int score;
  final int baseScore;
  final int letterScore;
  final int bonusScore;
  final int multiplier;
  final bool extraMoveGained;
  final int futureDoubleTurnsGained;
  final int futureQuadTurnsGained;

  TurnScoreResult({
    required this.score,
    required this.baseScore,
    required this.letterScore,
    required this.bonusScore,
    required this.multiplier,
    this.extraMoveGained = false,
    this.futureDoubleTurnsGained = 0,
    this.futureQuadTurnsGained = 0,
  });
}
