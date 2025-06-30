import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../magnet_walker_game.dart';
import '../level_types.dart';
import 'game_object.dart';

class Player extends CircleComponent with HasGameRef<MagnetWalkerGame> {
  double magnetRadius = 200.0;
  late Paint magnetFieldPaint;
  late Paint playerGlowPaint;
  SpriteComponent? earthSpriteComponent;

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

    // Load Earth sprite
    final earthImage = await game.images.load('player.png');
    earthSpriteComponent = SpriteComponent(
      sprite: Sprite(earthImage),
      size: Vector2.all(radius * 5),
      anchor: Anchor.center,
      priority: 1,
    );
    add(earthSpriteComponent!);
  }

  @override
  void render(Canvas canvas) {
    // Draw magnetic field
    canvas.drawCircle(
      Offset.zero,
      magnetRadius,
      magnetFieldPaint,
    );

    // Draw glow behind the Earth
    canvas.drawCircle(Offset.zero, radius + 8, playerGlowPaint);

    // The Earth sprite is rendered by the SpriteComponent (added as a child)
    // No need to draw the circle or border anymore
  }

  void moveBy(double deltaX, double deltaY) {
    final gameSize =
        game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);
    final currentLevelType = LevelTypeConfig.getLevelType(game.level);

    if (currentLevelType == LevelType.gravity) {
      // In gravity mode, player moves both horizontally and vertically
      position.x = (position.x + deltaX).clamp(30.0, gameSize.x - 30);
      position.y = (position.y + deltaY).clamp(30.0, gameSize.y - 30);
    } else if (currentLevelType == LevelType.survival) {
      // In survival mode, player stays stationary in center
      // No movement allowed
    }
  }

  void moveHorizontally(double deltaX) {
    final gameSize =
        game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);
    final currentLevelType = LevelTypeConfig.getLevelType(game.level);

    if (currentLevelType == LevelType.gravity) {
      // In gravity mode, player moves horizontally at bottom
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
    } else {
      obj.isMagnetized = false;
    }
  }

  void upgradeMagnet(int level) {
    //magnetRadius = math.min(120.0, 80.0 + level * 3);
    magnetRadius = 200.0 + level * 3;
  }

  void reset() {
    final gameSize =
        game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);
    final currentLevelType = LevelTypeConfig.getLevelType(game.level);

    if (currentLevelType == LevelType.gravity) {
      // In gravity mode, player stays at bottom
      position = Vector2(gameSize.x / 2, gameSize.y - 117);
    } else {
      // In survival mode, player starts at center
      position = Vector2(gameSize.x / 2, gameSize.y / 2);
    }

    magnetRadius = 200.0;
  }
}
