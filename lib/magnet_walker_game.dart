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
  int score = 0;
  int level = 1;
  int levelProgress = 0;
  int targetScore = 10;
  bool gameRunning = true;

  // Wave system
  int currentWave = 1;
  int scoreThisWave = 0;
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
  int lives = 5;
  int maxLives = 5;
  int lifeRegenMinutes = 1;
  int? lastLifeTimestamp; // Epoch millis

  @override
  Future<void> onLoad() async {
    // Wait for the game to be fully initialized
    await Future.delayed(const Duration(milliseconds: 50));

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
    currentLevelType = LevelTypeConfig.getLevelType(level);

    // Add background first
    background = Background();
    add(background);

    // Load saved progress (level and wave)
    await loadProgress();
    // Load lives system state
    await loadLives();
    // Regenerate lives on game start
    regenerateLivesIfNeeded();

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
    currentWave = currentWave == 0 ? 1 : currentWave; // Ensure at least wave 1
    scoreThisWave = 0;
    isWaveActive = false;
    isLevelComplete = false;
    waveMessage = null;
    await Future.delayed(const Duration(milliseconds: 100));
    // Only start wave if lives > 0
    if (lives > 0) {
      tryConsumeLifeAndStartWave(currentWave);
    } else {
      // Show no lives dialog after UI is ready
      Future.delayed(const Duration(milliseconds: 200), () {
        if (gameUI.isMounted) {
          gameUI.showNoLivesDialog();
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

  void startWave(int wave) {
    currentWave = wave;
    score = 0;
    scoreThisWave = 0;
    isWaveActive = true;
    waveMessage = null;
    gameRunning = true;
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
    final currentLevelType = LevelTypeConfig.getLevelType(level);
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
    } else if (currentWave < 3) {
      waveCountdown = 3.0;
      waveMessage = 'Wave $currentWave/3 Complete!';
    } else {
      // Level complete: show dialog immediately
      isLevelComplete = true;
      showLevelCompleteDialog();
    }

    // Save progress after wave ends
    saveProgress();
  }

  void showWaveFailedDialog() {
    gameUI.showWaveFailedDialog(level, currentWave, () {
      // Restart level (wave 1)
      currentWave = 1;
      score = 0;
      scoreThisWave = 0;
      isWaveActive = false;
      isLevelComplete = false;
      waveMessage = null;
      Future.delayed(const Duration(milliseconds: 300), () {
        tryConsumeLifeAndStartWave(1);
      });
    }, () {
      // Watch ad to restart wave (simulate ad)
      score = 0;
      scoreThisWave = 0;
      isWaveActive = false;
      isLevelComplete = false;
      waveMessage = null;
      Future.delayed(const Duration(milliseconds: 300), () {
        tryConsumeLifeAndStartWave(currentWave);
      });
    });
  }

  void updateWaveCountdown(double dt) {
    if (!isWaveActive && waveCountdown > 0) {
      waveCountdown -= dt;
      if (waveCountdown <= 0) {
        if (currentWave < 3) {
          waveMessage = 'Wave ${currentWave + 1}/3 starting...';
          Future.delayed(const Duration(seconds: 1), () {
            startWave(currentWave + 1);
          });
        } else {
          // Level complete
          isLevelComplete = true;
          showLevelCompleteDialog();
        }
      } else {
        waveMessage =
            'Wave ${currentWave + 1}/3 starting in ${waveCountdown.ceil()}';
      }
    }
  }

  void showLevelCompleteDialog() {
    gameUI.showLevelCompleted(score, level, playTime);
  }

  void collectObject(GameObject obj) {
    if (!obj.isMounted) return;

    if (obj.type == ObjectType.coin) {
      score += 10;
      scoreThisWave += 10;
      levelProgress++;
      createParticles(obj.position, Colors.yellow);

      if (scoreThisWave >= 10 && isWaveActive) {
        endWave();
        return;
      }

      // Check if player reached target score for current level
      if (levelProgress >= targetScore) {
        nextLevel();
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

  void nextLevel() {
    level++;
    currentWave = 1;
    score = 0;
    scoreThisWave = 0;
    isWaveActive = false;
    isLevelComplete = false;
    waveMessage = null;
    levelProgress = 0;
    targetScore = level * 8 + 5;
    player.upgradeMagnet(level);
    currentLevelType = LevelTypeConfig.getLevelType(level);
    startWave(1);
  }

  void restartGame() {
    // Reset game state
    score = 0;
    level = 1;
    levelProgress = 0;
    targetScore = 10;
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

  void continueToNextLevel() {
    // Resume play time before starting new level
    resumePlayTime();
    // Increment level and reset score but keep play time
    level++;
    currentWave = 1;
    score = 0;
    scoreThisWave = 0;
    isWaveActive = false;
    isLevelComplete = false;
    waveMessage = null;
    levelProgress = 0;
    targetScore = level * 8 + 5;
    currentLevelType = LevelTypeConfig.getLevelType(level);
    clearAllObjects();
    player.reset();
    player.upgradeMagnet(level);
    startWave(1);
    gameUI.hideLevelCompleted();

    // Save progress after level changes
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
    if (gameRunning) {
      //player.moveHorizontally(event.localDelta.x * 0.5);
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
    // Existing tap logic here
    if (gameRunning && currentLevelType == LevelType.survival) {
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
    regenerateLivesIfNeeded();

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

  // Save current level and wave to SharedPreferences
  Future<void> saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('saved_level', level);
  }

  // Load saved level and wave from SharedPreferences
  Future<void> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLevel = prefs.getInt('saved_level');
    final savedWave = prefs.getInt('saved_wave');
    if (savedLevel != null && savedWave != null) {
      level = savedLevel;
    }
  }

  // Save lives and last life timestamp to SharedPreferences
  Future<void> saveLives() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lives', lives);
    if (lastLifeTimestamp != null) {
      await prefs.setInt('last_life_timestamp', lastLifeTimestamp!);
    }
  }

  // Load lives and last life timestamp from SharedPreferences
  Future<void> loadLives() async {
    final prefs = await SharedPreferences.getInstance();
    lives = prefs.getInt('lives') ?? maxLives;
    lastLifeTimestamp = prefs.getInt('last_life_timestamp');
  }

  // Call this to update lives based on elapsed time
  void regenerateLivesIfNeeded() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lives >= maxLives) {
      // If already at max, reset timer
      lastLifeTimestamp = now;
      saveLives();
      return;
    }
    if (lastLifeTimestamp == null) {
      lastLifeTimestamp = now;
      saveLives();
      return;
    }
    final regenMillis = lifeRegenMinutes * 60 * 1000;
    int elapsed = now - lastLifeTimestamp!;
    int livesToAdd = elapsed ~/ regenMillis;
    if (livesToAdd > 0) {
      lives = (lives + livesToAdd).clamp(0, maxLives);
      // Set timestamp for next life (if not at max)
      if (lives < maxLives) {
        lastLifeTimestamp = lastLifeTimestamp! + livesToAdd * regenMillis;
      } else {
        lastLifeTimestamp = now;
      }
      saveLives();
    }
  }

  // Helper to consume a life and start a wave, or show no lives dialog
  void tryConsumeLifeAndStartWave(int wave) {
    if (lives > 0) {
      lives--;
      saveLives();
      startWave(wave);
    } else {
      gameUI.showNoLivesDialog();
    }
  }
}
