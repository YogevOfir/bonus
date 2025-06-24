import './letter.dart';
import './bonus_info.dart';

class BoardTile {
  Letter? letter;
  bool isPermanent;
  BonusInfo? bonus;

  BoardTile({this.letter, this.isPermanent = false, this.bonus});

  // Serialization
  Map<String, dynamic> toJson() => {
    'letter': letter?.toString(),
    'isPermanent': isPermanent,
    'bonus': bonus?.toJson(),
  };

  factory BoardTile.fromJson(Map<String, dynamic> json) {
    return BoardTile(
      letter: json['letter'] != null ? Letter.fromString(json['letter']) : null,
      isPermanent: json['isPermanent'] ?? false,
      bonus: json['bonus'] != null ? BonusInfo.fromJson(Map<String, dynamic>.from(json['bonus'])) : null,
    );
  }
} 