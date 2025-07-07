import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'package:magnet_walker/managers/ad_manager.dart';
import 'magnet_walker_game.dart';
import 'menu_screen.dart';
import 'skins/skin_store_screen.dart';
import 'skins/skin_manager.dart';

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
  late SkinManager skinManager;

  @override
  void initState() {
    super.initState();
    game = MagnetWalkerGame();
    skinManager = SkinManager();
    _initializeSkinManager();
    // Lock to portrait mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _initializeSkinManager() async {
    await skinManager.initialize();
    setState(() {}); // Refresh UI after skin manager is ready
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

  void _showSkins() async {
    // Ensure ads are initialized before showing skin store
    if (!AdManager.isAdsInitialized) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Initializing ads...'),
            ],
          ),
        ),
      );
      
      // Initialize ads
      await AdManager.initialize();
      await AdManager.loadRewardedAd();
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
    
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SkinStoreScreen(
            skinManager: skinManager,
            currentLevel: _showGame ? game.waveManager.level : 1,
            onSkinChanged: () {
              // Update game skin if game is loaded
              if (_showGame) {
                game.onSkinChanged();
              }
            },
          ),
        ),
      );
    }
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
        onSkins: _showSkins,
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
