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

    playerGlowPaint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    // Load initial skin (will be updated by game)
    await _loadSkin(_currentSkinPath);
  }

  Future<void> _loadSkin(String skinPath) async {
    try {
      // Remove existing sprite component
      if (playerSpriteComponent != null) {
        remove(playerSpriteComponent!);
      }

      // Load new skin
      final skinImage = await game.images.load(skinPath);
      playerSpriteComponent = SpriteComponent(
        sprite: Sprite(skinImage),
        size: Vector2.all(radius * 5),
        anchor: Anchor.center,
        priority: 1,
      );
      add(playerSpriteComponent!);
      _currentSkinPath = skinPath;
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
    if (_currentSkinPath != skinPath) {
      await _loadSkin(skinPath);
    }
  }

  @override
  void render(Canvas canvas) {
    // Draw magnetic field
    canvas.drawCircle(
      Offset.zero,
      magnetRadius,
      magnetFieldPaint,
    );

    // Draw glow behind the skin
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
      position.y = (position.y + deltaY).clamp(20.0, gameSize.y - 20);
    } else if (currentLevelType == LevelType.survival) {
      // In survival mode, player stays stationary in center
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
      final direction = (position - obj.position)..normalize();
      final force = 1000 * (1 - distance / magnetRadius);

      obj.velocity += direction * force * dt;
      obj.isMagnetized = true;
    }
  }

  void upgradeMagnet(int level) {
    //magnetRadius = math.min(120.0, 80.0 + level * 3);
    magnetRadius = 80.0 + level * 3;
  }

  void reset() {
    final gameSize = game.canvasSize;
    final currentLevelType =
        LevelTypeConfig.getLevelType(game.waveManager.level);
    if (currentLevelType == LevelType.gravity) {
      position = Vector2(gameSize.x / 2, gameSize.y - 117);
    } else {
      position = Vector2(gameSize.x / 2, gameSize.y / 2);
    }
    magnetRadius = 80.0;
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
