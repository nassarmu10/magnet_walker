import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../magnet_walker_game.dart';
import '../level_types.dart';
import 'game_object.dart';

class Player extends CircleComponent with HasGameRef<MagnetWalkerGame> {
  double magnetRadius = 80.0;
  late Paint magnetFieldPaint;
  late Paint playerGlowPaint;
  SpriteComponent? playerSpriteComponent;
  Vector2? _targetPosition;
  double? _moveDuration;
  double _moveElapsed = 0;
  String _currentSkinPath = 'player.png'; // Track current skin

  // Flag to indicate if animating to initial position
  bool isAnimatingToPosition = false;
  // ADD: Movement tracking for demon level
  Vector2 _lastPosition = Vector2.zero();
  double _timeSinceLastMovement = 0.0;
  bool _hasRecentMovement = false;
  static const double _movementThreshold =
      5.0; // Minimum distance to count as movement
  static const double _movementTimeWindow =
      1.0; // Time window to check for movement

  Player({required super.position})
      : super(
          radius: 15,
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    updateMagnetForLevel();
    // Set size for collision detection
    // size = Vector2.all(radius * 2);
    magnetFieldPaint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    playerGlowPaint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    // Load initial skin (will be updated by game)
    // await _loadSkin(_currentSkinPath);
  }

  Future<void> _loadSkin(String skinPath) async {
    try {
      // Dispose of the old sprite component properly
      if (playerSpriteComponent != null) {
        playerSpriteComponent!.removeFromParent();
        // Don't dispose the image here as it's cached by the game
        playerSpriteComponent = null;
      }
      // Remove ALL children components (not just sprite components)
      final allChildren = children.toList();
      for (final child in allChildren) {
        child.removeFromParent();
      }

      // Force clear the sprite reference
      playerSpriteComponent = null;

      // Wait longer for cleanup
      await Future.delayed(const Duration(milliseconds: 100));

      // Load new skin
      final skinImage = await game.images.load(skinPath);
      playerSpriteComponent = SpriteComponent(
        sprite: Sprite(skinImage),
        size: Vector2.all(radius * 7),
        anchor: Anchor.center,
        priority: 1,
      );

      // Add the new sprite
      add(playerSpriteComponent!);
      _currentSkinPath = skinPath;
    } catch (e) {
      // Fallback to default skin if loading fails
      if (skinPath != 'player.png') {
        await _loadSkin('player.png');
      }
    }
  }

  // Method to update the player's skin
  Future<void> updateSkin(String skinPath) async {
    await _loadSkin(skinPath);
  }

