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
  SpriteComponent? bombSpriteComponent; // For rocket image

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
    // Load rocket sprite for bombs
    if (type == ObjectType.bomb) {
      try {
        print('Loading rocket image for bomb...');
        // Randomly choose between rocket.png and rocket-2.png
        final rocketImages = ['rocket.png', 'rocket-2.png'];
        final chosen =
            (math.Random().nextBool()) ? rocketImages[0] : rocketImages[1];
        final bombSprite = Sprite(game.images.fromCache(chosen));
        print('Rocket sprite loaded successfully: $chosen');
        bombSpriteComponent = SpriteComponent(
          sprite: bombSprite,
          size: Vector2.all(radius * 4), // Make rocket 4x bigger (was 2x)
          anchor: Anchor.center, // Ensure it's centered
        );
        print('Adding bomb sprite component');
        add(bombSpriteComponent!);
        print('Bomb sprite component added successfully');
      } catch (e) {
        print('Could not load rocket image: $e');
        print('Stack trace: ${StackTrace.current}');
        // Fall back to default bomb rendering
      }
    }

    // Set velocity based on level type
    if (levelType == LevelType.gravity) {
      // Base speed increases with level
      final baseSpeed = 5.0;
      final levelSpeedMultiplier = 1.0 + (level * 0.3); // 30% faster per level
      velocity.y = baseSpeed * levelSpeedMultiplier;
    } else if (levelType == LevelType.survival) {
      // Objects move toward player
      final gameSize =
          game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);
      final playerPos = game.player.position;
      final direction = (playerPos - position)..normalize();
      final speed = 1.0 + (level * 5.0); // Speed increases with level
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

    // Apply pulse effect to bomb sprite component and rotate toward player
    if (type == ObjectType.bomb && bombSpriteComponent != null) {
      double pulseScale = 1.0;
      if (levelType == LevelType.survival) {
        pulseScale = 1.0 + 0.1 * math.sin(pulseTime); // 10% size variation
      }
      bombSpriteComponent!.size =
          Vector2.all(radius * 4 * pulseScale); // Use 4x scaling

      // Calculate angle to point toward player
      final player = game.player;
      final direction = (player.position - position);
      final angle = math.atan2(direction.y, direction.x);

      // Rotate the sprite component to point toward player
      bombSpriteComponent!.angle = angle;
    }

    position += velocity * dt;

    // Check collision with player based on level type
    final player = game.player;
    if (position.distanceTo(player.position) < radius + player.radius) {
      if (levelType == LevelType.gravity ||
          levelType == LevelType.survival ||
          levelType == LevelType.demon) {
        collected = true;
        game.collectObject(this);
      }
    }

    final demon = game.demon;
    if (position.distanceTo(demon.position) < radius + demon.radius) {
      if (levelType == LevelType.demon && isMagnetized) {
        if (type == ObjectType.bomb) {
          print("HIT A DEMON BY BOMB");
          demon.onHitByBomb();
        }
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
    } else if (levelType == LevelType.survival ||
        levelType == LevelType.demon) {
      // Remove if too far from player or off screen
      final distanceToPlayer = position.distanceTo(player.position);
      if (distanceToPlayer > gameSize.x * 1.5 ||
          position.x < -50 ||
          position.x > gameSize.x + 50 ||
          position.y < -50 ||
          position.y > gameSize.y + 50) {
        game.gameObjects.remove(this);
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

      // Adjust glow size based on object type
      double glowRadius;
      if (type == ObjectType.bomb && bombSpriteComponent != null) {
        // For rockets, make glow slightly larger than the sprite
        glowRadius = radius * pulseScale + 8;
      } else {
        // For coins and fallback bombs, use original size
        glowRadius = radius * pulseScale + 5;
      }

      canvas.drawCircle(Offset.zero, glowRadius, pulseGlowPaint);
    }

    // Draw main object with pulse effect
    final scaledRadius = radius * pulseScale;

    // Draw circle for coins or fallback for bombs
    if (type == ObjectType.coin || bombSpriteComponent == null) {
      canvas.drawCircle(Offset.zero, scaledRadius, objectPaint);

      // Draw border
      final borderPaint = Paint()
        ..color = type == ObjectType.coin ? Colors.orange : Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(Offset.zero, scaledRadius, borderPaint);

      // Draw symbol only for fallback bomb rendering
      if (type == ObjectType.bomb && bombSpriteComponent == null) {
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
}
