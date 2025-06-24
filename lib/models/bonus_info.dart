import 'package:flutter/material.dart';

enum BonusType {
  score,
  futureDouble,
  futureQuad,
  extraMove,
  wordGame;

  // Serialization
  String toJson() => name;
  static BonusType fromJson(String json) => values.byName(json);
}

class BonusInfo {
  final IconData icon;
  final Color color;
  final BonusType type;
  final int? scoreValue; // For score bonuses

  BonusInfo({required this.icon, required this.color, required this.type, this.scoreValue});

  // Serialization
  Map<String, dynamic> toJson() => {
    'icon': icon.codePoint,
    'color': color.value,
    'type': type.toJson(),
    'scoreValue': scoreValue,
  };

  factory BonusInfo.fromJson(Map<String, dynamic> json) {
    return BonusInfo(
      icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
      color: Color(json['color']),
      type: BonusType.fromJson(json['type']),
      scoreValue: json['scoreValue'],
    );
  }
} 