import 'package:bonus/models/draggable_letter.dart';
import 'package:bonus/models/letter.dart';
import 'package:bonus/services/game_logic.dart';
import 'package:bonus/widgets/letter_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GameBoard extends StatelessWidget {
  const GameBoard({super.key});

  @override
  Widget build(BuildContext context) {
    final gameLogic = Provider.of<GameLogic>(context);
    final board = gameLogic.board;

    return GridView.builder(
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
        final isPlayable = gameLogic.isPlayableTile(index);

        Widget tileContent;
        if (letter != null) {
          final letterTile = LetterTile(letter: letter);
          if (isPermanent) {
            tileContent = Container(
              decoration: BoxDecoration(
                color: Colors.grey[400],
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.circular(5),
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
                elevation: 4.0,
                child: letterTile,
              ),
              childWhenDragging: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  color: Colors.grey.withOpacity(0.5),
                ),
              ),
              child: letterTile,
            );
          }
        } else if (!isPlayable) {
          tileContent = Container();
        } else {
          tileContent = Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              color: bonusInfo != null
                  ? bonusInfo.color.withOpacity(0.2)
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(5),
            ),
            child: bonusInfo != null
                ? Center(
                    child: Icon(bonusInfo.icon, color: bonusInfo.color),
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
            // A tile can be dropped if the spot is empty
            // or if it's being returned to its original spot.
            return board[index]?.letter == null || data?.fromIndex == index;
          },
          onAccept: (draggableLetter) {
            gameLogic.moveLetter(draggableLetter, index);
          },
        );
      },
    );
  }
} 