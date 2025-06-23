import 'package:flutter/material.dart';
import '../models/letter.dart';

class LetterTile extends StatelessWidget {
  final Letter letter;

  const LetterTile({super.key, required this.letter});

  @override
  Widget build(BuildContext context) {
    final isBlank = letter.letter.trim().isEmpty;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isBlank ? Colors.brown[200] : Colors.amber[200],
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(5),
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