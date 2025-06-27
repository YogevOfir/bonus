import 'package:bonus/controllers/game_controller.dart';
import 'package:bonus/models/bonus_info.dart';
import 'package:bonus/models/draggable_letter.dart';
import 'package:bonus/models/letter.dart';
import 'package:bonus/services/scoring/score_service.dart';
import 'package:bonus/widgets/game_board.dart';
import 'package:bonus/widgets/letter_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:collection';

class GameScreen extends StatefulWidget {
  final bool isAiGame;
  final String roomID;
  final int localPlayerId;
  const GameScreen(
      {super.key,
      this.isAiGame = false,
      required this.roomID,
      this.localPlayerId = 1});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController _gameController;
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    _gameController = Provider.of<GameController>(context, listen: false);

    if (widget.roomID.isNotEmpty) {
      _gameController.setRoomID(widget.roomID);
      _gameController.setLocalPlayerId(widget.localPlayerId);
    }

    _gameController.onPlayerLeft = () {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.deepPurple, size: 28),
              SizedBox(width: 8),
              Text('Player Left',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            ],
          ),
          content: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('The other player has left the game.',
                style: TextStyle(fontSize: 18)),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: Text('OK'),
            ),
          ],
        ),
      );
    };

    _gameController.onTurnPassedDueToTimeout = () {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.deepPurple, size: 28),
              SizedBox(width: 8),
              Text('Turn Skipped',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            ],
          ),
          content: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('You did nothing and your turn was passed.',
                style: TextStyle(fontSize: 18)),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    };

    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _gameController.markPlayerLeft();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400;
    final isMediumScreen = screenSize.width >= 400 && screenSize.width < 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF7F53AC),
                  Color(0xFF647DEE),
                  Color(0xFF63E2FF)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Consumer<GameController>(
                builder: (context, gameController, child) {
                  bool isLocalGame = !gameController.isOnline;
                  bool isMyTurn = isLocalGame
                      ? true
                      : gameController.currentPlayer == widget.localPlayerId;

                  if (!gameController.isSynced) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Synchronizing game state...'),
                        ],
                      ),
                    );
                  }

                  gameController.onError = (msg) {
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.white.withOpacity(0.95),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.deepPurple, size: 28),
                            SizedBox(width: 8),
                            Text('Invalid Move',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple)),
                          ],
                        ),
                        content: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(msg, style: TextStyle(fontSize: 18)),
                        ),
                        actions: [
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.deepPurple,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              textStyle: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('OK'),
                          ),
                        ],
                      ),
                    );
                  };

                  if (!gameController.wordsLoaded) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (gameController.isGameOver()) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _showGameOverDialog(context, gameController);
                    });
                  }

                  return Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 6.0 : 10.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 600),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Score Board
                            _buildScoreBoard(gameController, isSmallScreen),
                            SizedBox(height: isSmallScreen ? 6 : 10),

                            // Timer and Deck Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Expanded(
                                    child: _buildTimer(gameController, isSmallScreen)),
                                SizedBox(width: isSmallScreen ? 6 : 8),
                                Expanded(
                                    child: _buildDeck(gameController, isSmallScreen)),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 6 : 10),

                            // Game Board
                            Card(
                              elevation: 8,
                              color: Colors.white.withOpacity(0.95),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                              child: Padding(
                                padding: EdgeInsets.all(isSmallScreen ? 3.0 : 6.0),
                                child: GameBoard(),
                              ),
                            ),

                            // Player Hand Area
                            SizedBox(height: isSmallScreen ? 6 : 10),
                            _buildPlayerHandArea(
                                gameController, context, isSmallScreen),

                            // Action Buttons
                            SizedBox(height: isSmallScreen ? 8 : 14),
                            _buildActionButtons(
                                gameController, isMyTurn, context, isSmallScreen),
                            SizedBox(height: isSmallScreen ? 6 : 10),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 24,
            child: FloatingActionButton(
              heroTag: 'homeBtn',
              backgroundColor: Colors.white,
              foregroundColor: Colors.deepPurple,
              child: const Icon(Icons.home, size: 28),
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBoard(GameController gameController, bool isSmallScreen) {
    final isPlayer1Leading =
        gameController.player1Score > gameController.player2Score;
    final isPlayer2Leading =
        gameController.player2Score > gameController.player1Score;
    return Card(
      color: Colors.white.withOpacity(0.92),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 6 : 8,
            horizontal: isSmallScreen ? 12 : 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      gameController.player1Name,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple[700],
                      ),
                    ),
                    if (gameController.player1QuadTurns > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.purple[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('x4',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10)),
                        ),
                      )
                    else if (gameController.player1DoubleTurns > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue[400],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('x2',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10)),
                        ),
                      ),
                  ],
                ),
                Text(
                  gameController.player1Score.toString(),
                  style: TextStyle(
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Turn',
                  style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14, color: Colors.grey),
                ),
                Text(
                  gameController.currentPlayer == 1
                      ? gameController.player1Name
                      : gameController.player2Name,
                  style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple),
                ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.isAiGame ? 'Computer' : gameController.player2Name,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.pink[700],
                      ),
                    ),
                    if (gameController.player2QuadTurns > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.purple[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('x4',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10)),
                        ),
                      )
                    else if (gameController.player2DoubleTurns > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue[400],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('x2',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10)),
                        ),
                      ),
                  ],
                ),
                Text(
                  gameController.player2Score.toString(),
                  style: TextStyle(
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimer(GameController gameController, bool isSmallScreen) {
    return Card(
      color: Colors.deepPurple[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 4 : 6,
            horizontal: isSmallScreen ? 8 : 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer,
                color: Colors.deepPurple, size: isSmallScreen ? 16 : 20),
            SizedBox(width: isSmallScreen ? 3 : 4),
            Text('Time: ',
                style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    color: Colors.deepPurple[900])),
            Text('${gameController.remainingTime}',
                style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeck(GameController gameController, bool isSmallScreen) {
    return Card(
      color: Colors.cyan[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 4 : 6,
            horizontal: isSmallScreen ? 8 : 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.layers,
                color: Colors.cyan, size: isSmallScreen ? 16 : 20),
            SizedBox(width: isSmallScreen ? 3 : 4),
            Text('Deck: ',
                style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    color: Colors.cyan[900])),
            Text('${gameController.letterPool.length}',
                style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerHandArea(
      GameController gameController, BuildContext context, bool isSmallScreen) {
    bool isPlayer1sTurn = gameController.currentPlayer == 1;
    bool isLocalGame = !gameController.isOnline;
    bool isMyTurn = isLocalGame
        ? true
        : gameController.currentPlayer == widget.localPlayerId;
    final screenWidth = MediaQuery.of(context).size.width;

    double player1Opacity, player2Opacity;
    if (isMyTurn) {
      player1Opacity = isPlayer1sTurn ? 1.0 : 0.6;
      player2Opacity = isPlayer1sTurn ? 0.6 : 1.0;
    } else {
      player1Opacity = 0.6;
      player2Opacity = 0.6;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.isAiGame
              ? 'Computer\'s Hand'
              : (widget.localPlayerId == 2
                  ? 'Your Hand'
                  : "${gameController.player2Name}'s Hand"),
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isSmallScreen ? 4 : 6),
        Opacity(
          opacity: player2Opacity,
          child: _buildPlayerHand(gameController.player2Hand, 2, isMyTurn,
              screenWidth, isSmallScreen),
        ),
        SizedBox(height: isSmallScreen ? 8 : 12),
        Text(
          (widget.localPlayerId == 1
              ? 'Your Hand'
              : "${gameController.player1Name}'s Hand"),
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isSmallScreen ? 4 : 6),
        Opacity(
          opacity: player1Opacity,
          child: _buildPlayerHand(gameController.player1Hand, 1, isMyTurn,
              screenWidth, isSmallScreen),
        ),
      ],
    );
  }

  Widget _buildPlayerHand(List<Letter> hand, int handOwnerId, bool isMyTurn,
      double screenWidth, bool isSmallScreen) {
    bool isLocalGame =
        Provider.of<GameController>(context, listen: false).isOnline == false;
    bool canDrag = isLocalGame
        ? (handOwnerId ==
            Provider.of<GameController>(context, listen: false).currentPlayer)
        : (isMyTurn && (handOwnerId == widget.localPlayerId));

    return Center(
      child: DragTarget<DraggableLetter>(
        builder: (context, candidateData, rejectedData) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: hand.map((letter) {
                final letterTile = LetterTile(letter: letter);
                return Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 2.0 : 4.0),
                  child: canDrag
                      ? Draggable<DraggableLetter>(
                          data: DraggableLetter(
                              letter: letter,
                              origin: LetterOrigin.hand,
                              fromIndex: -1),
                          feedback: Material(
                            color: Colors.transparent,
                            elevation: 4.0,
                            child: letterTile,
                          ),
                          childWhenDragging: SizedBox(
                            width: 40,
                            height: 40,
                          ),
                          child: letterTile,
                        )
                      : letterTile,
                );
              }).toList(),
            ),
          );
        },
        onWillAccept: (data) {
          return isMyTurn && data?.origin == LetterOrigin.board;
        },
        onAccept: (draggableLetter) {
          final gameController =
              Provider.of<GameController>(context, listen: false);
          gameController.returnLetterToHand(draggableLetter);
        },
      ),
    );
  }

  void _showGameOverDialog(
      BuildContext context, GameController gameController) {
    String winner;
    if (gameController.player1Score > gameController.player2Score) {
      winner = gameController.player1Name;
    } else if (gameController.player2Score > gameController.player1Score) {
      winner = widget.isAiGame ? 'Computer' : gameController.player2Name;
    } else {
      winner = 'It\'s a tie!';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.deepPurple, size: 28),
              SizedBox(width: 8),
              Text('Game Over',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            ],
          ),
          content: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('$winner wins!', style: TextStyle(fontSize: 18)),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String _bonusLabel(BonusInfo? bonus) {
    if (bonus == null) return '';
    switch (bonus.type) {
      case BonusType.score:
        return bonus.scoreValue != null ? '+${bonus.scoreValue}' : 'Score';
      case BonusType.futureDouble:
        return '2x Next 2 Turns';
      case BonusType.futureQuad:
        return '4x Next Turn';
      case BonusType.extraMove:
        return 'Extra Move';
      // case BonusType.wordGame:
      //   return 'Word Game';
    }
  }

  String _bonusDescription(BonusInfo bonus) {
    switch (bonus.type) {
      case BonusType.score:
        return 'Score: +${bonus.scoreValue}';
      case BonusType.futureDouble:
        return 'X2 to the score of the next 2 turns';
      case BonusType.futureQuad:
        return 'X4 to the score of the next turn';
      case BonusType.extraMove:
        return 'Gives an extra move';
      // case BonusType.wordGame:
      //   return 'Word Game';
    }
  }

  Widget _buildActionButtons(GameController gameController, bool isMyTurn,
      BuildContext context, bool isSmallScreen) {
    return SizedBox(
      width: isSmallScreen ? 250 : 320,
      height: 44,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: isSmallScreen ? 140 : 180,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMyTurn ? Colors.deepPurple : Colors.grey,
                  foregroundColor: Colors.white,
                  textStyle:
                      const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                  minimumSize: const Size(0, 44),
                ),
                onPressed: isMyTurn
                    ? () async {
                        final wasMyTurn = isMyTurn;
                        final results =
                            await gameController.validateAndGetTurnResults();
                        if (results == null) {
                          // Show detailed invalid words dialog
                          final wordsData = gameController.board;
                          final placedThisTurn = gameController.placedThisTurn;
                          final scoreService = gameController.scoreService;
                          final validationService =
                              gameController.validationService;
                          Set<int> placedSet = placedThisTurn.toSet();
                          int wordScore(Map<String, dynamic> wordData) {
                            int score = 0;
                            final indices = wordData['indices'] as List<int>?;
                            if (indices != null) {
                              for (final idx in indices) {
                                final tile = gameController.board[idx];
                                if (tile != null && tile.letter != null) {
                                  score += tile.letter!.isWildcard
                                      ? 0
                                      : tile.letter!.score;
                                }
                              }
                            }
                            return score;
                          }

                          final wordList =
                              scoreService.extractWordsForPlacedTilesWithBonuses(
                            board: wordsData,
                            placedThisTurn: placedSet,
                          );
                          if (!mounted) return;
                          await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.white.withOpacity(0.95),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              title: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.deepPurple, size: 28),
                                  SizedBox(width: 8),
                                  Text('Turn Words',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.deepPurple)),
                                ],
                              ),
                              content: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final wordData in wordList)
                                      Row(
                                        children: [
                                          Text(wordData['word'],
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold)),
                                          SizedBox(width: 8),
                                          validationService
                                                  .isValidWord(wordData['word'])
                                              ? Icon(Icons.check_circle,
                                                  color: Colors.green, size: 22)
                                              : Icon(Icons.cancel,
                                                  color: Colors.red, size: 22),
                                          SizedBox(width: 8),
                                          if (validationService
                                              .isValidWord(wordData['word']))
                                            Text(
                                              '+${wordScore(wordData)}',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.green[800]),
                                            ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.deepPurple,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    textStyle:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text('OK'),
                                ),
                              ],
                            ),
                          );
                          return;
                        }

                        // Get all words and their validation
                        final wordsData = gameController.board;
                        final placedThisTurn = gameController.placedThisTurn;
                        final scoreService = gameController.scoreService;
                        final validationService =
                            gameController.validationService;
                        Set<int> placedSet = placedThisTurn.toSet();
                        int wordScore(Map<String, dynamic> wordData) {
                          int score = 0;
                          final indices = wordData['indices'] as List<int>?;
                          if (indices != null) {
                            for (final idx in indices) {
                              final tile = gameController.board[idx];
                              if (tile != null && tile.letter != null) {
                                score += tile.letter!.isWildcard
                                    ? 0
                                    : tile.letter!.score;
                              }
                            }
                          }
                          return score;
                        }

                        final wordList =
                            scoreService.extractWordsForPlacedTilesWithBonuses(
                          board: wordsData,
                          placedThisTurn: placedSet,
                        );

                        // Calculate total score and bonus multiplier
                        int baseScore = 0;
                        for (final wordData in wordList) {
                          if (validationService.isValidWord(wordData['word'])) {
                            baseScore += wordScore(wordData);
                          }
                        }
                        int multiplier = 1;
                        if (gameController.currentPlayer == 1 && gameController.player1QuadTurns > 0) {
                          multiplier = 4;
                        } else if (gameController.currentPlayer == 1 && gameController.player1DoubleTurns > 0) {
                          multiplier = 2;
                        } else if (gameController.currentPlayer == 2 && gameController.player2QuadTurns > 0) {
                          multiplier = 4;
                        } else if (gameController.currentPlayer == 2 && gameController.player2DoubleTurns > 0) {
                          multiplier = 2;
                        }
                        int totalScore = baseScore * multiplier;

                        // Show bonus dialog if any bonus was collected
                        final collectedBonuses = wordList
                            .where((w) =>
                                w['bonus'] != null &&
                                validationService.isValidWord(w['word']))
                            .map((w) => w['bonus'] as BonusInfo)
                            .toList();
                        if (collectedBonuses.isNotEmpty) {
                          for (final bonus in collectedBonuses) {
                            if (!mounted) return;
                            await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: bonus.color.withOpacity(0.92),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  side: BorderSide(
                                      color: Colors.black.withOpacity(0.08),
                                      width: 2),
                                ),
                                title: Row(
                                  children: [
                                    Icon(bonus.icon,
                                        color: Colors.white, size: 32),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Bonus Collected!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                      ),
                                    ),
                                  ],
                                ),
                                content: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    _bonusDescription(bonus),
                                    style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: Colors.black26,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      textStyle: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                        }

                        final allValid = wordList.isNotEmpty &&
                            wordList.every(
                                (w) => validationService.isValidWord(w['word']));
                        if (!mounted) return;
                        await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: Colors.white.withOpacity(0.95),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            title: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.deepPurple, size: 28),
                                SizedBox(width: 8),
                                Text('Turn Words',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple)),
                              ],
                            ),
                            content: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final wordData in wordList)
                                    Row(
                                      children: [
                                        Text(wordData['word'],
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold)),
                                        SizedBox(width: 8),
                                        validationService
                                                .isValidWord(wordData['word'])
                                            ? Icon(Icons.check_circle,
                                                color: Colors.green, size: 22)
                                            : Icon(Icons.cancel,
                                                color: Colors.red, size: 22),
                                        SizedBox(width: 8),
                                        if (validationService
                                            .isValidWord(wordData['word']))
                                          Text(
                                            '+${wordScore(wordData)}',
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.green[800]),
                                          ),
                                      ],
                                    ),
                                  const SizedBox(height: 12),
                                  Divider(),
                                  Row(
                                    children: [
                                      Text('Total Score:',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                      SizedBox(width: 8),
                                      if (multiplier > 1)
                                        Text('$baseScore x $multiplier = $totalScore',
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.deepPurple,
                                                fontWeight: FontWeight.bold)),
                                      if (multiplier == 1)
                                        Text('$totalScore',
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.deepPurple,
                                                fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.deepPurple,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  textStyle:
                                      TextStyle(fontWeight: FontWeight.bold),
                                ),
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  await gameController.endTurn(
                                      skipValidation: true);
                                },
                                child: Text('OK'),
                              ),
                            ],
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.check_circle_outline, size: 30),
                label: const Text('End Turn'),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: 52,
              height: 44,
              child: IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white, size: 28),
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(
                    isMyTurn ? Colors.red : Colors.grey
                  ),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  minimumSize: MaterialStateProperty.all<Size>(const Size(52, 44)),
                ),
                tooltip: 'Skip Turn',
                onPressed: isMyTurn
                    ? () {
                        final gameController =
                            Provider.of<GameController>(context, listen: false);
                        gameController.skipTurn();
                      }
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
