import 'package:bonus/models/bonus_info.dart';
import 'package:bonus/models/draggable_letter.dart';
import 'package:bonus/models/letter.dart';
import 'package:bonus/services/game_logic.dart';
import 'package:bonus/widgets/game_board.dart';
import 'package:bonus/widgets/letter_tile.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class GameScreen extends StatefulWidget {
  final bool isAiGame;
  final String roomID;
  final int localPlayerId;
  const GameScreen({super.key, this.isAiGame = false, required this.roomID, this.localPlayerId = 1});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  late GameLogic _gameLogic;
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    _gameLogic = Provider.of<GameLogic>(context, listen: false);

    if (widget.roomID.isNotEmpty) {
      _gameLogic.setRoomID(widget.roomID);
      _gameLogic.setLocalPlayerId(widget.localPlayerId);

      final roomRef = _database.child('rooms/${widget.roomID}');

      // Use `onValue.first` to wait for the first data event, which includes the initial state.
      // This is more reliable than .get() for ensuring initial data is loaded.
      roomRef.onValue.first.then((event) {
        if (event.snapshot.value != null) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          _gameLogic.syncFromFirebase(data);
        }
      });

      // After getting the first value, set up a permanent listener for any future changes.
      roomRef.onValue.listen((event) {
        if (event.snapshot.value != null) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          _gameLogic.syncFromFirebase(data);
        }
      });
    }

    // Add a timer to refresh the UI every second for the timer display
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bonus'),
      ),
      body: Consumer<GameLogic>(
        builder: (context, gameLogic, child) {
          bool isMyTurn = gameLogic.currentPlayer == widget.localPlayerId;
          print("Player ${widget.localPlayerId} UI BUILD --- Current Turn: ${gameLogic.currentPlayer}, Is My Turn? $isMyTurn");

          // While waiting for the first sync, show a loading indicator.
          if (!gameLogic.isSynced) {
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
          // Attach error dialog callback
          gameLogic.onError = (msg) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Invalid Move'),
                content: Text(msg),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          };
          if (!gameLogic.wordsLoaded) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (gameLogic.isGameOver()) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showGameOverDialog(context, gameLogic);
            });
          }
          final currentPlayerHand = gameLogic.currentPlayer == 1
              ? gameLogic.player1Hand
              : gameLogic.player2Hand;

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildScoreBoard(gameLogic),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text('Time: ${gameLogic.remainingTime}',
                          style: const TextStyle(fontSize: 20)),
                      Text('Deck: ${gameLogic.letterPool.length}',
                          style: const TextStyle(fontSize: 20)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const GameBoard(),
                  const SizedBox(height: 20),
                  _buildPlayerHandArea(gameLogic, context),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final results = await gameLogic.validateWordsWithStatus();
                      final allValid = results.every((r) => r['isValid'] == true);
                      if (!allValid) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Word Validation'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: results.map<Widget>((r) => Row(
                                children: [
                                  Text(r['word'], style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 8),
                                  r['isValid']
                                    ? const Icon(Icons.check, color: Colors.green)
                                    : const Icon(Icons.close, color: Colors.red),
                                ],
                              )).toList(),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                        return;
                      }
                      // If all valid, show dialog with scores
                      final scoreResults = await gameLogic.wordsWithScoresForTurn();
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Words & Scores'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: scoreResults.map<Widget>((r) => Row(
                              children: [
                                Text(r['word'], style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Text(r['score'].toString(), style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                const Icon(Icons.check, color: Colors.green),
                                if (r['bonus'] != null) ...[
                                  const SizedBox(width: 8),
                                  Icon(r['bonus'].icon, color: r['bonus'].color),
                                  const SizedBox(width: 4),
                                  Text(_bonusLabel(r['bonus']), style: TextStyle(color: r['bonus'].color)),
                                ],
                              ],
                            )).toList(),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await gameLogic.endTurn();
                              },
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('End Turn'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScoreBoard(GameLogic gameLogic) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(
          children: [
            Text(gameLogic.player1Name, style: const TextStyle(fontSize: 18)),
            Text(gameLogic.player1Score.toString(),
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
        Column(
          children: [
            const Text('Turn', style: TextStyle(fontSize: 18)),
            Text(gameLogic.currentPlayer == 1 ? gameLogic.player1Name : gameLogic.player2Name,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
        Column(
          children: [
            Text(widget.isAiGame ? 'Computer' : gameLogic.player2Name,
                style: const TextStyle(fontSize: 18)),
            Text(gameLogic.player2Score.toString(),
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayerHandArea(GameLogic gameLogic, BuildContext context) {
    bool isPlayer1sTurn = gameLogic.currentPlayer == 1;
    bool isMyTurn = gameLogic.currentPlayer == widget.localPlayerId;
    final screenWidth = MediaQuery.of(context).size.width;

    // If it's my turn, highlight my hand, otherwise both faded
    double player1Opacity, player2Opacity;
    if (isMyTurn) {
      player1Opacity = isPlayer1sTurn ? 1.0 : 0.6;
      player2Opacity = isPlayer1sTurn ? 0.6 : 1.0;
    } else {
      player1Opacity = 0.6;
      player2Opacity = 0.6;
    }

    return Column(
      children: [
        Text(widget.isAiGame ? 'Computer\'s Hand' : "${gameLogic.player2Name}'s Hand"),
        Opacity(
          opacity: player2Opacity,
          child: _buildPlayerHand(gameLogic.player2Hand, 2, isMyTurn, screenWidth),
        ),
        const SizedBox(height: 20),
        Text("${gameLogic.player1Name}'s Hand"),
        Opacity(
          opacity: player1Opacity,
          child: _buildPlayerHand(gameLogic.player1Hand, 1, isMyTurn, screenWidth),
        ),
      ],
    );
  }

  Widget _buildPlayerHand(
      List<Letter> hand, int handOwnerId, bool isMyTurn, double screenWidth) {
    bool canDrag = isMyTurn && (handOwnerId == widget.localPlayerId);

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
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: canDrag
                      ? Draggable<DraggableLetter>(
                          data: DraggableLetter(letter: letter, origin: LetterOrigin.hand, fromIndex: -1),
                          feedback: Material(elevation: 4.0, child: letterTile),
                          childWhenDragging: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(5),
                            ),
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
          // Only allow returning if it's from the board, it's the player's turn, and not permanent
          return isMyTurn && data?.origin == LetterOrigin.board;
        },
        onAccept: (draggableLetter) {
          final gameLogic = Provider.of<GameLogic>(context, listen: false);
          gameLogic.returnLetterToHand(draggableLetter);
        },
      ),
    );
  }

  void _showGameOverDialog(BuildContext context, GameLogic gameLogic) {
    String winner;
    if (gameLogic.player1Score > gameLogic.player2Score) {
      winner = gameLogic.player1Name;
    } else if (gameLogic.player2Score > gameLogic.player1Score) {
      winner = widget.isAiGame ? 'Computer' : gameLogic.player2Name;
    } else {
      winner = 'It\'s a tie!';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Game Over'),
          content: Text('$winner wins!'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                Navigator.of(context).pop(); // Go back to home screen
              },
              child: const Text('Play Again'),
            ),
          ],
        );
      },
    );
  }

  String _bonusLabel(BonusInfo? bonus) {
    if (bonus == null) {
      return '';
    }
    switch (bonus.type) {
      case BonusType.score:
        return bonus.scoreValue != null ? '+${bonus.scoreValue}' : 'Score Bonus';
      case BonusType.futureDouble:
        return 'Double Next 2 Turns';
      case BonusType.futureQuad:
        return 'Quadruple Next Turn';
      case BonusType.extraMove:
        return 'Extra Move';
      case BonusType.wordGame:
        return 'Word Game Bonus';
    }
  }
} 