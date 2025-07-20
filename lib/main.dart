import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'menu_screen.dart';
import 'settings_screen.dart';
import 'skins/skin_store_screen.dart';
import 'skins/skin_manager.dart';
import 'game_screen.dart';
import 'managers/ad_manager.dart';

void main() {
  runApp(const MagnetWalkerApp());
}

class MagnetWalkerApp extends StatefulWidget {
  const MagnetWalkerApp({super.key});

  @override
  State<MagnetWalkerApp> createState() => _MagnetWalkerAppState();
}

class _MagnetWalkerAppState extends State<MagnetWalkerApp> {
  late SkinManager skinManager;
  bool _musicEnabled = true;
  bool _menuMusicEnabled = true;
  bool _sfxEnabled = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _loadSettings();
    skinManager = SkinManager();
    skinManager.initialize();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _musicEnabled = prefs.getBool('music_enabled') ?? true;
      _menuMusicEnabled = prefs.getBool('menu_music_enabled') ?? true;
      _sfxEnabled = prefs.getBool('sfx_enabled') ?? true;
    });

    if (_menuMusicEnabled) {
      FlameAudio.bgm.play('menu_music.mp3');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Magnet Walker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Arial'),
      routes: {
        '/': (context) => MenuScreen(
              onSettings: () => Navigator.pushNamed(context, '/settings'),
              onPlay: () => Navigator.pushReplacementNamed(context, '/game'),
              onSkins: () async {
                if (!AdManager.isAdsInitialized) {
                  await AdManager.initialize();
                  await AdManager.loadRewardedAd();
                }
                Navigator.pushNamed(context, '/skins');
              },
            ),
        '/game': (context) => GameScreen(
              musicEnabled: _musicEnabled,
              sfxEnabled: _sfxEnabled,
              menuMusicEnabled: _menuMusicEnabled,
            ),
        '/settings': (context) => SettingsScreen(
              musicEnabled: _musicEnabled,
              menuMusicEnabled: _menuMusicEnabled,
              sfxEnabled: _sfxEnabled,
              onMusicChanged: (val) => setState(() => _musicEnabled = val),
              onMenuMusicChanged: (val) =>
                  setState(() => _menuMusicEnabled = val),
              onSfxChanged: (val) => setState(() => _sfxEnabled = val),
              onBack: () => Navigator.pop(context),
            ),
        '/skins': (context) => SkinStoreScreen(
              skinManager: skinManager,
              currentLevel: 1,
              onSkinChanged: () {}, // You can access Game here if needed
            ),
      },
    );
  }

  @override
  void dispose() {
    FlameAudio.bgm.stop();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }
}