  @override
  void render(Canvas canvas) {
    final currentLevelType =
        LevelTypeConfig.getLevelType(game.waveManager.level);

    final time = game.currentTime(); // track game time
    final pulse = 0.9 + 0.1 * math.sin(time * 3);
    final rotation = time * 0.5; // rotation for field lines

    void drawLayeredMagneticField(Color baseColor, double radiusScale) {
      // Define multiple layers with different properties
      final layers = [
        {'scale': 1.0, 'opacity': 0.3, 'speed': 1.0, 'blur': 8.0},
        {'scale': 0.8, 'opacity': 0.4, 'speed': 1.3, 'blur': 6.0},
        {'scale': 0.6, 'opacity': 0.5, 'speed': 1.7, 'blur': 4.0},
        {'scale': 0.4, 'opacity': 0.6, 'speed': 2.2, 'blur': 2.0},
      ];

      // Draw each layer with different timing and properties
      for (int layerIndex = 0; layerIndex < layers.length; layerIndex++) {
        final layer = layers[layerIndex];
        final layerPulse = 0.9 + 0.1 * math.sin(time * 3 * layer['speed']!);
        final layerRadius = magnetRadius * layerPulse * radiusScale * layer['scale']!;
        final layerOpacity = layer['opacity']!;

        // Gradient fill for this layer
        final layerGradient = RadialGradient(
          colors: [
            baseColor.withOpacity(layerOpacity * 0.8),
            baseColor.withOpacity(layerOpacity * 0.4),
            baseColor.withOpacity(0.0)
          ],
          stops: [0.0, 0.6, 1.0],
        );
        final rect = Rect.fromCircle(center: Offset.zero, radius: layerRadius);
        final shader = layerGradient.createShader(rect);
        final fillPaint = Paint()
          ..shader = shader
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, layer['blur']!);
        canvas.drawCircle(Offset.zero, layerRadius, fillPaint);

        // Curved magnetic lines for this layer
        final layerRotation = time * (0.5 + layerIndex * 0.2);
        final linePaint = Paint()
          ..color = baseColor.withOpacity(layerOpacity * 0.7)
          ..strokeWidth = 1.5 - (layerIndex * 0.2)
          ..style = PaintingStyle.stroke
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, layer['blur']! * 0.3);

        final linesCount = 12 + (layerIndex * 2); // More lines on inner layers
        for (int i = 0; i < linesCount; i++) {
          final angle = i * 2 * math.pi / linesCount + layerRotation;
          final bend = (0.2 + layerIndex * 0.1) * math.sin(time * (2 + layerIndex) + i);
          final start = Offset(math.cos(angle), math.sin(angle)) * (radius + 4);
          final control = start + Offset(-start.dy, start.dx) * bend;
          final end = Offset(math.cos(angle), math.sin(angle)) * layerRadius;

          final path = Path()..moveTo(start.dx, start.dy);
          path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
          canvas.drawPath(path, linePaint);
        }

        // Layer border with different intensities
        final borderPaint = Paint()
          ..color = baseColor.withOpacity(layerOpacity * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 - (layerIndex * 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, layer['blur']! * 0.2);
        canvas.drawCircle(Offset.zero, layerRadius, borderPaint);

        // Add energy rings for inner layers
        if (layerIndex >= 2) {
          final ringPulse = 0.8 + 0.2 * math.sin(time * 4 + layerIndex);
          final ringPaint = Paint()
            ..color = Colors.white.withOpacity(layerOpacity * 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
          canvas.drawCircle(Offset.zero, layerRadius * ringPulse, ringPaint);
        }
      }
    }

    if (currentLevelType == LevelType.demon) {
      if (_hasRecentMovement) {
        drawLayeredMagneticField(Colors.redAccent, 1.0);
      } else {
        drawLayeredMagneticField(Colors.grey, 0.7);
      }
    } else {
      drawLayeredMagneticField(Colors.blueAccent, 1.0);
    }

    // Player glow behind skin
    canvas.drawCircle(Offset.zero, radius + 8, playerGlowPaint);
  }

  void moveBy(double deltaX, double deltaY) {
    if (isAnimatingToPosition) return;

    final gameSize = game.canvasSize;
    final currentLevelType =
        LevelTypeConfig.getLevelType(game.waveManager.level);

    if (currentLevelType == LevelType.gravity ||
        currentLevelType == LevelType.demon) {
      position.x = (position.x + deltaX).clamp(20.0, gameSize.x - 20);

      // For demon levels, restrict upward movement to avoid collision area
      if (currentLevelType == LevelType.gravity) {
        // GRAVITY LEVELS: Limit player to upper half of screen
        final minY = gameSize.y * 0.5; // Middle of screen (can't go higher)
        final maxY = gameSize.y - 20; // Near bottom (with small margin)

        position.y = (position.y + deltaY).clamp(minY, maxY);
      } else if (currentLevelType == LevelType.demon) {
        // DEMON LEVELS: Keep existing demon collision avoidance
        if (game.currentState == GameState.playing) {
          final demon = game.demon!;
          final minY = demon.patrolOrigin.y * 2 + demon.patrolRadius + 50.0;
          position.y = (position.y + deltaY).clamp(minY, gameSize.y - 20);
        } else {
          // When demon is not active, also limit to upper half like gravity
          final minY = gameSize.y * 0.5;
          final maxY = gameSize.y - 20;
          position.y = (position.y + deltaY).clamp(minY, maxY);
        }
      }
    } else if (currentLevelType == LevelType.survival) {
      // SURVIVAL MODE: No movement allowed (player stays stationary)
      // No movement allowed
    }
  }

  void moveHorizontally(double deltaX) {
    if (isAnimatingToPosition) return;
    final gameSize = game.canvasSize;
    final currentLevelType =
        LevelTypeConfig.getLevelType(game.waveManager.level);
    if (currentLevelType == LevelType.gravity) {
      position.x = (position.x + deltaX).clamp(30.0, gameSize.x - 30);
    } else if (currentLevelType == LevelType.survival) {
      // In survival mode, player stays stationary in center
      // No movement allowed
    }
  }

