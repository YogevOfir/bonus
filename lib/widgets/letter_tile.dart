import 'package:flutter/material.dart';
import '../models/letter.dart';

class LetterTile extends StatelessWidget {
  final Letter letter;
  final bool isPermanent;

  const LetterTile({super.key, required this.letter, this.isPermanent = false});

  @override
  Widget build(BuildContext context) {
    final isBlank = letter.letter.trim().isEmpty;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isPermanent ? const Color.fromARGB(255, 161, 137, 65) : Colors.amber[200],
        border: Border.all(color: Colors.black, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              isBlank ? '*' : letter.letter,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
    );
  }
} 