import 'dart:async';
import 'package:bonus/models/board_tile.dart';
import 'package:bonus/models/letter.dart';
import 'package:bonus/repositories/game_repository.dart';

class LocalGameRepository implements GameRepository {
  final Map<String, dynamic> _gameState = {};
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> getGameStateStream(String roomID) {
    // Immediately provide the current state to new listeners
    Future.microtask(() => _controller.add(_gameState));
    return _controller.stream;
  }

  @override
  Future<void> updateGameState(
    String roomID, {
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
  }) async {
    if (player1Score != null) _gameState['player1Score'] = player1Score;
    if (player2Score != null) _gameState['player2Score'] = player2Score;
    if (currentPlayer != null) _gameState['turn'] = currentPlayer == '1' ? 'player1' : 'player2';
    if (boardState != null) _gameState['boardState'] = boardState.map((t) => t?.toJson()).toList();
    if (player1Hand != null) _gameState['player1Hand'] = player1Hand.map((l) => l.toString()).toList();
    if (player2Hand != null) _gameState['player2Hand'] = player2Hand.map((l) => l.toString()).toList();
    if (letterPool != null) _gameState['letterPool'] = letterPool.map((l) => l.toString()).toList();
    if (turnStartTimestamp != null) _gameState['turnStartTimestamp'] = turnStartTimestamp;
    if (players != null) _gameState['players'] = players;
    if (firstWordPlaced != null) _gameState['firstWordPlaced'] = firstWordPlaced;
    if (player1DoubleTurns != null) _gameState['player1DoubleTurns'] = player1DoubleTurns;
    if (player2DoubleTurns != null) _gameState['player2DoubleTurns'] = player2DoubleTurns;
    if (player1QuadTurns != null) _gameState['player1QuadTurns'] = player1QuadTurns;
    if (player2QuadTurns != null) _gameState['player2QuadTurns'] = player2QuadTurns;
    if (firstMoveDone != null) _gameState['firstMoveDone'] = firstMoveDone;
    if (lastSkipped != null) _gameState['lastSkipped'] = lastSkipped;
    if (player1Replacements != null) _gameState['player1Replacements'] = player1Replacements;
    if (player2Replacements != null) _gameState['player2Replacements'] = player2Replacements;
    _controller.add(_gameState);
  }

  @override
  Future<String> createRoom(String player1Name) async {
    _gameState.clear();
    _gameState['players'] = {'player1': player1Name};
    return 'local_room';
  }

  @override
  Future<void> createNewGame(String roomID, Map<String, dynamic> initialGameState) async {
    _gameState.addAll(initialGameState);
    _controller.add(_gameState);
  }

  @override
  Future<void> joinRoom(String roomID, String player2Name) async {
    final players = _gameState['players'] as Map<String, String>? ?? {};
    players['player2'] = player2Name;
    _gameState['players'] = players;
  }

  @override
  Future<void> updatePlayerName(String roomID, String playerID, String name) async {
    final players = _gameState['players'] as Map<String, String>? ?? {};
    players[playerID] = name;
    _gameState['players'] = players;
  }

  @override
  Future<Map<String, String>> getPlayerNames(String roomID) async {
    return _gameState['players'] as Map<String, String>? ?? {};
  }

  void dispose() {
    _controller.close();
  }
} 