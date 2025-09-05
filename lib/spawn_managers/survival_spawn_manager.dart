import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async' as async;

import '../../magnet_walker_game.dart';
import '../../components/game_object.dart';
import '../../level_types.dart';

class SurvivalSpawnManager {
  final MagnetWalkerGame game;
  async.Timer? spawnTimer;

  SurvivalSpawnManager(this.game);

  void startSpawning() {
    spawnTimer?.cancel();

    // Base spawn delay (slower by default)
    final baseSpawnRate = 2.0; // start at 1 spawn every 2s

    // Scale per level (very gentle until 30)
    final levelFactor =
        (game.waveManager.level <= 30) ? game.waveManager.level * 0.03 : 0.9;

    // Scale per wave (gentle too)
    final waveFactor =
        (game.waveManager.currentWave - 1) * 0.05; // small wave boost

    // Final spawn rate (never faster than 0.8s before lvl 30, 0.3s after)
    final spawnRate = (baseSpawnRate - levelFactor - waveFactor)
        .clamp(0.8, game.waveManager.level < 30 ? 0.8 : 0.3);

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
    print('Spawning object called');
    print(game.waveManager.currentWave.toString());
    final gameSize =
        game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);
    final playerPos = game.player?.position;

    // Choose spawn edge (0: top, 1: right, 2: bottom, 3: left)
    final edge = math.Random().nextInt(4);
    Vector2 spawnPosition;

    switch (edge) {
      case 0: // Top
        spawnPosition = Vector2(
          math.Random().nextDouble() * gameSize.x,
          -20,
        );
        break;
      case 1: // Right
        spawnPosition = Vector2(
          gameSize.x + 20,
          math.Random().nextDouble() * gameSize.y,
        );
        break;
      case 2: // Bottom
        spawnPosition = Vector2(
          math.Random().nextDouble() * gameSize.x,
          gameSize.y + 20,
        );
        break;
      case 3: // Left
        spawnPosition = Vector2(
          -20,
          math.Random().nextDouble() * gameSize.y,
        );
        break;
      default:
        spawnPosition = Vector2(0, 0);
    }

    // Bomb/coin ratio scaling
    double baseBombChance;

// Before level 10: max 50% bombs
    if (game.waveManager.level < 10) {
      baseBombChance = 0.3 + 0.1 * (game.waveManager.currentWave - 1);
      // Wave 1 → 30%, Wave 3 → 50%
    }
// Mid levels 10–25: up to 65%
    else if (game.waveManager.level < 25) {
      baseBombChance = 0.4 + 0.1 * (game.waveManager.currentWave - 1);
      // Wave 1 → 40%, Wave 3 → 60%
    }
// High levels 25–40: up to 80%
    else if (game.waveManager.level < 55) {
      baseBombChance = 0.5 + 0.15 * (game.waveManager.currentWave - 1);
      // Wave 1 → 50%, Wave 3 → 80%
    }
// Insane mode 40+: up to 95%
    else {
      baseBombChance = 0.6 + 0.2 * (game.waveManager.currentWave - 1);
      // Wave 1 → 60%, Wave 3 → 95%
    }

// Clamp to avoid 100%
    final bombChance = baseBombChance.clamp(0.2, 0.95);
    final type = math.Random().nextDouble() < bombChance
        ? ObjectType.bomb
        : ObjectType.coin;

    final obj = GameObject(
      position: spawnPosition,
      type: type,
      level: game.waveManager.level,
      levelType: LevelType.survival,
    );
    // Increase speed per wave
    if (type == ObjectType.bomb || type == ObjectType.coin) {
      obj.velocity *= (1.0 + 0.2 * (game.waveManager.currentWave - 1));
    }

    game.add(obj);
  }

  void stop() {
    spawnTimer?.cancel();
  }
}
