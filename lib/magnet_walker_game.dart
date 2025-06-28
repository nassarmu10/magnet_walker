import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async' as async;

import 'components/player.dart';
import 'components/game_object.dart';
import 'components/game_particle.dart';
import 'components/background.dart';
import 'components/game_ui.dart';

class MagnetWalkerGame extends FlameGame
    with HasCollisionDetection, DragCallbacks {
  late Player player;
  late GameUI gameUI;
  late Background background;

  // Game state
  int score = 0;
  int level = 1;
  int levelProgress = 0;
  int targetScore = 10;
  bool gameRunning = true;

  // Play time tracking
  DateTime? gameStartTime;
  DateTime? pauseStartTime;
  Duration playTime = Duration.zero;
  Duration pausedTime = Duration.zero;
  async.Timer? playTimeTimer;

  // Spawning
  async.Timer? spawnTimer;
  final List<GameObject> gameObjects = [];
  final List<GameParticle> particles = [];

  @override
  Future<void> onLoad() async {
    // Wait for the game to be fully initialized
    await Future.delayed(const Duration(milliseconds: 50));

    // Set up camera with proper size
    camera.viewfinder.visibleGameSize = Vector2(375, 667);

    // Add background first
    background = Background();
    add(background);

    // Add player - use camera size for positioning
    final gameSize = camera.viewfinder.visibleGameSize!;
    player = Player(position: Vector2(gameSize.x / 2, gameSize.y - 117));
    add(player);

    // Add UI last to ensure game size is available
    gameUI = GameUI();
    add(gameUI);

    // Start play time tracking
    startPlayTimeTracking();

    // Start spawning objects after everything is loaded
    await Future.delayed(const Duration(milliseconds: 100));
    startSpawning();
  }

  void startPlayTimeTracking() {
    // If this is the first time starting, set the start time
    if (gameStartTime == null) {
      gameStartTime = DateTime.now();
    }

    // Cancel existing timer if any
    playTimeTimer?.cancel();

    playTimeTimer = async.Timer.periodic(const Duration(seconds: 1), (timer) {
      if (gameRunning && gameStartTime != null) {
        // Calculate total time minus paused time
        final totalTime = DateTime.now().difference(gameStartTime!);
        playTime = totalTime - pausedTime;
      }
    });
  }

  void startSpawning() {
    spawnTimer?.cancel(); // Cancel existing timer if any
    // Spawn rate decreases with level (faster spawning)
    final baseSpawnRate = 2.0;
    final levelSpawnReduction = level * 0.15; // 15% faster spawning per level
    final spawnRate = math.max(
        baseSpawnRate - levelSpawnReduction, 0.5); // Minimum 0.5 seconds

    spawnTimer = async.Timer.periodic(
        Duration(milliseconds: (spawnRate * 1000).round()), (timer) {
      // ← The timer parameter here
      if (gameRunning) {
        spawnObject();
      }
    });
  }

  void spawnObject() {
    final gameSize = camera.viewfinder.visibleGameSize ?? Vector2(375, 667);
    final x = math.Random().nextDouble() * (gameSize.x - 60) + 30;
    final type =
        math.Random().nextDouble() < 0.7 ? ObjectType.coin : ObjectType.bomb;
    final obj = GameObject(
      position: Vector2(x, -20),
      type: type,
      level: level,
    );
    add(obj);
    gameObjects.add(obj);
  }

  void collectObject(GameObject obj) {
    if (!obj.isMounted) return;

    if (obj.type == ObjectType.coin) {
      score += 10;
      levelProgress++;
      createParticles(obj.position, Colors.yellow);

      // Check if player reached 100 points (level completion)
      if (score >= 100) {
        levelCompleted();
        return;
      }

      // Check if player reached target score for current level
      if (levelProgress >= targetScore) {
        nextLevel();
      }
    } else {
      gameOver();
      createParticles(obj.position, Colors.red);
    }

    obj.removeFromParent();
    gameObjects.remove(obj);
  }

  void createParticles(Vector2 position, Color color) {
    // Ensure position is valid
    if (position.x.isNaN ||
        position.y.isNaN ||
        position.x.isInfinite ||
        position.y.isInfinite) {
      return;
    }

    for (int i = 0; i < 8; i++) {
      final particle = GameParticle(
        position: Vector2.copy(position),
        velocity: Vector2(
          (math.Random().nextDouble() - 0.5) * 200,
          (math.Random().nextDouble() - 0.5) * 200,
        ),
        color: color,
      );
      add(particle);
      particles.add(particle);
    }
  }

  void levelCompleted() {
    gameRunning = false;
    spawnTimer?.cancel();
    playTimeTimer?.cancel();

    // Clear all objects immediately when level ends
    clearAllObjects();

    // Pause play time when showing dialog
    pausePlayTime();

    // Show level completion dialog
    gameUI.showLevelCompleted(score, level, playTime);
  }

  void nextLevel() {
    level++;
    levelProgress = 0;
    targetScore = level * 8 + 5;
    player.upgradeMagnet(level);
    startSpawning(); // Restart timer with new spawn rate
  }

  void gameOver() {
    gameRunning = false;
    spawnTimer?.cancel();
    playTimeTimer?.cancel();

    // Clear all objects immediately when game ends
    clearAllObjects();

    // Pause play time when showing dialog
    pausePlayTime();

    // Show game over dialog
    gameUI.showGameOver(score, level, playTime);
  }

  void clearAllObjects() {
    // Clear all game objects
    for (final obj in gameObjects) {
      obj.removeFromParent();
    }
    gameObjects.clear();

    // Clear all particles
    for (final particle in particles) {
      particle.removeFromParent();
    }
    particles.clear();
  }

  void restartGame() {
    // Reset game state
    score = 0;
    level = 1;
    levelProgress = 0;
    targetScore = 10;
    gameRunning = true;
    playTime = Duration.zero;
    pausedTime = Duration.zero;
    gameStartTime = null; // Reset start time for new game
    pauseStartTime = null; // Reset pause time for new game

    // Clear all objects using the helper method
    clearAllObjects();

    // Reset player
    player.reset();

    // Restart timers
    startPlayTimeTracking();
    startSpawning();

    // Hide game over UI
    gameUI.hideGameOver();
  }

  void continueToNextLevel() {
    // Resume play time before starting new level
    resumePlayTime();

    // Increment level and reset score but keep play time
    level++;
    score = 0;
    levelProgress = 0;
    targetScore = level * 8 + 5;
    gameRunning = true;

    // Clear all objects using the helper method
    clearAllObjects();

    // Reset player position and upgrade magnet
    player.reset();
    player.upgradeMagnet(level);

    // Restart spawning with faster speed for next level
    startSpawning();

    // Hide level completion UI
    gameUI.hideLevelCompleted();
  }

  void pausePlayTime() {
    if (pauseStartTime == null) {
      pauseStartTime = DateTime.now();
      // Stop the timer immediately
      playTimeTimer?.cancel();
    }
  }

  void resumePlayTime() {
    if (pauseStartTime != null) {
      final pauseDuration = DateTime.now().difference(pauseStartTime!);
      pausedTime += pauseDuration;
      pauseStartTime = null;
      // Restart the timer
      startPlayTimeTracking();
    }
  }

  @override
  bool onDragStart(DragStartEvent event) {
    return true; // Accept all drag events
  }

  @override
  bool onDragUpdate(DragUpdateEvent event) {
    // Forward drag events to the player for better control
    if (gameRunning) {
      player.moveHorizontally(event.localDelta.x * 0.5);
    }
    return true;
  }

  @override
  bool onDragEnd(DragEndEvent event) {
    return true; // Accept all drag events
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (gameRunning) {
      // Update magnetic effects
      for (final obj in List.from(gameObjects)) {
        if (obj.isMounted) {
          player.applyMagneticForce(obj, dt);
        }
      }

      // Clean up particles and objects that are no longer mounted
      particles.removeWhere((particle) {
        if (!particle.isMounted) {
          return true;
        }
        // Also remove particles with invalid life values
        if (particle.life <= 0) {
          particle.removeFromParent();
          return true;
        }
        return false;
      });

      gameObjects.removeWhere((obj) => !obj.isMounted);
    }
  }

  @override
  void onRemove() {
    spawnTimer?.cancel();
    playTimeTimer?.cancel();
    super.onRemove();
  }
}
