import '../models/board_tile.dart';
import '../models/letter.dart';

abstract class GameRepository {
  Stream<Map<String, dynamic>> getGameStateStream(String roomID);

  Future<void> updateGameState(String roomID, {
    int? player1Score,
    int? player2Score,
    String? currentPlayer,
    List<BoardTile?>? boardState,
    List<Letter>? player1Hand,
    List<Letter>? player2Hand,
    List<Letter>? letterPool,
    int? turnStartTimestamp,
    Map<String, String>? players,
    bool? firstWordPlaced,
    int? player1DoubleTurns,
    int? player2DoubleTurns,
    int? player1QuadTurns,
    int? player2QuadTurns,
    bool? firstMoveDone,
    int? lastSkipped,
    int? player1Replacements,
    int? player2Replacements,
    Map<String, dynamic>? lastTurnResults,
    List<int>? lastTurnWordIndices,
    String? emojiEvent,
  });

  Future<String> createRoom(String player1Name);

  Future<void> createNewGame(String roomID, Map<String, dynamic> initialGameState);

  Future<void> joinRoom(String roomID, String player2Name);

  Future<void> updatePlayerName(String roomID, String playerID, String name);
  
  Future<Map<String, String>> getPlayerNames(String roomID);
} 