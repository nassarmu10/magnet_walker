import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:magnet_walker/components/demon.dart';
import 'package:magnet_walker/components/portal.dart';
import 'package:magnet_walker/skins/skin_model.dart';
import 'package:magnet_walker/skins/skin_store_screen.dart';
import 'package:magnet_walker/utils/screen_utils.dart';
import 'package:flame/parallax.dart';

import 'dart:math' as math;
import 'dart:async' as async;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';

import 'components/player.dart';
import 'components/game_object.dart';
import 'components/game_particle.dart';
import 'components/game_ui.dart';
import 'level_types.dart';
import 'spawn_managers/gravity_spawn_manager.dart';
import 'spawn_managers/survival_spawn_manager.dart';
import 'managers/lives_manager.dart';
import 'managers/wave_manager.dart';
import 'managers/ad_manager.dart';
import 'skins/skin_manager.dart';

enum GameState {
  menu,
  countdown,
  playing,
  paused,
  waveComplete,
  levelComplete,
  gameOver
}

class MagnetWalkerGame extends FlameGame
    with
        HasCollisionDetection,
        DragCallbacks,
        TapCallbacks,
        HasKeyboardHandlerComponents,
        WidgetsBindingObserver {
  Player? player;
  Demon? demon;
  GameUI? gameUI;
  SciFiPortal? spawnPortal;

  // Level type management
  late GravitySpawnManager gravitySpawnManager;
  late SurvivalSpawnManager survivalSpawnManager;
  late LevelType currentLevelType;

  // Game state
  GameState currentState = GameState.menu;

  // Audio settings
  bool sfxEnabled = true;
  bool musicEnabled = true;

  // Callback for game restart
  VoidCallback? onGameRestart;

  // Wave system
  double waveCountdown = 0.0;
  String? waveMessage;
  VoidCallback? onExitToMenu;

  // Score and level progression
  int totalScore =
      0; // Accumulative score across all levels/waves (never resets)
  // Waves needed to complete current level - calculated dynamically
  int get wavesNeededToNextLevel {
    if (waveManager.level <= 5) {
      return 1; // First 5 levels only need 1 wave
    } else {
      return 3; // Later levels need 3 waves
    }
  }

  int wavesCompletedInLevel = 0; // Waves completed in current level

  // Spawning
  final List<GameObject> gameObjects = [];
  final List<GameParticle> particles = [];

  // Lives system fields
  late LivesManager livesManager;
  late WaveManager waveManager;

  // ADD THIS: Skin system
  late SkinManager skinManager;

  bool noLivesDialogVisible = false;

  // Flag to track when game is intentionally paused for UI (popups, dialogs, etc.)
  bool isGameIntentionallyPaused = false;

  // Flag to track if user is navigating to skin store (to prevent auto-resume)
  bool isNavigatingToSkinStore = false;

  // Track the game state before pausing so we can restore it properly
  GameState? stateBeforePause;

  // Flag to track if level progression was handled manually (to prevent dialog fallback)
  bool levelProgressionHandled = false;

  // Method to set the exit callback
  void setExitCallback(VoidCallback callback) {
    onExitToMenu = callback;
  }

  // Method to exit to menu
  void exitToMainMenu() {
    // Reset game state
    currentState = GameState.menu;

    // Stop all timers and spawning
    gravitySpawnManager.stop();
    survivalSpawnManager.stop();

    // Clear all objects
    clearAllObjects();

    // Dispose of demon if exists
    if (demon != null) {
      demon!.removeFromParent();
      demon = null;
    }

    // Save progress
    saveProgress();
    stopGameMusic();

    // Call the exit callback - this should handle menu music restart
    if (onExitToMenu != null) {
      onExitToMenu!();
    }
  }

  @override
  void onMount() {
    super.onMount();
    // Register for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App went to background - pause music and game
        FlameAudio.bgm.pause();
        // Only pause engine if game is not already manually paused
        if (currentState != GameState.paused) {
          pauseGameForAppLifecycle();
          pauseEngine();
        }
        break;

      case AppLifecycleState.resumed:
        // App came to foreground - resume music and game
        if (musicEnabled) {
          FlameAudio.bgm.resume();
        }
        // Only resume if game was not manually paused
        if (currentState != GameState.paused) {
          resumeGameFromAppLifecycle();
          resumeEngine();
        }
        break;

      case AppLifecycleState.inactive:
        // Handle if needed (like when notification panel is pulled down)
        // Pause music but don't pause the entire game
        FlameAudio.bgm.pause();
        break;
    }
  }

  Future<void> _show_instructions() async {
    // Show instructions popup for first level of each type
    if (waveManager.level == 1 ||
        waveManager.level == 2 ||
        waveManager.level == 12) {
      await gameUI?.showInstructionsDialog(
        level: waveManager.level,
        onContinue: () {
          // This callback can be empty since we're using await
        },
      );
    }
  }

  @override
  Future<void> onLoad() async {
    // Wait for the game to be fully initialized
    final parallaxBackground = await loadParallax(
      [
        ParallaxImageData(
            'background-2.jpg'), // Closest layer // Farthest layer
      ],
      baseVelocity: Vector2(0, -20), // Scrolls upwards
      repeat: ImageRepeat
          .repeat, // Repeat both horizontally and vertically for tablets
      fill: LayerFill.width, // Fill the width to cover tablets properly
    );
    add(
      ParallaxComponent(
        parallax: parallaxBackground, // <-- wrap it here
      ),
    );
    await Future.delayed(const Duration(milliseconds: 50));

    // One-time initialization that should only happen once
    await _initializeOneTimeComponents();

    // Level-specific initialization that can be reused
    await _initializeLevel();

    //Start level
    await _startLevel();
    await _show_instructions();
  }

  /// Initialize or restart a level - can be called multiple times
  Future<void> _initializeLevel() async {
    // Clear any existing level-specific components
    _clearLevelComponents();

    // Set current level type
    currentLevelType = LevelTypeConfig.getLevelType(waveManager.level);

    // Regenerate lives if needed
    livesManager.regenerateLivesIfNeeded();

    // Add player - position based on current level type
    final gameSize = canvasSize;
    Vector2 initialPosition = _getPlayerInitialPosition(gameSize);

    player = Player(position: initialPosition);
    add(player as Component);

    // Apply current skin to player
    await _updatePlayerSkin();

    // Demon will be added after countdown

    // Add UI if not already added (only on first load)
    if (gameUI == null) {
      gameUI = GameUI();
      add(gameUI as Component);
      gameUI?.setExitCallback(() {
        exitToMainMenu();
      });
    }
    if (currentLevelType == LevelType.gravity && spawnPortal == null) {
      // Place the portal just under header
      final headerMarginX = gameSize.x * 0.025;
      final headerMarginY = gameSize.y * 0.025;
      final headerWidth = gameSize.x * 0.95;
      final portalSize = 60.0 * ScreenUtils.getScaleFactor(gameSize);
      spawnPortal = SciFiPortal(
        position: Vector2(
            headerMarginX + headerWidth / 2,
            headerMarginY +
                80 +
                ScreenUtils.getPreciseTopMargin(gameSize) +
                portalSize),
        size: portalSize,
      );

      add(spawnPortal as Component);
    }
  }

  Vector2 _getPlayerInitialPosition(Vector2 gameSize) {
    final actualSize = camera.viewfinder.visibleGameSize ?? gameSize;
    gameSize = actualSize;

    // Import screen utils for landscape-aware positioning
    final isLandscape = gameSize.x > gameSize.y;

    if (isLandscape) {
      // Landscape positioning - avoid UI areas
      switch (currentLevelType) {
        case LevelType.gravity:
          return Vector2(
              gameSize.x / 2, gameSize.y * 0.75); // Higher up in landscape
        case LevelType.demon:
          return Vector2(gameSize.x / 2, gameSize.y * 0.75);
        case LevelType.survival:
          return Vector2(gameSize.x / 2, gameSize.y / 2);
        default:
          return Vector2(gameSize.x / 2, gameSize.y / 2);
      }
    } else {
      // Portrait positioning (original)
      const double horizontalOffset = 10.0;
      switch (currentLevelType) {
        case LevelType.gravity:
          return Vector2(gameSize.x / 2 + horizontalOffset, gameSize.y - 117);
        case LevelType.demon:
          return Vector2(gameSize.x / 2 + horizontalOffset, gameSize.y - 117);
        case LevelType.survival:
          return Vector2(gameSize.x / 2 + horizontalOffset, gameSize.y / 2);
        default:
          return Vector2(gameSize.x / 2 + horizontalOffset, gameSize.y / 2);
      }
    }
  }

  /// Start the current level/wave
  Future<void> _startLevel() async {
    currentState = GameState.countdown;
    waveMessage = null;
    await Future.delayed(const Duration(milliseconds: 100));
    waveCountdown = 3.0;
    if (currentLevelType != LevelType.demon) {
      waveMessage =
          'Wave ${waveManager.currentWave}/$wavesNeededToNextLevel starting in 3';
    } else {
      waveMessage = 'Kill the demon';
    }
  }

  /// Clear level-specific components before restarting
  void _clearLevelComponents() {
    gravitySpawnManager.stop();
    survivalSpawnManager.stop();

    // Clear saved demon health when clearing level components (unless it's for ad continue)
    if (currentState != GameState.gameOver) {
      waveManager.clearDemonHealth();
    }

    // Remove player if exists
    if (player != null) {
      player!.removeFromParent();
      player = null;
    }

    // Remove demon if exists
    if (demon != null) {
      demon!.removeFromParent();
      demon = null;
    }

    // Remove portal if exists
    if (spawnPortal != null) {
      spawnPortal?.removeCompletely();
      spawnPortal = null;
    }
    clearAllObjects();
    // Clear any spawned objects, projectiles, etc.
    // Add other cleanup as needed for your specific game objects
  }

  /// Show no lives dialog
  void _showNoLivesDialog() {
    noLivesDialogVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (gameUI!.isMounted && gameUI?.game.buildContext != null) {
        gameUI?.showNoLivesDialog(onDialogClosed: () {
          noLivesDialogVisible = false;
        });
      } else {
        // If still not ready, try again after a short delay
        Future.delayed(const Duration(milliseconds: 100), () {
          if (gameUI!.isMounted) {
            gameUI?.showNoLivesDialog(onDialogClosed: () {
              noLivesDialogVisible = false;
            });
          }
        });
      }
    });
  }

  /// Call this method when the player loses and wants to restart
  Future<void> restartLevel() async {
    // Reset any game state
    currentState = GameState.menu; // or whatever initial state you want

    // Reinitialize the level
    await _initializeLevel();
  }

  /// One-time initialization that should only happen when the game first loads
  Future<void> _initializeOneTimeComponents() async {
    // Initialize AdManager
    await AdManager.initialize();
    await AdManager.loadRewardedAd();
    await AdManager.loadInterstitialAd();

    // Initialize skin manager
    skinManager = SkinManager();
    await skinManager.initialize();

    // Preload images
    try {
      await images.loadAll([
        'rocket.png',
        'rocket-2.png',
        'rocket-3.png',
        'rocket-4.png',
        'missile1.png',
        'missile2.png',
        'missile3.png',
        'missile4.png',
        'missile5.png',
        'missile6.png',
      ]);
    } catch (e) {
      print('Failed to preload rocket images: $e');
    }

    // Preload all skin images
    await _preloadSkinImages();

    // Initialize spawn managers
    gravitySpawnManager = GravitySpawnManager(this);
    survivalSpawnManager = SurvivalSpawnManager(this);

    // Initialize wave manager first
    waveManager = WaveManager();
    waveManager.setTarget();

    // Load saved progress (level and wave)
    await loadProgress();

    await loadSoundSettings();

    // Initialize lives manager
    livesManager = LivesManager();
    await livesManager.load();
  }

  Future<void> _preloadSkinImages() async {
    final skinImages = [
      "player.png", // default
      "whiteSS.png",
      "blue-yellow-SS.png",
      "red-yellow-SS.png",
      "graySS.png",
      "birdSS.png",
      "dogSS.png",
      "tenninSS.png",
      "GiraffeSS.png",
      "shitSS.png",
      "dolphinSS.png",
      "hippoSS.png",
      "lionSS.png",
      "pigSS.png",
      "starSS.png",
      "tigerSS.png",
    ];

    try {
      await images.loadAll(skinImages);
    } catch (e) {
      print('Failed to preload skin images: $e');
    }
  }

  Future<void> _updatePlayerSkin() async {
    if (player != null) {
      final selectedSkin = skinManager.selectedSkin;
      await player?.updateSkin(selectedSkin.imagePath);
    }
  }

  // Method to be called when skin changes
  Future<void> onSkinChanged() async {
    await _updatePlayerSkin();
  }

  // Update player position based on current level type
  void _updatePlayerPositionForLevelType() {
    final gameSize = canvasSize;
    double horizontalOffset = player!.radius / 2;
    final currentLevelType = LevelTypeConfig.getLevelType(waveManager.level);
    Vector2 initialPosition = Vector2(gameSize.x / 2, gameSize.y / 2);

    if (currentLevelType == LevelType.gravity) {
      initialPosition = Vector2(
          gameSize.x / 2 + horizontalOffset, gameSize.y - 117); // Add this line
    } else if (currentLevelType == LevelType.survival) {
      // Survival mode: center
      initialPosition =
          Vector2(gameSize.x / 2 + horizontalOffset, gameSize.y / 2);
    } else if (currentLevelType == LevelType.demon) {
      initialPosition =
          Vector2(gameSize.x / 2 + horizontalOffset, gameSize.y / 4);
    }
    // Animate player to new position
    player?.animateToPosition(initialPosition, 2.7);
  }

  void startSpawning() {
    // Stop any existing spawn managers
    gravitySpawnManager.stop();
    survivalSpawnManager.stop();
    // Use the current level for level type
    currentLevelType = LevelTypeConfig.getLevelType(waveManager.level);

    if (currentLevelType == LevelType.gravity) {
      gravitySpawnManager.startSpawning();
    } else if (currentLevelType == LevelType.survival) {
      survivalSpawnManager.startSpawning();
    } else if (currentLevelType == LevelType.demon) {}
  }

  void spawnObject() {
    // This method is now handled by the specific spawn managers
    // Keeping it for backward compatibility but it's not used
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
    isGameIntentionallyPaused = true;
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
          final screenHeight = MediaQuery.of(context).size.height;
          final dialogWidth = screenWidth * 0.9; // Made slightly wider
          final padding = dialogWidth * 0.05;

          // ✅ Fixed font sizes - use smaller, more appropriate values
          final titleFontSize = screenWidth * 0.045; // ~18px on most phones
          final bodyFontSize = screenWidth * 0.035; // ~14px on most phones
          final buttonFontSize = screenWidth * 0.04; // ~16px on most phones

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
                    padding: EdgeInsets.all(padding * 0.8), // Smaller padding
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
                      size: titleFontSize * 1.2, // Scale icon with title font
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
                      letterSpacing: 1.5, // Reduced letter spacing
                      shadows: const [
                        Shadow(
                          offset: Offset(0, 0),
                          blurRadius: 10, // Reduced blur
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
                      fontSize: bodyFontSize * 1.1, // Slightly larger than body
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5, // Reduced letter spacing
                    ),
                  ),
                ],
              ),
              content: Container(
                width: dialogWidth,
                constraints: BoxConstraints(
                  maxHeight: screenHeight * 0.4, // Use screen height instead
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
                              fontSize: bodyFontSize * 1.15, // Slightly larger
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                              letterSpacing: 0.8, // Reduced letter spacing
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
                          maxHeight: screenHeight * 0.15, // Use screen height
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
                                          // Skin image - smaller size
                                          Container(
                                            width: 32, // Reduced from 40
                                            height: 32, // Reduced from 40
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.deepPurple
                                                      .withOpacity(0.4),
                                                  blurRadius: 6, // Reduced blur
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
                                                      size:
                                                          16, // Reduced icon size
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
                                                    fontSize: bodyFontSize *
                                                        0.85, // Smaller description
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
                                                  size: 12, // Smaller icon
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'AD',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: bodyFontSize *
                                                        0.75, // Smaller text
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
                          borderRadius: BorderRadius.circular(
                              buttonFontSize * 0.8), // Smaller radius
                          gradient: const LinearGradient(
                            colors: [Colors.pinkAccent, Colors.deepPurple],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.pinkAccent.withOpacity(0.4),
                              blurRadius: 8, // Reduced blur
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            isNavigatingToSkinStore = true;
                            Navigator.of(context).pop();
                            _openSkinStore();
                            // Keep game paused - don't resume until returning from skin store
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(
                              horizontal: padding * 0.8,
                              vertical: padding * 0.6, // Reduced padding
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(buttonFontSize * 0.8),
                            ),
                          ),
                          icon: Icon(
                            Icons.store,
                            color: Colors.white,
                            size: buttonFontSize * 0.9, // Smaller icon
                          ),
                          label: Text(
                            'OPEN SKIN STORE',
                            style: TextStyle(
                              fontSize: buttonFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.8, // Reduced letter spacing
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
                              BorderRadius.circular(buttonFontSize * 0.8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Continue to next level preparation
                            isGameIntentionallyPaused = false;
                            _continueToNextLevel();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(
                              horizontal: padding * 0.8,
                              vertical: padding * 0.6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(buttonFontSize * 0.8),
                            ),
                          ),
                          icon: Icon(
                            Icons.close,
                            color: Colors.white.withOpacity(0.8),
                            size: buttonFontSize * 0.9,
                          ),
                          label: Text(
                            'CONTINUE PLAYING',
                            style: TextStyle(
                              fontSize: buttonFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withOpacity(0.8),
                              letterSpacing: 0.8,
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
                        fontSize: bodyFontSize * 0.8, // Smaller hint text
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
        // Only resume if user didn't navigate to skin store and level progression wasn't handled manually
        if (currentState == GameState.paused &&
            !isNavigatingToSkinStore &&
            !levelProgressionHandled) {
          isGameIntentionallyPaused = false;
          resumeGame();
        }
        // Reset the flag for next time
        levelProgressionHandled = false;
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
      // Continue to next level when returning from skin store
      // Clear both flags and continue level progression
      isNavigatingToSkinStore = false;
      isGameIntentionallyPaused = false;
      _continueToNextLevel();
    });
  }

  // Helper method to continue level progression after skin popup/store
  void _continueToNextLevel() {
    levelProgressionHandled = true;

    // Resume the engine first (it was paused when showing skin popup)
    resumeEngine();

    // Prepare the next wave/level (same logic as when no skins are unlocked)
    currentState = GameState.countdown;
    prepareWave();

    // Restart game music
    restartGameMusic();
  }

  // Helper to play audio
  void playSound(String fileName) {
    if (sfxEnabled) {
      FlameAudio.play(fileName);
    }
  }

  // Helper to play music
  void playMusic(String fileName) {
    if (musicEnabled) {
      stopGameMusic();
      FlameAudio.bgm.play(fileName);
    }
  }

  // Method to stop game music
  void stopGameMusic() {
    FlameAudio.bgm.stop();
  }

  // Method to restart game music
  void restartGameMusic() {
    if (musicEnabled) {
      stopGameMusic();
      FlameAudio.bgm.play('game_music.mp3');
    }
  }

  void showLevelCompleteDialog() {
    playSound('win.wav');
    gameUI?.showLevelCompleted(totalScore, waveManager.level);
  }

  void collectObject(GameObject obj) {
    if (!obj.isMounted) return;

    if (obj.type == ObjectType.coin) {
      createParticles(obj.position, Colors.yellow);
      playSound('coin.wav');
      if (currentLevelType != LevelType.demon) {
        totalScore += 1;
        waveManager.addWaveScore(1);

        if (waveManager.isWaveComplete() && currentState == GameState.playing) {
          endWave();
          return;
        }
      } // handle demon collecting coins
    } else {
      // Handle bomb collision based on level type
      if (currentLevelType == LevelType.gravity ||
          currentLevelType == LevelType.survival) {
        endWave(failed: true);
        createParticles(obj.position, Colors.red);
        playSound('bomb.wav');
      } else if (currentLevelType == LevelType.demon) {
        createParticles(obj.position, Colors.red);
        playSound('bomb.wav');
        failDemonLevel();
      }
    }

    obj.removeFromParent();
    gameObjects.remove(obj);
  }

  void destroyBomb(GameObject bomb) {
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

  void clearAllObjects() {
    // Clear and dispose all game objects
    for (final obj in gameObjects.toList()) {
      obj.removeFromParent();
    }
    gameObjects.clear();

    // Clear and dispose all particles
    for (final particle in particles.toList()) {
      particle.removeFromParent();
    }
    particles.clear();

    // Clear any remaining components that might be game objects
    final componentsToRemove = children
        .where(
            (component) => component is GameObject || component is GameParticle)
        .toList();
    for (final component in componentsToRemove) {
      component.removeFromParent();
    }
  }

  @override
  bool onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    return true; // Accept all drag events
  }

  @override
  bool onDragUpdate(DragUpdateEvent event) {
    if (currentState == GameState.paused) return false;
    // Forward drag events to the player for better control
    // Allow movement only when game is running and wave is active
    if (currentState == GameState.playing) {
      // Increase movement speed and responsiveness
      player?.moveBy(event.localDelta.x * 1, event.localDelta.y * 1);
    }
    return true;
  }

  @override
  bool onDragEnd(DragEndEvent event) {
    return true; // Accept all drag events
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (currentState == GameState.paused) return;
    // Existing tap logic here
    if (currentState == GameState.playing &&
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
    if (currentState != GameState.paused) {
      super.update(dt);
      updateWaveCountdown(dt);
    }
    // Regenerate lives periodically while running
    livesManager.regenerateLivesIfNeeded();

    // Check if we need to show no lives dialog
    if (livesManager.lives == 0 &&
        !noLivesDialogVisible &&
        !gameUI!.gameOverVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (gameUI!.isMounted && this.buildContext != null) {
          noLivesDialogVisible = true;
          gameUI?.showNoLivesDialog(onDialogClosed: () {
            noLivesDialogVisible = false;
          });
        }
      });
    }

    // Update game objects only when game is running
    if (currentState == GameState.playing) {
      // Update magnetic effects
      for (final obj in List.from(gameObjects)) {
        if (obj.isMounted) {
          player?.applyMagneticForce(obj, dt);
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
    // Stop all timers
    gravitySpawnManager.stop();
    survivalSpawnManager.stop();

    // Clear all objects
    clearAllObjects();

    // Remove player and demon
    player?.removeFromParent();
    player = null;
    demon?.removeFromParent();
    demon = null;

    // Dispose ads
    AdManager.disposeAds();
    WidgetsBinding.instance.removeObserver(this);

    super.onRemove();
  }

  void setPaused(bool paused) {
    if (paused) {
      pauseEngine();
    } else {
      resumeEngine();
    }
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
    // final savedLevel = 1;
    final savedLevel = prefs.getInt('saved_level');
    final savedTotalScore = prefs.getInt('saved_total_score');
    if (savedLevel != null) {
      waveManager.level = savedLevel;
      waveManager.setTarget(); // Update target after loading saved level
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
      currentState = GameState.playing;
    } else {
      // If no lives, keep game in a paused state
      currentState = GameState.countdown;
    }
  }

  // Play button sound on tap
  void playButtonSound() {
    playSound('button.mp3');
  }

//////////// HEREEEEE ONLY WE HANDLE THE GAME STATE ////////////
  void tryConsumeLifeAndStartWave(int wave) {
    if (livesManager.tryConsumeLife()) {
      startWave(wave);
    }
  }

  void startGameOrShowNoLivesDialog() {
    // if (livesManager.lives == 0) {
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     gameUI.showNoLivesDialog();
    //   });
    //   return;
    // }
    tryConsumeLifeAndStartWave(1);
  }

  // Method to pause the game (freezes all game logic)
  void pauseGame() {
    // Save the current state before pausing
    stateBeforePause = currentState;
    currentState = GameState.paused;
    stopGameMusic();

    // Stop all spawning
    gravitySpawnManager.stop();
    survivalSpawnManager.stop();
    if (currentLevelType == LevelType.demon)
      demon?.isAlive = false; // TODO handle pause demon level

    // Pause the entire engine to prevent any updates
    pauseEngine();
  }

  // Method to resume the game
  void resumeGame() {
    // Restore the previous state, or default to playing if no previous state
    currentState = stateBeforePause ?? GameState.playing;
    stateBeforePause = null; // Clear the saved state

    // Resume the engine first
    resumeEngine();

    // Resume spawning only if we're in playing state, not countdown
    if (currentState == GameState.playing) {
      startSpawning();
      // Resume demon if it was active
      if (currentLevelType == LevelType.demon && demon != null) {
        demon?.isAlive = true;
      }
    }
    // Note: If state is countdown, the countdown will continue naturally in update()

    restartGameMusic();
  }

  // Method to pause the game for app lifecycle (without stopping music)
  void pauseGameForAppLifecycle() {
    // Save the current state before pausing (if not already saved)
    if (stateBeforePause == null) {
      stateBeforePause = currentState;
    }
    currentState = GameState.paused;

    // Stop all spawning
    gravitySpawnManager.stop();
    survivalSpawnManager.stop();
    if (currentLevelType == LevelType.demon)
      demon?.isAlive = false; // TODO handle pause demon level

    // The game objects will remain in their current positions
    // Music is handled separately in didChangeAppLifecycleState
  }

  // Method to resume the game from app lifecycle (without restarting music)
  void resumeGameFromAppLifecycle() {
    // Don't resume if the game is intentionally paused for UI (popups, dialogs, etc.)
    if (isGameIntentionallyPaused) {
      return;
    }

    // Restore the previous state, or default to playing if no previous state
    currentState = stateBeforePause ?? GameState.playing;
    stateBeforePause = null; // Clear the saved state

    // Resume spawning only if we're in playing state, not countdown
    if (currentState == GameState.playing) {
      startSpawning();
      // Resume demon if it was active
      if (currentLevelType == LevelType.demon && demon != null) {
        demon?.isAlive = true;
      }
    }
    // Music is handled separately in didChangeAppLifecycleState
  }

// Prepares the current wave (shows countdown, positions player, etc.)
  void prepareWave() {
    // Clear any existing objects
    clearAllObjects();

    // Position player for current level type
    _updatePlayerPositionForLevelType();

    // Set up countdown
    waveCountdown = 3.0;
    if (currentLevelType == LevelType.demon) {
      waveMessage = 'Demon Attacks in 3';
    } else {
      waveMessage =
          'Wave ${waveManager.currentWave}/$wavesNeededToNextLevel starting in 3';
    }
    if (currentLevelType == LevelType.gravity && spawnPortal == null) {
      // Place the portal just under header
      final headerMarginX = canvasSize.x * 0.025;
      final headerMarginY = canvasSize.y * 0.025;
      final headerWidth = canvasSize.x * 0.95;
      final portalSize = 60.0 * ScreenUtils.getScaleFactor(canvasSize);
      spawnPortal = SciFiPortal(
        position: Vector2(
            headerMarginX + headerWidth / 2,
            headerMarginY +
                80 +
                ScreenUtils.getPreciseTopMargin(canvasSize) +
                portalSize),
        size: portalSize,
      );

      add(spawnPortal as Component);
    }
    // Stop any existing spawning
    gravitySpawnManager.stop();
    survivalSpawnManager.stop();

    // Reset wave score
    waveManager.resetWaveScore();
  }

// Call this when the countdown finishes to start the wave
  void onCountdownFinished() {
    currentState = GameState.playing;
    waveMessage = null;

    if (currentLevelType != LevelType.demon) {
      startSpawning();
    } else {
      startDemonLeve();
    }
  }

// Call this when the player completes a wave
  void completeWave() {
    wavesCompletedInLevel++;

    if (wavesCompletedInLevel >= wavesNeededToNextLevel) {
      // Level complete
      currentState = GameState.levelComplete;
      _initializeLevel();
      showLevelCompleteDialog();
    } else {
      // More waves to complete in this level
      waveManager.currentWave++;
      currentState = GameState.countdown;
      prepareWave();
    }

    saveProgress();
  }

// Call this when the player fails a wave
  void failWave() {
    currentState = GameState.gameOver;

    bool hasLivesLeft = livesManager.tryConsumeLife();

    // Stop spawning and clear objects
    gravitySpawnManager.stop();
    survivalSpawnManager.stop();
    clearAllObjects();

    // Position player back to start
    _updatePlayerPositionForLevelType();

    playSound('lose.mp3');
    stopGameMusic();

    if (!hasLivesLeft) {
      // No lives left - show no lives dialog
      gameUI?.showNoLivesDialog();
      return;
    }

    // Show failure dialog
    gameUI?.showFailureDialog(
      score: totalScore,
      level: waveManager.level,
      wave: waveManager.currentWave,
      onRestartLevel: () {
        // if (livesManager.lives <= 0) {
        //   gameUI?.showNoLivesDialog();
        // } else {
        //   livesManager.tryConsumeLife();
        //   waveManager.currentWave = 1;
        //   wavesCompletedInLevel = 0;
        //   waveManager.resetWaveScore();
        //   restartGameMusic();
        //   _initializeLevel();
        //   _startLevel();
        // }
        waveManager.currentWave = 1;
        wavesCompletedInLevel = 0;
        waveManager.resetWaveScore();
        restartGameMusic();
        _initializeLevel();
        _startLevel();
      },
      onWatchAd: () {
        AdManager.showRewardedAd(
          onRewarded: () {
            restartWave();
          },
          onAdDismissed: () {
            // Start music only after ad is dismissed
            restartGameMusic();
          },
          onFailed: () {
            final context = gameUI?.game.buildContext;
            if (context != null) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('No Ad Available'),
                  content: const Text(
                      'No ad is available right now. Please try again later.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
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
  }

// Call this to restart the current wave (e.g., after failure)
  void restartWave() {
    currentState = GameState.countdown;
    prepareWave();
  }

// Call this to advance to the next level
  async.Future<void> nextLevel() async {
    waveManager.level++;
    await _show_instructions();
    waveManager.setTarget(); // Update target for new level
    currentLevelType = LevelTypeConfig.getLevelType(waveManager.level);
    if (player != null) player?.updateMagnetForLevel();
    // Show interstitial every 5 levels after level 15
    if (waveManager.level >= 15 && waveManager.level % 5 == 0) {
      //pauseGame();
      AdManager.showInterstitialAd();
      //resumeGame();
    }
    // FIX A BUG where portal didn't go
    if (currentLevelType == LevelType.survival) {
      if (spawnPortal != null) {
        spawnPortal!.removeCompletely();
        spawnPortal = null;
      }
    }
    if (currentLevelType == LevelType.demon) {
      await _initializeLevel();
      await _startLevel();
    } else {
      waveManager.currentWave = 1;
      wavesCompletedInLevel = 0;
      waveManager.resetWaveScore();

      // Check for newly available skins
      final newlyAvailableSkins = _checkForNewAvailableSkins(waveManager.level);
      if (newlyAvailableSkins.isNotEmpty) {
        _showNewSkinsAvailableNotification(newlyAvailableSkins);
      } else {
        // If no new skins, just prepare the next wave
        currentState = GameState.countdown;
        prepareWave();
      }
    }

    saveProgress();
  }

  void startWave(int wave) {
    waveManager.startWave(wave);
    prepareWave();
  }

  void endWave({bool failed = false}) {
    if (failed) {
      failWave();
    } else {
      completeWave();
    }
  }

  void SuccessDemonLevel() {
    // Clear any saved demon health when successfully completing the level
    waveManager.clearDemonHealth();

    clearAllObjects();
    currentState = GameState.levelComplete;
    //playSound('win.wav');
    //pauseGame();
    endDemonLevel();
    showLevelCompleteDialog();
  }

  void startDemonLeve() {
    final y_pos = ScreenUtils.responsive(250.0, canvasSize);

    // Check if we have saved demon health (from watching ad to continue)
    if (waveManager.hasSavedDemonHealth()) {
      // Restore demon with saved health
      if (demon == null) {
        demon = Demon(position: Vector2(canvasSize.x / 2, y_pos));
        add(demon as Component);
      }
      demon?.restoreHealth(
        waveManager.savedDemonHealth!,
        waveManager.savedDemonMaxHealth!,
      );
      // Clear saved health after restoring
      waveManager.clearDemonHealth();
    } else {
      // Start fresh demon
      if (demon == null) {
        demon = Demon(position: Vector2(canvasSize.x / 2, y_pos));
        add(demon as Component);
      }
      demon?.isAlive = true;
    }
    currentState = GameState.playing;
  }

  void endDemonLevel() {
    demon?.isAlive = true;
    demon?.deleteDemon();
  }

  void failDemonLevel() {
    // Save demon's current health before ending the level
    if (demon != null && demon!.isAlive) {
      waveManager.saveDemonHealth(demon!.health, demon!.maxHealth);
    }

    endDemonLevel();

    currentState = GameState.gameOver;
    bool hasLivesLeft = livesManager.tryConsumeLife();

    clearAllObjects();

    // Position player back to start
    _updatePlayerPositionForLevelType();
    saveProgress();

    playSound('lose.mp3');
    stopGameMusic();

    if (!hasLivesLeft) {
      gameUI?.showNoLivesDialog();
      return;
    }

    // Show failure dialog with demon health percentage
    final demonHealthPercent =
        demon != null ? demon!.getHealthPercentage() : 0.0;

    gameUI?.showFailureDialog(
      score: totalScore,
      level: waveManager.level,
      wave: waveManager.currentWave,
      onRestartLevel: () {
        // Clear saved demon health when restarting
        waveManager.clearDemonHealth();

        // if (livesManager.lives <= 0) {
        //   gameUI?.showNoLivesDialog();
        // } else {
        //   livesManager.lives--;
        //   restartGameMusic();
        //   _initializeLevel();
        //   _startLevel();
        // }

        // No need to consume life here - already consumed above
        restartGameMusic();
        _initializeLevel();
        _startLevel();
      },
      onWatchAd: () {
        AdManager.showRewardedAd(
          onRewarded: () {
            // Continue from where the player left off
            // The saved demon health will be restored in startDemonLeve()
            _initializeLevel();
            _startLevel();
          },
          onAdDismissed: () {
            // Start music only after ad is dismissed
            restartGameMusic();
          },
          onFailed: () {
            // If ad fails, clear saved demon health
            waveManager.clearDemonHealth();

            final context = gameUI?.game.buildContext;
            if (context != null) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('No Ad Available'),
                  content: const Text(
                      'No ad is available right now. Please try again later.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
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
  }

  void restartGame() {
    //TODO THIS IS NOT RIGHT
    // Reset game state but keep the current level
    waveManager.startWave(1);

    clearAllObjects();
    player?.reset();

    gravitySpawnManager.stop();
    survivalSpawnManager.stop();
    gameUI?.hideGameOver();

    saveProgress();
    startGameOrShowNoLivesDialog();
    onGameRestart?.call();
  }

  void updateWaveCountdown(double dt) {
    if (currentState == GameState.countdown && waveCountdown > 0) {
      waveCountdown -= dt;
      if (waveCountdown <= 0) {
        onCountdownFinished();
      } else {
        if (currentLevelType != LevelType.demon) {
          waveMessage =
              'Wave ${waveManager.currentWave}/$wavesNeededToNextLevel starting in ${waveCountdown.ceil()}';
        } else {
          waveMessage = 'Demon Attacks in ${waveCountdown.ceil()}';
        }
      }
    }
  }

  loadSoundSettings() async {
    final prefs = await SharedPreferences.getInstance();
    musicEnabled = prefs.getBool('music_enabled') ?? true;
    sfxEnabled = prefs.getBool('sfx_enabled') ?? true;
    if (musicEnabled) {
      playMusic('game_music.mp3');
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    // The screen size has changed - update all responsive elements
    if (player != null) {
      player?.animateToPosition(_getPlayerInitialPosition(size), 2.7);
    }
    if (demon != null) {
      demon?.updateResponsiveSizes(size);
    }
  }
}
