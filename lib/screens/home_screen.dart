import 'dart:async';
import 'dart:math';

import 'package:bonus/controllers/game_controller.dart';
import 'package:bonus/repositories/firebase_game_repository.dart';
import 'package:bonus/repositories/local_game_repository.dart';
import 'package:bonus/screens/game_screen.dart';
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
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7F53AC), Color(0xFF647DEE), Color(0xFF63E2FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Centered white container with menu buttons
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 160),
                child: Card(
                  elevation: 16,
                  color: Colors.white.withOpacity(0.92),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[

                        _buildMenuButton(
                          context,
                          icon: Icons.play_circle_fill,
                          label: 'Start Game',
                          color: Colors.deepPurple,
                          onPressed: () {
                            _showStartGameDialog(context);
                          },
                        ),
                        const SizedBox(height: 18),
                        _buildMenuButton(
                          context,
                          icon: Icons.info_outline,
                          label: 'Instructions',
                          color: Colors.cyan[700]!,
                          onPressed: () {
                            _showInstructionsDialog(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Logo positioned at top center
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/bonusLogo.png',
                  height: 280,
                  width: 280,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onPressed}) {
    return SizedBox(
      width: 220,
      height: 54,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
        ),
        icon: Icon(icon, size: 28),
        label: Text(label),
        onPressed: onPressed,
      ),
    );
  }

  void _showStartGameDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.play_circle_fill, color: Colors.deepPurple, size: 28),
              SizedBox(width: 8),
              Text('Start Game', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            ],
          ),
          content: SizedBox(
            width: 340,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogButton(
                  dialogContext,
                  label: 'Online',
                  color: Colors.deepPurple,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _showOnlineGameDialog(context);
                  },
                ),
                _buildDialogButton(
                  dialogContext,
                  label: 'Local',
                  color: Colors.green[700]!,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                      return ChangeNotifierProvider(
                        create: (context) => GameController(repository: LocalGameRepository()),
                        child: const GameScreen(roomID: 'local_room'),
                      );
                    }));
                  },
                ),
                _buildDialogButton(
                  dialogContext,
                  label: 'Play vs Computer',
                  color: Colors.pink[700]!,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                       return ChangeNotifierProvider(
                        create: (context) => GameController(repository: LocalGameRepository()),
                        child: const GameScreen(isAiGame: true, roomID: 'local_room'),
                      );
                    }));
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogButton(
                    dialogContext,
                    label: 'Close',
                    color: Colors.cyan,
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogButton(BuildContext context, {required String label, required Color color, required VoidCallback onPressed}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 6,
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }

  void _showOnlineGameDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.public, color: Colors.deepPurple, size: 28),
              SizedBox(width: 8),
              Text('Online Game', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            ],
          ),
          content: SizedBox(
            width: 340,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogButton(
                  dialogContext,
                  label: 'Create Room',
                  color: Colors.deepPurple,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _createRoom(context);
                  },
                ),
                _buildDialogButton(
                  dialogContext,
                  label: 'Join Room',
                  color: Colors.green[700]!,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _joinRoom(context);
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            Container(
              alignment: Alignment.centerLeft,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogButton(
                    dialogContext,
                    label: 'Close',
                    color: Colors.cyan,
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                ],
              ),
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
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.person, color: Colors.deepPurple, size: 28),
              SizedBox(width: 8),
              Text('Enter Your Name', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            ],
          ),
          content: SizedBox(
            width: 340,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Your Name'),
                ),
                _buildDialogButton(
                  dialogContext,
                  label: 'Create',
                  color: Colors.deepPurple,
                  onPressed: () async {
                    final String playerName = nameController.text.trim().isEmpty ? 'Player 1' : nameController.text.trim();
                    Navigator.of(dialogContext).pop();
                    final repository = FirebaseGameRepository();
                    final roomID = await repository.createRoom(playerName);
                    final gameController = GameController(repository: repository);
                    gameController.setPlayer1Name(playerName);
                    await gameController.startNewOnlineGame(roomID);
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (waitingDialogContext) {
                        StreamSubscription<DatabaseEvent>? player2Listener;
                        bool isNavigating = false;
                        player2Listener = _database.child('rooms/$roomID/players/player2').onValue.listen((event) {
                          if (isNavigating) return;
                          final p2name = event.snapshot.value as String?;
                          if (p2name != null && p2name.isNotEmpty) {
                            isNavigating = true;
                            player2Listener?.cancel();
                            Navigator.of(waitingDialogContext).pop();
                            Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                              return ChangeNotifierProvider.value(
                                value: gameController,
                                child: GameScreen(isAiGame: false, roomID: roomID, localPlayerId: 1),
                              );
                            }));
                          }
                        });
                        return AlertDialog(
                          backgroundColor: Colors.white.withOpacity(0.95),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Row(
                            children: const [
                              Icon(Icons.hourglass_top, color: Colors.deepPurple, size: 28),
                              SizedBox(width: 8),
                              Text('Room Created!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SelectableText(
                                'Your room PIN is: $roomID\n\nShare it with a friend to play.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                              ),
                              const SizedBox(height: 24),
                              const CircularProgressIndicator(),
                              const SizedBox(height: 12),
                              const Text('Waiting for player to join...', style: TextStyle(color: Colors.deepPurple)),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            Container(
              alignment: Alignment.centerLeft,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogButton(
                    dialogContext,
                    label: 'Close',
                    color: Colors.cyan,
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                ],
              ),
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
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.login, color: Colors.deepPurple, size: 28),
              SizedBox(width: 8),
              Text('Join Room', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            ],
          ),
          content: SizedBox(
            width: 340,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
          ),
          actions: [
            Container(
              alignment: Alignment.centerLeft,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogButton(
                    dialogContext,
                    label: 'Join',
                    color: Colors.deepPurple,
                    onPressed: () async {
                      final String roomID = pinController.text.trim();
                      final String playerName = nameController.text.trim().isEmpty ? 'Player 2' : nameController.text.trim();
                      if (roomID.isEmpty || roomID.length != 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid 6-digit PIN.')),
                        );
                        return;
                      }
                      final snapshot = await _database.child('rooms/$roomID').get();
                      if (snapshot.exists) {
                        final repository = FirebaseGameRepository();
                        await repository.joinRoom(roomID, playerName);
                        Navigator.of(dialogContext).pop();
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                          return ChangeNotifierProvider(
                            create: (context) => GameController(repository: repository),
                            child: GameScreen(isAiGame: false, roomID: roomID, localPlayerId: 2),
                          );
                        }));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Room not found!')),
                        );
                      }
                    },
                  ),
                ],
              ),
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
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.cyan, size: 28),
              SizedBox(width: 8),
              Text('הוראות משחק', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            ],
          ),
          content: const SingleChildScrollView(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                '''
1. מטרת המשחק:
   ליצור מילים חדשות על לוח המשחק בעזרת האותיות שבידך, לצבור נקודות ולנצח את היריב.

2. מהלך המשחק:
   - כל שחקן בתורו גורר אותיות מהיד אל הלוח כדי ליצור מילה חדשה.
   - כל האותיות שמונחות בתור חייבות להיות בשורה אחת (אופקית) או בעמודה אחת (אנכית), ללא פיצול.
   - כל מילה חדשה חייבת להיות מחוברת למילים קיימות על הלוח (מלבד המילה הראשונה).

3. חוקים נוספים:
   - ניתן להניח אותיות רק על משבצות ריקות.
   - אסור להניח אותיות כך שהן לא יוצרות מילה תקינה בעברית.
   - ניתן להחזיר אותיות ליד לפני סיום התור.

4. סיום תור:
   - לאחר הנחת האותיות, לחץ על "סיום תור" כדי לחשב את הניקוד.
   - אם לא ביצעת מהלך, תוכל ללחוץ על "דלג תור" כדי להעביר את התור ליריב.
   - אם הזמן נגמר, התור יידלג אוטומטית והאותיות שהונחו יחזרו ליד.

5. בונוסים:
   - חלק מהמשבצות מעניקות בונוסים מיוחדים (כמו הכפלת ניקוד, תור נוסף ועוד).
   - בונוסים מופעלים רק כאשר מניחים אות על המשבצת המסומנת.

6. סיום המשחק:
   - המשחק מסתיים כאשר כל האותיות נגמרות ואין לשחקנים אותיות ביד.
   - המנצח הוא השחקן עם מספר הנקודות הגבוה ביותר.

בהצלחה ושיהיה משחק מהנה!
''',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
              ),
            ),
          ),
          actions: <Widget>[
            _buildDialogButton(
              context,
              label: 'סגור',
              color: Colors.cyan,
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
} 