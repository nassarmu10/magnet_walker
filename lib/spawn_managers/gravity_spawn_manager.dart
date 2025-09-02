import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async' as async;
import '../../magnet_walker_game.dart';
import '../../components/game_object.dart';
import '../../level_types.dart';

class GravitySpawnManager {
  final MagnetWalkerGame game;
  async.Timer? spawnTimer;
  final double _minDistanceBetweenObjects = 60.0;
  final List<Vector2> _recentSpawnPositions = [];
  static const int _maxRecentPositions = 5;

  GravitySpawnManager(this.game);

  void startSpawning() {
    spawnTimer?.cancel();
    _recentSpawnPositions.clear();

    // Improved spawn rate calculation - starts faster, scales better
    final level = game.waveManager.level;
    final wave = game.waveManager.currentWave;

    // More aggressive early game, smoother scaling
    double spawnRate;
    if (level <= 3) {
      // Early levels: Start at 1.2s, reduce by wave
      spawnRate = math.max(1.2 - (wave - 1) * 0.15, 0.6);
    } else if (level <= 8) {
      // Mid-early levels: Start at 1.0s
      spawnRate = math.max(1.0 - (wave - 1) * 0.12 - (level - 3) * 0.05, 0.4);
    } else {
      // Higher levels: More intense
      spawnRate = math.max(0.8 - (wave - 1) * 0.1 - (level - 8) * 0.03, 0.2);
    }

    spawnTimer = async.Timer.periodic(
        Duration(milliseconds: (spawnRate * 1000).round()), (timer) {
      if (game.currentState == GameState.playing) {
        spawnObject();
      }
    });
  }

  void spawnObject() {
    final gameSize =
        game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);

    // Find valid spawn position
    Vector2 spawnPosition;
    int attempts = 0;
    final maxAttempts = 10;

    do {
      final x = math.Random().nextDouble() * (gameSize.x - 80) + 40;
      spawnPosition = Vector2(x, gameSize.y * 0.12 + gameSize.y * 0.055);
      attempts++;
      if (attempts >= maxAttempts) break;
    } while (_isTooCloseToRecentSpawns(spawnPosition));

    _recentSpawnPositions.add(spawnPosition);
    if (_recentSpawnPositions.length > _maxRecentPositions) {
      _recentSpawnPositions.removeAt(0);
    }

    // Improved bomb chance scaling
    final level = game.waveManager.level;
    final wave = game.waveManager.currentWave;

    double bombChance;
    if (level <= 3) {
      bombChance = 0.2 + 0.15 * (wave - 1); // 20% → 35% → 50%
    } else if (level <= 8) {
      bombChance = 0.3 + 0.2 * (wave - 1); // 30% → 50% → 70%
    } else {
      bombChance = math.min(0.4 + 0.25 * (wave - 1), 0.85); // Up to 85% bombs
    }

    final type = math.Random().nextDouble() < (1 - bombChance)
        ? ObjectType.coin
        : ObjectType.bomb;

    final obj = GameObject(
      position: spawnPosition,
      type: type,
      level: level,
      levelType: LevelType.gravity,
    );

    // Improved speed scaling - starts with decent speed
    double speedMultiplier;
    if (level <= 3) {
      // Early: Start at 1.3x, increase by 0.3x per wave
      speedMultiplier = 1.3 + 0.3 * (wave - 1);
    } else if (level <= 8) {
      // Mid: Start at 1.5x, increase by 0.35x per wave
      speedMultiplier = 1.5 + 0.35 * (wave - 1) + 0.1 * (level - 3);
    } else {
      // High: More dramatic scaling
      speedMultiplier = 2.0 + 0.4 * (wave - 1) + 0.15 * (level - 8);
    }

    if (type == ObjectType.bomb || type == ObjectType.coin) {
      obj.velocity.y *= speedMultiplier;
    }
    if (game.spawnPortal != null) {
      game.spawnPortal?.spawnFlash();
      obj.position = game.spawnPortal!.position;
    }

    final angle =
        (math.pi / 2) + (math.Random().nextDouble() - 0.5) * math.pi / 2;
// math.pi/2 = downward, ±15 degrees spread
    final speed = 50.0; // adjust
    obj.velocity = Vector2(math.cos(angle), math.sin(angle)) * speed;
    game.add(obj);
  }

  bool _isTooCloseToRecentSpawns(Vector2 position) {
    for (final recentPos in _recentSpawnPositions) {
      if (position.distanceTo(recentPos) < _minDistanceBetweenObjects) {
        return true;
      }
    }
    return false;
  }

  void stop() {
    spawnTimer?.cancel();
    _recentSpawnPositions.clear();
  }
}
