import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'package:magnet_walker/managers/ad_manager.dart';
import 'magnet_walker_game.dart';
import 'menu_screen.dart';
import 'skins/skin_store_screen.dart';
import 'skins/skin_manager.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_screen.dart';

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
  bool _showSettings = false;
  bool _musicEnabled = true;
  bool _menuMusicEnabled = true;
  bool _sfxEnabled = true;

  @override
  void initState() {
    super.initState();
    game = MagnetWalkerGame();
    skinManager = SkinManager();
    _initializeSkinManager();
    _loadSettings();
    // Lock to portrait mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    // Play menu music if enabled
    if (_menuMusicEnabled) {
      FlameAudio.bgm.play('menu_music.mp3');
    }
  }

  Future<void> _initializeSkinManager() async {
    await skinManager.initialize();
    setState(() {}); // Refresh UI after skin manager is ready
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _musicEnabled = prefs.getBool('music_enabled') ?? true;
      _menuMusicEnabled = prefs.getBool('menu_music_enabled') ?? true;
      _sfxEnabled = prefs.getBool('sfx_enabled') ?? true;
    });
  }

  void _startGame() {
    setState(() {
      _showGame = true;
      // Stop menu music
      FlameAudio.bgm.stop();
      // Play game music only if enabled
      if (_musicEnabled) {
        FlameAudio.bgm.play('game_music.mp3');
      }
    });
    // Set initial SFX setting in the game
    game.setSfxEnabled(_sfxEnabled);
  }

  void _returnToMenu() {
    setState(() {
      _showGame = false;
      // Stop game music and play menu music if enabled
      FlameAudio.bgm.stop();
      if (_menuMusicEnabled) {
        FlameAudio.bgm.play('menu_music.mp3');
      }
    });
  }

  void _showSettingsScreen() {
    setState(() {
      _showSettings = true;
    });
  }

  void _hideSettingsScreen() {
    setState(() {
      _showSettings = false;
    });
  }

  void _onMusicChanged(bool enabled) {
    setState(() {
      _musicEnabled = enabled;
    });
    // If game is currently running and music is disabled, stop game music
    if (_showGame) {
      if (enabled) {
        FlameAudio.bgm.play('game_music.mp3');
      } else {
        FlameAudio.bgm.stop();
      }
    }
  }

  void _onMenuMusicChanged(bool enabled) {
    setState(() {
      _menuMusicEnabled = enabled;
    });
    // If we're in the menu, start/stop menu music immediately
    if (!_showGame) {
      if (enabled) {
        FlameAudio.bgm.play('menu_music.mp3');
      } else {
        FlameAudio.bgm.stop();
      }
    }
  }

  void _onSfxChanged(bool enabled) {
    setState(() {
      _sfxEnabled = enabled;
    });
    // Update game SFX setting if game is running
    if (_showGame) {
      game.setSfxEnabled(enabled);
    }
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
        floatingActionButton: FloatingActionButton(
          onPressed: _returnToMenu,
          child: const Icon(Icons.home),
        ),
      );
    } else if (_showSettings) {
      return SettingsScreen(
        musicEnabled: _musicEnabled,
        menuMusicEnabled: _menuMusicEnabled,
        sfxEnabled: _sfxEnabled,
        onMusicChanged: _onMusicChanged,
        onMenuMusicChanged: _onMenuMusicChanged,
        onSfxChanged: _onSfxChanged,
        onBack: _hideSettingsScreen,
      );
    } else {
      return MenuScreen(
        onPlay: _startGame,
        onSettings: _showSettingsScreen,
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
