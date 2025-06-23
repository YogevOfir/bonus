import 'package:flutter/material.dart';

enum BonusType {
  score,
  futureDouble,
  futureQuad,
  extraMove,
  wordGame,
}

class BonusInfo {
  final IconData icon;
  final Color color;
  final BonusType type;
  final int? scoreValue; // For score bonuses

  BonusInfo({required this.icon, required this.color, required this.type, this.scoreValue});
} 