import 'package:bonus/models/bonus_info.dart';
import 'package:bonus/models/draggable_letter.dart';
import 'package:bonus/models/letter.dart';
import 'package:bonus/services/game_logic.dart';
import 'package:bonus/widgets/game_board.dart';
import 'package:bonus/widgets/letter_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GameScreen extends StatelessWidget {
  final bool isAiGame;
  const GameScreen({super.key, this.isAiGame = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bonus'),
      ),
      body: Consumer<GameLogic>(
        builder: (context, gameLogic, child) {
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
            const Text('Player 1', style: TextStyle(fontSize: 18)),
            Text(gameLogic.player1Score.toString(),
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
        Column(
          children: [
            const Text('Turn', style: TextStyle(fontSize: 18)),
            Text('Player ${gameLogic.currentPlayer}',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
        Column(
          children: [
            Text(isAiGame ? 'Computer' : 'Player 2', style: const TextStyle(fontSize: 18)),
            Text(gameLogic.player2Score.toString(),
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayerHandArea(GameLogic gameLogic, BuildContext context) {
    bool isPlayer1Turn = gameLogic.currentPlayer == 1;
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        Text(isAiGame ? 'Computer\'s Hand' : 'Player 2\'s Hand'),
        DragTarget<DraggableLetter>(
          builder: (context, candidateData, rejectedData) {
            return Opacity(
              opacity: isPlayer1Turn ? 0.5 : 1.0,
              child: _buildPlayerHand(
                  gameLogic.player2Hand, isPlayer1Turn, screenWidth),
            );
          },
          onWillAccept: (data) =>
              data?.origin == LetterOrigin.board && !isPlayer1Turn,
          onAccept: (data) {
            gameLogic.returnLetterToHand(data);
          },
        ),
        const SizedBox(height: 20),
        const Text('Player 1\'s Hand'),
        DragTarget<DraggableLetter>(
          builder: (context, candidateData, rejectedData) {
            return Opacity(
              opacity: isPlayer1Turn ? 1.0 : 0.5,
              child: _buildPlayerHand(
                  gameLogic.player1Hand, !isPlayer1Turn, screenWidth),
            );
          },
          onWillAccept: (data) =>
              data?.origin == LetterOrigin.board && isPlayer1Turn,
          onAccept: (data) {
            gameLogic.returnLetterToHand(data);
          },
        ),
      ],
    );
  }

  Widget _buildPlayerHand(
      List<Letter> hand, bool isOpponent, double screenWidth) {
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: hand.map((letter) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Draggable<DraggableLetter>(
                data: DraggableLetter(
                    letter: letter, origin: LetterOrigin.hand),
                feedback: Material(
                  elevation: 4.0,
                  child: LetterTile(letter: letter),
                ),
                childWhenDragging: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: LetterTile(letter: letter),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showGameOverDialog(BuildContext context, GameLogic gameLogic) {
    String winner;
    if (gameLogic.player1Score > gameLogic.player2Score) {
      winner = 'Player 1';
    } else if (gameLogic.player2Score > gameLogic.player1Score) {
      winner = isAiGame ? 'Computer' : 'Player 2';
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