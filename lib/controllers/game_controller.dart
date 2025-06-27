import 'dart:async';
import 'dart:math';

import 'package:bonus/models/draggable_letter.dart';
import 'package:bonus/repositories/firebase_game_repository.dart';
import 'package:bonus/repositories/local_game_repository.dart';
import 'package:bonus/services/rules/game_rules_service.dart';
import 'package:bonus/services/scoring/score_service.dart';
import 'package:bonus/services/validation/word_validation_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:bonus/models/board_tile.dart';
import 'package:bonus/models/bonus_info.dart';
import 'package:bonus/models/letter.dart';
import 'package:bonus/repositories/game_repository.dart';

class GameController extends ChangeNotifier {
  // Services
  late final GameRulesService _rulesService;
  late final WordValidationService _validationService;
  late final ScoreService _scoreService;

  // Repository
  late final GameRepository _repository;
  bool get isOnline => _repository is FirebaseGameRepository;

  // Game State
  late List<Letter> _letterPool;
  final List<Letter> _player1Hand = [];
  final List<Letter> _player2Hand = [];
  late List<BoardTile?> _board;
  int _currentPlayer = 1;
  int _player1Score = 0;
  int _player2Score = 0;
  String? _roomID;
  String _player1Name = 'Player 1';
  String _player2Name = 'Player 2';
  int _localPlayerId = 1;
  List<int> _bonusIndices = [];
  Timer? _timer;
  int? _turnStartTimestamp;
  int _serverTimeOffset = 0;
  final Set<int> _placedThisTurn = {};
  bool _isSynced = false;
  bool _firstMoveDone = false;
  int _firstPlayerId = 1;

  // Bonus State
  int _player1DoubleTurns = 0;
  int _player2DoubleTurns = 0;
  int _player1QuadTurns = 0;
  int _player2QuadTurns = 0;
  bool _player1ExtraMove = false;
  bool _player2ExtraMove = false;

  void Function(String)? onError;
  void Function()? onPlayerLeft;
  void Function()? onTurnPassedDueToTimeout;

  // Getters
  List<Letter> get player1Hand => _player1Hand;
  List<Letter> get player2Hand => _player2Hand;
  List<BoardTile?> get board => _board;
  int get currentPlayer => _currentPlayer;
  int get player1Score => _player1Score;
  int get player2Score => _player2Score;
  String get player1Name => _player1Name;
  String get player2Name => _player2Name;
  int get localPlayerId => _localPlayerId;
  bool get isSynced => _isSynced;
  bool get wordsLoaded => _validationService.wordsLoaded;
  List<Letter> get letterPool => _letterPool;
  int get remainingTime {
    if (_turnStartTimestamp == null) return 120;
    // In local games, offset is 0. In online games, it's calculated.
    final now = DateTime.now().millisecondsSinceEpoch - _serverTimeOffset;
    final elapsed = ((now - _turnStartTimestamp!) / 1000).floor();
    return (120 - elapsed).clamp(0, 120);
  }

  List<int> get placedThisTurn => _placedThisTurn.toList();
  ScoreService get scoreService => _scoreService;
  WordValidationService get validationService => _validationService;
  int get player1DoubleTurns => _player1DoubleTurns;
  int get player1QuadTurns => _player1QuadTurns;
  int get player2DoubleTurns => _player2DoubleTurns;
  int get player2QuadTurns => _player2QuadTurns;
  bool get firstMoveDone => _firstMoveDone;

  GameController({GameRepository? repository}) {
    _validationService = WordValidationService();
    _scoreService = ScoreService(_validationService);
    _rulesService = GameRulesService();
    _repository = repository ?? LocalGameRepository();

    _initialize();
  }

  void _initialize() async {
    await _validationService.loadWords();
    _board = List.generate(144, (index) => BoardTile());
    _letterPool = [];
    if (!isOnline) {
      startNewLocalGame();
    }
    notifyListeners();
  }

  // SECTION: Game Setup

  void startNewLocalGame() {
    _player1Score = 0;
    _player2Score = 0;
    _firstPlayerId = Random().nextBool() ? 1 : 2;
    _currentPlayer = _firstPlayerId;
    _firstMoveDone = false;
    _initializeLetterPool();
    _initializeBoard();
    _letterPool.shuffle();

    _drawLetters(_player1Hand, 8);
    _drawLetters(_player2Hand, 8);
    _startTurnTimer();
    _isSynced = true;
    notifyListeners();
  }

