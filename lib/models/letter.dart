class Letter {
  final String letter;
  final int score;

  Letter(this.letter, this.score);

  factory Letter.fromString(String str) {
    final parts = str.split(':');
    return Letter(parts[0], int.parse(parts[1]));
  }

  @override
  String toString() {
    return '$letter:$score';
  }
} 