import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../magnet_walker_game.dart';

class Background extends Component with HasGameReference<MagnetWalkerGame> {
  @override
  void render(Canvas canvas) {
    // final game = gameReference;
    // if (game == null) return;
    final rect = Rect.fromLTWH(0, 0, game.size.x, game.size.y);
    final gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF87CEEB),
        Color(0xFF98FB98),
      ],
    );
    
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }
}
