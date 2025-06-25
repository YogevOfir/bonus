class Letter {
  final String letter;
  final int score;
  final bool isWildcard;

  Letter(this.letter, this.score, {this.isWildcard = false});

  factory Letter.fromString(String str) {
    final parts = str.split(':');
    final letter = parts[0];
    final score = int.parse(parts[1]);
    final isWildcard = parts.length > 2 ? parts[2] == 'true' : false;
    return Letter(letter, score, isWildcard: isWildcard);
  }

  @override
  String toString() {
    return '$letter:$score:$isWildcard';
  }
} 