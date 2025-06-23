import 'package:bonus/models/letter.dart';

enum LetterOrigin { hand, board }

class DraggableLetter {
  final Letter letter;
  final LetterOrigin origin;
  final int? fromIndex; // The index on the board, if from the board.

  DraggableLetter({
    required this.letter,
    required this.origin,
    this.fromIndex,
  });
} 