import 'package:characters/characters.dart';

class TrieNode {
  final Map<String, TrieNode> children = {};
  bool isWord = false;
}

class Trie {
  final TrieNode root = TrieNode();

  void insert(String word) {
    var node = root;
    for (final char in word.characters) {
      node = node.children.putIfAbsent(char, () => TrieNode());
    }
    node.isWord = true;
  }

  bool contains(String word) {
    var node = root;
    for (final char in word.characters) {
      if (!node.children.containsKey(char)) return false;
      node = node.children[char]!;
    }
    return node.isWord;
  }
} 