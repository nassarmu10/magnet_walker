import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../magnet_walker_game.dart';

class Background extends Component with HasGameReference<MagnetWalkerGame> {
  Sprite? _bgSprite;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Load the background image as a sprite
    final image = await game.images.load('background.jpg');
    _bgSprite = Sprite(image);
  }

  @override
  void render(Canvas canvas) {
    if (_bgSprite != null && _bgSprite!.image != null) {
      final gameSize = game.size;
      final imgWidth = _bgSprite!.image.width.toDouble();
      final imgHeight = _bgSprite!.image.height.toDouble();
      final scale = (gameSize.x / imgWidth > gameSize.y / imgHeight)
          ? gameSize.x / imgWidth
          : gameSize.y / imgHeight;
      final drawWidth = imgWidth * scale;
      final drawHeight = imgHeight * scale;
      final offsetX = (gameSize.x - drawWidth) / 2;
      final offsetY = (gameSize.y - drawHeight) / 2;
      canvas.save();
      canvas.translate(offsetX, offsetY);
      _bgSprite!.render(
        canvas,
        size: Vector2(drawWidth, drawHeight),
        anchor: Anchor.topLeft,
      );
      canvas.restore();
    }
  }
}
