import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../magnet_walker_game.dart';

class GameParticle extends CircleComponent
    with HasGameReference<MagnetWalkerGame> {
  Vector2 velocity;
  Color color;
  double life = 1.0;
  final double maxLife = 1.0;
  late Paint particlePaint;

  GameParticle({
    required super.position,
    required this.velocity,
    required this.color,
  }) : super(radius: 3);

  @override
  Future<void> onLoad() async {
    particlePaint = Paint()..color = color;
  }

  @override
  void update(double dt) {
    position += velocity * dt;
    velocity *= 0.95; // Friction
    life -= dt * 2;

    // Ensure life doesn't go below 0
    if (life <= 0) {
      life = 0;
      removeFromParent();
    }

    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    // Ensure opacity is between 0 and 1
    final opacity = (life / maxLife).clamp(0.0, 1.0);
    particlePaint.color = color.withOpacity(opacity);
    canvas.drawCircle(Offset.zero, radius, particlePaint);
  }
}