  Future<void> startNewOnlineGame(String roomID) async {
    _roomID = roomID;
    _player1Score = 0;
    _player2Score = 0;
    _firstPlayerId = Random().nextBool() ? 1 : 2;
    _currentPlayer = _firstPlayerId;
    _firstMoveDone = false;
    _initializeLetterPool();
    _initializeBoard();
    _letterPool.shuffle();

    _drawLetters(_player1Hand, 8);
    _drawLetters(_player2Hand, 8);

    final initialState = {
      'player1Score': _player1Score,
      'player2Score': _player2Score,
      'turn': _firstPlayerId == 1 ? 'player1' : 'player2',
      'boardState': _board.map((t) => t?.toJson() ?? {}).toList(),
      'player1Hand': _player1Hand.map((l) => l.toString()).toList(),
      'player2Hand': _player2Hand.map((l) => l.toString()).toList(),
      'letterPool': _letterPool.map((l) => l.toString()).toList(),
      'players': {'player1': _player1Name},
      'firstMoveDone': _firstMoveDone,
      'firstPlayerId': _firstPlayerId,
    };

    await _repository.createNewGame(roomID, initialState);
    _listenToRemoteChanges();
  }

  void setPlayer1Name(String name) {
    _player1Name = name;
    if (_roomID != null) {
      _repository.updatePlayerName(_roomID!, 'player1', name);
    }
    notifyListeners();
  }

  void setRoomID(String roomID) {
    _roomID = roomID;
    if (isOnline) {
      _setupOnDisconnect();
      _listenToRemoteChanges();
    }
  }

  void setLocalPlayerId(int id) {
    _localPlayerId = id;
  }

  // SECTION: Core Game Logic (Turn Management)

  Future<TurnScoreResult?> validateAndGetTurnResults() async {
    if (!_rulesService.validatePlacementTouchesExisting(
        board: _board, placedThisTurn: _placedThisTurn)) {
      onError?.call(
          'At least one letter must touch an existing word on the board.');
      return null;
    }

    if (!_rulesService.validatePlacement(
        board: _board, placedThisTurn: _placedThisTurn)) {
      onError?.call('All placed letters must be connected and part of a word.');
      return null;
    }

    bool hasValidWords = await _hasValidWords();
    if (!hasValidWords) {
      return null;
    }

    return await _scoreService.calculateTurnScore(
      board: _board,
      placedThisTurn: _placedThisTurn,
      letterPool: _letterPool,
      activeDoubleTurns:
          _currentPlayer >= 1 ? _player1DoubleTurns : _player2DoubleTurns,
      activeQuadTurns:
          _currentPlayer == 1 ? _player1QuadTurns : _player2QuadTurns,
    );
  }

