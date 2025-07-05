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
import 'skins/skin_manager.dart';


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

  // ADD THIS: Skin system
  late SkinManager skinManager;

  bool noLivesDialogVisible = false;

  @override
  Future<void> onLoad() async {
    // Wait for the game to be fully initialized
    await Future.delayed(const Duration(milliseconds: 50));

    // Initialize AdManager
    await AdManager.initialize();
    await AdManager.loadRewardedAd();
    await AdManager.loadInterstitialAd();

    // Initialize skin manager
    skinManager = SkinManager();
    await skinManager.initialize();

    // Preload images
    try {
      await images.load('rocket.png');
      await images.load('rocket-2.png');
      print('Rocket images preloaded successfully');
    } catch (e) {
      print('Failed to preload rocket images: $e');
    }

    // Preload all skin images
    await _preloadSkinImages();

    // Set up camera with proper size
    camera.viewfinder.visibleGameSize = Vector2(375, 667);

    // Initialize spawn managers
    gravitySpawnManager = GravitySpawnManager(this);
    survivalSpawnManager = SurvivalSpawnManager(this);

    // Add background first
    background = Background();
    add(background);

    // Initialize wave manager first
    waveManager = WaveManager();
    // Load saved progress (level and wave)
    await loadProgress();

    // Set initial level type
    currentLevelType = LevelTypeConfig.getLevelType(waveManager.level);
    // Initialize lives manager
    livesManager = LivesManager();
    await livesManager.load();
    livesManager.regenerateLivesIfNeeded();

    // Add player - position based on current level type
    final gameSize = camera.viewfinder.visibleGameSize!;
    Vector2 initialPosition;
    if (currentLevelType == LevelType.gravity) {
      // Gravity mode: bottom center
      initialPosition = Vector2(gameSize.x / 2, gameSize.y - 117);
    } else {
      // Survival mode: center
      initialPosition = Vector2(gameSize.x / 2, gameSize.y / 2);
    }
    player = Player(position: initialPosition);
    add(player);

    // Apply current skin to player
    await _updatePlayerSkin();

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
      noLivesDialogVisible = true;
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

  Future<void> _preloadSkinImages() async {
    final skinImages = [
      'player.png', // default
      'player_mars.png',
      'player_venus.png',
      'player_jupiter.png',
      'player_saturn.png',
      'player_neptune.png',
      'player_sun.png',
      'player_blackhole.png',
    ];

    for (final imageName in skinImages) {
      try {
        await images.load(imageName);
        print('Preloaded skin image: $imageName');
      } catch (e) {
        print('Failed to preload skin image $imageName: $e');
      }
    }
  }

  Future<void> _updatePlayerSkin() async {
    final selectedSkin = skinManager.selectedSkin;
    await player.updateSkin(selectedSkin.imagePath);
  }

  // Method to be called when skin changes
  Future<void> onSkinChanged() async {
    await _updatePlayerSkin();
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

    // Use the current level for level type
    currentLevelType = LevelTypeConfig.getLevelType(waveManager.level);

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
    final currentLevelType = LevelTypeConfig.getLevelType(waveManager.level);
    if (currentLevelType == LevelType.gravity) {
      // Gravity mode: bottom center
      initialPosition = Vector2(gameSize.x / 2, gameSize.y - 117);
    } else {
      // Survival mode: center
      initialPosition = Vector2(gameSize.x / 2, gameSize.y / 2);
    }
    player.animateToPosition(initialPosition, 2.7); // 2.7 seconds animation

    if (failed) {
      // Show unified failure dialog
      gameUI.showFailureDialog(
        score: waveManager.score,
        level: waveManager.level,
        wave: waveManager.currentWave,
        playTime: playTime,
        onRestartLevel: () {
          // Check if we have lives before restarting
          if (livesManager.lives == 0) {
            // Show no lives dialog if no lives available
            gameUI.showNoLivesDialog();
          } else {
            // Restart level (wave 1) - this will consume a life
            waveManager.currentWave = 1;
            waveManager.score = 0;
            waveManager.scoreThisWave = 0;
            waveManager.levelProgress = 0;
            Future.delayed(const Duration(milliseconds: 300), () {
              tryConsumeLifeAndStartWave(1);
            });
          }
        },
        onWatchAd: () {
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
        },
      );
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
    // Reset game state but keep the current level
    waveManager.score = 0;
    // Do NOT reset waveManager.level
    waveManager.currentWave = 1;
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

    // Stop any existing spawning
    gravitySpawnManager.stop();
    survivalSpawnManager.stop();

    // Hide game over UI
    gameUI.hideGameOver();

    // Save progress after restart
    saveProgress();

    // Start the first wave or show no lives dialog
    startGameOrShowNoLivesDialog();
  }

  void startGameOrShowNoLivesDialog() {
    if (livesManager.lives == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        gameUI.showNoLivesDialog();
      });
      return;
    }
    tryConsumeLifeAndStartWave(1);
  }

  void tryConsumeLifeAndStartWave(int wave) {
    if (livesManager.lives == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        gameUI.showNoLivesDialog();
      });
      return;
    }
    if (livesManager.tryConsumeLife()) {
      waveManager.startWave(wave);
      startWave(wave);
    }
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
    // Allow movement only when game is running and wave is active
    print('onDragUpdate called');
    print(isWaveActive);
    print(gameRunning);
    print(livesManager.lives);
    if (gameRunning && isWaveActive) {
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
    if (gameRunning && isWaveActive && currentLevelType == LevelType.survival) {
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

    // Check if we need to show no lives dialog
    if (livesManager.lives == 0 &&
        !noLivesDialogVisible &&
        !gameUI.gameOverVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (gameUI.isMounted && this.buildContext != null) {
          noLivesDialogVisible = true;
          gameUI.showNoLivesDialog(onDialogClosed: () {
            noLivesDialogVisible = false;
          });
        }
      });
    }

    // Update game objects only when game is running
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
    // Only set gameRunning to true if we have lives
    if (livesManager.lives > 0) {
      gameRunning = true;
    } else {
      // If no lives, keep game in a paused state
      gameRunning = false;
      isWaveActive = false;
    }
  }

  // Helper to handle Play Again from Game Over dialog
  void handlePlayAgain() {
    if (livesManager.lives > 0) {
      restartGame();
    } else {
      gameUI.showNoLivesDialog();
    }
  }
}
