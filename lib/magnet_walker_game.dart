import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:magnet_walker/skins/skin_model.dart';
import 'dart:math' as math;
import 'dart:async' as async;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flame_audio/flame_audio.dart';

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

  // Score and level progression
  int totalScore =
      0; // Accumulative score across all levels/waves (never resets)
  int wavesNeededToNextLevel = 3; // Waves needed to complete current level
  int wavesCompletedInLevel = 0; // Waves completed in current level

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
    // camera.viewfinder.visibleGameSize = Vector2(375, 667);

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
    final gameSize = canvasSize;
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

  // Update player position based on current level type
  void _updatePlayerPositionForLevelType() {
    final gameSize = canvasSize;
    final currentLevelType = LevelTypeConfig.getLevelType(waveManager.level);
    Vector2 initialPosition;

    if (currentLevelType == LevelType.gravity) {
      // Gravity mode: bottom center
      initialPosition = Vector2(gameSize.x / 2, gameSize.y - 117);
    } else {
      // Survival mode: center
      initialPosition = Vector2(gameSize.x / 2, gameSize.y / 2);
    }

    // Animate player to new position
    player.animateToPosition(initialPosition, 2.7);
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
    waveManager.startWave(wave);

    // Show countdown for all waves, including wave 1
    waveCountdown = 3.0;
    isWaveActive = false;
    gameRunning = false;
    waveMessage = 'Wave $wave/3 starting in 3';

    // Ensure player is in correct position for current level type
    if (wave == 1) {
      _updatePlayerPositionForLevelType();
    }

    // The actual wave will start after countdown in updateWaveCountdown
  }

  // Move to the next level
  void nextLevel() async {
    waveManager.level++;
    waveManager.currentWave = 1;
    wavesCompletedInLevel = 0;
    waveManager.resetWaveScore();

    // NEW: Check for newly available skins (not auto-unlock, just available for purchase)
    final newlyAvailableSkins = _checkForNewAvailableSkins(waveManager.level);

    // NEW: Show notification for newly available skins
    if (newlyAvailableSkins.isNotEmpty) {
      _showNewSkinsAvailableNotification(newlyAvailableSkins);
    }

    // Update player position for new level type
    _updatePlayerPositionForLevelType();

    // Save progress immediately after advancing to a new level
    saveProgress();
  }

  List<Skin> _checkForNewAvailableSkins(int currentLevel) {
    final newlyAvailable = <Skin>[];

    for (final skin in skinManager.skins) {
      // If skin is not unlocked and requires exactly this level, it's newly available
      if (!skin.isUnlocked && skin.price == currentLevel) {
        newlyAvailable.add(skin);
      }
    }

    return newlyAvailable;
  }

  void _showNewSkinsAvailableNotification(List<Skin> newSkins) {
    // Show notification after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      final context = buildContext;
      if (context == null || newSkins.isEmpty) return;

      showDialog(
        context: context,
        builder: (context) {
          final screenWidth = MediaQuery.of(context).size.width;
          final dialogWidth = screenWidth * 0.85;

          return AlertDialog(
            backgroundColor: const Color(0xFF1a1a2e),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dialogWidth * 0.07),
              side: BorderSide(
                color: Colors.pinkAccent.withOpacity(0.5),
                width: 2,
              ),
            ),
            title: Text(
              newSkins.length > 1
                  ? 'NEW SKINS AVAILABLE!'
                  : 'NEW SKIN AVAILABLE!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: dialogWidth * 0.08,
                fontWeight: FontWeight.bold,
                color: Colors.pinkAccent,
                letterSpacing: 1.5,
                shadows: const [
                  Shadow(
                    offset: Offset(0, 0),
                    blurRadius: 10,
                    color: Colors.pinkAccent,
                  ),
                ],
              ),
            ),
            content: Container(
              width: dialogWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show newly available skins
                  ...newSkins.map((skin) => Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.pinkAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.pinkAccent.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.pinkAccent.withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/${skin.imagePath}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            Colors.pinkAccent.withOpacity(0.3),
                                            Colors.pinkAccent.withOpacity(0.1)
                                          ],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.public,
                                        color: Colors.pinkAccent,
                                        size: 20,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    skin.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    skin.description,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Watch ad icon
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.pinkAccent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    'AD',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),
                  Text(
                    'Watch ads to unlock these ${newSkins.length > 1 ? 'skins' : 'skin'} in the Skin Store!',
                    style: TextStyle(
                      color: Colors.pinkAccent.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'LATER',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Open skin store directly to the "Available" tab
                        _openSkinStore();
                      },
                      child: const Text(
                        'SKIN STORE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    });
  }

  void _openSkinStore() {
    final context = buildContext;
    if (context == null) return;

    // You can either navigate to skin store or show a message
    // This depends on how your app navigation is set up
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Open the menu to access the Skin Store!'),
        backgroundColor: Colors.pinkAccent,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Helper to play audio
  void playSound(String fileName) {
    FlameAudio.play(fileName);
  }

  void endWave({bool failed = false}) {
    isWaveActive = false;
    gameRunning = false;
    gravitySpawnManager.stop();
    survivalSpawnManager.stop();
    clearAllObjects(); // Clear all objects immediately

    // Animate player back to initial position depending on level type
    final gameSize = canvasSize;
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
      playSound('lose.mp3');
      // Show unified failure dialog
      gameUI.showFailureDialog(
        score: totalScore,
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
            waveManager.startWave(1);
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
              clearAllObjects();
              final currentWave = waveManager.currentWave;
              waveManager.startWave(currentWave);
              Future.delayed(const Duration(milliseconds: 300), () {
                startWaveWithoutConsumingLife(currentWave);
              });
            },
          );
        },
      );
    } else {
      // Wave completed successfully
      wavesCompletedInLevel++;

      if (wavesCompletedInLevel >= wavesNeededToNextLevel) {
        // Level complete: show dialog immediately
        isLevelComplete = true;
        showLevelCompleteDialog();
      } else {
        // More waves to go - start countdown for next wave
        waveManager.currentWave++;
        startWave(waveManager.currentWave);
      }
    }

    // Save progress after wave ends
    saveProgress();
  }

  void updateWaveCountdown(double dt) {
    if (!isWaveActive && waveCountdown > 0) {
      waveCountdown -= dt;
      if (waveCountdown <= 0) {
        // Start the actual wave
        isWaveActive = true;
        gameRunning = true;
        waveMessage = null;
        startSpawning();
      } else {
        waveMessage =
            'Wave ${waveManager.currentWave}/3 starting in ${waveCountdown.ceil()}';
      }
    }
  }

  void showLevelCompleteDialog() {
    playSound('win.mp3');
    gameUI.showLevelCompleted(totalScore, waveManager.level, playTime);
  }

  void collectObject(GameObject obj) {
    if (!obj.isMounted) return;

    if (obj.type == ObjectType.coin) {
      totalScore += 1;
      waveManager.addWaveScore(1);
      createParticles(obj.position, Colors.yellow);
      playSound('coin.wav');

      if (waveManager.isWaveComplete() && isWaveActive) {
        endWave();
        return;
      }
    } else {
      // Handle bomb collision based on level type
      if (currentLevelType == LevelType.gravity) {
        endWave(failed: true);
        createParticles(obj.position, Colors.red);
        playSound('bomb.wav');
      } else {
        endWave(failed: true);
        createParticles(obj.position, Colors.red);
        playSound('bomb.wav');
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
      playSound('bomb.wav');
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
    waveManager.startWave(1);
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
    if (gameRunning && isWaveActive) {
      // Increase movement speed and responsiveness
      player.moveBy(event.localDelta.x * 1, event.localDelta.y * 1);
    }
    return true;
  }

  @override
  bool onDragEnd(DragEndEvent event) {
    return true; // Accept all drag events
  }

  @override
  void onTapDown(TapDownEvent event) {
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

  // Save current level and total score to SharedPreferences
  Future<void> saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('saved_level', waveManager.level);
    await prefs.setInt('saved_total_score', totalScore);
  }

  // Load saved level and total score from SharedPreferences
  Future<void> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLevel = prefs.getInt('saved_level');
    final savedTotalScore = prefs.getInt('saved_total_score');
    if (savedLevel != null) {
      waveManager.level = savedLevel;
    }
    if (savedTotalScore != null) {
      totalScore = savedTotalScore;
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

  // Play button sound on tap
  void playButtonSound() {
    playSound('button.mp3');
  }
}