  Future<void> endTurn(
      {bool skipValidation = false, bool fromTimeout = false}) async {
    if (isOnline && _localPlayerId != _currentPlayer) {
      onError?.call("It's not your turn!");
      return;
    }

    if (_placedThisTurn.isEmpty) {
      if (fromTimeout) {
        _returnPlacedLettersToHand();
        onTurnPassedDueToTimeout?.call();
        _passTurn();
        return;
      }
      _passTurn();
      return;
    }

    if (fromTimeout) {
      _returnPlacedLettersToHand();
      onTurnPassedDueToTimeout?.call();
      _passTurn();
      return;
    }

    if (!skipValidation) {
      if (!_rulesService.validatePlacementTouchesExisting(
          board: _board, placedThisTurn: _placedThisTurn)) {
        onError?.call(
            'At least one letter must touch an existing word on the board.');
        return;
      }

      if (!_rulesService.validatePlacement(
          board: _board, placedThisTurn: _placedThisTurn)) {
        onError
            ?.call('All placed letters must be connected and part of a word.');
        return;
      }

      bool hasValidWords = await _hasValidWords();
      if (!hasValidWords) {
        return;
      }
    }

    // Calculate score and get bonuses gained this turn
    final scoreResult = await _scoreService.calculateTurnScore(
      board: _board,
      placedThisTurn: _placedThisTurn,
      letterPool: _letterPool,
      activeDoubleTurns:
          _currentPlayer == 1 ? _player1DoubleTurns : _player2DoubleTurns,
      activeQuadTurns:
          _currentPlayer == 1 ? _player1QuadTurns : _player2QuadTurns,
    );

    // Store bonuses gained this turn
    int gainedDouble = scoreResult.futureDoubleTurnsGained;
    int gainedQuad = scoreResult.futureQuadTurnsGained;

    _applyScore(scoreResult,
        applyBonuses: false); // Don't increment bonuses yet

    // Set firstMoveDone immediately after the first player's first valid turn
    if (!_firstMoveDone && _currentPlayer == _firstPlayerId) {
      _firstMoveDone = true;
      await _updateRepository();
    }

    // Decrement double/quad turn if it was active for this turn
    if (_currentPlayer == 1) {
      if (_player1QuadTurns > 0) {
        _player1QuadTurns--;
      } else if (_player1DoubleTurns > 0) {
        _player1DoubleTurns--;
      }
    } else {
      if (_player2QuadTurns > 0) {
        _player2QuadTurns--;
      } else if (_player2DoubleTurns > 0) {
        _player2DoubleTurns--;
      }
    }

    // Now apply any new bonuses gained this turn (for NEXT turn(s))
    if (_currentPlayer == 1) {
      if (gainedDouble > 0) {
        _player1DoubleTurns += gainedDouble;
      }
      if (gainedQuad > 0) {
        _player1QuadTurns += gainedQuad;
      }
    } else {
      if (gainedDouble > 0) {
        _player2DoubleTurns += gainedDouble;
      }
      if (gainedQuad > 0) {
        _player2QuadTurns += gainedQuad;
      }
    }

    _makePlacedLettersPermanent();

    if (!_firstMoveDone &&
        _currentPlayer == _firstPlayerId &&
        _placedThisTurn.isNotEmpty) {
      _firstMoveDone = true;
    }

    _placedThisTurn.clear();

    List<Letter> currentHand =
        (_currentPlayer == 1) ? _player1Hand : _player2Hand;
    int lettersToDraw = 8 - currentHand.length;
    if (lettersToDraw > 0) {
      _drawLetters(currentHand, lettersToDraw);
    }

    if (isGameOver()) {
      // TODO: Handle game over
    } else {
      bool extraMove =
          _currentPlayer == 1 ? _player1ExtraMove : _player2ExtraMove;
      if (extraMove) {
        if (_currentPlayer == 1)
          _player1ExtraMove = false;
        else
          _player2ExtraMove = false;
        _startTurnTimer();
      } else {
        _currentPlayer = (_currentPlayer == 1) ? 2 : 1;
        _startTurnTimer();
      }
    }

    await _updateRepository();
    notifyListeners();
  }

  void _passTurn() {
    // If the first player passes/skips their first turn, mark firstMoveDone
    if (!_firstMoveDone && _currentPlayer == _firstPlayerId) {
      _firstMoveDone = true;
      _updateRepository(); // Ensure sync immediately
    }
    _currentPlayer = (_currentPlayer == 1) ? 2 : 1;
    _startTurnTimer();
    _updateRepository();
    notifyListeners();
  }

  // SECTION: Letter & Board Manipulation

  void moveLetter(DraggableLetter draggableLetter, int toIndex) {
    if (isOnline && _localPlayerId != _currentPlayer) {
      onError?.call("It's not your turn!");
      return;
    }
    if (_board[toIndex]?.isPermanent == true) return;

    if (draggableLetter.origin == LetterOrigin.board) {
      if (_board[draggableLetter.fromIndex!]?.isPermanent == true) return;
      _board[draggableLetter.fromIndex!]!.letter = null;
      _placedThisTurn.remove(draggableLetter.fromIndex!);
    } else {
      final hand = (_currentPlayer == 1) ? _player1Hand : _player2Hand;
      hand.remove(draggableLetter.letter);
    }

    _board[toIndex]!.letter = draggableLetter.letter;
    _placedThisTurn.add(toIndex);
    notifyListeners();
  }

  void returnLetterToHand(DraggableLetter draggableLetter) {
    if (draggableLetter.origin != LetterOrigin.board ||
        _board[draggableLetter.fromIndex!]?.isPermanent == true) {
      return;
    }

    _board[draggableLetter.fromIndex!]!.letter = null;
    _placedThisTurn.remove(draggableLetter.fromIndex!);

    final currentHand = (_currentPlayer == 1) ? _player1Hand : _player2Hand;
    currentHand.add(draggableLetter.letter);
    notifyListeners();
  }

