import 'dart:async' as async;
import 'dart:math' as math;
import 'package:flame/components.dart';
import '../magnet_walker_game.dart';
import '../components/game_object.dart';
import '../config/game_config.dart';
import '../level_types.dart';

abstract class BaseSpawnManager {
  final MagnetWalkerGame game;
  async.Timer? spawnTimer;

  BaseSpawnManager(this.game);

  // Abstract methods that must be implemented by subclasses
  double getSpawnRate();
  Vector2 getSpawnPosition();
  double getBombChance();
  double getObjectSpeed();

  // Common spawn logic
  void startSpawning() {
    spawnTimer?.cancel();

    final spawnRate = getSpawnRate();
    final spawnInterval = Duration(milliseconds: (spawnRate * 1000).round());

    spawnTimer = async.Timer.periodic(spawnInterval, (timer) {
      // Only spawn if game is running AND wave is active AND wave is not complete
      // AND spawn timer is not null (additional safety check)
      if (spawnTimer != null &&
          game.gameRunning &&
          game.isWaveActive &&
          !game.waveManager.isWaveComplete()) {
        print(
            'Spawning object - gameRunning: ${game.gameRunning}, isWaveActive: ${game.isWaveActive}');
        spawnObject();
      } else {
        print(
            'Spawn blocked - timer: ${spawnTimer != null}, gameRunning: ${game.gameRunning}, isWaveActive: ${game.isWaveActive}, waveComplete: ${game.waveManager.isWaveComplete()}');
      }
    });
  }

  void spawnObject() {
    final gameSize = game.canvasSize;
    final spawnPosition = getSpawnPosition();
    final bombChance = getBombChance();
    final type = math.Random().nextDouble() < bombChance
        ? ObjectType.bomb
        : ObjectType.coin;

    final obj = GameObject(
      position: spawnPosition,
      type: type,
      level: game.waveManager.level,
      levelType: game.waveManager.level % 2 == 1
          ? LevelType.gravity
          : LevelType.survival,
    );

    // Apply speed based on level and wave
    final speed = getObjectSpeed();
    if (game.waveManager.level % 2 == 1) {
      // Gravity mode
      obj.velocity.y = speed;
    } else {
      // Survival mode
      final playerPos = game.player.position;
      final direction = (playerPos - obj.position)..normalize();
      obj.velocity = direction * speed;
    }

    game.add(obj);
    game.gameObjects.add(obj);
  }

  void stop() {
    spawnTimer?.cancel();
  }

  // Force stop spawning immediately (for wave completion)
  void forceStop() {
    print('Force stopping spawn manager');
    spawnTimer?.cancel();
    spawnTimer = null;
    print('Spawn timer cancelled and set to null');
  }

  // Helper method to get random position within bounds
  Vector2 getRandomPositionInBounds(Vector2 gameSize, double margin) {
    return Vector2(
      math.Random().nextDouble() * (gameSize.x - margin * 2) + margin,
      math.Random().nextDouble() * (gameSize.y - margin * 2) + margin,
    );
  }

  // Helper method to get edge spawn position
  Vector2 getEdgeSpawnPosition(Vector2 gameSize, int edge) {
    switch (edge) {
      case 0: // Top
        return Vector2(
          math.Random().nextDouble() * gameSize.x,
          -GameConfig.offscreenBuffer,
        );
      case 1: // Right
        return Vector2(
          gameSize.x + GameConfig.offscreenBuffer,
          math.Random().nextDouble() * gameSize.y,
        );
      case 2: // Bottom
        return Vector2(
          math.Random().nextDouble() * gameSize.x,
          gameSize.y + GameConfig.offscreenBuffer,
        );
      case 3: // Left
        return Vector2(
          -GameConfig.offscreenBuffer,
          math.Random().nextDouble() * gameSize.y,
        );
      default:
        return Vector2.zero();
    }
  }
}
