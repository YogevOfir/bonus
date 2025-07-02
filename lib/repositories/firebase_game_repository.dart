import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:bonus/models/board_tile.dart';
import 'package:bonus/models/letter.dart';
import 'package:bonus/repositories/game_repository.dart';
import 'package:bonus/services/auth_service.dart';

class FirebaseGameRepository implements GameRepository {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final AuthService _authService = AuthService();

  @override
  Stream<Map<String, dynamic>> getGameStateStream(String roomID) {
    return _database.ref('rooms/$roomID').onValue.map((event) {
      if (event.snapshot.value == null) {
        return {};
      }
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return data;
    });
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
    Map<String, dynamic>? lastTurnResults,
    List<int>? lastTurnWordIndices,
    String? emojiEvent,
  }) async {
    // Ensure user is authenticated before making database calls
    final userId = await _authService.getUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final Map<String, dynamic> updates = {};
    if (player1Score != null) updates['player1Score'] = player1Score;
    if (player2Score != null) updates['player2Score'] = player2Score;
    if (currentPlayer != null) updates['turn'] = currentPlayer == '1' ? 'player1' : 'player2';
    if (boardState != null) updates['boardState'] = boardState.map((t) => t?.toJson() ?? {}).toList();
    if (player1Hand != null) updates['player1Hand'] = player1Hand.map((l) => l.toString()).toList();
    if (player2Hand != null) updates['player2Hand'] = player2Hand.map((l) => l.toString()).toList();
    if (letterPool != null) updates['letterPool'] = letterPool.map((l) => l.toString()).toList();
    if (turnStartTimestamp != null) updates['turnStartTimestamp'] = turnStartTimestamp;
    if (players != null) updates['players'] = players;
    if (firstWordPlaced != null) updates['firstWordPlaced'] = firstWordPlaced;
    if (player1DoubleTurns != null) updates['player1DoubleTurns'] = player1DoubleTurns;
    if (player2DoubleTurns != null) updates['player2DoubleTurns'] = player2DoubleTurns;
    if (player1QuadTurns != null) updates['player1QuadTurns'] = player1QuadTurns;
    if (player2QuadTurns != null) updates['player2QuadTurns'] = player2QuadTurns;
    if (firstMoveDone != null) updates['firstMoveDone'] = firstMoveDone;
    if (lastSkipped != null) updates['lastSkipped'] = lastSkipped;
    if (player1Replacements != null) updates['player1Replacements'] = player1Replacements;
    if (player2Replacements != null) updates['player2Replacements'] = player2Replacements;
    if (lastTurnResults != null) updates['lastTurnResults'] = lastTurnResults;
    if (lastTurnWordIndices != null) updates['lastTurnWordIndices'] = lastTurnWordIndices;
    if (emojiEvent != null) updates['emojiEvent'] = emojiEvent;
    
    // Add user ID to track who made the update
    updates['lastUpdatedBy'] = userId;
    updates['lastUpdatedAt'] = ServerValue.timestamp;
    
    if (updates.isNotEmpty) {
      await _database.ref('rooms/$roomID').update(updates);
    }
  }

  @override
  Future<String> createRoom(String player1Name) async {
    // Ensure user is authenticated before creating room
    final userId = await _authService.getUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final roomID = (100000 + Random().nextInt(900000)).toString();
    await _database.ref('rooms/$roomID/players/player1').set(player1Name);
    await _database.ref('rooms/$roomID/createdBy').set(userId);
    await _database.ref('rooms/$roomID/createdAt').set(ServerValue.timestamp);
    return roomID;
  }

  @override
  Future<void> createNewGame(String roomID, Map<String, dynamic> initialGameState) async {
    // Ensure user is authenticated before creating game
    final userId = await _authService.getUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    initialGameState['createdBy'] = userId;
    initialGameState['createdAt'] = ServerValue.timestamp;
    await _database.ref('rooms/$roomID').set(initialGameState);
  }

  @override
  Future<void> joinRoom(String roomID, String player2Name) async {
    // Ensure user is authenticated before joining room
    final userId = await _authService.getUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await _database.ref('rooms/$roomID/players/player2').set(player2Name);
    await _database.ref('rooms/$roomID/joinedBy').set(userId);
    await _database.ref('rooms/$roomID/joinedAt').set(ServerValue.timestamp);
  }

  @override
  Future<void> updatePlayerName(String roomID, String playerID, String name) async {
    // Ensure user is authenticated before updating player name
    final userId = await _authService.getUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await _database.ref('rooms/$roomID/players/$playerID').set(name);
    await _database.ref('rooms/$roomID/lastUpdatedBy').set(userId);
    await _database.ref('rooms/$roomID/lastUpdatedAt').set(ServerValue.timestamp);
  }

  @override
  Future<Map<String, String>> getPlayerNames(String roomID) async {
    final snapshot = await _database.ref('rooms/$roomID/players').get();
    if (snapshot.exists && snapshot.value != null) {
      return Map<String, String>.from(snapshot.value as Map);
    }
    return {};
  }
  
  Future<int> fetchServerTime() async {
    final tempRef = _database.ref('serverTimeForSync').push();
    await tempRef.set(ServerValue.timestamp);
    final snap = await tempRef.get();
    final serverTime = snap.value as int?;
    await tempRef.remove();
    return serverTime ?? DateTime.now().millisecondsSinceEpoch;
  }
} 