  void setWildcardLetter(int boardIndex, String chosenLetter) {
    final tile = _board[boardIndex];
    // Ensure there is a letter and it is a wildcard.
    if (tile != null && tile.letter != null && tile.letter!.letter == ' ') {
      tile.letter = Letter(chosenLetter.toUpperCase(), 0, isWildcard: true);
      notifyListeners();
    }
  }

  void _makePlacedLettersPermanent() {
    for (final index in _placedThisTurn) {
      _board[index]?.isPermanent = true;
    }
  }

  // SECTION: Data Sync & Repository

  void _listenToRemoteChanges() {
    if (_roomID == null) return;
    _repository.getGameStateStream(_roomID!).listen((data) {
      if (data.isNotEmpty) {
        _syncFromRemote(data);
      }
    });
  }

  Future<void> _updateRepository() async {
    if (_roomID == null) return;
    await _repository.updateGameState(
      _roomID!,
      player1Score: _player1Score,
      player2Score: _player2Score,
      currentPlayer: _currentPlayer.toString(),
      boardState: _board,
      player1Hand: _player1Hand,
      player2Hand: _player2Hand,
      letterPool: _letterPool,
      turnStartTimestamp: _turnStartTimestamp,
      players: {'player1': _player1Name, 'player2': _player2Name},
      player1DoubleTurns: _player1DoubleTurns,
      player2DoubleTurns: _player2DoubleTurns,
      player1QuadTurns: _player1QuadTurns,
      player2QuadTurns: _player2QuadTurns,
      firstMoveDone: _firstMoveDone,
    );
  }

  bool _skipDialogShown = false;

  void _syncFromRemote(Map<dynamic, dynamic> data) async {
    if (data['player1Score'] != null) _player1Score = data['player1Score'];
    if (data['player2Score'] != null) _player2Score = data['player2Score'];
    if (data['turn'] != null)
      _currentPlayer = data['turn'] == 'player1' ? 1 : 2;

    if (data['players'] != null) {
      _player1Name = data['players']['player1'] ?? 'Player 1';
      _player2Name = data['players']['player2'] ?? 'Player 2';
    }

    if (data['player1DoubleTurns'] != null)
      _player1DoubleTurns = data['player1DoubleTurns'];
    if (data['player2DoubleTurns'] != null)
      _player2DoubleTurns = data['player2DoubleTurns'];
    if (data['player1QuadTurns'] != null)
      _player1QuadTurns = data['player1QuadTurns'];
    if (data['player2QuadTurns'] != null)
      _player2QuadTurns = data['player2QuadTurns'];

    if (data['boardState'] != null) {
      final boardFromDb = List<dynamic>.from(data['boardState']);
      final newBonusIndices = <int>[];
      if (_board.length == boardFromDb.length) {
        _board = List.generate(boardFromDb.length, (index) {
          final val = boardFromDb[index];
          if (val == null || val.isEmpty || !(val is Map)) return BoardTile();
          final tile = BoardTile.fromJson(Map<String, dynamic>.from(val));
          if (tile.bonus != null) newBonusIndices.add(index);
          return tile;
        });
        _bonusIndices = newBonusIndices;
      }
    }

    if (data['player1Hand'] != null) {
      final handFromDb = List<dynamic>.from(data['player1Hand']);
      _player1Hand.clear();
      _player1Hand
          .addAll(handFromDb.map((s) => Letter.fromString(s.toString())));
    }

    if (data['player2Hand'] != null) {
      final handFromDb = List<dynamic>.from(data['player2Hand']);
      _player2Hand.clear();
      _player2Hand
          .addAll(handFromDb.map((s) => Letter.fromString(s.toString())));
    }

    if (data['letterPool'] != null) {
      final poolFromDb = List<dynamic>.from(data['letterPool']);
      _letterPool.clear();
      _letterPool
          .addAll(poolFromDb.map((s) => Letter.fromString(s.toString())));
    }

    if (data['turnStartTimestamp'] != null) {
      _turnStartTimestamp = data['turnStartTimestamp'];
      if (_repository is FirebaseGameRepository) {
        final serverNow =
            await (_repository as FirebaseGameRepository).fetchServerTime();
        final localNow = DateTime.now().millisecondsSinceEpoch;
        final offset = localNow - serverNow;
        if (_serverTimeOffset == 0 ||
            (_serverTimeOffset - offset).abs() > 2000) {
          _serverTimeOffset = offset;
        }
      }
    }

    if (data['firstMoveDone'] != null) {
      _firstMoveDone = data['firstMoveDone'] == true;
    }

    if (data['firstPlayerId'] != null) {
      _firstPlayerId = data['firstPlayerId'];
    }

    if (!_isSynced) {
      _isSynced = true;
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      notifyListeners();
      if (remainingTime <= 0 && _localPlayerId == _currentPlayer) {
        skipTurn(dueToTimeout: true);
      }
    });

