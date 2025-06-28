import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../magnet_walker_game.dart';
import 'game_object.dart';

class Player extends CircleComponent with HasGameRef<MagnetWalkerGame> {
  double magnetRadius = 80.0;
  late Paint magnetFieldPaint;
  late Paint playerPaint;

  Player({required super.position})
      : super(
          radius: 15,
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    // Set size for collision detection
    size = Vector2.all(radius * 2);

    magnetFieldPaint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    playerPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
  }

  @override
  void render(Canvas canvas) {
    // Draw magnetic field
    canvas.drawCircle(
      Offset.zero,
      magnetRadius,
      magnetFieldPaint,
    );

    // Draw player with glow effect
    final glowPaint = Paint()
      ..color = Colors.blue.withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawCircle(Offset.zero, radius, glowPaint);
    canvas.drawCircle(Offset.zero, radius, playerPaint);

    // Draw player border
    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(Offset.zero, radius, borderPaint);
  }

  void moveHorizontally(double deltaX) {
    final gameSize =
        game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);
    position.x = (position.x + deltaX).clamp(30.0, gameSize.x - 30);
  }

  void applyMagneticForce(GameObject obj, double dt) {
    final distance = position.distanceTo(obj.position);

    if (distance < magnetRadius && distance > 0) {
      final direction = (position - obj.position)..normalize();
      final force = 100 * (1 - distance / magnetRadius);

      obj.velocity += direction * force * dt;
      obj.isMagnetized = true;
    } else {
      obj.isMagnetized = false;
    }
  }

  void upgradeMagnet(int level) {
    magnetRadius = math.min(120.0, 80.0 + level * 3);
  }

  void reset() {
    final gameSize =
        game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);
    position = Vector2(gameSize.x / 2, gameSize.y - 117);
    magnetRadius = 80.0;
  }
}
