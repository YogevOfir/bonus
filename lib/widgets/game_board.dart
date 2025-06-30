import 'package:bonus/controllers/game_controller.dart';
import 'package:bonus/models/draggable_letter.dart';
import 'package:bonus/models/letter.dart';
import 'package:bonus/widgets/letter_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GameBoard extends StatelessWidget {
  const GameBoard({super.key});

  @override
  Widget build(BuildContext context) {
    final gameController = Provider.of<GameController>(context);
    final board = gameController.board;
    final lastTurnWordIndices = gameController.lastTurnWordIndices;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFe0cda9), // light wood
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 12,
        ),
        itemCount: 144,
        itemBuilder: (context, index) {
          final tile = board[index];
          final letter = tile?.letter;
          final isPermanent = tile?.isPermanent ?? false;
          final bonusInfo = tile?.bonus;
          final isPlayable = gameController.isPlayableTile(index);
          final wasInLastTurnWord = lastTurnWordIndices.contains(index);

          Widget tileContent;
          if (letter != null) {
            final letterTile = LetterTile(
              letter: letter,
              isPermanent: isPermanent,
            );
            if (isPermanent) {
              tileContent = Container(
                decoration: BoxDecoration(
                  color: Colors.grey[400]!.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: wasInLastTurnWord ? Border.all(color: Colors.blue.shade700, width: 1.5) : null,
                ),
                child: letterTile,
              );
            } else {
              tileContent = Draggable<DraggableLetter>(
                data: DraggableLetter(
                  letter: letter,
                  origin: LetterOrigin.board,
                  fromIndex: index,
                ),
                feedback: Material(
                  elevation: 8.0,
                  borderRadius: BorderRadius.circular(12),
                  child: letterTile,
                ),
                childWhenDragging: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    color: Colors.grey.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: letterTile,
                ),
              );
            }
          } else if (!isPlayable) {
            // Always show bonuses, even if not playable
            if (bonusInfo != null) {
              final isFirstTurn = !(gameController.firstMoveDone);
              Widget bonusIconContainer = Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: bonusInfo.color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: bonusInfo.color.withOpacity(0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.brown.withOpacity(0.08),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    bonusInfo.assetPath,
                    width: 22,
                    height: 22,
                  ),
                ),
              );
              if (isFirstTurn) {
                bonusIconContainer = Opacity(
                  opacity: 0.5,
                  child: bonusIconContainer,
                );
              }
              tileContent = Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: bonusInfo.color.withOpacity(0.5), width: 2),
                  color: bonusInfo.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: bonusIconContainer,
                ),
              );
            } else {
              tileContent = Container();
            }
          } else {
            final isFirstTurn = !(gameController.firstMoveDone);
            Widget? bonusIconContainer;
            if (bonusInfo != null) {
              bonusIconContainer = Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: bonusInfo.color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: bonusInfo.color.withOpacity(0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.brown.withOpacity(0.08),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    bonusInfo.assetPath,
                    width: 22,
                    height: 22,
                  ),
                ),
              );
              if (isFirstTurn) {
                bonusIconContainer = Opacity(
                  opacity: 0.5,
                  child: bonusIconContainer,
                );
              }
            }
            tileContent = Container(
              decoration: BoxDecoration(
                border: Border.all(
                    color: bonusInfo != null
                        ? bonusInfo.color
                        : Colors.brown[300]!,
                    width: 2),
                gradient: bonusInfo != null
                    ? LinearGradient(
                        colors: [
                          bonusInfo.color.withOpacity(0.18),
                          Colors.white
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [Colors.brown[100]!, Colors.brown[200]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.brown.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: bonusInfo != null
                  ? Center(
                      child: bonusIconContainer,
                    )
                  : null,
            );
          }

          if (!isPlayable) {
            return tileContent;
          }

          return DragTarget<DraggableLetter>(
            builder: (context, candidateData, rejectedData) {
              return tileContent;
            },
            onWillAccept: (data) {
              if (board[index]?.isPermanent == true) return false;
              return board[index]?.letter == null || data?.fromIndex == index;
            },
            onAccept: (draggableLetter) {
              // First move the blank tile to the board
              gameController.moveLetter(draggableLetter, index);

              // If it's a wildcard, show the dialog
              if (draggableLetter.letter.letter == ' ') {
                _showWildcardDialog(context, index);
              }
            },
          );
        },
      ),
    );
  }

  Future<void> _showWildcardDialog(BuildContext context, int boardIndex) async {
    final gameController = Provider.of<GameController>(context, listen: false);
    const alphabet = 'הדגבאיטחזוסנמלכתשרקצ';

    final chosenLetter = await showDialog<String>(
      context: context,
      barrierDismissible: false, // User must choose a letter
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side:
                BorderSide(color: Colors.deepPurple.withOpacity(0.3), width: 2),
          ),
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.deepPurple, size: 28),
              SizedBox(width: 8),
              Text(
                'Choose Letter for Joker',
                style: TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(maxHeight: 300),
            child: GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: alphabet.runes.map((rune) {
                var character = String.fromCharCode(rune);
                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).pop(character);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple[100]!,
                            Colors.deepPurple[200]!
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          character,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple[800],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (chosenLetter != null) {
      gameController.setWildcardLetter(boardIndex, chosenLetter);
    }
  }
}
