import 'package:flutter/material.dart';

// 1. Define a mapping from icon names to IconData (add more as needed)
const Map<String, IconData> bonusIconMap = {
  'star': Icons.star,
  'bolt': Icons.bolt,
  'add': Icons.add,
  // Add more icon mappings as needed
};

enum BonusType {
  score,
  futureDouble,
  futureQuad,
  extraMove;
  // wordGame;

  // Serialization
  String toJson() => name;
  static BonusType fromJson(String json) => values.byName(json);
}

class BonusInfo {
  final String iconName; // Store the asset file name, e.g. 3dicons-fire-dynamic-color.png
  final Color color;
  final BonusType type;
  final int? scoreValue; // For score bonuses

  BonusInfo({required this.iconName, required this.color, required this.type, this.scoreValue});

  // Getter to retrieve the asset path for the icon
  String get assetPath => 'assets/bonuses_icons/$iconName';

  // Serialization
  Map<String, dynamic> toJson() => {
    'iconName': iconName,
    'color': color.value,
    'type': type.toJson(),
    'scoreValue': scoreValue,
  };

  factory BonusInfo.fromJson(Map<String, dynamic> json) {
    return BonusInfo(
      iconName: json['iconName'],
      color: Color(json['color']),
      type: BonusType.fromJson(json['type']),
      scoreValue: json['scoreValue'],
    );
  }
} 