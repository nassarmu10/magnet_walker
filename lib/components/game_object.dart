import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../magnet_walker_game.dart';
import '../level_types.dart';
import 'dart:math' as math;

enum ObjectType { coin, bomb }

class GameObject extends CircleComponent
    with HasGameReference<MagnetWalkerGame> {
  final ObjectType type;
  final int level;
  final LevelType levelType;
  Vector2 velocity = Vector2.zero();
  bool isMagnetized = false;
  bool collected = false;
  double pulseTime = 0.0; // For pulsing effect in survival mode

  late Paint objectPaint;
  late Paint glowPaint;

  GameObject({
    required super.position,
    required this.type,
    required this.level,
    required this.levelType,
  }) : super(
          radius: type == ObjectType.coin ? 8 : 12,
        );

  @override
  Future<void> onLoad() async {
    // Set velocity based on level type
    if (levelType == LevelType.gravity) {
      // Base speed increases with level
      final baseSpeed = 50.0;
      final levelSpeedMultiplier = 1.0 + (level * 0.3); // 30% faster per level
      velocity.y = baseSpeed * levelSpeedMultiplier;
    } else if (levelType == LevelType.survival) {
      // Objects move toward player
      final gameSize =
          game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);
      final playerPos = game.player.position;
      final direction = (playerPos - position)..normalize();
      final speed = 80.0 + (level * 10.0); // Speed increases with level
      velocity = direction * speed;
    }

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

    // Update pulse time for survival mode
    if (levelType == LevelType.survival) {
      pulseTime += dt * 3.0; // Pulse speed
    }

    position += velocity * dt;

    // Check collision with player based on level type
    final player = game.player;
    if (position.distanceTo(player.position) < radius + player.radius) {
      if (levelType == LevelType.gravity) {
        // In gravity mode, all objects collide with player
        collected = true;
        game.collectObject(this);
      } else if (levelType == LevelType.survival) {
        // In survival mode, only bombs collide with player (coins are clicked)
        if (type == ObjectType.bomb) {
          collected = true;
          game.collectObject(this);
        }
        // Coins in survival mode don't collide, they must be clicked
      }
    }

    // Remove if off screen (different logic per level type)
    final gameSize =
        game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);
    if (levelType == LevelType.gravity) {
      // Remove if below screen
      if (position.y > gameSize.y + 50) {
        removeFromParent();
      }
    } else if (levelType == LevelType.survival) {
      // Remove if too far from player or off screen
      final distanceToPlayer = position.distanceTo(player.position);
      if (distanceToPlayer > gameSize.x * 1.5 ||
          position.x < -50 ||
          position.x > gameSize.x + 50 ||
          position.y < -50 ||
          position.y > gameSize.y + 50) {
        removeFromParent();
      }
    }

    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (collected) return;

    // Calculate pulse effect for survival mode
    double pulseScale = 1.0;
    if (levelType == LevelType.survival) {
      pulseScale = 1.0 + 0.1 * math.sin(pulseTime); // 10% size variation
    }

    // Draw glow effect if magnetized or in survival mode
    if (isMagnetized || levelType == LevelType.survival) {
      final pulseGlowPaint = Paint()
        ..color = (type == ObjectType.coin ? Colors.amber : Colors.red)
            .withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(Offset.zero, radius * pulseScale + 5, pulseGlowPaint);
    }

    // Draw main object with pulse effect
    final scaledRadius = radius * pulseScale;
    canvas.drawCircle(Offset.zero, scaledRadius, objectPaint);

    // Draw border
    final borderPaint = Paint()
      ..color = type == ObjectType.coin ? Colors.orange : Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(Offset.zero, scaledRadius, borderPaint);

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
