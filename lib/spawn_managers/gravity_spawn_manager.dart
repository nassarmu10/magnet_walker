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
    print('Spawning object called');
    print(game.waveManager.currentWave);
    final gameSize =
        game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);
    final x = math.Random().nextDouble() * (gameSize.x - 60) + 30;
    // Bomb/coin ratio increases with wave
    final bombChance =
        0.3 + 0.2 * (game.waveManager.currentWave - 1); // 0.3, 0.5, 0.7
    final type = math.Random().nextDouble() < (1 - bombChance)
        ? ObjectType.coin
        : ObjectType.bomb;

    final obj = GameObject(
      position: Vector2(x, -20),
      type: type,
      level: game.waveManager.level,
      levelType: LevelType.gravity,
    );
    // Increase speed per wave
    if (type == ObjectType.bomb || type == ObjectType.coin) {
      obj.velocity.y *= (1.0 + 0.2 * (game.waveManager.currentWave - 1));
    }
    game.add(obj);
  }

  void stop() {
    spawnTimer?.cancel();
  }
}