    if (_localPlayerId == 1 && data['player2Left'] == true) {
      if (onPlayerLeft != null) onPlayerLeft!();
    } else if (_localPlayerId == 2 && data['player1Left'] == true) {
      if (onPlayerLeft != null) onPlayerLeft!();
    }

    notifyListeners();

    // Only start the timer and set turnStartTimestamp when both players are present and timer hasn't started
    if (isOnline &&
        _roomID != null &&
        data['players'] != null &&
        data['players']['player1'] != null &&
        data['players']['player2'] != null &&
        (data['turnStartTimestamp'] == null ||
            data['turnStartTimestamp'] == 0)) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _repository.updateGameState(_roomID!, turnStartTimestamp: now);
      // _turnStartTimestamp will be set on next sync
    }

    // Multiplayer skip notification
    if (isOnline &&
        data['lastSkipped'] != null &&
        data['lastSkipped'] != _localPlayerId) {
      // Show alert only if the other player skipped
      if (!_skipDialogShown && onError != null) {
        _skipDialogShown = true;
        onError!("The other player skipped their turn.");
      }
      // Clear the skip notification so it doesn't repeat
      if (_roomID != null) {
        await _repository.updateGameState(_roomID!, lastSkipped: null);
      }
    } else {
      _skipDialogShown = false;
    }
  }

  void _setupOnDisconnect() {
    if (_roomID == null) return;
    final db = FirebaseDatabase.instance.ref();
    final playerKey = _localPlayerId == 1 ? 'player1Left' : 'player2Left';
    db.child('rooms/$_roomID/$playerKey').onDisconnect().set(true);
  }

  // SECTION: Helpers & Private Methods

  bool isPlayableTile(int index) {
    bool blockBonus = !_firstMoveDone &&
        _currentPlayer == _firstPlayerId &&
        _bonusIndices.contains(index);
    if (blockBonus) return false;
    return _rulesService.isPlayableTile(
      index: index,
      firstMoveDone: _firstMoveDone,
      currentPlayer: _currentPlayer,
      firstPlayerId: _firstPlayerId,
      bonusIndices: _bonusIndices,
    );
  }

  Future<bool> _hasValidWords() async {
    final wordsData = _scoreService.extractWordsForPlacedTilesWithBonuses(
      board: _board,
      placedThisTurn: _placedThisTurn,
    );
    if (wordsData.isEmpty && _placedThisTurn.isNotEmpty) return false;

    for (final wordData in wordsData) {
      if (!_validationService.isValidWord(wordData['word'])) {
        return false;
      }
    }
    return true;
  }

  void _applyScore(TurnScoreResult result, {bool applyBonuses = true}) {
    if (_currentPlayer == 1) {
      _player1Score += result.score;
      _player1ExtraMove = result.extraMoveGained;
      if (applyBonuses) {
        if (result.futureDoubleTurnsGained > 0) {
          _player1DoubleTurns += result.futureDoubleTurnsGained;
        }
        if (result.futureQuadTurnsGained > 0) {
          _player1QuadTurns += result.futureQuadTurnsGained;
        }
      }
    } else {
      _player2Score += result.score;
      _player2ExtraMove = result.extraMoveGained;
      if (applyBonuses) {
        if (result.futureDoubleTurnsGained > 0) {
          _player2DoubleTurns += result.futureDoubleTurnsGained;
        }
        if (result.futureQuadTurnsGained > 0) {
          _player2QuadTurns += result.futureQuadTurnsGained;
        }
      }
    }
  }

  void _startTurnTimer() {
    _turnStartTimestamp = DateTime.now().millisecondsSinceEpoch;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingTime <= 0 &&
          (!isOnline || _localPlayerId == _currentPlayer)) {
        skipTurn(dueToTimeout: true);
      }
      notifyListeners();
    });
    if (isOnline) {
      _updateRepository();
    }
  }

  bool isGameOver() {
    if (_letterPool.isEmpty) {
      if (_player1Hand.isEmpty || _player2Hand.isEmpty) {
        return true;
      }
    }
    return false;
  }

  void _initializeLetterPool() {
    _letterPool = [];
    _addLetters('ו', 1, 7);
    _addLetters('י', 1, 6);
    _addLetters('ת', 2, 5);
    _addLetters('ר', 3, 4);
    _addLetters('ה', 2, 5);
    _addLetters('א', 7, 3);
    _addLetters('ל', 4, 4);
    _addLetters('מ', 2, 5);
    _addLetters('ש', 4, 3);
    _addLetters('ב', 4, 3);
    _addLetters('ד', 5, 3);
    _addLetters('נ', 3, 4);
    _addLetters('פ', 5, 3);
    _addLetters('ח', 4, 3);
    _addLetters('כ', 7, 3);
    _addLetters('ק', 4, 3);
    _addLetters('ע', 5, 3);
    _addLetters('ג', 8, 2);
    _addLetters('ז', 9, 2);
    _addLetters('ט', 7, 3);
    _addLetters('ס', 6, 3);
    _addLetters('צ', 7, 3);
    _addLetters(' ', 0, 2);
  }

  void _addLetters(String letter, int score, int count) {
    for (int i = 0; i < count; i++) {
      _letterPool.add(Letter(letter, score));
    }
  }

  void _drawLetters(List<Letter> hand, int count) {
    for (int i = 0; i < count; i++) {
      if (_letterPool.isNotEmpty) {
        hand.add(_letterPool.removeAt(0));
      }
    }
  }

  void _initializeBoard() {
    _board = List.generate(144, (index) => BoardTile());
    _bonusIndices = _generateBonusPositions();
    for (final index in _bonusIndices) {
      _board[index] = BoardTile(bonus: _createRandomBonus());
    }
  }

  List<int> _generateBonusPositions() {
    final random = Random();
    final List<int> bonusIndices = [];

    Set<int> markUnavailable(
        Set<int> available, int pos, List<int> edgeIndices) {
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

  BonusInfo _createRandomBonus() {
    final random = Random();
    const iconNames = [
      '3dicons-fire-dynamic-color.png',
      '3dicons-gift-box-dynamic-color.png',
      '3dicons-heart-dynamic-color.png',
      '3dicons-money-dynamic-color.png',
      '3dicons-dollar-dynamic-color.png',
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
      // BonusType.score,
      BonusType.futureDouble,
      BonusType.futureQuad,
      BonusType.extraMove,
      // BonusType.wordGame,
    ];
    final type = bonusTypes[random.nextInt(bonusTypes.length)];
    int? scoreValue;
    if (type == BonusType.score) {
      final values = [25, 40, 100, 1];
      scoreValue = values[random.nextInt(values.length)];
    }
    return BonusInfo(
      iconName: iconNames[random.nextInt(iconNames.length)],
      color: colors[random.nextInt(colors.length)],
      type: type,
      scoreValue: scoreValue,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    // If the repo is local, it might have a stream controller to close
    if (_repository is LocalGameRepository) {
      (_repository as LocalGameRepository).dispose();
    }
    super.dispose();
  }

  Future<void> markPlayerLeft() async {
    if (!isOnline || _roomID == null) return;
    final db = FirebaseDatabase.instance.ref();
    final playerKey = _localPlayerId == 1 ? 'player1Left' : 'player2Left';
    await db.child('rooms/$_roomID/$playerKey').set(true);
  }

  void _returnPlacedLettersToHand() {
    if (_placedThisTurn.isEmpty) return;
    final currentHand = (_currentPlayer == 1) ? _player1Hand : _player2Hand;
    for (final idx in _placedThisTurn) {
      final letter = _board[idx]?.letter;
      if (letter != null) {
        currentHand.add(letter);
        _board[idx]!.letter = null;
      }
    }
    _placedThisTurn.clear();
  }

  void skipTurn({bool dueToTimeout = false}) async {
    if (isOnline && _localPlayerId != _currentPlayer) {
      onError?.call("It's not your turn!");
      return;
    }
    // Multiplayer: notify the other player
    if (isOnline && _roomID != null) {
      await _repository.updateGameState(_roomID!, lastSkipped: _localPlayerId);
    }
    // Only show dialog for the local player whose turn it is
    if (!isOnline || _localPlayerId == _currentPlayer) {
      if (onError != null) {
        if (dueToTimeout) {
          onError!("Time's up! Your turn was skipped.");
        } else {
          onError!("Turn skipped!");
        }
      }
    }
    _returnPlacedLettersToHand();
    _passTurn();
  }
}
