import 'package:flame/components.dart';
import 'dart:math' as math;
import '../../magnet_walker_game.dart';
import '../../components/game_object.dart';
import '../../config/game_config.dart';
import 'base_spawn_manager.dart';

class SurvivalSpawnManager extends BaseSpawnManager {
  SurvivalSpawnManager(super.game);

  @override
  double getSpawnRate() {
    return GameConfig.calculateSurvivalSpawnRate(
        game.waveManager.level, game.waveManager.currentWave);
  }

  @override
  Vector2 getSpawnPosition() {
    final gameSize = game.canvasSize;
    // Choose spawn edge (0: top, 1: right, 2: bottom, 3: left)
    final edge = math.Random().nextInt(4);
    return getEdgeSpawnPosition(gameSize, edge);
  }

  @override
  double getBombChance() {
    return GameConfig.calculateSurvivalBombChance(game.waveManager.currentWave);
  }

  @override
  double getObjectSpeed() {
    return GameConfig.calculateSurvivalSpeed(
        game.waveManager.level, game.waveManager.currentWave);
  }
}
