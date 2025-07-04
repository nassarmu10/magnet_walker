import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'magnet_walker_game.dart';
import 'menu_screen.dart';

void main() {
  runApp(const MagnetWalkerApp());
}

class MagnetWalkerApp extends StatelessWidget {
  const MagnetWalkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Magnet Walker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Arial',
      ),
      home: const MainMenuWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainMenuWrapper extends StatefulWidget {
  const MainMenuWrapper({super.key});

  @override
  State<MainMenuWrapper> createState() => _MainMenuWrapperState();
}

class _MainMenuWrapperState extends State<MainMenuWrapper> {
  bool _showGame = false;
  late MagnetWalkerGame game;

  @override
  void initState() {
    super.initState();
    game = MagnetWalkerGame();
    // Lock to portrait mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  void _startGame() {
    setState(() {
      _showGame = true;
    });
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: const Text('Settings screen coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showGame) {
      return Scaffold(
        body: Container(
          color: Colors.black,
          child: SafeArea(
            child: GameWidget(game: game),
          ),
        ),
      );
    } else {
      return MenuScreen(
        onPlay: _startGame,
        onSettings: _showSettings,
      );
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }
}
