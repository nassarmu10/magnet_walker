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

    final level = game.waveManager.level;
    final wave = game.waveManager.currentWave;

    // Smooth spawn rate scaling
    double spawnRate;
    if (level <= 10) {
      // Early–mid game: start at 1.2s → around 0.8s
      spawnRate = math.max(1.2 - (wave - 1) * 0.08 - (level - 1) * 0.03, 0.6);
    } else if (level <= 25) {
      // Mid–high game: scale more gradually
      spawnRate = math.max(0.9 - (wave - 1) * 0.05 - (level - 10) * 0.02, 0.45);
    } else {
      // High levels: don’t flood, cap around 0.35s
      spawnRate =
          math.max(0.7 - (wave - 1) * 0.04 - (level - 25) * 0.015, 0.35);
    }

    spawnTimer = async.Timer.periodic(
      Duration(milliseconds: (spawnRate * 1000).round()),
      (timer) {
        if (game.currentState == GameState.playing) {
          spawnObject();
        }
      },
    );
  }

  void spawnObject() {
    final gameSize =
        game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);

    // Choose x position
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

    final level = game.waveManager.level;
    final wave = game.waveManager.currentWave;

    // Smooth bomb chance scaling
    double bombChance;
    if (level <= 10) {
      bombChance = 0.25 + 0.08 * (wave - 1); // ~25% → 50%
    } else if (level <= 25) {
      bombChance = 0.35 + 0.1 * (wave - 1); // ~35% → 70%
    } else {
      bombChance = math.min(0.5 + 0.12 * (wave - 1), 0.85); // cap at 85%
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

    // Smooth velocity scaling
    double speedMultiplier;
    if (level <= 10) {
      speedMultiplier = 1.2 + 0.15 * (wave - 1);
    } else if (level <= 25) {
      speedMultiplier = 1.5 + 0.2 * (wave - 1) + 0.05 * (level - 10);
    } else {
      speedMultiplier = 2.0 + 0.25 * (wave - 1) + 0.1 * (level - 25);
    }

    // Apply downward velocity with slight random angle
    final angle =
        (math.pi / 2) + (math.Random().nextDouble() - 0.5) * math.pi / 3;
    final baseSpeed = 60.0;
    obj.velocity =
        Vector2(math.cos(angle), math.sin(angle)) * baseSpeed * speedMultiplier;

    if (game.spawnPortal != null) {
      game.spawnPortal?.spawnFlash();
      obj.position = game.spawnPortal!.position;
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
