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
  Set<int> _lastTurnWordIndices = {};

  // Bonus State
  int _player1DoubleTurns = 0;
  int _player2DoubleTurns = 0;
  int _player1QuadTurns = 0;
  int _player2QuadTurns = 0;
  bool _player1ExtraMove = false;
  bool _player2ExtraMove = false;

  // Letter replacement tracking
  int _player1Replacements = 0;
  int _player2Replacements = 0;

  // Turn results tracking
  Map<String, dynamic>? _lastTurnResults;
  bool _showTurnResults = false;

  // Debounce mechanism to prevent too frequent updates
  Timer? _updateDebounceTimer;
  bool _pendingUpdate = false;

  // Replacement state for current turn
  int? _replacedPermanentIndex;
  Letter? _replacedPermanentLetter;
  Letter? _replacementLetter;

  int? get replacedPermanentIndex => _replacedPermanentIndex;
  Letter? get replacedPermanentLetter => _replacedPermanentLetter;
  Letter? get replacementLetter => _replacementLetter;

  bool get hasReplacedPermanentThisTurn => _replacedPermanentIndex != null;

  void Function(String)? onError;
  void Function()? onPlayerLeft;
  void Function()? onTurnPassedDueToTimeout;
  void Function(Map<String, dynamic>)? onShowTurnResults;

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
  Set<int> get lastTurnWordIndices => _lastTurnWordIndices;
  int get remainingTime {
    if (_turnStartTimestamp == null) return 125;
    // In local games, offset is 0. In online games, it's calculated.
    final now = DateTime.now().millisecondsSinceEpoch - _serverTimeOffset;
    final elapsed = ((now - _turnStartTimestamp!) / 1000).floor();
    return (125 - elapsed).clamp(0, 125);
  }

  List<int> get placedThisTurn => _placedThisTurn.toList();
  ScoreService get scoreService => _scoreService;
  WordValidationService get validationService => _validationService;
  int get player1DoubleTurns => _player1DoubleTurns;
  int get player1QuadTurns => _player1QuadTurns;
  int get player2DoubleTurns => _player2DoubleTurns;
  int get player2QuadTurns => _player2QuadTurns;
  bool get firstMoveDone => _firstMoveDone;

  // Get replacement cost for current player
  int get replacementCost {
    int replacements = _currentPlayer == 1 ? _player1Replacements : _player2Replacements;
    return 25 * (1 << replacements); // 25, 50, 100, 200, 400, etc.
  }

  // Get replacement count for current player
  int get replacementCount {
    return _currentPlayer == 1 ? _player1Replacements : _player2Replacements;
  }

  // Turn results getters
  Map<String, dynamic>? get lastTurnResults => _lastTurnResults;
  bool get showTurnResults => _showTurnResults;

  // Helper method to calculate word score
  int _wordScore(Map<String, dynamic> wordData) {
    try {
      int score = 0;
      final indices = wordData['indices'] as List<int>?;
      if (indices != null) {
        for (final idx in indices) {
          if (idx >= 0 && idx < _board.length) {
            final tile = _board[idx];
            if (tile != null && tile.letter != null) {
              score += tile.letter!.isWildcard ? 0 : tile.letter!.score;
            }
          }
        }
      }
      return score;
    } catch (e) {
      print('Error calculating word score: $e');
      return 0;
    }
  }

  Map<String, dynamic>? _lastEmojiEvent;
  Map<String, dynamic>? get lastEmojiEvent => _lastEmojiEvent;
  Timer? _emojiTimer;

  String? _lastProcessedEmojiKey;

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
    _lastTurnWordIndices.clear();
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
    _lastTurnWordIndices.clear();
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
      // Immediately clear the player left flag to indicate presence
      final db = FirebaseDatabase.instance.ref();
      final playerKey = _localPlayerId == 1 ? 'player1Left' : 'player2Left';
      db.child('rooms/$_roomID/$playerKey').set(false);
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
      {bool skipValidation = false, bool fromTimeout = false, List<String>? acceptedInvalidWords}) async {
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

    // Enforce: if a permanent letter was replaced, at least one more letter must be placed
    if (_replacedPermanentIndex != null && _placedThisTurn.length <= 1) {
      onError?.call('If you replaced a permanent letter, you must place at least one more letter on the grid.');
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
      acceptedInvalidWords: acceptedInvalidWords,
    );

    // Get words created this turn
    final wordList = _scoreService.extractWordsForPlacedTilesWithBonuses(
      board: _board,
      placedThisTurn: _placedThisTurn,
    );

    print('Debug: Word list length: ${wordList.length}');
    print('Debug: Score result: ${scoreResult.score}');

    _lastTurnWordIndices.clear();
    for (final wordData in wordList) {
      final indices = wordData['indices'] as List<int>;
      _lastTurnWordIndices.addAll(indices);
    }

    try {
      // Store turn results for both players to see
      _lastTurnResults = {
        'playerId': _currentPlayer,
        'playerName': _currentPlayer == 1 ? _player1Name : _player2Name,
        'words': wordList.map((wordData) {
          try {
            final word = wordData['word'] as String;
            final isAcceptedInvalid = acceptedInvalidWords?.contains(word) ?? false;
            final isActuallyValid = _validationService.isValidWord(word) || isAcceptedInvalid;
            
            return {
              'word': word,
              'isValid': isActuallyValid,
              'score': _wordScore(wordData),
              'wasAccepted': isAcceptedInvalid,
            };
          } catch (e) {
            print('Error processing word data: $e');
            return {
              'word': wordData['word'] ?? 'ERROR',
              'isValid': false,
              'score': 0,
              'wasAccepted': false,
            };
          }
        }).toList(),
        'totalScore': scoreResult.score,
        'baseScore': scoreResult.baseScore,
        'letterScore': scoreResult.letterScore,
        'bonusScore': scoreResult.bonusScore,
        'multiplier': scoreResult.multiplier,
        'extraMoveGained': scoreResult.extraMoveGained,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      print('Debug: Turn results created successfully');
      
      // Trigger callback to show turn results to both players
      onShowTurnResults?.call(_lastTurnResults!);
    } catch (e) {
      print('Error creating turn results: $e');
    }

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

    // At end of turn, clear replacement state so replaced icons and indexes are reset
    _replacedPermanentIndex = null;
    _replacedPermanentLetter = null;
    _replacementLetter = null;

    await _updateRepository();
    notifyListeners();
  }

  void _passTurn() {
    // If the first player passes/skips their first turn, mark firstMoveDone
    if (!_firstMoveDone && _currentPlayer == _firstPlayerId) {
      _firstMoveDone = true;
    }
    
    // Clear any placed letters that might still be on the board
    _returnPlacedLettersToHand();
    _lastTurnWordIndices.clear();
    
    // Switch to the other player
    _currentPlayer = (_currentPlayer == 1) ? 2 : 1;
    
    // Start the timer for the new turn
    _startTurnTimer();
    
    // Update the repository immediately for critical turn changes
    _updateRepositoryImmediate();
    
    notifyListeners();
  }

  // SECTION: Letter & Board Manipulation

  void moveLetter(DraggableLetter draggableLetter, int toIndex) {
    if (isOnline && _localPlayerId != _currentPlayer) {
      onError?.call("It's not your turn!");
      return;
    }
    // If trying to replace a permanent letter
    if (_board[toIndex]?.isPermanent == true) {
      if (_replacedPermanentIndex != null) return; // Only one per turn
      if (draggableLetter.origin == LetterOrigin.hand) {
        // Replace permanent letter
        if (replacePermanentLetter(toIndex, draggableLetter.letter)) {
          final hand = (_currentPlayer == 1) ? _player1Hand : _player2Hand;
          hand.remove(draggableLetter.letter);
        }
      }
      return;
    }
    // If trying to undo replacement by dragging permanent letter from hand
    if (_replacedPermanentIndex == toIndex && draggableLetter.origin == LetterOrigin.hand && draggableLetter.letter == _replacedPermanentLetter) {
      if (undoReplacePermanentLetter(toIndex)) {
        final hand = (_currentPlayer == 1) ? _player1Hand : _player2Hand;
        hand.remove(draggableLetter.letter);
      }
      return;
    }
    // Prevent placing the replaced permanent letter anywhere except its original position
    if (_replacedPermanentIndex != null && draggableLetter.origin == LetterOrigin.hand && draggableLetter.letter == _replacedPermanentLetter && toIndex != _replacedPermanentIndex) {
      // Do nothing, illegal move
      return;
    }
    // Normal move logic
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

  bool _skipDialogShown = false;

  void _syncFromRemote(Map<dynamic, dynamic> data) async {
    // Prevent infinite loops by checking if data is actually different
    bool hasChanges = false;
    
    if (data['player1Score'] != null && data['player1Score'] != _player1Score) {
      _player1Score = data['player1Score'];
      hasChanges = true;
    }
    if (data['player2Score'] != null && data['player2Score'] != _player2Score) {
      _player2Score = data['player2Score'];
      hasChanges = true;
    }
    if (data['turn'] != null) {
      int newCurrentPlayer = data['turn'] == 'player1' ? 1 : 2;
      if (newCurrentPlayer != _currentPlayer) {
        _currentPlayer = newCurrentPlayer;
        hasChanges = true;
      }
    }

    if (data['players'] != null) {
      String newPlayer1Name = data['players']['player1'] ?? 'Player 1';
      String newPlayer2Name = data['players']['player2'] ?? 'Player 2';
      if (newPlayer1Name != _player1Name || newPlayer2Name != _player2Name) {
        _player1Name = newPlayer1Name;
        _player2Name = newPlayer2Name;
        hasChanges = true;
      }
    }

    if (data['player1DoubleTurns'] != null && data['player1DoubleTurns'] != _player1DoubleTurns) {
      _player1DoubleTurns = data['player1DoubleTurns'];
      hasChanges = true;
    }
    if (data['player2DoubleTurns'] != null && data['player2DoubleTurns'] != _player2DoubleTurns) {
      _player2DoubleTurns = data['player2DoubleTurns'];
      hasChanges = true;
    }
    if (data['player1QuadTurns'] != null && data['player1QuadTurns'] != _player1QuadTurns) {
      _player1QuadTurns = data['player1QuadTurns'];
      hasChanges = true;
    }
    if (data['player2QuadTurns'] != null && data['player2QuadTurns'] != _player2QuadTurns) {
      _player2QuadTurns = data['player2QuadTurns'];
      hasChanges = true;
    }

    if (data['player1Replacements'] != null && data['player1Replacements'] != _player1Replacements) {
      _player1Replacements = data['player1Replacements'];
      hasChanges = true;
    }
    if (data['player2Replacements'] != null && data['player2Replacements'] != _player2Replacements) {
      _player2Replacements = data['player2Replacements'];
      hasChanges = true;
    }

    if (data['boardState'] != null) {
      final boardFromDb = List<dynamic>.from(data['boardState']);
      final newBonusIndices = <int>[];
      if (_board.length == boardFromDb.length) {
        bool boardChanged = false;
        _board = List.generate(boardFromDb.length, (index) {
          final val = boardFromDb[index];
          if (val == null || val.isEmpty || !(val is Map)) return BoardTile();
          final tile = BoardTile.fromJson(Map<String, dynamic>.from(val));
          if (tile.bonus != null) newBonusIndices.add(index);
          // Check if this tile is different from current
          if (index < _board.length && _board[index]?.toJson() != tile.toJson()) {
            boardChanged = true;
          }
          return tile;
        });
        _bonusIndices = newBonusIndices;
        if (boardChanged) hasChanges = true;
      }
    }

    if (data['player1Hand'] != null) {
      final handFromDb = List<dynamic>.from(data['player1Hand']);
      final newHand = handFromDb.map((s) => Letter.fromString(s.toString())).toList();
      if (!_listsEqual(_player1Hand, newHand)) {
      _player1Hand.clear();
        _player1Hand.addAll(newHand);
        hasChanges = true;
      }
    }

    if (data['player2Hand'] != null) {
      final handFromDb = List<dynamic>.from(data['player2Hand']);
      final newHand = handFromDb.map((s) => Letter.fromString(s.toString())).toList();
      if (!_listsEqual(_player2Hand, newHand)) {
      _player2Hand.clear();
        _player2Hand.addAll(newHand);
        hasChanges = true;
      }
    }

    if (data['letterPool'] != null) {
      final poolFromDb = List<dynamic>.from(data['letterPool']);
      final newPool = poolFromDb.map((s) => Letter.fromString(s.toString())).toList();
      if (!_listsEqual(_letterPool, newPool)) {
      _letterPool.clear();
        _letterPool.addAll(newPool);
        hasChanges = true;
      }
    }

    if (data['turnStartTimestamp'] != null && data['turnStartTimestamp'] != _turnStartTimestamp) {
      _turnStartTimestamp = data['turnStartTimestamp'];
      hasChanges = true;
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

    if (data['firstMoveDone'] != null && data['firstMoveDone'] != _firstMoveDone) {
      _firstMoveDone = data['firstMoveDone'] == true;
      hasChanges = true;
    }

    if (data['firstPlayerId'] != null && data['firstPlayerId'] != _firstPlayerId) {
      _firstPlayerId = data['firstPlayerId'];
      hasChanges = true;
    }

    if (data['lastTurnWordIndices'] != null) {
      final indicesFromDb = List<int>.from(data['lastTurnWordIndices']);
      if (Set.from(indicesFromDb).difference(_lastTurnWordIndices).isNotEmpty ||
          _lastTurnWordIndices.difference(Set.from(indicesFromDb)).isNotEmpty) {
        _lastTurnWordIndices = Set.from(indicesFromDb);
        hasChanges = true;
      }
    }

    // Handle turn results - show to both players
    if (data['lastTurnResults'] != null) {
      final newTurnResults = Map<String, dynamic>.from(data['lastTurnResults']);
      final currentTimestamp = _lastTurnResults?['timestamp'] ?? 0;
      final newTimestamp = newTurnResults['timestamp'] ?? 0;
      
      // Only show if this is a new turn result (different timestamp)
      if (newTimestamp > currentTimestamp) {
        _lastTurnResults = newTurnResults;
        // Trigger callback to show turn results to both players
        onShowTurnResults?.call(newTurnResults);
      }
    }

    if (data.containsKey('emojiEvent')) {
      final event = data['emojiEvent'] as String?;
      if (event != null && event.contains('|')) {
        final parts = event.split('|');
        final emojiKey = event; // Use the raw event string as a key
        if (_lastProcessedEmojiKey != emojiKey) {
          _lastEmojiEvent = {'emoji': parts[0], 'sender': int.tryParse(parts[1])};
          _lastProcessedEmojiKey = emojiKey;
          // Clear emojiEvent from the game state after displaying
          if (_roomID != null) {
            _repository.updateGameState(_roomID!, emojiEvent: null);
          }
        }
      } else {
        _lastEmojiEvent = null;
      }
      notifyListeners();
      _emojiTimer?.cancel();
      _emojiTimer = Timer(const Duration(seconds: 2), () {
        _lastEmojiEvent = null;
        notifyListeners();
      });
    }

    if (!_isSynced) {
      _isSynced = true;
      hasChanges = true;
    }

    // Handle player left notifications
    if (_localPlayerId == 1 && data['player2Left'] == true) {
      if (onPlayerLeft != null) onPlayerLeft!();
    } else if (_localPlayerId == 2 && data['player1Left'] == true) {
      if (onPlayerLeft != null) onPlayerLeft!();
    }

    // Handle skip turn notifications - only show once per skip
    if (isOnline &&
        data['lastSkipped'] != null &&
        data['lastSkipped'] != _localPlayerId &&
        data['lastSkipped'] != 0) {
      // Show alert only if the other player skipped and we haven't shown it yet
      if (!_skipDialogShown && onError != null) {
        _skipDialogShown = true;
        onError!("The other player skipped their turn.");
        // Clear the skip notification after showing the message
        await _clearSkipNotification();
      }
    } else if (data['lastSkipped'] == null || data['lastSkipped'] == 0) {
      _skipDialogShown = false;
    }

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

    // Only notify listeners if there were actual changes
    if (hasChanges) {
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        notifyListeners();
        if (remainingTime <= 0 && _localPlayerId == _currentPlayer) {
          skipTurn(dueToTimeout: true);
        }
      });
      notifyListeners();
      }
  }

  // Helper method to compare lists of letters
  bool _listsEqual(List<Letter> list1, List<Letter> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].toString() != list2[i].toString()) return false;
    }
    return true;
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
      BonusType.score,
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
    _updateDebounceTimer?.cancel();
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

  // Clear skip notification to prevent infinite loops
  Future<void> _clearSkipNotification() async {
    if (isOnline && _roomID != null) {
      await _repository.updateGameState(_roomID!, lastSkipped: 0);
    }
  }

  void skipTurn({bool dueToTimeout = false}) async {
    if (isOnline && _localPlayerId != _currentPlayer) {
      onError?.call("It's not your turn!");
      return;
    }
    // Undo replacement if active before skipping
    if (_replacedPermanentIndex != null) {
      undoReplacePermanentLetter(_replacedPermanentIndex!);
    }
    // Return placed letters to hand before skipping
    _returnPlacedLettersToHand();
    
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
    
    _passTurn();
  }

  // Replace a letter in the current player's hand with a random letter from the pool
  bool replaceLetterInHand(int letterIndex) {
    print('replaceLetterInHand called with index: $letterIndex'); // Debug
    
    if (isOnline && _localPlayerId != _currentPlayer) {
      print('Not your turn!'); // Debug
      onError?.call("It's not your turn!");
      return false;
    }

    // Calculate the cost for this replacement
    int cost = replacementCost;
    print('Replacement cost: $cost'); // Debug

    // Check if player has enough score
    int currentScore = _currentPlayer == 1 ? _player1Score : _player2Score;
    print('Current score: $currentScore'); // Debug
    
    if (currentScore < cost) {
      print('Not enough points! Need $cost, have $currentScore'); // Debug
      onError?.call("You need at least $cost points to replace a letter!");
      return false;
    }

    // Get current player's hand
    List<Letter> currentHand = _currentPlayer == 1 ? _player1Hand : _player2Hand;
    print('Current hand size: ${currentHand.length}'); // Debug
    
    // Check if index is valid
    if (letterIndex < 0 || letterIndex >= currentHand.length) {
      print('Invalid index!'); // Debug
      onError?.call("Invalid letter index!");
      return false;
    }

    // Check if letter pool has letters
    if (_letterPool.isEmpty) {
      print('Letter pool is empty!'); // Debug
      onError?.call("No letters available in the pool!");
      return false;
    }

    print('Replacing letter: ${currentHand[letterIndex].letter}'); // Debug

    // Remove the letter from hand and add it back to the pool
    Letter removedLetter = currentHand.removeAt(letterIndex);
    _letterPool.add(removedLetter);
    
    // Shuffle the pool to randomize
    _letterPool.shuffle();
    
    // Draw a new random letter
    Letter newLetter = _letterPool.removeAt(0);
    currentHand.add(newLetter);
    
    print('New letter: ${newLetter.letter}'); // Debug
    
    // Deduct the cost
    if (_currentPlayer == 1) {
      _player1Score -= cost;
      _player1Replacements++;
    } else {
      _player2Score -= cost;
      _player2Replacements++;
    }
    
    print('Score after deduction: ${_currentPlayer == 1 ? _player1Score : _player2Score}'); // Debug
    print('Next replacement will cost: ${replacementCost}'); // Debug
    
    // Update repository
    _updateRepository();
    notifyListeners();
    
    print('Letter replacement successful!'); // Debug
    return true;
  }

  // Immediate update for critical changes that shouldn't be debounced
  Future<void> _updateRepositoryImmediate() async {
    if (_roomID == null) return;
    
    // Cancel any pending debounced update
    _updateDebounceTimer?.cancel();
    _pendingUpdate = false;
    
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
      lastTurnWordIndices: _lastTurnWordIndices.toList(),
    );
  }

  Future<void> _updateRepository() async {
    if (_roomID == null) return;
    
    // Cancel any pending update
    _updateDebounceTimer?.cancel();
    
    // Set a flag to indicate we have a pending update
    _pendingUpdate = true;
    
    // Debounce the update to prevent too frequent database calls
    _updateDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (_pendingUpdate) {
        _pendingUpdate = false;
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
          player1Replacements: _player1Replacements,
          player2Replacements: _player2Replacements,
          lastTurnResults: _lastTurnResults,
          lastTurnWordIndices: _lastTurnWordIndices.toList(),
        );
      }
    });
  }

  // Call this to attempt to replace a permanent letter
  bool replacePermanentLetter(int boardIndex, Letter newLetter) {
    if (_replacedPermanentIndex != null) return false; // Only one per turn
    final tile = _board[boardIndex];
    if (tile == null || !tile.isPermanent || tile.letter == null) return false;
    // Prevent replacing with the same letter
    if (tile.letter!.letter == newLetter.letter) {
      onError?.call('Cannot replace a permanent letter with the same letter!');
      return false;
    }
    _replacedPermanentIndex = boardIndex;
    _replacedPermanentLetter = tile.letter;
    _replacementLetter = newLetter;
    // Remove permanent letter from board, add to hand
    tile.letter = newLetter;
    tile.isPermanent = false;
    final hand = (_currentPlayer == 1) ? _player1Hand : _player2Hand;
    hand.add(_replacedPermanentLetter!);
    _placedThisTurn.add(boardIndex);
    notifyListeners();
    return true;
  }

  // Undo the replacement if the player drags the permanent letter back
  bool undoReplacePermanentLetter(int boardIndex) {
    if (_replacedPermanentIndex != boardIndex) return false;
    final tile = _board[boardIndex];
    if (tile == null) return false;
    final hand = (_currentPlayer == 1) ? _player1Hand : _player2Hand;
    // Remove the replacement letter from the board, add to hand
    if (_replacementLetter != null) {
      hand.add(_replacementLetter!);
    }
    // Restore the permanent letter to the board, remove from hand
    tile.letter = _replacedPermanentLetter;
    tile.isPermanent = true;
    hand.remove(_replacedPermanentLetter);
    _placedThisTurn.remove(boardIndex);
    _replacedPermanentIndex = null;
    _replacedPermanentLetter = null;
    _replacementLetter = null;
    notifyListeners();
    return true;
  }

  // Enforce that if a replacement was made, at least one more letter must be placed
  bool get canEndTurn {
    if (_replacedPermanentIndex != null) {
      // Must have placed at least one other letter
      return _placedThisTurn.length > 1;
    }
    return _placedThisTurn.isNotEmpty;
  }

  void sendEmoji(String emoji) async {
    if (_roomID != null) {
      final senderId = _localPlayerId;
      await _repository.updateGameState(_roomID!, emojiEvent: '$emoji|$senderId');
    }
  }
}
