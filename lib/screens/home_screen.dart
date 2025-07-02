import 'dart:async';
import 'dart:math';

import 'package:bonus/controllers/game_controller.dart';
import 'package:bonus/repositories/firebase_game_repository.dart';
import 'package:bonus/repositories/local_game_repository.dart';
import 'package:bonus/screens/game_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../strings.dart';
import '../services/preferences_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  bool _isHebrew = false;
  final PreferencesService _preferencesService = PreferencesService();

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final saved = await _preferencesService.loadLanguageSetting();
    if (saved != null) {
      setState(() {
        _isHebrew = saved;
      });
    }
  }

  void _toggleLanguage() {
    setState(() {
      _isHebrew = !_isHebrew;
    });
    _preferencesService.saveLanguageSetting(_isHebrew);
  }

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
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: Icon(Icons.language, color: Colors.deepPurple),
                            tooltip: _isHebrew ? 'Switch to English' : Strings.get('switchToHebrew', isHebrew: _isHebrew),
                            onPressed: () {
                              _toggleLanguage();
                            },
                          ),
                        ),
                        _buildMenuButton(
                          context,
                          icon: Icons.play_circle_fill,
                          label: Strings.get('startGame', isHebrew: _isHebrew),
                          color: Colors.deepPurple,
                          onPressed: () {
                            _showStartGameDialog(context);
                          },
                        ),
                        const SizedBox(height: 18),
                        _buildMenuButton(
                          context,
                          icon: Icons.info_outline,
                          label: Strings.get('instructions', isHebrew: _isHebrew),
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
                  label: Strings.get('onlineGame', isHebrew: _isHebrew),
                  color: Colors.deepPurple,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _showOnlineGameDialog(context);
                  },
                ),
                _buildDialogButton(
                  dialogContext,
                  label: Strings.get('localGame', isHebrew: _isHebrew),
                  color: Colors.green[700]!,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                      return ChangeNotifierProvider(
                        create: (context) => GameController(repository: LocalGameRepository()),
                        child: GameScreen(roomID: 'local_room', isHebrew: _isHebrew),
                      );
                    }));
                  },
                ),
                _buildDialogButton(
                  dialogContext,
                  label: Strings.get('playVsComputer', isHebrew: _isHebrew),
                  color: Colors.pink[700]!,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                       return ChangeNotifierProvider(
                        create: (context) => GameController(repository: LocalGameRepository()),
                        child: GameScreen(isAiGame: true, roomID: 'local_room', isHebrew: _isHebrew),
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
                    label: Strings.get('close', isHebrew: _isHebrew),
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
      child: SizedBox(
        width: 220,
        height: 44,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
          ),
          onPressed: onPressed,
          child: Text(label, textDirection: _isHebrew ? TextDirection.rtl : TextDirection.ltr),
        ),
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
            children: [
              Icon(Icons.public, color: Colors.deepPurple, size: 28),
              SizedBox(width: 8),
              Text(Strings.get('onlineGame', isHebrew: _isHebrew), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
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
                  label: Strings.get('createRoom', isHebrew: _isHebrew),
                  color: Colors.deepPurple,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _createRoom(context);
                  },
                ),
                _buildDialogButton(
                  dialogContext,
                  label: Strings.get('joinRoom', isHebrew: _isHebrew),
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
                    label: Strings.get('close', isHebrew: _isHebrew),
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
            children: [
              Icon(Icons.person, color: Colors.deepPurple, size: 28),
              SizedBox(width: 8),
              Text(Strings.get('enterYourName', isHebrew: _isHebrew), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
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
                  decoration: InputDecoration(labelText: Strings.get('yourName', isHebrew: _isHebrew)),
                  textDirection: _isHebrew ? TextDirection.rtl : TextDirection.ltr,
                ),
                _buildDialogButton(
                  dialogContext,
                  label: Strings.get('create', isHebrew: _isHebrew),
                  color: Colors.deepPurple,
                  onPressed: () async {
                    final String playerName = nameController.text.trim().isEmpty ? Strings.get('player1', isHebrew: _isHebrew) : nameController.text.trim();
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
                                child: GameScreen(isAiGame: false, roomID: roomID, localPlayerId: 1, isHebrew: _isHebrew),
                              );
                            }));
                          }
                        });
                        return AlertDialog(
                          backgroundColor: Colors.white.withOpacity(0.95),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Row(
                            children: [
                              Icon(Icons.hourglass_top, color: Colors.deepPurple, size: 28),
                              SizedBox(width: 8),
                              Text(Strings.get('roomCreated', isHebrew: _isHebrew), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SelectableText(
                                Strings.get('roomPin', isHebrew: _isHebrew, params: {'pin': roomID}),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                                textDirection: _isHebrew ? TextDirection.rtl : TextDirection.ltr,
                              ),
                              const SizedBox(height: 24),
                              const CircularProgressIndicator(),
                              const SizedBox(height: 12),
                              Text(Strings.get('waitingForPlayer', isHebrew: _isHebrew), style: TextStyle(color: Colors.deepPurple)),
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
                    label: Strings.get('close', isHebrew: _isHebrew),
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
            children: [
              Icon(Icons.login, color: Colors.deepPurple, size: 28),
              SizedBox(width: 8),
              Text(Strings.get('joinRoom', isHebrew: _isHebrew), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
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
                  decoration: InputDecoration(labelText: Strings.get('enterPIN', isHebrew: _isHebrew)),
                  keyboardType: TextInputType.number,
                  textDirection: _isHebrew ? TextDirection.rtl : TextDirection.ltr,
                ),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: Strings.get('yourName', isHebrew: _isHebrew)),
                  textDirection: _isHebrew ? TextDirection.rtl : TextDirection.ltr,
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
                    label: Strings.get('join', isHebrew: _isHebrew),
                    color: Colors.deepPurple,
                    onPressed: () async {
                      final String roomID = pinController.text.trim();
                      final String playerName = nameController.text.trim().isEmpty ? Strings.get('player2', isHebrew: _isHebrew) : nameController.text.trim();
                      if (roomID.isEmpty || roomID.length != 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(Strings.get('enterValid6DigitPIN', isHebrew: _isHebrew))),
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
                            child: GameScreen(isAiGame: false, roomID: roomID, localPlayerId: 2, isHebrew: _isHebrew),
                          );
                        }));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(Strings.get('roomNotFound', isHebrew: _isHebrew))),
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
            children: [
              Icon(Icons.info_outline, color: Colors.cyan, size: 28),
              SizedBox(width: 8),
              Text(Strings.get('instructions', isHebrew: _isHebrew), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            ],
          ),
          content: SingleChildScrollView(
            child: Directionality(
              textDirection: _isHebrew ? TextDirection.rtl : TextDirection.ltr,
              child: Text(
                Strings.get('gameInstructions', isHebrew: _isHebrew),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
              ),
            ),
          ),
          actions: <Widget>[
            _buildDialogButton(
              context,
              label: Strings.get('close', isHebrew: _isHebrew),
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