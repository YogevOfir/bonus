import 'package:bonus/models/board_tile.dart';

class GameRulesService {
  
  bool isPlayableTile({
    required int index,
    required bool firstMoveDone,
    required int currentPlayer,
    required int firstPlayerId,
    required List<int> bonusIndices,
  }) {
    final row = index ~/ 12;
    final col = index % 12;

    final isOuterRing = row == 0 || row == 11 || col == 0 || col == 11;

    if (!firstMoveDone && currentPlayer == firstPlayerId && bonusIndices.contains(index)) {
      return false;
    }

    if (isOuterRing) {
      return bonusIndices.contains(index);
    }
    return true;
  }

  bool validatePlacement({
    required List<BoardTile?> board,
    required Set<int> placedThisTurn,
  }) {
    if (placedThisTurn.isEmpty) return true;
    
    // Ensure all placed letters are in the same row or same column
    final rows = placedThisTurn.map((i) => i ~/ 12).toSet();
    final cols = placedThisTurn.map((i) => i % 12).toSet();
    if (rows.length > 1 && cols.length > 1) {
      return false;
    }

    final visited = <int>{};
    final queue = <int>[];
    queue.add(placedThisTurn.first);
    visited.add(placedThisTurn.first);

    while (queue.isNotEmpty) {
      final idx = queue.removeLast();
      final neighbors = <int>[];
      int row = idx ~/ 12, col = idx % 12;
      if (col > 0) neighbors.add(idx - 1);
      if (col < 11) neighbors.add(idx + 1);
      if (row > 0) neighbors.add(idx - 12);
      if (row < 11) neighbors.add(idx + 12);
      
      for (final n in neighbors) {
        if (board[n]?.letter != null && !visited.contains(n)) {
          visited.add(n);
          queue.add(n);
        }
      }
    }
    
    if (!visited.containsAll(placedThisTurn)) return false;
    
    for (final idx in placedThisTurn) {
      if (!_isPartOfWord(idx, board)) return false;
    }
    
    return true;
  }

  bool _isPartOfWord(int idx, List<BoardTile?> board) {
    int row = idx ~/ 12;
    int col = idx % 12;
    
    int left = col, right = col;
    while (left > 0 && board[row * 12 + (left - 1)]?.letter != null) left--;
    while (right < 11 && board[row * 12 + (right + 1)]?.letter != null) right++;
    if (right - left + 1 >= 2) return true;
    
    int up = row, down = row;
    while (up > 0 && board[(up - 1) * 12 + col]?.letter != null) up--;
    while (down < 11 && board[(down + 1) * 12 + col]?.letter != null) down++;
    if (down - up + 1 >= 2) return true;
    
    return false;
  }

  bool validatePlacementTouchesExisting({
    required List<BoardTile?> board,
    required Set<int> placedThisTurn,
  }) {
    bool hasPermanentLetters = board.any((tile) => tile?.isPermanent == true);
    if (!hasPermanentLetters) {
      return true;
    }

    for (final placedIndex in placedThisTurn) {
      final row = placedIndex ~/ 12;
      final col = placedIndex % 12;
      
      final adjacentPositions = [
        if (row > 0) (row - 1) * 12 + col,
        if (row < 11) (row + 1) * 12 + col,
        if (col > 0) row * 12 + (col - 1),
        if (col < 11) row * 12 + (col + 1),
      ];
      
      for (final adjIndex in adjacentPositions) {
        if (board[adjIndex]?.isPermanent == true && board[adjIndex]?.letter != null) {
          return true;
        }
      }
    }
    
    return false;
  }
} 