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

    // Spawn rate for survival mode (slightly faster than gravity)
    final baseSpawnRate = 1.5;
    final levelSpawnReduction = game.waveManager.level * 0.1;
    final waveSpawnReduction =
        game.waveManager.currentWave * 0.2; // 20% faster per wave
    final spawnRate = math.max(
        baseSpawnRate - levelSpawnReduction - waveSpawnReduction,
        0.2); // Minimum 0.2 seconds

    spawnTimer = async.Timer.periodic(
        Duration(milliseconds: (spawnRate * 1000).round()), (timer) {
      if (game.gameRunning) {
        spawnObject();
      }
    });
  }

  void spawnObject() {
    print('Spawning object called');
    print(game.waveManager.currentWave.toString());
    final gameSize =
        game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);
    final playerPos = game.player.position;

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

    // Bomb/coin ratio increases with wave
    final bombChance =
        0.6 + 0.15 * (game.waveManager.currentWave - 1); // 0.6, 0.75, 0.9
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
    game.gameObjects.add(obj);
  }

  void stop() {
    spawnTimer?.cancel();
  }
}
