import './letter.dart';
import './bonus_info.dart';

class BoardTile {
  Letter? letter;
  bool isPermanent;
  BonusInfo? bonus;

  BoardTile({this.letter, this.isPermanent = false, this.bonus});
} 