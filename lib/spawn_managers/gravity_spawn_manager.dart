import 'package:flame/components.dart';
import 'dart:math' as math;
import '../../magnet_walker_game.dart';
import '../../components/game_object.dart';
import '../../config/game_config.dart';
import 'base_spawn_manager.dart';

class GravitySpawnManager extends BaseSpawnManager {
  GravitySpawnManager(super.game);

  @override
  double getSpawnRate() {
    return GameConfig.calculateGravitySpawnRate(
        game.waveManager.level, game.waveManager.currentWave);
  }

  @override
  Vector2 getSpawnPosition() {
    final gameSize = game.canvasSize;
    final x = math.Random().nextDouble() * (gameSize.x - 60) + 30;
    return Vector2(x, -GameConfig.offscreenBuffer);
  }

  @override
  double getBombChance() {
    return GameConfig.calculateGravityBombChance(game.waveManager.currentWave);
  }

  @override
  double getObjectSpeed() {
    return GameConfig.calculateGravitySpeed(
        game.waveManager.level, game.waveManager.currentWave);
  }
}
