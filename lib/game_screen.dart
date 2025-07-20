import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'magnet_walker_game.dart';

class GameScreen extends StatefulWidget {
  final bool musicEnabled;
  final bool sfxEnabled;
  final bool menuMusicEnabled;

  const GameScreen({
    super.key,
    required this.musicEnabled,
    required this.sfxEnabled,
    required this.menuMusicEnabled,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late MagnetWalkerGame game;

  @override
  void initState() {
    super.initState();
    game = MagnetWalkerGame();
    FlameAudio.bgm.stop();
    game.setExitCallback(() {
      FlameAudio.bgm.stop();
      if (widget.menuMusicEnabled) {
        FlameAudio.bgm.play('menu_music.mp3');
      }
      Navigator.pushReplacementNamed(context, '/');
    });

    game.setSfxEnabled(widget.sfxEnabled);

    if (widget.musicEnabled) {
      FlameAudio.bgm.play('game_music.mp3');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: GameWidget(game: game)),
    );
  }

  @override
  void dispose() {
    //FlameAudio.bgm.stop();
    super.dispose();
  }
}
