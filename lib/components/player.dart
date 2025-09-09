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
  static const double _movementThreshold = 5.0; // Minimum distance to count as movement
  static const double _movementTimeWindow = 1.0; // Time window to check for movement

  Player({required super.position})
      : super(
          radius: 15,
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    super.onLoad();
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
      print('Loading skin: $skinPath');

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

      print(
          'Successfully loaded skin: $skinPath, children count: ${children.length}');
    } catch (e) {
      print('Failed to load skin $skinPath: $e');
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

  // @override
  // void render(Canvas canvas) {
  //   // Draw magnetic field
  //   canvas.drawCircle(
  //     Offset.zero,
  //     magnetRadius,
  //     magnetFieldPaint,
  //   );

  //   // Draw glow behind the skin
  //   canvas.drawCircle(Offset.zero, radius + 8, playerGlowPaint);

  //   // The skin sprite is rendered by the SpriteComponent (added as a child)
  // }

  @override
  void render(Canvas canvas) {
    final currentLevelType = LevelTypeConfig.getLevelType(game.waveManager.level);
    
    // ✅ MODIFIED: Different magnetic field rendering for demon level
    if (currentLevelType == LevelType.demon) {
      // Show magnetic field only when player is moving
      if (_hasRecentMovement) {
        // Active magnetic field - brighter and more visible
        final activeMagnetPaint = Paint()
          ..color = Colors.redAccent.withOpacity(0.3)
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(Offset.zero, magnetRadius, activeMagnetPaint);
        
        // Add pulsing border to show it's active
        final activeBorderPaint = Paint()
          ..color = Colors.redAccent.withOpacity(0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        
        canvas.drawCircle(Offset.zero, magnetRadius, activeBorderPaint);
      } else {
        // Inactive magnetic field - dim and barely visible
        final inactiveMagnetPaint = Paint()
          ..color = Colors.grey.withOpacity(0.1)
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(Offset.zero, magnetRadius, inactiveMagnetPaint);
        
        // Dashed border to show it's inactive
        final inactiveBorderPaint = Paint()
          ..color = Colors.grey.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        
        canvas.drawCircle(Offset.zero, magnetRadius, inactiveBorderPaint);
      }
    } else {
      // Normal magnetic field for other level types
      canvas.drawCircle(Offset.zero, magnetRadius, magnetFieldPaint);
    }

    // Draw glow behind the skin (keep existing)
    canvas.drawCircle(Offset.zero, radius + 8, playerGlowPaint);

    // The skin sprite is rendered by the SpriteComponent (added as a child)
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
        final maxY = gameSize.y - 20;  // Near bottom (with small margin)
        
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

  void upgradeMagnet(int level) {
    //magnetRadius = math.min(120.0, 80.0 + level * 3);
    magnetRadius = 80.0 + level * 3;
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
    magnetRadius = 80.0;

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
    final currentLevelType = LevelTypeConfig.getLevelType(game.waveManager.level);
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
