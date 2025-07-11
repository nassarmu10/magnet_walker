import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:magnet_walker/skins/skin_model.dart';
import 'package:magnet_walker/skins/skin_store_screen.dart';
import 'dart:math' as math;
import 'dart:async' as async;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flame_audio/flame_audio.dart';
import 'config/game_config.dart';

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

  // Audio settings
  bool sfxEnabled = true;

  // Callback for game restart
  VoidCallback? onGameRestart;

  // Wave system
  bool isWaveActive = false;
  double waveCountdown = 0.0;
  String? waveMessage;
  bool isLevelComplete = false;
  bool isPaused = false;
  VoidCallback? onExitToMenu;

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

  // Method to set the exit callback
  void setExitCallback(VoidCallback callback) {
    onExitToMenu = callback;
  }

  // Method to pause the game (freezes all game logic)
  void pauseGame() {
    isPaused = true;
    pausePlayTime();

    // Stop all spawning
    gravitySpawnManager.stop();
    survivalSpawnManager.stop();

    // The game objects will remain in their current positions
    // because the update loop will be skipped
  }

  // Method to resume the game
  void resumeGame() {
    isPaused = false;
    resumePlayTime();

    // Resume spawning only if wave is active
    if (isWaveActive && gameRunning) {
      startSpawning();
    }
  }

  // Method to exit to menu
  void exitToMainMenu() {
    // Reset game state
    isPaused = false;
    gameRunning = false;
    isWaveActive = false;

    // Stop all timers and spawning
    gravitySpawnManager.stop();
    survivalSpawnManager.stop();
    playTimeTimer?.cancel();

    // Clear all objects
    clearAllObjects();

    // Save progress
    saveProgress();

    // Call the exit callback
    if (onExitToMenu != null) {
      onExitToMenu!();
    }
  }

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
    gameUI.setExitCallback(() {
      exitToMainMenu();
    });

    // Start play time tracking
    startPlayTimeTracking();

    // Start spawning objects after everything is loaded
    isWaveActive = false;
    isLevelComplete = false;
    waveMessage = null;
    await Future.delayed(const Duration(milliseconds: 100));
    // Only start wave if lives > 0
    if (livesManager.lives > 0) {
      startLevel(waveManager.level, waveManager.currentWave);
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

  void spawnObject() {
    // This method is now handled by the specific spawn managers
    // Keeping it for backward compatibility but it's not used
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

    // Start the new level
    startLevel(waveManager.level, 1);
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
    // IMPORTANT: Pause the game when showing skin notification
    pauseGame();

    // Show notification after a short delay to ensure game is properly paused
    Future.delayed(const Duration(milliseconds: 500), () {
      final context = buildContext;
      if (context == null || newSkins.isEmpty) {
        // Resume game if we can't show dialog
        resumeGame();
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissing by tapping outside
        builder: (context) {
          final screenWidth = MediaQuery.of(context).size.width;
          final dialogWidth = screenWidth * 0.9; // Made slightly wider
          final padding = dialogWidth * 0.05;
          final titleFontSize = dialogWidth * 0.09;
          final bodyFontSize = dialogWidth * 0.045;
          final buttonFontSize = dialogWidth * 0.055;

          return WillPopScope(
            onWillPop: () async => false, // Prevent back button
            child: AlertDialog(
              backgroundColor: const Color(0xFF1a1a2e),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(dialogWidth * 0.06),
                side: BorderSide(
                  color: Colors.amber.withOpacity(0.8),
                  width: 3,
                ),
              ),
              title: Column(
                children: [
                  // Celebration icon
                  Container(
                    padding: EdgeInsets.all(padding),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.amber.withOpacity(0.3),
                          Colors.amber.withOpacity(0.1),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: Colors.amber,
                      size: titleFontSize * 0.8,
                    ),
                  ),
                  SizedBox(height: padding * 0.5),
                  Text(
                    'CONGRATULATIONS!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                      letterSpacing: 2.0,
                      shadows: const [
                        Shadow(
                          offset: Offset(0, 0),
                          blurRadius: 15,
                          color: Colors.amber,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: padding * 0.3),
                  Text(
                    'Level ${waveManager.level} Reached!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: bodyFontSize * 1.2,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              content: Container(
                width: dialogWidth,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Unlock message
                    Container(
                      padding: EdgeInsets.all(padding * 0.8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.withOpacity(0.2),
                            Colors.amber.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(dialogWidth * 0.04),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.4),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            newSkins.length > 1
                                ? '🎉 ${newSkins.length} NEW SKINS UNLOCKED! 🎉'
                                : '🎉 NEW SKIN UNLOCKED! 🎉',
                            style: TextStyle(
                              fontSize: bodyFontSize * 1.1,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                              letterSpacing: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: padding * 0.5),
                          Text(
                            'You can now purchase ${newSkins.length > 1 ? 'these awesome skins' : 'this awesome skin'} with ads!',
                            style: TextStyle(
                              fontSize: bodyFontSize,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: padding),

                    // Show newly available skins in a scrollable container
                    if (newSkins.isNotEmpty)
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.15,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: newSkins
                                .map((skin) => Container(
                                      margin: EdgeInsets.symmetric(
                                          vertical: padding * 0.2),
                                      padding: EdgeInsets.all(padding * 0.6),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.deepPurple.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(
                                            dialogWidth * 0.03),
                                        border: Border.all(
                                          color: Colors.deepPurple
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Skin image
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.deepPurple
                                                      .withOpacity(0.4),
                                                  blurRadius: 8,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                            child: ClipOval(
                                              child: Image.asset(
                                                'assets/images/${skin.imagePath}',
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return Container(
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      gradient: RadialGradient(
                                                        colors: [
                                                          Colors.deepPurple
                                                              .withOpacity(0.3),
                                                          Colors.deepPurple
                                                              .withOpacity(0.1)
                                                        ],
                                                      ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.public,
                                                      color: Colors.deepPurple,
                                                      size: 20,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: padding * 0.8),
                                          // Skin info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  skin.name,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: bodyFontSize,
                                                  ),
                                                ),
                                                Text(
                                                  skin.description,
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(0.7),
                                                    fontSize:
                                                        bodyFontSize * 0.8,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Watch ad icon
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: padding * 0.4,
                                              vertical: padding * 0.2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.pinkAccent,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.play_arrow,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'AD',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize:
                                                        bodyFontSize * 0.7,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                Column(
                  children: [
                    // Go to store button
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(buttonFontSize * 1.2),
                          gradient: const LinearGradient(
                            colors: [Colors.pinkAccent, Colors.deepPurple],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.pinkAccent.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _openSkinStore();
                            // Don't resume game yet - let skin store handle it
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(
                              horizontal: padding,
                              vertical: padding * 0.8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(buttonFontSize * 1.2),
                            ),
                          ),
                          icon: Icon(
                            Icons.store,
                            color: Colors.white,
                            size: buttonFontSize,
                          ),
                          label: Text(
                            'OPEN SKIN STORE',
                            style: TextStyle(
                              fontSize: buttonFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: padding * 0.6),
                    // Close button
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(buttonFontSize * 1.2),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Resume the game
                            resumeGame();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(
                              horizontal: padding,
                              vertical: padding * 0.8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(buttonFontSize * 1.2),
                            ),
                          ),
                          icon: Icon(
                            Icons.close,
                            color: Colors.white.withOpacity(0.8),
                            size: buttonFontSize,
                          ),
                          label: Text(
                            'CONTINUE PLAYING',
                            style: TextStyle(
                              fontSize: buttonFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withOpacity(0.8),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: padding * 0.4),
                    // Small hint text
                    Text(
                      '💡 You can always access skins from the main menu',
                      style: TextStyle(
                        fontSize: bodyFontSize * 0.8,
                        color: Colors.white.withOpacity(0.6),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ).then((_) {
        // Ensure game is resumed if dialog is closed unexpectedly
        if (isPaused) {
          resumeGame();
        }
      });
    });
  }

  void _openSkinStore() {
    final context = buildContext;
    if (context == null) return;

    // Navigate to skin store screen
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => SkinStoreScreen(
          skinManager: skinManager,
          currentLevel: waveManager.level,
          onSkinChanged: () {
            onSkinChanged();
          },
        ),
      ),
    )
        .then((_) {
      // Resume game when returning from skin store
      if (isPaused) {
        resumeGame();
      }
    });
  }

  // Helper to play audio
  void playSound(String fileName) {
    if (sfxEnabled) {
      FlameAudio.play(fileName);
    }
  }

  // Method to update SFX setting
  void setSfxEnabled(bool enabled) {
    sfxEnabled = enabled;
  }

  // Method to stop game music
  void stopGameMusic() {
    FlameAudio.bgm.stop();
  }

  // Method to restart game music
  void restartGameMusic() {
    FlameAudio.bgm.play('game_music.mp3');
  }

  void updateWaveCountdown(double dt) {
    if (!isWaveActive && waveCountdown > 0) {
      waveCountdown -= dt;
      if (waveCountdown <= 0) {
        // Start the actual wave - but only if game is not in a failed state
        if (gameRunning || !gameUI.gameOverVisible) {
          print('Starting wave after countdown');
          isWaveActive = true;
          gameRunning = true;
          waveMessage = null;
          startSpawning();
        } else {
          print(
              'Countdown finished but game is in failed state - not starting wave');
          waveCountdown = 0.0;
          waveMessage = null;
        }
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

    // Remove the object first to prevent any further interactions
    obj.removeFromParent();
    gameObjects.remove(obj);

    if (obj.type == ObjectType.coin) {
      totalScore += 1;
      waveManager.addWaveScore(1);
      createParticles(obj.position, Colors.yellow);
      playSound('coin.wav');

      // Check if wave is complete after adding score
      if (waveManager.isWaveComplete() && isWaveActive) {
        print(
            'Wave complete! Score: ${waveManager.waveScore}/${waveManager.waveTarget}');
        endWave(waveManager.currentWave);
        return;
      }
    } else {
      // Handle bomb collision based on level type
      if (currentLevelType == LevelType.gravity) {
        endWave(waveManager.currentWave, failed: true);
        createParticles(obj.position, Colors.red);
        playSound('bomb.wav');
      } else {
        endWave(waveManager.currentWave, failed: true);
        createParticles(obj.position, Colors.red);
        playSound('bomb.wav');
      }
    }
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

    // Notify main wrapper about game restart
    onGameRestart?.call();
  }

  void startGameOrShowNoLivesDialog() {
    if (livesManager.lives == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        gameUI.showNoLivesDialog();
      });
      return;
    }
    startLevel(waveManager.level, 1);
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
      print("REMOVING OBJECT: ${obj.type}");
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
    if (isPaused) return false;
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
    print(
        "onTapDown - gameRunning: $gameRunning, isWaveActive: $isWaveActive, levelType: $currentLevelType");
    if (isPaused) return;

    // Only handle taps in survival mode when game is active
    if (gameRunning && isWaveActive && currentLevelType == LevelType.survival) {
      final tapPosition = event.localPosition;
      print("Checking for bombs at tap position: $tapPosition");

      for (final obj in List.from(gameObjects)) {
        if (obj.isMounted && !obj.collected && obj.type == ObjectType.bomb) {
          final distance = tapPosition.distanceTo(obj.position);
          print(
              "Bomb at ${obj.position}, distance: $distance, radius: ${obj.radius}");

          if (distance < obj.radius + 15) {
            print("Bomb tapped! Destroying...");
            obj.collected = true;
            destroyBomb(obj);
            return;
          }
        }
      }
      print("No bombs found at tap position");
    }
  }

  @override
  void update(double dt) {
    // Handle wave countdown even when paused (but don't start spawning if paused)
    if (!isPaused) {
      updateWaveCountdown(dt);
    }

    // Regenerate lives periodically while running (even when paused)
    livesManager.regenerateLivesIfNeeded();

    // Check if we need to show no lives dialog (only when not paused)
    if (!isPaused &&
        livesManager.lives == 0 &&
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

    // Only update game logic when not paused
    if (!isPaused && gameRunning) {
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
        if (particle.life <= 0) {
          particle.removeFromParent();
          return true;
        }
        return false;
      });

      gameObjects.removeWhere((obj) => !obj.isMounted);
    }

    // Always call super.update, but game objects won't update if paused
    if (!isPaused) {
      super.update(dt);
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

  // ===== CORE GAME FUNCTIONS =====

  // Start a level (consumes a life)
  void startLevel(int levelNumber, int waveNumber) {
    print(
        'startLevel called - level: $levelNumber, wave: $waveNumber, lives: ${livesManager.lives}');

    // Check if we have lives
    if (livesManager.lives == 0) {
      print('No lives left, showing no lives dialog');
      gameUI.showNoLivesDialog();
      return;
    }

    // Consume a life
    if (!livesManager.tryConsumeLife()) {
      print('Failed to consume life');
      gameUI.showNoLivesDialog();
      return;
    }

    // Set level and wave
    waveManager.level = levelNumber;
    waveManager.currentWave = waveNumber;
    wavesCompletedInLevel = 0;

    // Update level type
    currentLevelType = LevelTypeConfig.getLevelType(levelNumber);

    // Reset game state
    isWaveActive = false;
    gameRunning = false;
    isLevelComplete = false;
    noLivesDialogVisible = false;

    // Clear all objects and stop spawning
    clearAllObjects();
    gravitySpawnManager.forceStop();
    survivalSpawnManager.forceStop();

    // Hide any existing dialogs
    gameUI.hideFailureDialog();
    gameUI.hideGameOver();

    // Start the wave
    startWave(waveNumber);

    // Notify main wrapper about game restart
    onGameRestart?.call();
  }

  // Start a wave
  void startWave(int waveNumber) {
    print('startWave called - wave: $waveNumber');

    // Set wave
    waveManager.currentWave = waveNumber;
    waveManager.startWave(waveNumber);

    // Show countdown
    waveCountdown = 3.0;
    isWaveActive = false;
    gameRunning = false;
    waveMessage = 'Wave $waveNumber/3 starting in 3';

    // Ensure player is in correct position for current level type
    _updatePlayerPositionForLevelType();

    // The actual wave will start after countdown in updateWaveCountdown
  }

  // End a wave
  void endWave(int waveNumber, {bool failed = false}) {
    print('endWave called - wave: $waveNumber, failed: $failed');

    // GUARD: Prevent duplicate endWave logic if already ended
    if (gameUI.gameOverVisible) {
      print('endWave: already ended, dialog visible, skipping.');
      return;
    }

    // Stop wave activity immediately
    isWaveActive = false;
    gameRunning = false;

    // Stop all spawning immediately
    print('Stopping spawn managers...');
    gravitySpawnManager.forceStop();
    survivalSpawnManager.forceStop();

    // Cancel any countdown that might restart spawning
    waveCountdown = 0.0;
    waveMessage = null;

    // Clear all objects immediately
    print('Clearing all objects...');
    clearAllObjects();

    // Animate player back to initial position
    _updatePlayerPositionForLevelType();

    if (failed) {
      print('Wave failed - showing failure dialog');
      playSound('lose.mp3');
      stopGameMusic();

      // Show failure dialog
      gameUI.showFailureDialog(
        score: totalScore,
        level: waveManager.level,
        wave: waveNumber,
        playTime: playTime,
        onRestartLevel: () {
          print('onRestartLevel callback called');
          restartWave(waveNumber);
        },
        onWatchAd: () {
          AdManager.showRewardedAd(
            onRewarded: () {
              // Restart the current wave without consuming a life
              clearAllObjects();
              startWave(waveNumber);
              // Notify main wrapper about game restart
              onGameRestart?.call();
            },
            onFailed: () {
              final context = gameUI.game.buildContext;
              if (context != null) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('No Ad Available'),
                    content: const Text(
                        'No ad is available right now. Please try again later.'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // Re-show the failure dialog
                          gameUI.showFailureDialog(
                            score: totalScore,
                            level: waveManager.level,
                            wave: waveNumber,
                            playTime: playTime,
                            onRestartLevel: () {
                              restartWave(waveNumber);
                            },
                            onWatchAd: () {/* recursion handled */},
                          );
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
          );
        },
      );
    } else {
      // Wave completed successfully
      wavesCompletedInLevel++;

      if (wavesCompletedInLevel >= wavesNeededToNextLevel) {
        // Level complete
        isLevelComplete = true;
        showLevelCompleteDialog();
      } else {
        // More waves to go - start next wave
        startWave(waveNumber + 1);
      }
    }

    // Save progress
    saveProgress();
  }

  // Restart a wave (calls endWave and startWave)
  void restartWave(int waveNumber) {
    print('restartWave called - wave: $waveNumber');

    // Check if we have lives
    if (livesManager.lives == 0) {
      print('No lives left, showing no lives dialog');
      gameUI.hideFailureDialog();
      gameUI.showNoLivesDialog();
      return;
    }

    // Consume a life
    if (!livesManager.tryConsumeLife()) {
      print('Failed to consume life');
      gameUI.hideFailureDialog();
      gameUI.showNoLivesDialog();
      return;
    }

    // Hide failure dialog
    gameUI.hideFailureDialog();

    // Start the wave
    startWave(waveNumber);

    // Notify main wrapper about game restart
    onGameRestart?.call();
  }

  // ===== HELPER FUNCTIONS =====

  void _updatePlayerPositionForLevelType() {
    final gameSize = canvasSize;
    Vector2 initialPosition;

    if (currentLevelType == LevelType.gravity) {
      // Gravity mode: bottom center
      initialPosition = Vector2(
          gameSize.x / 2, gameSize.y - GameConfig.gravityModeBottomOffset);
    } else {
      // Survival mode: center
      initialPosition = Vector2(gameSize.x / 2, gameSize.y / 2);
    }

    player.animateToPosition(
        initialPosition, GameConfig.playerAnimationDuration);
  }

  void startSpawning() {
    // Safety check: don't start spawning if game is not running or wave is not active
    if (!gameRunning || !isWaveActive) {
      print(
          'startSpawning called but game not ready - gameRunning: $gameRunning, isWaveActive: $isWaveActive');
      return;
    }

    // Stop any existing spawn managers
    gravitySpawnManager.stop();
    survivalSpawnManager.stop();

    print('Starting spawn managers for level type: $currentLevelType');
    if (currentLevelType == LevelType.gravity) {
      gravitySpawnManager.startSpawning();
    } else {
      survivalSpawnManager.startSpawning();
    }
  }
}
