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
  final double _minDistanceBetweenObjects =
      60.0; // Minimum distance between objects
  final List<Vector2> _recentSpawnPositions = [];
  static const int _maxRecentPositions = 5;

  GravitySpawnManager(this.game);

  void startSpawning() {
    spawnTimer?.cancel();
    _recentSpawnPositions.clear();

    // Make spawn rate depend on wave
    final baseSpawnRate = 2.0;
    final levelSpawnReduction = game.waveManager.level * 0.15;
    final waveSpawnReduction =
        game.waveManager.currentWave * 0.3; // 30% faster per wave
    final spawnRate = math.max(
        baseSpawnRate - levelSpawnReduction - waveSpawnReduction,
        0.3); // Minimum 0.3 seconds

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

    // Find a valid spawn position that's not too close to recent objects
    Vector2 spawnPosition;
    int attempts = 0;
    final maxAttempts = 10;

    do {
      final x = math.Random().nextDouble() * (gameSize.x - 80) + 40;
      spawnPosition = Vector2(x, -30);
      attempts++;

      // If we've tried too many times, just use this position
      if (attempts >= maxAttempts) break;
    } while (_isTooCloseToRecentSpawns(spawnPosition));

    // Add to recent positions and maintain list size
    _recentSpawnPositions.add(spawnPosition);
    if (_recentSpawnPositions.length > _maxRecentPositions) {
      _recentSpawnPositions.removeAt(0);
    }

    // Bomb/coin ratio increases with wave
    final bombChance =
        0.3 + 0.2 * (game.waveManager.currentWave - 1); // 0.3, 0.5, 0.7
    final type = math.Random().nextDouble() < (1 - bombChance)
        ? ObjectType.coin
        : ObjectType.bomb;

    final obj = GameObject(
      position: spawnPosition,
      type: type,
      level: game.waveManager.level,
      levelType: LevelType.gravity,
    );

    // Increase speed per wave - make it significantly faster
    final baseSpeedMultiplier = 1.0 + 0.4 * (game.waveManager.currentWave - 1);
    if (type == ObjectType.bomb || type == ObjectType.coin) {
      obj.velocity.y *= baseSpeedMultiplier;
    }

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
