import 'package:bonus/screens/game_screen.dart';
import 'package:bonus/services/game_logic.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bonus'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                _showStartGameDialog(context);
              },
              child: const Text('Start Game'),
            ),
            ElevatedButton(
              onPressed: () {
                _showInstructionsDialog(context);
              },
              child: const Text('Instructions'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStartGameDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Start Game'),
          content: const Text('Select game mode:'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                  return ChangeNotifierProvider(
                    create: (context) => GameLogic(),
                    child: const GameScreen(),
                  );
                }));
              },
              child: const Text('2 Players'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                   return ChangeNotifierProvider(
                    create: (context) => GameLogic(),
                    child: const GameScreen(isAiGame: true),
                  );
                }));
              },
              child: const Text('Play vs Computer'),
            ),
          ],
        );
      },
    );
  }

  void _showInstructionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Instructions'),
          content: const SingleChildScrollView(
            child: Text(
              'The goal of the game is to score points by creating words on the board.\n\n'
              'Each player starts with 8 random letters.\n\n'
              'On your turn, place letters on the board to form a word. The first word must cover the center tile.\n\n'
              'Subsequent words must connect to existing words.\n\n'
              'The game ends when a player uses all their letters and the letter pool is empty.\n\n'
              'The player with the highest score wins.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
} 