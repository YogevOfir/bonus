import 'dart:async';
import 'dart:math';

import 'package:bonus/screens/game_screen.dart';
import 'package:bonus/services/game_logic.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

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
                _showOnlineGameDialog(context);
              },
              child: const Text('Online'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                  return ChangeNotifierProvider(
                    create: (context) => GameLogic(),
                    child: const GameScreen(roomID: ''),
                  );
                }));
              },
              child: const Text('Local'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                   return ChangeNotifierProvider(
                    create: (context) => GameLogic(),
                    child: const GameScreen(isAiGame: true, roomID: ''),
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

  void _showOnlineGameDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Online Game'),
          content: const Text('Create or join a room:'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _createRoom(context);
              },
              child: const Text('Create Room'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _joinRoom(context);
              },
              child: const Text('Join Room'),
            ),
          ],
        );
      },
    );
  }

  void _createRoom(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Your Name'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Your Name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final String playerName = nameController.text.trim().isEmpty ? 'Player 1' : nameController.text.trim();
                Navigator.of(context).pop();
                final String roomID = (100000 + Random().nextInt(900000)).toString();
                final gameLogic = GameLogic();
                gameLogic.setRoomID(roomID);
                gameLogic.setPlayer1Name(playerName);
                // Show the room PIN and wait for player 2
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    StreamSubscription<DatabaseEvent>? player2Listener;
                    // Listen for player2 to join
                    player2Listener = _database.child('rooms/$roomID/players/player2').onValue.listen((event) {
                      final p2name = event.snapshot.value as String?;
                      if (p2name != null && p2name.isNotEmpty) {
                        player2Listener?.cancel(); // Stop listening to avoid multiple navigations
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                          // Use .value to provide the *existing* gameLogic instance.
                          return ChangeNotifierProvider.value(
                            value: gameLogic,
                            child: GameScreen(isAiGame: false, roomID: roomID, localPlayerId: 1),
                          );
                        }));
                      }
                    });
                    return AlertDialog(
                      title: const Text('Room Created!'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SelectableText(
                            'Your room PIN is: $roomID\n\nShare it with a friend to play.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 24),
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          const Text('Waiting for player to join...'),
                        ],
                      ),
                    );
                  },
                );
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _joinRoom(BuildContext context) {
    final TextEditingController pinController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Join Room'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinController,
                decoration: const InputDecoration(labelText: 'Enter PIN'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Your Name'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final String roomID = pinController.text.trim();
                final String playerName = nameController.text.trim().isEmpty ? 'Player 2' : nameController.text.trim();
                if (roomID.isEmpty || roomID.length != 6) {
                  print('Invalid PIN');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid 6-digit PIN.')),
                  );
                  return;
                }
                final snapshot = await _database.child('rooms/$roomID').get();
                if (snapshot.exists) {
                  // Set player2 name in Firebase
                  await _database.child('rooms/$roomID/players').update({'player2': playerName});
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                    // The joiner starts with a clean slate and will sync from Firebase.
                    return ChangeNotifierProvider(
                      create: (context) => GameLogic.online(),
                      child: GameScreen(isAiGame: false, roomID: roomID, localPlayerId: 2),
                    );
                  }));
                } else {
                  print('Room not found!');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Room not found!')),
                  );
                }
              },
              child: const Text('Join'),
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