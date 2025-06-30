import 'package:bonus/controllers/game_controller.dart';
import 'package:bonus/models/bonus_info.dart';
import 'package:bonus/models/draggable_letter.dart';
import 'package:bonus/models/letter.dart';
import 'package:bonus/widgets/game_board.dart';
import 'package:bonus/widgets/letter_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

class GameScreen extends StatefulWidget {
  final bool isAiGame;
  final String roomID;
  final int localPlayerId;
  const GameScreen(
      {super.key,
      this.isAiGame = false,
      required this.roomID,
      this.localPlayerId = 1});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController _gameController;
  Timer? _uiTimer;
  AudioPlayer? _backgroundPlayer;
  AudioPlayer? _timeRunningOutPlayer;
  bool _isPlayingTimeRunningOut = false;
  double _backgroundMusicVolume = 0.3;
  double _timeRunningOutVolume = 0.5;
  bool _showVolumeSliders = false;
  int _lastTimeRunningOutTime = 0;

  @override
  void initState() {
    super.initState();
    _gameController = Provider.of<GameController>(context, listen: false);
    _initializeAudio();
    _startUITimer();

    if (widget.roomID.isNotEmpty) {
      _gameController.setRoomID(widget.roomID);
      _gameController.setLocalPlayerId(widget.localPlayerId);
    }

    _gameController.onPlayerLeft = () {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.deepPurple, size: 28),
              SizedBox(width: 8),
              Text('Player Left',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            ],
          ),
          content: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('The other player has left the game.',
                style: TextStyle(fontSize: 18)),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                // Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: Text('OK'),
            ),
          ],
        ),
      );
    };

    _gameController.onTurnPassedDueToTimeout = () {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.deepPurple, size: 28),
              SizedBox(width: 8),
              Text('Turn Skipped',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            ],
          ),
          content: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('You did nothing and your turn was passed.',
                style: TextStyle(fontSize: 18)),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    };

    _gameController.onShowTurnResults = (turnResults) {
      if (!mounted) return;
      _showTurnResultsDialog(turnResults);
    };

    // Start background music after a short delay to ensure audio is initialized
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        _startBackgroundMusic();
      }
    });
  }

  void _initializeAudio() async {
    try {
      print('Initializing audio players...');
      _backgroundPlayer = AudioPlayer();
      _timeRunningOutPlayer = AudioPlayer();
      
      // Set volume for background music
      await _backgroundPlayer?.setVolume(_backgroundMusicVolume);
      await _timeRunningOutPlayer?.setVolume(_timeRunningOutVolume);
      print('Audio players initialized successfully');
    } catch (e) {
      print('Error initializing audio: $e');
    }
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _backgroundPlayer?.dispose();
    _timeRunningOutPlayer?.dispose();
    _gameController.markPlayerLeft();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400;
    final isMediumScreen = screenSize.width >= 400 && screenSize.width < 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () {
          if (_showVolumeSliders) {
            setState(() {
              _showVolumeSliders = false;
            });
          }
        },
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF7F53AC),
                    Color(0xFF647DEE),
                    Color(0xFF63E2FF)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Consumer<GameController>(
                  builder: (context, gameController, child) {
                    bool isLocalGame = !gameController.isOnline;
                    bool isMyTurn = isLocalGame
                        ? true
                        : gameController.currentPlayer == widget.localPlayerId;

                    if (!gameController.isSynced) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Synchronizing game state...'),
                          ],
                        ),
                      );
                    }

                    gameController.onError = (msg) {
                      if (!mounted) return;
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Colors.white.withOpacity(0.95),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          title: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.deepPurple, size: 28),
                              SizedBox(width: 8),
                              Text(
                                msg == "Turn skipped!" || msg == "Time's up! Your turn was skipped." || msg == "The other player skipped their turn."
                                    ? 'Turn Skipped'
                                    : 'Invalid Move',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple),
                              ),
                            ],
                          ),
                          content: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(msg, style: TextStyle(fontSize: 18)),
                          ),
                          actions: [
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.deepPurple,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                textStyle: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text('OK'),
                            ),
                          ],
                        ),
                      );
                    };

                    if (!gameController.wordsLoaded) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (gameController.isGameOver()) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _showGameOverDialog(context, gameController);
                      });
                    }

                    return Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 6.0 : 10.0),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 600),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Score Board
                              _buildScoreBoard(gameController, isSmallScreen),
                              SizedBox(height: isSmallScreen ? 6 : 10),

                              // Timer and Deck Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Expanded(
                                      child: _buildTimer(gameController, isSmallScreen)),
                                  SizedBox(width: isSmallScreen ? 6 : 8),
                                  Expanded(
                                      child: _buildDeck(gameController, isSmallScreen)),
                                ],
                              ),
                              SizedBox(height: isSmallScreen ? 6 : 10),

                              // Game Board
                              Card(
                                elevation: 8,
                                color: Colors.white.withOpacity(0.95),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18)),
                                child: Padding(
                                  padding: EdgeInsets.all(isSmallScreen ? 3.0 : 6.0),
                                  child: GameBoard(),
                                ),
                              ),

                              // Player Hand Area
                              SizedBox(height: isSmallScreen ? 6 : 10),
                              _buildPlayerHandArea(
                                  gameController, context, isSmallScreen),

                              // Action Buttons
                              SizedBox(height: isSmallScreen ? 8 : 14),
                              _buildActionButtons(
                                  gameController, isMyTurn, context, isSmallScreen),
                              SizedBox(height: isSmallScreen ? 6 : 10),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              bottom: 22,
              left: 22,
              child: FloatingActionButton.small(
                heroTag: 'homeBtn',
                backgroundColor: Colors.white.withOpacity(0.9),
                foregroundColor: Colors.deepPurple,
                elevation: 4,
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Icon(Icons.home, size: 20),
              ),
            ),
            // Debug audio button
            Positioned(
              bottom: 22,
              right: 22,
              child: FloatingActionButton.small(
                heroTag: 'audioBtn',
                backgroundColor: _backgroundMusicVolume > 0 || _timeRunningOutVolume > 0 ? Colors.green.withOpacity(0.9) : Colors.red.withOpacity(0.9),
                foregroundColor: Colors.white,
                elevation: 4,
                onPressed: () {
                  setState(() {
                    _showVolumeSliders = !_showVolumeSliders;
                  });
                },
                child: Icon(_backgroundMusicVolume > 0 || _timeRunningOutVolume > 0 ? Icons.volume_up : Icons.volume_off, size: 20),
              ),
            ),
            // Volume Sliders
            if (_showVolumeSliders)
              Positioned(
                bottom: 70,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildVolumeSliderColumn(
                        'Music',
                        Icons.music_note,
                        _backgroundMusicVolume,
                        (newVolume) {
                          setState(() {
                            _backgroundMusicVolume = newVolume;
                          });
                          _backgroundPlayer?.setVolume(newVolume);
                        },
                      ),
                      const SizedBox(width: 16),
                      _buildVolumeSliderColumn(
                        'Effects',
                        Icons.timer,
                        _timeRunningOutVolume,
                        (newVolume) {
                          setState(() {
                            _timeRunningOutVolume = newVolume;
                          });
                          _timeRunningOutPlayer?.setVolume(newVolume);
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBoard(GameController gameController, bool isSmallScreen) {
    final isPlayer1Leading =
        gameController.player1Score > gameController.player2Score;
    final isPlayer2Leading =
        gameController.player2Score > gameController.player1Score;
    return Card(
      color: Colors.white.withOpacity(0.92),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 6 : 8,
            horizontal: isSmallScreen ? 12 : 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      gameController.player1Name,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple[700],
                      ),
                    ),
                    if (gameController.player1QuadTurns > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.purple[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('x4',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ),
                      )
                    else if (gameController.player1DoubleTurns > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue[400],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('x2',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ),
                      ),
                  ],
                ),
                Text(
                  gameController.player1Score.toString(),
                  style: TextStyle(
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Turn',
                  style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14, color: Colors.grey),
                ),
                Text(
                  gameController.currentPlayer == 1
                      ? gameController.player1Name
                      : gameController.player2Name,
                  style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple),
                ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.isAiGame ? 'Computer' : gameController.player2Name,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.pink[700],
                      ),
                    ),
                    if (gameController.player2QuadTurns > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.purple[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('x4',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ),
                      )
                    else if (gameController.player2DoubleTurns > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue[400],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('x2',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ),
                      ),
                  ],
                ),
                Text(
                  gameController.player2Score.toString(),
                  style: TextStyle(
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimer(GameController gameController, bool isSmallScreen) {
    final remainingTime = gameController.remainingTime;
    final isLowTime = remainingTime <= 30;
    final isCriticalTime = remainingTime <= 10;
    
    // Play time running out sound for last 10 seconds
    if (isCriticalTime && !_isPlayingTimeRunningOut) {
      _playTimeRunningOutSound();
      _isPlayingTimeRunningOut = true;
    } else if (!isCriticalTime && _isPlayingTimeRunningOut) {
      _stopTimeRunningOutSound();
      _isPlayingTimeRunningOut = false;
    }
    
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: isCriticalTime ? 500 : 1000),
      tween: Tween(begin: 0.8, end: 1.1),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: isLowTime ? scale : 1.0,
          child: Card(
            color: isCriticalTime 
                ? Colors.red[100] 
                : isLowTime 
                    ? Colors.orange[100] 
                    : Colors.deepPurple[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 4 : 6,
            horizontal: isSmallScreen ? 8 : 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
                  AnimatedSwitcher(
                    duration: Duration(milliseconds: 300),
                    child: Icon(
                      isCriticalTime ? Icons.warning : Icons.timer,
                      key: ValueKey(isCriticalTime),
                      color: isCriticalTime 
                          ? Colors.red[700] 
                          : isLowTime 
                              ? Colors.orange[700] 
                              : Colors.deepPurple,
                      size: isSmallScreen ? 16 : 20,
                    ),
                  ),
            SizedBox(width: isSmallScreen ? 3 : 4),
            Text('Time: ',
                style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                          color: isCriticalTime 
                              ? Colors.red[900] 
                              : isLowTime 
                                  ? Colors.orange[900] 
                                  : Colors.deepPurple[900])),
                  AnimatedDefaultTextStyle(
                    duration: Duration(milliseconds: 300),
                style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: isCriticalTime 
                          ? Colors.red[700] 
                          : isLowTime 
                              ? Colors.orange[700] 
                              : Colors.deepPurple[700],
                    ),
                    child: Text('$remainingTime'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeck(GameController gameController, bool isSmallScreen) {
    return Card(
      color: Colors.cyan[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 4 : 6,
            horizontal: isSmallScreen ? 8 : 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.layers,
                color: Colors.cyan, size: isSmallScreen ? 16 : 20),
            SizedBox(width: isSmallScreen ? 3 : 4),
            Text('Deck: ',
                style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    color: Colors.cyan[900])),
            Text('${gameController.letterPool.length}',
                style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerHandArea(
      GameController gameController, BuildContext context, bool isSmallScreen) {
    bool isPlayer1sTurn = gameController.currentPlayer == 1;
    bool isLocalGame = !gameController.isOnline;
    bool isMyTurn = isLocalGame
        ? true
        : gameController.currentPlayer == widget.localPlayerId;
    final screenWidth = MediaQuery.of(context).size.width;

    double player1Opacity, player2Opacity;
    if (isMyTurn) {
      player1Opacity = isPlayer1sTurn ? 1.0 : 0.6;
      player2Opacity = isPlayer1sTurn ? 0.6 : 1.0;
    } else {
      player1Opacity = 0.6;
      player2Opacity = 0.6;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.isAiGame
              ? 'Computer\'s Hand'
              : (widget.localPlayerId == 2
                  ? 'Your Hand'
                  : "${gameController.player2Name}'s Hand"),
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isSmallScreen ? 4 : 6),
        Opacity(
          opacity: player2Opacity,
          child: _buildPlayerHand(gameController.player2Hand, 2, isMyTurn,
              screenWidth, isSmallScreen),
        ),
        SizedBox(height: isSmallScreen ? 8 : 12),
        Text(
          (widget.localPlayerId == 1
              ? 'Your Hand'
              : "${gameController.player1Name}'s Hand"),
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isSmallScreen ? 4 : 6),
        Opacity(
          opacity: player1Opacity,
          child: _buildPlayerHand(gameController.player1Hand, 1, isMyTurn,
              screenWidth, isSmallScreen),
        ),
      ],
    );
  }

  Widget _buildPlayerHand(List<Letter> hand, int handOwnerId, bool isMyTurn,
      double screenWidth, bool isSmallScreen) {
    bool isLocalGame =
        Provider.of<GameController>(context, listen: false).isOnline == false;
    bool canDrag = isLocalGame
        ? (handOwnerId ==
            Provider.of<GameController>(context, listen: false).currentPlayer)
        : (isMyTurn && (handOwnerId == widget.localPlayerId));

    return Center(
      child: DragTarget<DraggableLetter>(
        builder: (context, candidateData, rejectedData) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: hand.map((letter) {
                final letterTile = LetterTile(letter: letter);
                return Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 2.0 : 4.0),
                  child: canDrag
                      ? Draggable<DraggableLetter>(
                          data: DraggableLetter(
                              letter: letter,
                              origin: LetterOrigin.hand,
                              fromIndex: -1),
                          feedback: Material(
                            color: Colors.transparent,
                            elevation: 4.0,
                            child: letterTile,
                          ),
                          childWhenDragging: SizedBox(
                            width: 40,
                            height: 40,
                          ),
                          child: letterTile,
                        )
                      : letterTile,
                );
              }).toList(),
            ),
          );
        },
        onWillAccept: (data) {
          return isMyTurn && data?.origin == LetterOrigin.board;
        },
        onAccept: (draggableLetter) {
          final gameController =
              Provider.of<GameController>(context, listen: false);
          gameController.returnLetterToHand(draggableLetter);
        },
      ),
    );
  }

  void _showGameOverDialog(
      BuildContext context, GameController gameController) {
    String winner;
    if (gameController.player1Score > gameController.player2Score) {
      winner = gameController.player1Name;
    } else if (gameController.player2Score > gameController.player1Score) {
      winner = widget.isAiGame ? 'Computer' : gameController.player2Name;
    } else {
      winner = 'It\'s a tie!';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.deepPurple, size: 28),
              SizedBox(width: 8),
              Text('Game Over',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            ],
          ),
          content: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('$winner wins!', style: TextStyle(fontSize: 18)),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String _bonusLabel(BonusInfo? bonus) {
    if (bonus == null) return '';
    switch (bonus.type) {
      case BonusType.score:
        return bonus.scoreValue != null ? '+${bonus.scoreValue}' : 'Score';
      case BonusType.futureDouble:
        return '2x Next 2 Turns';
      case BonusType.futureQuad:
        return '4x Next Turn';
      case BonusType.extraMove:
        return 'Extra Move';
      // case BonusType.wordGame:
      //   return 'Word Game';
    }
  }

  String _bonusDescription(BonusInfo bonus) {
    switch (bonus.type) {
      case BonusType.score:
        return 'Score: +${bonus.scoreValue}';
      case BonusType.futureDouble:
        return 'X2 to the score of the next 2 turns';
      case BonusType.futureQuad:
        return 'X4 to the score of the next turn';
      case BonusType.extraMove:
        return 'Gives an extra move';
      // case BonusType.wordGame:
      //   return 'Word Game';
    }
  }

  // Show dialog to select which letter to replace
  void _showReplaceLetterDialog(BuildContext context, GameController gameController) {
    List<Letter> currentHand = gameController.currentPlayer == 1 
        ? gameController.player1Hand 
        : gameController.player2Hand;
    
    int currentScore = gameController.currentPlayer == 1 
        ? gameController.player1Score 
        : gameController.player2Score;

    int replacementCost = gameController.replacementCost;
    int replacementCount = gameController.replacementCount;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.swap_horiz, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Replace Letter', 
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select a letter to replace',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              SizedBox(height: 4),
              Text(
                'Cost: $replacementCost points (${replacementCount + 1}${_getOrdinalSuffix(replacementCount + 1)} replacement)',
                style: TextStyle(
                  fontSize: 14, 
                  color: Colors.orange[700],
                  fontWeight: FontWeight.bold
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Your score: $currentScore',
                style: TextStyle(
                  fontSize: 14, 
                  color: currentScore >= replacementCost ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold
                ),
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(currentHand.length, (index) {
                  final letter = currentHand[index];
                  final canAfford = currentScore >= replacementCost;
                  
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: canAfford ? () {
                        print('Letter tapped: ${letter.letter} at index $index'); // Debug
                        Navigator.of(dialogContext).pop();
                        final success = gameController.replaceLetterInHand(index);
                        print('Replace result: $success'); // Debug
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Letter replaced! -$replacementCost points'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      } : () {
                        print('Cannot afford replacement. Score: $currentScore, Cost: $replacementCost'); // Debug
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('You need at least $replacementCost points to replace a letter!'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: canAfford 
                              ? Colors.orange.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          border: Border.all(
                            color: canAfford 
                                ? Colors.orange 
                                : Colors.grey,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            letter.letter,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: canAfford 
                                  ? Colors.orange[800] 
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.grey,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Helper method to get ordinal suffix (1st, 2nd, 3rd, etc.)
  String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) return 'th';
    switch (number % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  Widget _buildActionButtons(GameController gameController, bool isMyTurn,
      BuildContext context, bool isSmallScreen) {
    return SizedBox(
      width: isSmallScreen ? 250 : 320,
      height: 44,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: isSmallScreen ? 140 : 180,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isMyTurn && gameController.placedThisTurn.isNotEmpty) ? Colors.deepPurple : Colors.grey,
                  foregroundColor: Colors.white,
                  textStyle:
                      const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                  minimumSize: const Size(0, 44),
                ),
                onPressed: (isMyTurn && gameController.placedThisTurn.isNotEmpty)
                    ? () async {
                        final wasMyTurn = isMyTurn;
                        final results =
                            await gameController.validateAndGetTurnResults();
                        if (results == null) {
                          // Show dialog asking if player wants to accept invalid words
                          final wordsData = gameController.board;
                          final placedThisTurn = gameController.placedThisTurn;
                          final scoreService = gameController.scoreService;
                          final validationService =
                              gameController.validationService;
                          Set<int> placedSet = placedThisTurn.toSet();
                          int wordScore(Map<String, dynamic> wordData) {
                            int score = 0;
                            final indices = wordData['indices'] as List<int>?;
                            if (indices != null) {
                              for (final idx in indices) {
                                final tile = gameController.board[idx];
                                if (tile != null && tile.letter != null) {
                                  score += tile.letter!.isWildcard
                                      ? 0
                                      : tile.letter!.score;
                                }
                              }
                            }
                            return score;
                          }

                          final wordList =
                              scoreService.extractWordsForPlacedTilesWithBonuses(
                            board: wordsData,
                            placedThisTurn: placedSet,
                          );
                          
                          // Check if there are any invalid words
                          final invalidWords = wordList
                              .where((w) => !validationService.isValidWord(w['word']))
                              .toList();
                          
                          if (invalidWords.isNotEmpty) {
                          if (!mounted) return;
                            final shouldAccept = await showDialog<bool>(
                            context: context,
                              barrierDismissible: false,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.white.withOpacity(0.95),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              title: Row(
                                children: [
                                    Icon(Icons.help_outline,
                                        color: Colors.orange, size: 28),
                                  SizedBox(width: 8),
                                    Text('Invalid Words Found',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.deepPurple)),
                                ],
                              ),
                              content: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      Text(
                                        'The following words are not in the dictionary:',
                                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                      ),
                                      SizedBox(height: 12),
                                      for (final wordData in invalidWords)
                                      Row(
                                        children: [
                                            Icon(Icons.close, color: Colors.red, size: 20),
                                          SizedBox(width: 8),
                                            Text(
                                              wordData['word'],
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red[700]),
                                            ),
                                          ],
                                        ),
                                      SizedBox(height: 16),
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.orange[200]!),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Would you like to accept these words anyway, or skip your turn?',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.orange[800],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: Colors.grey[600],
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12)),
                                      textStyle: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: Text('Skip Turn'),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: Colors.orange[600],
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12)),
                                      textStyle: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: Text('Accept Words'),
                                  ),
                                ],
                              ),
                            );
                            
                            if (shouldAccept == true) {
                              // Accept invalid words and continue with turn
                              final acceptedWords = invalidWords.map((w) => w['word'] as String).toList();
                              await gameController.endTurn(skipValidation: true, acceptedInvalidWords: acceptedWords);
                            } else {
                              // Skip turn
                              gameController.skipTurn();
                            }
                            return;
                          }
                          
                          // If no invalid words, just show the regular invalid move dialog
                          if (!mounted) return;
                          await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.white.withOpacity(0.95),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              title: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.deepPurple, size: 28),
                                  SizedBox(width: 8),
                                  Text('Invalid Move',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.deepPurple)),
                                ],
                              ),
                              content: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'Your move is invalid. Please check your word placement.',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.deepPurple,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    textStyle: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text('OK'),
                                ),
                              ],
                            ),
                          );
                          return;
                        }

                        // Get all words and their validation
                        final wordsData = gameController.board;
                        final placedThisTurn = gameController.placedThisTurn;
                        final scoreService = gameController.scoreService;
                        final validationService =
                            gameController.validationService;
                        Set<int> placedSet = placedThisTurn.toSet();
                        int wordScore(Map<String, dynamic> wordData) {
                          int score = 0;
                          final indices = wordData['indices'] as List<int>?;
                          if (indices != null) {
                            for (final idx in indices) {
                              final tile = gameController.board[idx];
                              if (tile != null && tile.letter != null) {
                                score += tile.letter!.isWildcard
                                    ? 0
                                    : tile.letter!.score;
                              }
                            }
                          }
                          return score;
                        }

                        final wordList =
                            scoreService.extractWordsForPlacedTilesWithBonuses(
                          board: wordsData,
                          placedThisTurn: placedSet,
                        );

                        // Calculate total score and bonus multiplier
                        int baseScore = 0;
                        for (final wordData in wordList) {
                          if (validationService.isValidWord(wordData['word'])) {
                            baseScore += wordScore(wordData);
                          }
                        }
                        int multiplier = 1;
                        if (gameController.currentPlayer == 1 && gameController.player1QuadTurns > 0) {
                          multiplier = 4;
                        } else if (gameController.currentPlayer == 1 && gameController.player1DoubleTurns > 0) {
                          multiplier = 2;
                        } else if (gameController.currentPlayer == 2 && gameController.player2QuadTurns > 0) {
                          multiplier = 4;
                        } else if (gameController.currentPlayer == 2 && gameController.player2DoubleTurns > 0) {
                          multiplier = 2;
                        }
                        int totalScore = baseScore * multiplier;

                        // Show bonus dialog if any bonus was collected
                        final collectedBonuses = wordList
                            .where((w) =>
                                w['bonus'] != null &&
                                validationService.isValidWord(w['word']))
                            .map((w) => w['bonus'] as BonusInfo)
                            .toList();
                        if (collectedBonuses.isNotEmpty) {
                          for (final bonus in collectedBonuses) {
                            if (!mounted) return;
                            await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                content: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        bonus.color.withOpacity(0.95),
                                        bonus.color.withOpacity(0.8),
                                        bonus.color.withOpacity(0.7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: bonus.color.withOpacity(0.4),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                        spreadRadius: 2,
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Header with icon and title
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                              width: 48,
                                              height: 48,
                                      decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.25),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: Colors.white.withOpacity(0.3),
                                                  width: 2,
                                                ),
                                        boxShadow: [
                                          BoxShadow(
                                                    color: Colors.black.withOpacity(0.1),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Image.asset(
                                          bonus.assetPath,
                                          width: 32,
                                          height: 32,
                                        ),
                                      ),
                                    ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Text(
                                      'Bonus Collected!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                                  fontSize: 24,
                                                  shadows: [
                                                    Shadow(
                                                      color: Colors.black.withOpacity(0.3),
                                                      offset: const Offset(0, 2),
                                                      blurRadius: 4,
                                                    ),
                                                  ],
                                                ),
                                      ),
                                    ),
                                  ],
                                ),
                                        const SizedBox(height: 20),
                                        
                                        // Bonus description
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.2),
                                              width: 1,
                                            ),
                                            ),
                                  child: Text(
                                    _bonusDescription(bonus),
                                    style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  shadows: [
                                                    Shadow(
                                                      color: Colors.black26,
                                                      offset: Offset(0, 1),
                                                      blurRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                                textAlign: TextAlign.center,
                                            ),
                                        ),
                                        const SizedBox(height: 24),
                                        
                                        // OK button
                                        SizedBox(
                                          width: double.infinity,
                                          height: 48,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white.withOpacity(0.25),
                                      foregroundColor: Colors.white,
                                              elevation: 0,
                                      shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                                side: BorderSide(
                                                  color: Colors.white.withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                      textStyle: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                    ),
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('OK'),
                                          ),
                                  ),
                                ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                        }

                        final allValid = wordList.isNotEmpty &&
                            wordList.every(
                                (w) => validationService.isValidWord(w['word']));
                        if (!mounted) return;
                        await gameController.endTurn();
                      }
                    : null,
                icon: const Icon(Icons.check_circle_outline, size: 30),
                label: const Text('End Turn'),
              ),
            ),
          ),
          // Replace Letter Button (Left side)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: 52,
              height: 44,
              child: IconButton(
                icon: const Icon(Icons.swap_horiz, color: Colors.white, size: 24),
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(
                    isMyTurn ? Colors.orange : Colors.grey
                  ),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  minimumSize: MaterialStateProperty.all<Size>(const Size(52, 44)),
                ),
                tooltip: 'Replace Letter (${gameController.replacementCost} points)',
                onPressed: isMyTurn
                    ? () {
                        _showReplaceLetterDialog(context, gameController);
                      }
                    : null,
              ),
            ),
          ),
          // Skip Turn Button (Right side)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: 52,
              height: 44,
              child: IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white, size: 28),
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(
                    isMyTurn ? Colors.red : Colors.grey
                  ),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  minimumSize: MaterialStateProperty.all<Size>(const Size(52, 44)),
                ),
                tooltip: 'Skip Turn',
                onPressed: isMyTurn
                    ? () {
                        final gameController =
                            Provider.of<GameController>(context, listen: false);
                        gameController.skipTurn();
                      }
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTurnResultsDialog(Map<String, dynamic> turnResults) {
    final playerName = turnResults['playerName'] as String;
    final playerId = turnResults['playerId'] as int;
    final words = turnResults['words'] as List<dynamic>;
    final totalScore = turnResults['totalScore'] as int;
    final baseScore = turnResults['baseScore'] as int;
    final multiplier = turnResults['multiplier'] as int;
    
    // Check if this is the current player's score or the other player's
    final isMyScore = playerId == widget.localPlayerId;
    
    // Different styles based on whose score it is
    final titleIcon = isMyScore ? Icons.celebration : Icons.info_outline;
    final titleIconColor = isMyScore ? Colors.orange : Colors.blue;
    final titleText = isMyScore ? 'You Scored!' : '$playerName Scored';
    final backgroundColor = isMyScore ? Colors.orange[50] : Colors.blue[50];
    final borderColor = isMyScore ? Colors.orange[200] : Colors.blue[200];
    final textColor = isMyScore ? Colors.orange[700] : Colors.blue[700];
    final scoreColor = isMyScore ? Colors.green[700] : Colors.black;
    final encouragementText = isMyScore ? 'Amazing work!' : 'Nice play!';
    final encouragementIcon = isMyScore ? Icons.emoji_events : Icons.thumb_up;

    showDialog(
                          context: context,
      barrierDismissible: false,
                          builder: (context) => AlertDialog(
                            backgroundColor: Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: Row(
                              children: [
            Icon(titleIcon, color: titleIconColor, size: 28),
                                SizedBox(width: 8),
            Text(titleText,
                                    style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                              ],
                            ),
                            content: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
              if (words.isNotEmpty) ...[
                Text('Words Created:', 
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                for (final wordData in words)
                                    Row(
                                      children: [
                                        Text(wordData['word'],
                                            style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                                        SizedBox(width: 8),
                      if (wordData['isValid']) ...[
                        if (isMyScore && wordData['wasAccepted'] == true)
                          Icon(Icons.star, color: Colors.amber, size: 20)
                        else if (isMyScore)
                          Icon(Icons.star, color: Colors.amber, size: 20),
                        if (isMyScore) SizedBox(width: 8),
                        Text(
                          '+${wordData['score']}',
                          style: TextStyle(
                              fontSize: 16, color: scoreColor, fontWeight: FontWeight.bold),
                        ),
                        if (isMyScore && wordData['wasAccepted'] == true) ...[
                          SizedBox(width: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber[300]!),
                            ),
                            child: Text(
                              'Accepted',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.amber[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ] else ...[
                        Icon(Icons.close, color: Colors.red[400], size: 20),
                                        SizedBox(width: 8),
                                          Text(
                          'Invalid',
                                            style: TextStyle(
                              fontSize: 14, color: Colors.red[400], fontStyle: FontStyle.italic),
                                          ),
                      ],
                                      ],
                                    ),
                SizedBox(height: 12),
                                  Divider(),
              ],
                                  Row(
                                    children: [
                      if (isMyScore) ...[
                        Icon(Icons.trending_up, color: scoreColor, size: 20),
                        SizedBox(width: 8),
                      ],
                  Text('Total Points:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      SizedBox(width: 8),
                                      if (multiplier > 1)
                    Text('$baseScore × $multiplier = $totalScore',
                                            style: TextStyle(
                            fontSize: 18,
                            color: scoreColor,
                                                fontWeight: FontWeight.bold)),
                                      if (multiplier == 1)
                                        Text('$totalScore',
                                            style: TextStyle(
                            fontSize: 18,
                            color: scoreColor,
                                                fontWeight: FontWeight.bold)),
                                    ],
                                  ),
              if (isMyScore) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor!),
                  ),
                  child: Row(
                    children: [
                      Icon(encouragementIcon, color: textColor, size: 16),
                      SizedBox(width: 4),
                      Text(
                        encouragementText,
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
              backgroundColor: isMyScore ? Colors.orange[600] : Colors.blue[600],
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
              textStyle: TextStyle(fontWeight: FontWeight.bold),
                                ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Continue'),
                              ),
                            ],
                          ),
                        );
                      }

  void _startBackgroundMusic() async {
    try {
      print('Starting background music...');
      if (_backgroundPlayer != null) {
        await _backgroundPlayer!.play(AssetSource('sounds/bonusBackGroundMusic.mp3'));
        await _backgroundPlayer!.setReleaseMode(ReleaseMode.loop);
        await _backgroundPlayer!.setVolume(_backgroundMusicVolume);
        print('Background music started successfully');
      } else {
        print('Background player is null');
      }
    } catch (e) {
      print('Could not play background music: $e');
    }
  }

  void _pauseBackgroundMusic() async {
    try {
      await _backgroundPlayer?.pause();
    } catch (e) {
      print('Could not pause background music: $e');
    }
  }

  void _resumeBackgroundMusic() async {
    try {
      await _backgroundPlayer?.resume();
    } catch (e) {
      print('Could not resume background music: $e');
    }
  }

  void _playTimeRunningOutSound() async {
    try {
      print('Playing time running out sound...');
      if (_timeRunningOutPlayer != null) {
        await _timeRunningOutPlayer!.play(AssetSource('sounds/timeRunningOut.mp3'));
        print('Time running out sound played successfully');
      } else {
        print('Time running out player is null');
      }
    } catch (e) {
      print('Could not play time running out sound: $e');
    }
  }

  void _stopTimeRunningOutSound() async {
    if (_timeRunningOutPlayer != null) {
      try {
        await _timeRunningOutPlayer!.stop();
      } catch (e) {
        print('Could not stop time running out sound: $e');
      }
    }
  }

  Widget _buildVolumeSliderColumn(String title, IconData icon, double volume,
      ValueChanged<double> onChanged) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.deepPurple),
        const SizedBox(height: 4),
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: volume,
              onChanged: onChanged,
              activeColor: Colors.deepPurple,
              inactiveColor: Colors.deepPurple[100],
            ),
          ),
        ),
      ],
    );
  }

  void _startUITimer() {
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }
}
