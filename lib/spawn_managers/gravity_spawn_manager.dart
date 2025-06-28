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

  GravitySpawnManager(this.game);

  void startSpawning() {
    spawnTimer?.cancel();

    // Spawn rate decreases with level (faster spawning)
    final baseSpawnRate = 2.0;
    final levelSpawnReduction =
        game.level * 0.15; // 15% faster spawning per level
    final spawnRate = math.max(
        baseSpawnRate - levelSpawnReduction, 0.5); // Minimum 0.5 seconds

    spawnTimer = async.Timer.periodic(
        Duration(milliseconds: (spawnRate * 1000).round()), (timer) {
      if (game.gameRunning) {
        spawnObject();
      }
    });
  }

  void spawnObject() {
    final gameSize =
        game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);
    final x = math.Random().nextDouble() * (gameSize.x - 60) + 30;
    final type =
        math.Random().nextDouble() < 0.7 ? ObjectType.coin : ObjectType.bomb;

    final obj = GameObject(
      position: Vector2(x, -20),
      type: type,
      level: game.level,
      levelType: LevelType.gravity,
    );

    game.add(obj);
    game.gameObjects.add(obj);
  }

  void stop() {
    spawnTimer?.cancel();
  }
}
