import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../magnet_walker_game.dart';

enum ObjectType { coin, bomb }

class GameObject extends CircleComponent
    with HasGameReference<MagnetWalkerGame> {
  final ObjectType type;
  final int level;
  Vector2 velocity = Vector2.zero();
  bool isMagnetized = false;
  bool collected = false;

  late Paint objectPaint;
  late Paint glowPaint;

  GameObject({
    required super.position,
    required this.type,
    required this.level,
  }) : super(
          radius: type == ObjectType.coin ? 8 : 12,
        );

  @override
  Future<void> onLoad() async {
    velocity.y = 50 + level * 10.0;

    if (type == ObjectType.coin) {
      objectPaint = Paint()..color = Colors.amber;
      glowPaint = Paint()
        ..color = Colors.amber.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    } else {
      objectPaint = Paint()..color = Colors.red;
      glowPaint = Paint()
        ..color = Colors.red.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    }
  }

  @override
  void update(double dt) {
    if (collected) return;

    position += velocity * dt;

    // Check collision with player
    final player = game.player;
    if (position.distanceTo(player.position) < radius + player.radius) {
      collected = true;
      game.collectObject(this);
    }

    // Remove if off screen - use camera size
    final gameSize =
        game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);
    if (position.y > gameSize.y + 50) {
      removeFromParent();
    }

    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (collected) return;

    // Draw glow effect if magnetized
    if (isMagnetized) {
      canvas.drawCircle(Offset.zero, radius + 5, glowPaint);
    }

    // Draw main object
    canvas.drawCircle(Offset.zero, radius, objectPaint);

    // Draw border
    final borderPaint = Paint()
      ..color = type == ObjectType.coin ? Colors.orange : Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(Offset.zero, radius, borderPaint);

    // Draw symbol
    if (type == ObjectType.bomb) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: '!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
    }
  }
}