  void applyMagneticForce(GameObject obj, double dt) {
    final distance = position.distanceTo(obj.position);
    if (distance < magnetRadius && distance > 0) {
      final currentLevelType =
          LevelTypeConfig.getLevelType(game.waveManager.level);
      final isBomb = obj.type == ObjectType.bomb;

      Vector2 targetDirection;
      double force;

      // Default behavior: pull toward player (for non-demon levels or non-bombs)
      targetDirection = (position - obj.position)..normalize();
      force = 600 * (1 - distance / magnetRadius);
      // Enhanced force for gravity mode based on object speed
      if (currentLevelType == LevelType.gravity) {
        final objectSpeed = obj.velocity.length;
        final speedMultiplier =
            1.0 + (objectSpeed / 100.0); // Adjust 200.0 as needed
        force *= speedMultiplier;

        // Optional: Cap the maximum force to prevent over-correction
        force = math.min(force, 3000.0);
      }
      // Special handling for demon level bombs
      if (currentLevelType == LevelType.demon && isBomb) {
        final demon = game.demon;
        if (demon != null) {
          final closeDistanceThreshold =
              radius + obj.radius + 5; // Very close to player

          if (distance > closeDistanceThreshold && _hasRecentMovement) {
            // Repulsive force: push bomb back toward demon
            targetDirection = (demon.position - obj.position)..normalize();
            force =
                1500 * (1 - distance / magnetRadius); // Strong repulsive force
            obj.isMagnetized = true;
          } else if (distance <= closeDistanceThreshold) {
            // Bomb is very close to player - collision damage
            // Don't apply magnetic force, let it hit the player
            obj.isMagnetized = false;
            return;
          } else {
            // // Bomb is very close to player - reduce force to allow collision
            // // Still push toward demon but with much weaker force
            // targetDirection = (demon.position - obj.position)..normalize();
            // force = 50 * (1 - distance / magnetRadius); // Very weak force
            // Player isn't moving - no magnetic repulsion, bomb continues toward player
            obj.isMagnetized = false;
            return;
          }
        }
      }

      obj.velocity += targetDirection * force * dt;
      obj.isMagnetized = true;
    }
  }

  void resetMovementTracking() {
    _lastPosition = position.clone();
    _timeSinceLastMovement = 0.0;
    _hasRecentMovement = false;
  }

  void updateMagnetForLevel() {
    final currentLevelType =
        LevelTypeConfig.getLevelType(game.waveManager.level);
    if (currentLevelType == LevelType.demon) {
      magnetRadius = 80;
      return;
    }
    //magnetRadius = math.min(120.0, 80.0 + level * 3);
    final currentLevel = game.waveManager.level;
    // Base radius of 80, grows by 5 pixels per level
    double desiredRadius = 80.0 + (currentLevel * 3.0);
    final gameSize = game.canvasSize;

    // Optional: Cap the maximum radius to prevent it from getting too large
    final maxRadius = gameSize.x / 2 - 15;
    magnetRadius = math.min(desiredRadius, maxRadius);
  }

  void reset() {
    final gameSize = game.canvasSize;
    final currentLevelType =
        LevelTypeConfig.getLevelType(game.waveManager.level);
    const double horizontalOffset = 10.0;
    if (currentLevelType == LevelType.gravity) {
      position = Vector2(gameSize.x / 2 + horizontalOffset, gameSize.y - 117);
    } else {
      position = Vector2(gameSize.x / 2 + horizontalOffset, gameSize.y / 2);
    }

    updateMagnetForLevel();

    // Reset movement tracking
    resetMovementTracking();
  }

  // Animate the player to a target position over a duration (in seconds)
  void animateToPosition(Vector2 target, double duration) {
    _targetPosition = target.clone();
    _moveDuration = duration;
    _moveElapsed = 0;
    isAnimatingToPosition = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    // ADD: Track player movement for demon level
    final currentLevelType =
        LevelTypeConfig.getLevelType(game.waveManager.level);
    if (currentLevelType == LevelType.demon) {
      // Check if player has moved significantly
      final distanceMoved = position.distanceTo(_lastPosition);

      if (distanceMoved > _movementThreshold) {
        _timeSinceLastMovement = 0.0;
        _hasRecentMovement = true;
        _lastPosition = position.clone();
      } else {
        _timeSinceLastMovement += dt;
        if (_timeSinceLastMovement > _movementTimeWindow) {
          _hasRecentMovement = false;
        }
      }
    }

    // Animate movement if needed
    if (_targetPosition != null && _moveDuration != null) {
      _moveElapsed += dt;
      final t = (_moveElapsed / _moveDuration!).clamp(0.0, 1.0);
      // Manually interpolate between position and _targetPosition!
      position = position + (_targetPosition! - position) * t;
      if (t >= 1.0) {
        position = _targetPosition!;
        _targetPosition = null;
        _moveDuration = null;
        _moveElapsed = 0;
        isAnimatingToPosition = false;
      }
    }
  }
}
