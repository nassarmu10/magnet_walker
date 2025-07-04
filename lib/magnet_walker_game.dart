import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async' as async;
import 'package:shared_preferences/shared_preferences.dart';

import 'components/player.dart';
import 'components/game_object.dart';
import 'components/game_particle.dart';
import 'components/background.dart';
import 'components/game_ui.dart';
import 'level_types.dart';
import 'spawn_managers/gravity_spawn_manager.dart';
import 'spawn_managers/survival_spawn_manager.dart';
import 'managers/lives_manager.dart';
import 'managers/wave_manager.dart';
import 'managers/ad_manager.dart';

class MagnetWalkerGame extends FlameGame
    with HasCollisionDetection, DragCallbacks, TapCallbacks {
  late Player player;
  late GameUI gameUI;
  late Background background;

  // Level type management
  late GravitySpawnManager gravitySpawnManager;
  late SurvivalSpawnManager survivalSpawnManager;
  late LevelType currentLevelType;

  // Game state
  bool gameRunning = true;

  // Wave system
  bool isWaveActive = false;
  double waveCountdown = 0.0;
  String? waveMessage;
  bool isLevelComplete = false;

  // Play time tracking
  DateTime? gameStartTime;
  DateTime? pauseStartTime;
  Duration playTime = Duration.zero;
  Duration pausedTime = Duration.zero;
  async.Timer? playTimeTimer;

  // Spawning
  final List<GameObject> gameObjects = [];
  final List<GameParticle> particles = [];

  // Lives system fields
  late LivesManager livesManager;
  late WaveManager waveManager;

  bool noLivesDialogVisible = false;

  @override
  Future<void> onLoad() async {
    // Wait for the game to be fully initialized
    await Future.delayed(const Duration(milliseconds: 50));

    // Initialize AdManager
    await AdManager.initialize();
    await AdManager.loadRewardedAd();

    // Preload images
    try {
      await images.load('rocket.png');
      print('Rocket image preloaded successfully');
    } catch (e) {
      print('Failed to preload rocket image: $e');
    }

    try {
      await images.load('rocket-2.png');
      print('Rocket image preloaded successfully');
    } catch (e) {
      print('Failed to preload rocket image: $e');
    }
    // Set up camera with proper size
    camera.viewfinder.visibleGameSize = Vector2(375, 667);

    // Initialize spawn managers
    gravitySpawnManager = GravitySpawnManager(this);
    survivalSpawnManager = SurvivalSpawnManager(this);

    // Set initial level type
    currentLevelType = LevelTypeConfig.getLevelType(1);

    // Add background first
    background = Background();
    add(background);

    // Initialize wave manager first
    waveManager = WaveManager();
    // Load saved progress (level and wave)
    await loadProgress();
    // Initialize lives manager
    livesManager = LivesManager();
    await livesManager.load();
    livesManager.regenerateLivesIfNeeded();

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
    isWaveActive = false;
    isLevelComplete = false;
    waveMessage = null;
    await Future.delayed(const Duration(milliseconds: 100));
    // Only start wave if lives > 0
    if (livesManager.lives > 0) {
      tryConsumeLifeAndStartWave(waveManager.currentWave);
    } else {
      // Show no lives dialog after UI is ready
      noLivesDialogVisible =
          true; // Set the flag when showing dialog from onLoad
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (gameUI.isMounted && gameUI.game.buildContext != null) {
          gameUI.showNoLivesDialog(onDialogClosed: () {
            noLivesDialogVisible = false;
          });
        } else {
          // If still not ready, try again after a short delay
          Future.delayed(const Duration(milliseconds: 100), () {
            if (gameUI.isMounted) {
              gameUI.showNoLivesDialog(onDialogClosed: () {
                noLivesDialogVisible = false;
              });
            }
          });
        }
      });
    }
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
        if (playTime.isNegative) playTime = Duration.zero;
      }
    });
  }

  void startSpawning() {
    // Stop any existing spawn managers
    gravitySpawnManager.stop();
    survivalSpawnManager.stop();

    // Do not start spawning if no lives left
    if (livesManager.lives == 0) return;

    // Start the appropriate spawn manager based on level type
    currentLevelType = LevelTypeConfig.getLevelType(1);

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

  void startWave(int wave) {
    print(
        'startWave called with wave: $wave, lives: \\${livesManager.lives}, gameRunning: \\${gameRunning}');
    waveManager.currentWave = wave;
    waveManager.score = 0;
    waveManager.scoreThisWave = 0;
    waveManager.levelProgress = 0;
    waveManager.targetScore = wave * 8 + 5;
    isWaveActive = true;
    gameRunning = true;
    waveCountdown = 0;
    waveMessage = null;
    startSpawning();
    print(
        'Wave started successfully - isWaveActive: \\${isWaveActive}, gameRunning: \\${gameRunning}');
    // Optionally, adjust player, etc.
  }

  void endWave({bool failed = false}) {
    isWaveActive = false;
    gameRunning = false;
    gravitySpawnManager.stop();
    survivalSpawnManager.stop();
    clearAllObjects(); // Clear all objects immediately

    // Animate player back to initial position depending on level type
    final gameSize = camera.viewfinder.visibleGameSize ?? Vector2(375, 667);
    Vector2 initialPosition;
    final currentLevelType = LevelTypeConfig.getLevelType(1);
    if (currentLevelType == LevelType.gravity) {
      // Gravity mode: bottom center
      initialPosition = Vector2(gameSize.x / 2, gameSize.y - 117);
    } else {
      // Survival mode: center
      initialPosition = Vector2(gameSize.x / 2, gameSize.y / 2);
    }
    player.animateToPosition(initialPosition, 2.7); // 2.7 seconds animation

    if (failed) {
      showWaveFailedDialog();
    } else if (waveManager.currentWave < 3) {
      waveCountdown = 3.0;
      waveMessage = 'Wave ${waveManager.currentWave}/3 Complete!';
    } else {
      // Level complete: show dialog immediately
      isLevelComplete = true;
      showLevelCompleteDialog();
    }

    // Save progress after wave ends
    saveProgress();
  }

  void showWaveFailedDialog() {
    gameUI.showWaveFailedDialog(waveManager.level, waveManager.currentWave, () {
      // Restart level (wave 1)
      waveManager.currentWave = 1;
      waveManager.score = 0;
      waveManager.scoreThisWave = 0;
      waveManager.levelProgress = 0;
      Future.delayed(const Duration(milliseconds: 300), () {
        tryConsumeLifeAndStartWave(1);
      });
    }, () {
      // Watch ad to restart wave
      AdManager.showRewardedAd(
        onRewarded: () {
          // Restart the current wave without consuming a life
          waveManager.score = 0;
          waveManager.scoreThisWave = 0;
          Future.delayed(const Duration(milliseconds: 300), () {
            startWaveWithoutConsumingLife(waveManager.currentWave);
          });
        },
      );
    });
  }

  void updateWaveCountdown(double dt) {
    if (!isWaveActive && waveCountdown > 0) {
      waveCountdown -= dt;
      if (waveCountdown <= 0) {
        if (waveManager.currentWave < 3) {
          waveMessage = 'Wave ${waveManager.currentWave + 1}/3 starting...';
          Future.delayed(const Duration(seconds: 1), () {
            startWave(waveManager.currentWave + 1);
          });
        } else {
          // Level complete
          isLevelComplete = true;
          showLevelCompleteDialog();
        }
      } else {
        waveMessage =
            'Wave ${waveManager.currentWave + 1}/3 starting in ${waveCountdown.ceil()}';
      }
    }
  }

  void showLevelCompleteDialog() {
    gameUI.showLevelCompleted(waveManager.score, waveManager.level, playTime);
  }

  void collectObject(GameObject obj) {
    if (!obj.isMounted) return;

    if (obj.type == ObjectType.coin) {
      waveManager.score += 10;
      waveManager.scoreThisWave += 10;
      waveManager.levelProgress++;
      createParticles(obj.position, Colors.yellow);

      if (waveManager.scoreThisWave >= 10 && isWaveActive) {
        endWave();
        return;
      }

      // Check if player reached target score for current level
      if (waveManager.levelProgress >= waveManager.targetScore) {
        // Progress to next level
        waveManager.nextLevel();
        // Optionally, show a dialog or start the next wave
        tryConsumeLifeAndStartWave(waveManager.currentWave);
        return;
      }
    } else {
      // Handle bomb collision based on level type
      if (currentLevelType == LevelType.gravity) {
        endWave(failed: true);
        createParticles(obj.position, Colors.red);
      } else {
        endWave(failed: true);
        createParticles(obj.position, Colors.red);
      }
    }

    obj.removeFromParent();
    gameObjects.remove(obj);
  }

  void destroyBomb(GameObject bomb) {
    print('Destroying bomb');
    if (bomb.type == ObjectType.bomb && bomb.isMounted) {
      createParticles(bomb.position, Colors.red);
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

  void gameOver() {
    // Not used for wave fail anymore
    gameRunning = false;
    gravitySpawnManager.stop();
    survivalSpawnManager.stop();
    playTimeTimer?.cancel();
    clearAllObjects();
    pausePlayTime();
    // Show game over dialog if needed (handled by endWave now)
  }

  void restartGame() {
    // Reset game state
    waveManager.score = 0;
    waveManager.level = 1;
    waveManager.levelProgress = 0;
    waveManager.targetScore = 10;
    gameRunning = true;
    playTime = Duration.zero;
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

    // Save progress after restart
    saveProgress();
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
      // Clamp pausedTime to not exceed totalTime
      final totalTime = DateTime.now().difference(gameStartTime!);
      if (pausedTime > totalTime) {
        pausedTime = totalTime;
      }
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
    // Allow movement only when game is running and we have lives
    print('onDragUpdate called');
    print(isWaveActive);
    print(gameRunning);
    print(livesManager.lives);
    if (gameRunning && livesManager.lives > 0 && isWaveActive) {
      player.moveBy(event.localDelta.x * 0.5, event.localDelta.y * 0.5);
    }
    return true;
  }

  @override
  bool onDragEnd(DragEndEvent event) {
    return true; // Accept all drag events
  }

  @override
  void onTapDown(TapDownEvent event) {
    print('onTapDown called');
    print(isWaveActive);
    print(gameRunning);
    print(livesManager.lives);
    // Existing tap logic here
    if (gameRunning &&
        livesManager.lives > 0 &&
        isWaveActive &&
        currentLevelType == LevelType.survival) {
      final tapPosition = event.localPosition;
      for (final obj in List.from(gameObjects)) {
        if (obj.isMounted && !obj.collected && obj.type == ObjectType.bomb) {
          final distance = tapPosition.distanceTo(obj.position);
          if (distance < obj.radius + 15) {
            obj.collected = true;
            destroyBomb(obj);
            return;
          }
        }
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    updateWaveCountdown(dt);
    // Regenerate lives periodically while running
    livesManager.regenerateLivesIfNeeded();

    // Manage No Lives Left dialog state
    if (livesManager.lives == 0 && !noLivesDialogVisible) {
      print(
          'Showing No Lives Left dialog - lives: ${livesManager.lives}, flag: $noLivesDialogVisible');
      noLivesDialogVisible = true;
      gameUI.showNoLivesDialog(onDialogClosed: () {
        noLivesDialogVisible = false;
      });
      // Stop all spawning if lives are zero
      gravitySpawnManager.stop();
      survivalSpawnManager.stop();
    } else if (livesManager.lives > 0 && noLivesDialogVisible) {
      // If we now have lives but the dialog was visible, reset the flag
      print(
          'Resetting No Lives Left dialog flag - lives: ${livesManager.lives}, flag: $noLivesDialogVisible');
      noLivesDialogVisible = false;
    }

    // Update game objects only when game is running and we have lives
    if (gameRunning && livesManager.lives > 0) {
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
    AdManager.disposeAds();
    super.onRemove();
  }

  // Save current level and wave to SharedPreferences
  Future<void> saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('saved_level', waveManager.level);
  }

  // Load saved level and wave from SharedPreferences
  Future<void> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLevel = prefs.getInt('saved_level');
    final savedWave = prefs.getInt('saved_wave');
    if (savedLevel != null && savedWave != null) {
      waveManager.level = savedLevel;
    }
  }

  // Helper to consume a life and start a wave, or show no lives dialog
  void tryConsumeLifeAndStartWave(int wave) {
    print(
        'tryConsumeLifeAndStartWave called with wave: $wave, lives: ${livesManager.lives}');
    if (livesManager.tryConsumeLife()) {
      print('Life consumed successfully, starting wave $wave');
      waveManager.startWave(wave);
      startWave(wave);
    } else {
      print('Failed to consume life, showing no lives dialog');
      gameUI.showNoLivesDialog();
    }
  }

  // Helper to start a wave without consuming a life (for ad rewards)
  void startWaveWithoutConsumingLife(int wave) {
    print(
        'startWaveWithoutConsumingLife called with wave: $wave, lives: \\${livesManager.lives}');
    // Ensure proper game state
    gameRunning = true;
    isWaveActive = true;
    waveCountdown = 0;
    waveMessage = null;
    noLivesDialogVisible = false;
    waveManager.startWave(wave);
    startWave(wave);
  }

  // Helper to dismiss any existing dialogs and reset state
  void dismissNoLivesDialog() {
    noLivesDialogVisible = false;
    gameRunning = true;
  }
}
