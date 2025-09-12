import 'package:flame/components.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';
import 'package:magnet_walker/level_types.dart';
import 'dart:math' as math;
import '../magnet_walker_game.dart';
import 'game_object.dart';

class Demon extends CircleComponent with HasGameRef<MagnetWalkerGame> {
  double shootInterval = 2.0; // seconds between shots
  double shootTimer = 0.0;
  bool isAlive = false;
  SpriteComponent? demonSprite;

  // Health
  int maxHealth = 3;
  int health = 3; //TODO FIND BETTER VALUES
  double hitEffectTimer = 0.0;
  static const double hitEffectDuration = 0.2;

  // Movement
  Vector2 patrolOrigin = Vector2.zero();
  double patrolRadius = 60.0;
  double patrolSpeed = 40.0; // pixels per second
  double patrolAngle = 0.0;

  Demon({required Vector2 position, double radius = 30})
      : super(
          position: position,
          radius: radius,
          anchor: Anchor.center,
        ) {
    patrolOrigin = position.clone();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Load and add the demon sprite as a child
    String demonImage = 'demon.png';
    if (game.waveManager.level > 10 && game.waveManager.level < 20) {
      demonImage = 'demon2.png';
    } else {
      demonImage = 'demon3.png';
    }
    final sprite = await game.loadSprite(demonImage);
    demonSprite = SpriteComponent(
      sprite: sprite,
      size: Vector2.all(radius * 2),
      anchor: Anchor.center,
      priority: 1,
    );
    shootInterval = math.max(0.9, 2.0 - (game.waveManager.level * 0.1));

    add(demonSprite!);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isAlive) return;

    // Movement: simple circular patrol
    patrolAngle += patrolSpeed * dt / patrolRadius;
    position = patrolOrigin +
        Vector2(math.cos(patrolAngle), math.sin(patrolAngle)) * patrolRadius;

    // Hit effect timer
    if (hitEffectTimer > 0) {
      hitEffectTimer -= dt;
      if (hitEffectTimer < 0) hitEffectTimer = 0;
    }

    // Shooting logic
    shootTimer += dt;
    if (shootTimer >= shootInterval) {
      shootTimer = 0.0;
      shootBombAtPlayer();
    }
  }

  @override
  void render(Canvas canvas) {
    // Don't call super.render(canvas) to avoid drawing the white circle
    // Draw health bar above demon
    if (isAlive) {
      final barWidth = radius * 2;
      final barHeight = 6.0;
      final healthPercent = health / maxHealth;
      final barBgRect =
          Rect.fromLTWH(-radius, -radius - 18, barWidth, barHeight);
      final barRect = Rect.fromLTWH(
          -radius, -radius - 18, barWidth * healthPercent, barHeight);
      canvas.drawRect(barBgRect,
          BasicPalette.black.paint()..color = Colors.black.withOpacity(0.5));
      canvas.drawRect(
          barRect, BasicPalette.red.paint()..color = Colors.redAccent);
    }
    // Draw hit effect overlay
    if (hitEffectTimer > 0) {
      final paint = Paint()
        ..color = Colors.white
            .withOpacity(0.5 * (hitEffectTimer / hitEffectDuration));
      canvas.drawCircle(Offset.zero, radius, paint);
    }
  }

  void shootBombAtPlayer() {
    final playerPos = game.player?.position;
    final direction = (playerPos! - position).normalized();
    final bomb = GameObject(
      position: position.clone(),
      type: ObjectType.bomb,
      level: game.waveManager.level,
      levelType: LevelType.demon,
    );
    bomb.velocity = direction * 200; // Adjust speed as needed
    game.add(bomb);
  }

  // Call this when a bomb is returned and hits the demon
  void onHitByBomb() {
    if (!isAlive) return;
    health--;
    game.playSound('bomb.wav');
    hitEffectTimer = hitEffectDuration;
    if (health <= 0) {
      isAlive = false;
      // Play animation, sound, etc.
      game.SuccessDemonLevel();
    }
  }

  void deleteDemon() {
    isAlive = false;
    removeFromParent();
  }

  // NEW: Method to restore demon's health
  void restoreHealth(int restoredHealth, int restoredMaxHealth) {
    health = restoredHealth;
    maxHealth = restoredMaxHealth;
    isAlive = true;
    hitEffectTimer = 0.0;
    shootTimer = 0.0; // Reset shoot timer
  }

  // NEW: Method to get current health percentage
  double getHealthPercentage() {
    return health / maxHealth;
  }
}
