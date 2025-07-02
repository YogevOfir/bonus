import 'package:flutter/material.dart';
import '../models/letter.dart';

class LetterTile extends StatelessWidget {
  final Letter letter;
  final bool isPermanent;
  final bool isReplacement;

  const LetterTile({super.key, required this.letter, this.isPermanent = false, this.isReplacement = false});

  @override
  Widget build(BuildContext context) {
    final isBlank = letter.letter.trim().isEmpty;
    // Check if this is the replaced permanent letter in hand
    final gameController = Navigator.canPop(context)
        ? null
        : null; // placeholder, will be ignored in widget tree
    // The icon is shown if isReplacement is true (set by parent)
    return Stack(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isPermanent
                ? const Color.fromARGB(255, 161, 137, 65)
                : Colors.amber[200],
            border: Border.all(color: Colors.black, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isBlank ? '🤡' : letter.letter,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (!isBlank)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Text(
                    letter.score.toString(),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
        if (isReplacement)
          Positioned(
            top: 2,
            right: 2,
            child: Icon(Icons.swap_horiz, size: 16, color: Colors.redAccent),
          ),
      ],
    );
  }
}
