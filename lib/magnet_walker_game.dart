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
import 'level_types.dart';
import 'spawn_managers/gravity_spawn_manager.dart';
import 'spawn_managers/survival_spawn_manager.dart';

class MagnetWalkerGame extends FlameGame
    with HasCollisionDetection, DragCallbacks {
  late Player player;
  late GameUI gameUI;
  late Background background;

  // Level type management
  late GravitySpawnManager gravitySpawnManager;
  late SurvivalSpawnManager survivalSpawnManager;
  late LevelType currentLevelType;

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
  final List<GameObject> gameObjects = [];
  final List<GameParticle> particles = [];

  @override
  Future<void> onLoad() async {
    // Wait for the game to be fully initialized
    await Future.delayed(const Duration(milliseconds: 50));

    // Set up camera with proper size
    camera.viewfinder.visibleGameSize = Vector2(375, 667);

    // Initialize spawn managers
    gravitySpawnManager = GravitySpawnManager(this);
    survivalSpawnManager = SurvivalSpawnManager(this);

    // Set initial level type
    currentLevelType = LevelTypeConfig.getLevelType(level);

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
    // Stop any existing spawn managers
    gravitySpawnManager.stop();
    survivalSpawnManager.stop();

    // Start the appropriate spawn manager based on level type
    currentLevelType = LevelTypeConfig.getLevelType(level);

    if (currentLevelType == LevelType.gravity) {
      gravitySpawnManager.startSpawning();
    } else {
      survivalSpawnManager.startSpawning();
    }
  }

  void spawnObject() {
    // This method is now handled by the specific spawn managers
    // Keeping it for backward compatibility but it's not used
  }

  void collectObject(GameObject obj) {
    if (!obj.isMounted) return;

    if (obj.type == ObjectType.coin) {
      score += 10;
      levelProgress++;
      createParticles(obj.position, Colors.yellow);

      // Check if player reached 10 points (level completion)
      if (score >= 10) {
        levelCompleted();
        return;
      }

      // Check if player reached target score for current level
      if (levelProgress >= targetScore) {
        nextLevel();
      }
    } else {
      // Handle bomb collision based on level type
      if (currentLevelType == LevelType.gravity) {
        // In gravity mode, bomb collision = game over
        gameOver();
        createParticles(obj.position, Colors.red);
      } else {
        // In survival mode, bombs should be clicked, not collided with
        // If we reach here, it means the bomb hit the player = game over
        gameOver();
        createParticles(obj.position, Colors.red);
      }
    }

    obj.removeFromParent();
    gameObjects.remove(obj);
  }

  void destroyBomb(GameObject bomb) {
    if (bomb.type == ObjectType.bomb && bomb.isMounted) {
      createParticles(bomb.position, Colors.orange);
      bomb.removeFromParent();
      gameObjects.remove(bomb);
    }
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
    gravitySpawnManager.stop();
    survivalSpawnManager.stop();
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
    gravitySpawnManager.stop();
    survivalSpawnManager.stop();
    playTimeTimer?.cancel();

    // Clear all objects immediately when game ends
    clearAllObjects();

    // Pause play time when showing dialog
    pausePlayTime();

    // Show game over dialog
    gameUI.showGameOver(score, level, playTime);
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
  bool onTapDown(TapDownEvent event) {
    // Handle tap events for survival mode (bomb destruction and coin collection)
    if (gameRunning && currentLevelType == LevelType.survival) {
      final tapPosition = event.localPosition;

      // Check if any object was tapped
      for (final obj in List.from(gameObjects)) {
        if (obj.isMounted) {
          final distance = tapPosition.distanceTo(obj.position);
          if (distance < obj.radius + 15) {
            // Larger tap area for easier clicking
            if (obj.type == ObjectType.bomb) {
              // Destroy bomb
              destroyBomb(obj);
              return true;
            } else if (obj.type == ObjectType.coin) {
              // Collect coin
              collectObject(obj);
              return true;
            }
          }
        }
      }
    }
    return true;
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
    gravitySpawnManager.stop();
    survivalSpawnManager.stop();
    playTimeTimer?.cancel();
    super.onRemove();
  }
}
