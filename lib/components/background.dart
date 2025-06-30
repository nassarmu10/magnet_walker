import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../magnet_walker_game.dart';

class Background extends Component with HasGameReference<MagnetWalkerGame> {
  Sprite? _bgSprite;
  double _offsetY = 0.0;
  final double _speed = 30.0; // pixels per second

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Load the background image as a sprite
    final image = await game.images.load('background-2.jpg');
    _bgSprite = Sprite(image);
  }

  @override
  void update(double dt) {
    if (_bgSprite != null) {
      _offsetY += _speed * dt;
      // Loop the background
      final gameSize = game.size;
      final imgWidth = _bgSprite!.image.width.toDouble();
      final imgHeight = _bgSprite!.image.height.toDouble();
      final scale = (gameSize.x / imgWidth > gameSize.y / imgHeight)
          ? gameSize.x / imgWidth
          : gameSize.y / imgHeight;
      final drawHeight = imgHeight * scale;
      if (_offsetY > drawHeight) {
        _offsetY -= drawHeight;
      }
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (_bgSprite != null) {
      final gameSize = game.size;
      final imgWidth = _bgSprite!.image.width.toDouble();
      final imgHeight = _bgSprite!.image.height.toDouble();
      final scale = (gameSize.x / imgWidth > gameSize.y / imgHeight)
          ? gameSize.x / imgWidth
          : gameSize.y / imgHeight;
      final drawWidth = imgWidth * scale;
      final drawHeight = imgHeight * scale;

      // Draw two images for seamless vertical scrolling
      for (int i = 0; i < 2; i++) {
        final offsetY = _offsetY - i * drawHeight;
        canvas.save();
        canvas.translate(0, offsetY);
        _bgSprite!.render(
          canvas,
          size: Vector2(drawWidth, drawHeight),
          anchor: Anchor.topLeft,
        );
        canvas.restore();
      }
    }
  }
}
