import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../magnet_walker_game.dart';
import '../level_types.dart';
import '../utils/screen_utils.dart';
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
  String? bombImageName; // Track which image is being used

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
    // Make object size responsive to screen size
    final screenSize = game.canvasSize;
    radius = type == ObjectType.coin
        ? math.min(ScreenUtils.responsive(8.0, screenSize), 12)
        : math.min(ScreenUtils.responsive(12.0, screenSize), 16);

    // Load rocket sprite for bombs
    if (type == ObjectType.bomb) {
      try {
        // Randomly choose between available missile/rocket images
        final rocketImages = [
          'rocket.png',
          'rocket-2.png',
          'rocket-3.png',
          'rocket-4.png',
          'missile1.png',
          'missile2.png',
          'missile3.png',
          'missile4.png',
          'missile5.png',
          'missile6.png',
        ];
        final random = math.Random();
        final chosen = rocketImages[random.nextInt(rocketImages.length)];
        bombImageName = chosen; // Save the image name for later reference
        final bombSprite = Sprite(game.images.fromCache(chosen));

        // Calculate size while preserving aspect ratio
        final image = game.images.fromCache(chosen);
        final aspectRatio = image.width / image.height;
        Vector2 spriteSize;

        // Different sizing for missiles vs rockets
        final isMissile = chosen.contains('missile');

        if (isMissile) {
          // Missiles: make them larger and thicker for better visibility
          final missileLength = radius * 4.2; // Much larger length
          final missileWidth = radius * 1.4; // Thicker width

          if (aspectRatio > 1.0) {
            // Wide missile (horizontal) - long and thin
            spriteSize = Vector2(missileLength, missileWidth);
          } else {
            // Tall missile (vertical) - long and thin
            spriteSize = Vector2(missileWidth, missileLength);
          }
        } else {
          // Rockets: keep original sizing
          final rocketScale = radius * 2;
          if (aspectRatio > 1.0) {
            spriteSize = Vector2(rocketScale * aspectRatio, rocketScale);
          } else {
            spriteSize = Vector2(rocketScale, rocketScale / aspectRatio);
          }
        }

        bombSpriteComponent = SpriteComponent(
          sprite: bombSprite,
          size: spriteSize, // Preserve aspect ratio
          anchor: Anchor.center, // Ensure it's centered
        );
        add(bombSpriteComponent!);
      } catch (e) {
        print('Could not load rocket image: $e');
      }
    }

    // Set velocity based on level type
    if (levelType == LevelType.gravity) {
      double baseSpeed = 25.0; // Made responsive
      if (level < 10) {
        baseSpeed = 50.0;
      }
      final levelSpeedMultiplier =
          1.0 + (level * 0.2); // Reduced from 0.3 to balance
      velocity.y = baseSpeed * levelSpeedMultiplier;
    } else if (levelType == LevelType.survival) {
      // Objects move toward player
      final playerPos = game.player?.position;
      final direction = (playerPos! - position)..normalize();
      double rootSpeed = 25.0; // Made responsive
      if (level < 10) {
        rootSpeed = 50.0;
      }
      final baseSpeed =
          ScreenUtils.responsive(rootSpeed, screenSize); // Made responsive
      final speedGrowth = 1.0 + (level * 0.15); // Reduced from 0.12 to balance
      final waveGrowth =
          1.0 + (game.waveManager.currentWave - 1) * 0.08; // Reduced slightly
      velocity = direction * baseSpeed * speedGrowth * waveGrowth;
    }

    if (type == ObjectType.coin) {
      objectPaint = Paint()..color = Colors.amber;
      glowPaint = Paint()
        ..color = Colors.amber.withOpacity(0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal,
            ScreenUtils.responsive(5, screenSize)); // Made responsive
    } else {
      objectPaint = Paint()..color = Colors.red;
      glowPaint = Paint()
        ..color = Colors.red.withOpacity(0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal,
            ScreenUtils.responsive(5, screenSize)); // Made responsive
    }
  }

  @override
  void update(double dt) {
    if (collected) return;

    final screenSize =
        game.canvasSize; // Get screen size for responsive calculations

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
      // Apply responsive sizing while preserving missile proportions
      final isMissile = bombImageName?.contains('missile') ?? false;

      if (isMissile) {
        // Missiles: larger and thicker for better visibility
        final missileLength =
            ScreenUtils.responsive(radius * 4.2 * pulseScale, screenSize);
        final missileWidth =
            ScreenUtils.responsive(radius * 1.4 * pulseScale, screenSize);

        // Determine orientation from current size (which was set in onLoad)
        final currentSize = bombSpriteComponent!.size;
        if (currentSize.x > currentSize.y) {
          // Horizontal missile
          bombSpriteComponent!.size = Vector2(missileLength, missileWidth);
        } else {
          // Vertical missile
          bombSpriteComponent!.size = Vector2(missileWidth, missileLength);
        }
      } else {
        // Rockets: use original square sizing
        bombSpriteComponent!.size = Vector2.all(ScreenUtils.responsive(
            radius * 3.8 * pulseScale, screenSize)); // Made responsive
      }

      Vector2 direction;

      if (levelType == LevelType.demon && isMagnetized) {
        // Point toward demon when magnetized in demon level
        final demon = game.demon;
        if (demon != null) {
          direction = (demon.position - position);
        } else {
          // Fallback to player if demon is null
          final player = game.player;
          direction = (player!.position - position);
        }
      } else {
        // Default: point toward player
        final player = game.player;
        direction = (player!.position - position);
      }

      final angle = math.atan2(direction.y, direction.x);
      // Rotate the sprite component to point toward target
      bombSpriteComponent!.angle = angle;
    }

    position += velocity * dt;

    // Check collision with player based on level type
    final player = game.player;
    if (position.distanceTo(player?.position as Vector2) <
        radius + player!.radius) {
      if (levelType == LevelType.gravity ||
          levelType == LevelType.survival ||
          levelType == LevelType.demon) {
        collected = true;
        game.collectObject(this);
      }
    }

    if (levelType == LevelType.demon) {
      final demon = game.demon;
      if (demon != null) {
        final distanceToDemon = position.distanceTo(demon.position);

        if (distanceToDemon < (radius * 1.2 + demon.radius) && isMagnetized) {
          // 1.2 to give a little leeway

          if (type == ObjectType.bomb) {
            demon.onHitByBomb();

            // Mark bomb as destroyed
            collected = true;
            game.createParticles(demon.position, Colors.red);
            game.gameObjects.remove(this);
            removeFromParent();
          }
        }
      }
    }

    // Remove if off screen (different logic per level type)
    final gameSize = game.canvasSize;
    if (levelType == LevelType.gravity) {
      // Remove if below screen (with responsive margin)
      final margin = ScreenUtils.responsive(50.0, gameSize);
      if (position.y > gameSize.y + margin) {
        removeFromParent();
      }
    } else if (levelType == LevelType.survival ||
        levelType == LevelType.demon) {
      // Remove if too far from player or off screen (with responsive margins)
      final margin = ScreenUtils.responsive(50.0, gameSize);
      final distanceToPlayer = position.distanceTo(player.position);
      if (distanceToPlayer > gameSize.x * 1.5 ||
          position.x < -margin ||
          position.x > gameSize.x + margin ||
          position.y < -margin ||
          position.y > gameSize.y + margin) {
        game.gameObjects.remove(this);
        removeFromParent();
      }
    }

    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (collected) return;

    final screenSize =
        game.canvasSize; // Get screen size for responsive calculations

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
        ..maskFilter = MaskFilter.blur(BlurStyle.normal,
            ScreenUtils.responsive(5, screenSize)); // Made responsive

      // Adjust glow size based on object type
      double glowRadius;
      if (type == ObjectType.bomb && bombSpriteComponent != null) {
        // For rockets, make glow slightly larger than the sprite
        glowRadius = ScreenUtils.responsive(
            radius * pulseScale + 8, screenSize); // Made responsive
      } else {
        // For coins and fallback bombs, use original size
        glowRadius = ScreenUtils.responsive(
            radius * pulseScale + 5, screenSize); // Made responsive
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
        ..strokeWidth =
            ScreenUtils.responsive(2, screenSize); // Made responsive

      canvas.drawCircle(Offset.zero, scaledRadius, borderPaint);

      // Draw symbol only for fallback bomb rendering
      if (type == ObjectType.bomb && bombSpriteComponent == null) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '!',
            style: TextStyle(
              color: Colors.white,
              fontSize:
                  ScreenUtils.responsive(12, screenSize), // Made responsive
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

  @override
  void onMount() {
    super.onMount();
    // Add to gameObjects here instead
    (game).gameObjects.add(this);
  }
}
