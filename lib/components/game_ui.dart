import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import '../magnet_walker_game.dart';
import '../managers/ad_manager.dart';
import '../level_types.dart';
import 'dart:math' as math;
import 'package:flame/input.dart';
import '../skins/skin_store_screen.dart';

// Custom rounded rectangle component for modern UI
class RoundedRectComponent extends Component {
  Vector2 position;
  Vector2 size;
  Paint paint;
  double radius;
  int priority;

  RoundedRectComponent({
    required this.position,
    required this.size,
    required this.paint,
    this.radius = 0.0,
    this.priority = 0,
  }) : super(priority: priority);

  @override
  void render(Canvas canvas) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(position.x, position.y, size.x, size.y),
      Radius.circular(radius),
    );
    canvas.drawRRect(rect, paint);
  }
}

class GameUI extends Component with HasGameRef<MagnetWalkerGame> {
  late TextComponent scoreText;
  late TextComponent levelText;
  late TextComponent levelTypeText;
  late TextComponent playTimeText;
  late TextComponent targetScoreText;
  late TextComponent instructionsText;
  late TextComponent livesText;
  bool gameOverVisible = false;
  bool isInitialized = false;

  // Modern UI components - redesigned layout
  late RoundedRectComponent headerBg;
  late RoundedRectComponent topRowBg;
  late RoundedRectComponent bottomRowBg;
  late ButtonComponent livesButton;
  late ButtonComponent pauseButton;
  bool isPaused = false;
  VoidCallback? onExitToMenu;

  // Animation properties
  double pulseTime = 0.0;
  double glowIntensity = 0.0;

  @override
  Future<void> onLoad() async {
    // Wait for the game to be properly initialized
    await Future.delayed(const Duration(milliseconds: 100));
    _initializeUI();
  }

  void _initializeUI() {
    if (isInitialized) return;

    // Use camera size instead of game size
    final gameSize = game.canvasSize;

    // Move pause button to bottom-right corner
    pauseButton = ButtonComponent(
      position: Vector2(gameSize.x - 16, gameSize.y - 40), // Bottom-right corner
      size: Vector2(50, 50), // Made it slightly larger
      anchor: Anchor.bottomRight,
      button: RectangleComponent(
        size: Vector2(50, 50),
        paint: Paint()..color = Colors.transparent,
      ),
      children: [
        // Background circle with better visibility
        CircleComponent(
          radius: 25,
          paint: Paint()
            ..color = const Color(0xFF1a1a2e).withOpacity(0.95), // More opaque
          position: Vector2(25, 25),
          anchor: Anchor.center,
        ),
        // Add border for better visibility
        CircleComponent(
          radius: 25,
          paint: Paint()
            ..color = Colors.cyanAccent.withOpacity(0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
          position: Vector2(25, 25),
          anchor: Anchor.center,
        ),
        // Pause icon (two rectangles) - made slightly larger
        RectangleComponent(
          position: Vector2(18, 17),
          size: Vector2(5, 16),
          paint: Paint()..color = Colors.white,
        ),
        RectangleComponent(
          position: Vector2(27, 17),
          size: Vector2(5, 16),
          paint: Paint()..color = Colors.white,
        ),
      ],
      onPressed: () {
        print('Pause button pressed!'); // Debug log
        showPauseDialog();
      },
      priority: 25, // Higher priority to ensure it's on top
    );
    add(pauseButton);

    // REDESIGNED: Single header container with two rows
    final headerMarginX = gameSize.x * 0.03; // 3% margin
    final headerMarginY = gameSize.y * 0.02; // 2% from top
    final headerWidth = gameSize.x * 0.94; // 94% width
    final headerHeight = gameSize.y * 0.14; // 14% height

    headerBg = RoundedRectComponent(
      position: Vector2(headerMarginX, headerMarginY),
      size: Vector2(headerWidth, headerHeight),
      paint: Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1a1a2e).withOpacity(0.95),
            const Color(0xFF16213e).withOpacity(0.90),
            const Color(0xFF0f0f23).withOpacity(0.85),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(
            headerMarginX, headerMarginY, headerWidth, headerHeight)),
      radius: 16,
      priority: -2,
    );
    add(headerBg);

    // REDESIGNED: Top row background (Score, Level, Lives)
    final topRowHeight = headerHeight * 0.45;
    final topRowY = headerMarginY + headerHeight * 0.08;

    topRowBg = RoundedRectComponent(
      position: Vector2(headerMarginX + 8, topRowY),
      size: Vector2(headerWidth - 16, topRowHeight),
      paint: Paint()..color = const Color(0xFF000000).withOpacity(0.2),
      radius: 12,
      priority: -1,
    );
    add(topRowBg);

    // REDESIGNED: Bottom row background (Target, Time)
    final bottomRowHeight = headerHeight * 0.35;
    final bottomRowY = topRowY + topRowHeight + 8;

    bottomRowBg = RoundedRectComponent(
      position: Vector2(headerMarginX + 8, bottomRowY),
      size: Vector2(headerWidth - 16, bottomRowHeight),
      paint: Paint()..color = const Color(0xFF000000).withOpacity(0.2),
      radius: 12,
      priority: -1,
    );
    add(bottomRowBg);

    // REDESIGNED: Top row elements (perfectly aligned)
    final topRowCenterY = topRowY + topRowHeight / 2;
    final topRowLeftX = headerMarginX + 24;
    final topRowCenterX = headerMarginX + headerWidth / 2;
    final topRowRightX = headerMarginX + headerWidth - 24;

    // Score (left)
    scoreText = TextComponent(
      text: 'Score: 0',
      position: Vector2(topRowLeftX, topRowCenterY),
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: Color(0xFF00ff88),
          fontSize: 16,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(
              offset: Offset(0, 0),
              blurRadius: 8,
              color: Color(0xFF00ff88),
            ),
            Shadow(
              offset: Offset(1, 1),
              blurRadius: 4,
              color: Colors.black87,
            ),
          ],
        ),
      ),
      anchor: Anchor.centerLeft,
    );
    add(scoreText);

    // Level (center)
    levelText = TextComponent(
      text: 'Level 1 (Wave 1/3)',
      position: Vector2(topRowCenterX, topRowCenterY),
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: Color(0xFF8844ff),
          fontSize: 16,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(
              offset: Offset(0, 0),
              blurRadius: 8,
              color: Color(0xFF8844ff),
            ),
            Shadow(
              offset: Offset(1, 1),
              blurRadius: 4,
              color: Colors.black87,
            ),
          ],
        ),
      ),
      anchor: Anchor.center,
    );
    add(levelText);

    // Lives (right)
    livesText = TextComponent(
      text: '❤️ ${game.livesManager.lives}',
      position: Vector2(topRowRightX, topRowCenterY),
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: Colors.redAccent,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: Offset(0, 0),
              blurRadius: 6,
              color: Colors.black54,
            ),
          ],
        ),
      ),
      anchor: Anchor.centerRight,
      priority: 10,
    );

    livesButton = ButtonComponent(
      position: Vector2(topRowRightX - 20, topRowCenterY),
      size: Vector2(60, topRowHeight),
      anchor: Anchor.center,
      button: RectangleComponent(
        size: Vector2(60, topRowHeight),
        paint: Paint()..color = const Color(0x00000000), // transparent
      ),
      children: [
        TextComponent(
          text: '❤️ ${game.livesManager.lives}',
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(
              fontFamily: 'Roboto',
              color: Colors.redAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  offset: Offset(0, 0),
                  blurRadius: 6,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
          position: Vector2(30, topRowHeight / 2),
        ),
      ],
      onPressed: showLivesDialog,
      priority: 10,
    );
    add(livesButton);

    // REDESIGNED: Bottom row elements (perfectly aligned)
    final bottomRowCenterY = bottomRowY + bottomRowHeight / 2;
    final bottomRowLeftX = headerMarginX + 24;
    final bottomRowRightX = headerMarginX + headerWidth - 24;

    // Target score (left)
    targetScoreText = TextComponent(
      text: 'Target: 13',
      position: Vector2(bottomRowLeftX, bottomRowCenterY),
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: Color(0xFFff8844),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          shadows: [
            Shadow(
              offset: Offset(0, 0),
              blurRadius: 6,
              color: Color(0xFFff8844),
            ),
            Shadow(
              offset: Offset(1, 1),
              blurRadius: 3,
              color: Colors.black87,
            ),
          ],
        ),
      ),
      anchor: Anchor.centerLeft,
    );
    add(targetScoreText);

    // Play time (right)
    playTimeText = TextComponent(
      text: 'Time: 00:00',
      position: Vector2(bottomRowRightX, bottomRowCenterY),
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: Color(0xFF44aaff),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          shadows: [
            Shadow(
              offset: Offset(0, 0),
              blurRadius: 6,
              color: Color(0xFF44aaff),
            ),
            Shadow(
              offset: Offset(1, 1),
              blurRadius: 3,
              color: Colors.black87,
            ),
          ],
        ),
      ),
      anchor: Anchor.centerRight,
    );
    add(playTimeText);

    // REDESIGNED: Instructions at the bottom with better spacing
    instructionsText = TextComponent(
      text: 'Swipe left/right to move • Collect coins • Avoid bombs',
      position: Vector2(gameSize.x / 2, gameSize.y - 30),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: Color(0xFF88aacc),
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              offset: Offset(0, 0),
              blurRadius: 4,
              color: Color(0xFF44aaff),
            ),
            Shadow(
              offset: Offset(1, 1),
              blurRadius: 2,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );
    add(instructionsText);

    isInitialized = true;
  }

  // Add this method to initialize the exit callback
  void setExitCallback(VoidCallback callback) {
    onExitToMenu = callback;
  }

  void showPauseDialog() {
    print('showPauseDialog called, isPaused: $isPaused'); // Debug log
    
    if (isPaused) {
      print('Already paused, returning');
      return; // Prevent multiple dialogs
    }

    // Pause the game immediately
    isPaused = true;
    game.pauseGame();
    print('Game paused successfully');

    // Use a post-frame callback to ensure the context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = game.buildContext;
      print('Context available: ${context != null}');
      
      if (context == null) {
        print('Context is null, retrying...');
        // If context is not available, try again after a short delay
        Future.delayed(const Duration(milliseconds: 100), () {
          final retryContext = game.buildContext;
          if (retryContext != null) {
            _showPauseDialogWithContext(retryContext);
          } else {
            print('Context still null after retry, resuming game');
            // If we still can't get context, resume the game
            resumeGame();
          }
        });
        return;
      }
      
      _showPauseDialogWithContext(context);
    });
  }

  void _showPauseDialogWithContext(BuildContext context) {
    print('Showing pause dialog with context');
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext dialogContext) {
        final screenWidth = MediaQuery.of(dialogContext).size.width;
        final dialogWidth = screenWidth * 0.8;
        final padding = dialogWidth * 0.06;
        final titleFontSize = dialogWidth * 0.08;
        final buttonFontSize = dialogWidth * 0.055;
        final buttonPaddingV = dialogWidth * 0.045;
        final buttonPaddingH = dialogWidth * 0.08;

        return WillPopScope(
          onWillPop: () async => false, // Prevent back button from closing dialog
          child: AlertDialog(
            backgroundColor: const Color(0xFF1a1a2e),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dialogWidth * 0.07),
              side: BorderSide(
                color: Colors.cyanAccent.withOpacity(0.5),
                width: 2,
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pause_circle_filled,
                  color: Colors.cyanAccent,
                  size: titleFontSize * 0.8,
                ),
                SizedBox(width: padding * 0.5),
                Text(
                  'GAME PAUSED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyanAccent,
                    letterSpacing: 1.5,
                    shadows: const [
                      Shadow(
                        offset: Offset(0, 0),
                        blurRadius: 10,
                        color: Colors.cyanAccent,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Container(
              width: dialogWidth,
              padding: EdgeInsets.all(padding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Game status info
                  Container(
                    padding: EdgeInsets.all(padding * 0.8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF44aaff).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(dialogWidth * 0.04),
                      border: Border.all(
                        color: const Color(0xFF44aaff).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildStatRow('LEVEL', '${game.waveManager.level}', 
                            const Color(0xFF8844ff), buttonFontSize * 0.9),
                        SizedBox(height: padding * 0.3),
                        _buildStatRow('WAVE', '${game.waveManager.currentWave}/3', 
                            const Color(0xFFff8844), buttonFontSize * 0.9),
                        SizedBox(height: padding * 0.3),
                        _buildStatRow('SCORE', '${game.totalScore}', 
                            const Color(0xFF00ff88), buttonFontSize * 0.9),
                      ],
                    ),
                  ),
                  SizedBox(height: padding),
                  Text(
                    'Choose an option to continue:',
                    style: TextStyle(
                      fontSize: buttonFontSize * 0.9,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            actions: [
              Column(
                children: [
                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    child: _buildPauseActionButton(
                      'CONTINUE GAME',
                      const Color(0xFF00ff88),
                      Icons.play_arrow,
                      () {
                        print('Continue button pressed');
                        Navigator.of(dialogContext).pop();
                        resumeGame();
                      },
                      buttonFontSize,
                      buttonPaddingH,
                      buttonPaddingV,
                    ),
                  ),
                  SizedBox(height: padding * 0.5),
                  // Exit to menu button
                  SizedBox(
                    width: double.infinity,
                    child: _buildPauseActionButton(
                      'EXIT TO MENU',
                      const Color(0xFFff4444),
                      Icons.home, // Changed icon to home
                      () {
                        print('Exit to menu button pressed');
                        Navigator.of(dialogContext).pop();
                        exitToMenu();
                      },
                      buttonFontSize,
                      buttonPaddingH,
                      buttonPaddingV,
                    ),
                  ),
                  SizedBox(height: padding * 0.3),
                  // Warning text
                  Text(
                    '⚠️ Exiting will lose current wave progress',
                    style: TextStyle(
                      fontSize: buttonFontSize * 0.7,
                      color: const Color(0xFFff4444).withOpacity(0.8),
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
      // Ensure the game is resumed if dialog is dismissed unexpectedly
      if (isPaused) {
        print('Dialog dismissed unexpectedly, resuming game');
        resumeGame();
      }
    });
  }

  // Helper method for pause dialog action buttons
  Widget _buildPauseActionButton(
    String text, 
    Color color, 
    IconData icon,
    VoidCallback onPressed,
    double fontSize, 
    double paddingH, 
    double paddingV
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(fontSize * 1.2),
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(fontSize * 1.2),
          ),
        ),
        icon: Icon(
          icon,
          color: Colors.white,
          size: fontSize,
        ),
        label: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  // Method to resume the game
  void resumeGame() {
    isPaused = false;
    game.resumeGame();
  }

  // Method to exit to menu
  void exitToMenu() {
    isPaused = false;
    if (onExitToMenu != null) {
      onExitToMenu!();
    }
  }

  @override
  void update(double dt) {
    if (!isInitialized) return;

    // Update animation time only when not paused
    if (!isPaused) {
      pulseTime += dt * 2.0;
      glowIntensity = (math.sin(pulseTime) * 0.5 + 0.5) * 0.3 + 0.7;
    }

    // Update text content with wave information
    scoreText.text = 'Score: ${game.totalScore}';
    levelText.text =
        'Level ${game.waveManager.level} (Wave ${game.waveManager.currentWave}/3)';

    // Update target score display
    targetScoreText.text =
        'Target: ${game.waveManager.waveScore}/${game.waveManager.waveTarget}';

    // Update play time display
    final minutes = game.playTime.inMinutes;
    final seconds = game.playTime.inSeconds % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    playTimeText.text = 'Time: $timeString';

    // Update instructions based on level type
    final currentLevelType =
        LevelTypeConfig.getLevelType(game.waveManager.level);
    final instructions = LevelTypeConfig.getLevelInstructions(currentLevelType);
    instructionsText.text = instructions;

    // Update container colors with pulsing effect
    if (!isPaused) {
      final glowOpacity = (glowIntensity * 0.15).clamp(0.05, 0.15);
      topRowBg.paint.color = Color(0xFF000000).withOpacity(glowOpacity);
      bottomRowBg.paint.color = Color(0xFF000000).withOpacity(glowOpacity);
    }

    // Update lives counter in button
    if (livesButton.children.isNotEmpty) {
      (livesButton.children.first as TextComponent).text =
          '❤️ ${game.livesManager.lives}';
    }

    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (!isInitialized) return;

    // Add subtle geometric patterns to header
    _renderModernDecorations(canvas);

    // Add border glow effects
    _renderGlowEffects(canvas);

    // Show wave message/countdown overlay with modern styling
    if (game.waveMessage != null && game.waveMessage!.isNotEmpty) {
      final gameSize = game.canvasSize;

      // Modern wave message design
      final message = game.waveMessage!;
      final messageTextStyle = const TextStyle(
        fontFamily: 'Roboto',
        color: Color(0xFF00ff88),
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: 2.0,
        shadows: [
          Shadow(
            offset: Offset(0, 0),
            blurRadius: 12,
            color: Color(0xFF00ff88),
          ),
          Shadow(
            offset: Offset(2, 2),
            blurRadius: 8,
            color: Colors.black87,
          ),
        ],
      );

      final textPainter = TextPainter(
        text: TextSpan(text: message, style: messageTextStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      // Modern rounded rectangle with gradient
      final padding = gameSize.x * 0.1;
      final rectWidth = textPainter.width + padding;
      final rectHeight = textPainter.height + padding * 0.8;

      final messageBg = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(gameSize.x / 2, gameSize.y / 2 - 50),
          width: rectWidth,
          height: rectHeight,
        ),
        Radius.circular(rectHeight * 0.25),
      );

      // Gradient background
      final bgPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1a1a2e).withOpacity(0.95),
            const Color(0xFF16213e).withOpacity(0.90),
          ],
        ).createShader(messageBg.outerRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawRRect(messageBg, bgPaint);

      // Multiple border glows for depth
      final borderPaint1 = Paint()
        ..color = const Color(0xFF00ff88).withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(messageBg, borderPaint1);

      final borderPaint2 = Paint()
        ..color = const Color(0xFF44aaff).withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawRRect(messageBg, borderPaint2);

      // Wave message text
      final offset = Offset(
        (gameSize.x - textPainter.width) / 2,
        (gameSize.y - textPainter.height) / 2 - 50,
      );
      textPainter.paint(canvas, offset);
    }
  }

  void _renderModernDecorations(Canvas canvas) {
    final gameSize = game.canvasSize;

    // Subtle corner decorations
    final decorPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Top-left corner decoration
    final topLeft = Offset(gameSize.x * 0.03 + 8, gameSize.y * 0.02 + 8);
    canvas.drawLine(topLeft, Offset(topLeft.dx + 15, topLeft.dy), decorPaint);
    canvas.drawLine(topLeft, Offset(topLeft.dx, topLeft.dy + 15), decorPaint);

    // Top-right corner decoration
    final topRight = Offset(gameSize.x * 0.97 - 8, gameSize.y * 0.02 + 8);
    canvas.drawLine(
        topRight, Offset(topRight.dx - 15, topRight.dy), decorPaint);
    canvas.drawLine(
        topRight, Offset(topRight.dx, topRight.dy + 15), decorPaint);
  }

  void _renderGlowEffects(Canvas canvas) {
    final gameSize = game.canvasSize;

    // Header border glow with multiple layers
    final headerMarginX = gameSize.x * 0.03;
    final headerMarginY = gameSize.y * 0.02;
    final headerWidth = gameSize.x * 0.94;
    final headerHeight = gameSize.y * 0.14;

    final headerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(headerMarginX, headerMarginY, headerWidth, headerHeight),
      const Radius.circular(16),
    );

    // Outer glow
    final outerGlowPaint = Paint()
      ..color = Color(0xFF44aaff).withOpacity(glowIntensity * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRRect(headerRect, outerGlowPaint);

    // Inner glow
    final innerGlowPaint = Paint()
      ..color = Color(0xFF8844ff).withOpacity(glowIntensity * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(headerRect, innerGlowPaint);
  }

  // [Keep all your existing dialog methods exactly the same - showFailureDialog, showLevelCompleted, etc.]
  // I'm omitting them here for brevity, but they should remain unchanged

  void showFailureDialog({
    required int score,
    required int level,
    required int wave,
    required Duration playTime,
    required VoidCallback onRestartLevel,
    required VoidCallback onWatchAd,
  }) {
    gameOverVisible = true;

    // Format play time
    final minutes = playTime.inMinutes;
    final seconds = playTime.inSeconds % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    // Show unified failure dialog using Flutter's overlay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = game.buildContext;
      if (context == null) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          final screenWidth = MediaQuery.of(context).size.width;
          final dialogWidth = screenWidth * 0.85;
          final padding = dialogWidth * 0.06;
          final titleFontSize = dialogWidth * 0.08;
          final statFontSize = dialogWidth * 0.06;
          final bodyFontSize = dialogWidth * 0.05;
          final buttonFontSize = dialogWidth * 0.055;
          final buttonPaddingV = dialogWidth * 0.045;
          final buttonPaddingH = dialogWidth * 0.08;
          return AlertDialog(
            backgroundColor: const Color(0xFF1a1a2e),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dialogWidth * 0.07),
              side: BorderSide(
                color: const Color(0xFFff4444).withOpacity(0.5),
                width: 2,
              ),
            ),
            title: Text(
              'WAVE FAILED!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFff4444),
                letterSpacing: 1.5,
                shadows: const [
                  Shadow(
                    offset: Offset(0, 0),
                    blurRadius: 10,
                    color: Color(0xFFff4444),
                  ),
                ],
              ),
            ),
            content: Container(
              width: dialogWidth,
              padding: EdgeInsets.all(padding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Stats section
                  _buildStatRow('⏱️ TIME', timeString, const Color(0xFF44aaff),
                      statFontSize),
                  SizedBox(height: dialogWidth * 0.04),
                  _buildStatRow('⭐ SCORE', '$score', const Color(0xFF00ff88),
                      statFontSize),
                  SizedBox(height: dialogWidth * 0.04),
                  _buildStatRow('🚀 LEVEL', '$level', const Color(0xFF8844ff),
                      statFontSize),
                  SizedBox(height: dialogWidth * 0.04),
                  _buildStatRow('🌊 WAVE', '$wave/3', const Color(0xFFff8844),
                      statFontSize),
                  SizedBox(height: dialogWidth * 0.05),
                  // Explanation section
                  Container(
                    padding: EdgeInsets.all(dialogWidth * 0.045),
                    decoration: BoxDecoration(
                      color: const Color(0xFF44aaff).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(dialogWidth * 0.04),
                      border: Border.all(
                        color: const Color(0xFF44aaff).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      'You failed wave $wave of level $level. Choose your next action:',
                      style: TextStyle(
                        fontSize: bodyFontSize,
                        color: const Color(0xFF44aaff),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'RESTART LEVEL',
                      const Color(0xFF666666),
                      () {
                        Navigator.of(context).pop();
                        onRestartLevel();
                      },
                      buttonFontSize,
                      buttonPaddingH,
                      buttonPaddingV,
                    ),
                  ),
                  SizedBox(width: dialogWidth * 0.04),
                  Expanded(
                    child: _buildActionButton(
                      'WATCH AD',
                      const Color(0xFFff8844),
                      () {
                        Navigator.of(context).pop();
                        onWatchAd();
                      },
                      buttonFontSize,
                      buttonPaddingH,
                      buttonPaddingV,
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

  void showLevelCompleted(int finalScore, int finalLevel, Duration playTime) {
    gameOverVisible = true;

    // Format play time
    final minutes = playTime.inMinutes;
    final seconds = playTime.inSeconds % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    // Show level completion dialog using Flutter's overlay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = game.buildContext;
      if (context == null) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          final screenWidth = MediaQuery.of(context).size.width;
          final dialogWidth = screenWidth * 0.85;
          final padding = dialogWidth * 0.06;
          final titleFontSize = dialogWidth * 0.08;
          final statFontSize = dialogWidth * 0.06;
          final buttonFontSize = dialogWidth * 0.055;
          final buttonPaddingV = dialogWidth * 0.045;
          final buttonPaddingH = dialogWidth * 0.08;
          return AlertDialog(
            backgroundColor: const Color(0xFF1a1a2e),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dialogWidth * 0.07),
              side: BorderSide(
                color: const Color(0xFF00ff88).withOpacity(0.5),
                width: 2,
              ),
            ),
            title: Text(
              'LEVEL COMPLETE! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00ff88),
                letterSpacing: 1.5,
                shadows: const [
                  Shadow(
                    offset: Offset(0, 0),
                    blurRadius: 10,
                    color: Color(0xFF00ff88),
                  ),
                ],
              ),
            ),
            content: Container(
              width: dialogWidth,
              padding: EdgeInsets.all(padding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatRow('⏱️ TIME', timeString, const Color(0xFF44aaff),
                      statFontSize),
                  SizedBox(height: dialogWidth * 0.04),
                  _buildStatRow('⭐ SCORE', '$finalScore',
                      const Color(0xFF00ff88), statFontSize),
                  SizedBox(height: dialogWidth * 0.04),
                  _buildStatRow('🚀 LEVEL', '$finalLevel',
                      const Color(0xFF8844ff), statFontSize),
                  SizedBox(height: dialogWidth * 0.05),
                  Container(
                    padding: EdgeInsets.all(dialogWidth * 0.045),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8844ff).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(dialogWidth * 0.04),
                      border: Border.all(
                        color: const Color(0xFF8844ff).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      'Objects will move faster in the next level!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: dialogWidth * 0.045,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8844ff),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'RESTART',
                      const Color(0xFF666666),
                      () {
                        Navigator.of(context).pop();
                        game.restartGame();
                      },
                      buttonFontSize,
                      buttonPaddingH,
                      buttonPaddingV,
                    ),
                  ),
                  SizedBox(width: dialogWidth * 0.04),
                  Expanded(
                    child: _buildActionButton(
                      'NEXT LEVEL',
                      const Color(0xFF00ff88),
                      () {
                        Navigator.of(context).pop();
                        game.nextLevel();
                        game.tryConsumeLifeAndStartWave(
                            game.waveManager.currentWave);
                      },
                      buttonFontSize,
                      buttonPaddingH,
                      buttonPaddingV,
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

  // Responsive stat row for dialogs
  Widget _buildStatRow(
      String label, String value, Color color, double fontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: color.withOpacity(0.8),
            letterSpacing: 1.0,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize * 1.25,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 1.2,
            shadows: [
              Shadow(
                offset: const Offset(0, 0),
                blurRadius: 8,
                color: color,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Responsive action button for dialogs
  Widget _buildActionButton(String text, Color color, VoidCallback onPressed,
      double fontSize, double paddingH, double paddingV) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(fontSize * 1.2),
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding:
              EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(fontSize * 1.2),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  void hideGameOver() {
    gameOverVisible = false;
  }

  void hideLevelCompleted() {
    gameOverVisible = false;
  }

  void showLivesDialog() {
    final context = game.buildContext;
    if (context == null) {
      // If context is not available yet, schedule to show later
      Future.delayed(const Duration(milliseconds: 500), () {
        if (game.buildContext != null) {
          showLivesDialog();
        }
      });
      return;
    }
    final lives = game.livesManager.lives;
    final maxLives = game.livesManager.maxLives;
    final regenMinutes = game.livesManager.lifeRegenMinutes;
    final lastLifeTimestamp = game.livesManager.lastLifeTimestamp;
    final now = DateTime.now().millisecondsSinceEpoch;
    final regenMillis = regenMinutes * 60 * 1000;
    int millisLeft = 0;
    double percent = 1.0;
    String timeLeftStr = '';
    if (lives < maxLives && lastLifeTimestamp != null) {
      millisLeft = (lastLifeTimestamp + regenMillis) - now;
      if (millisLeft < 0) millisLeft = 0;
      percent = 1.0 - (millisLeft / regenMillis).clamp(0.0, 1.0);
      final secondsLeft = (millisLeft / 1000).ceil();
      final minutes = (secondsLeft ~/ 60).toString().padLeft(2, '0');
      final seconds = (secondsLeft % 60).toString().padLeft(2, '0');
      timeLeftStr = '$minutes:$seconds';
    }
    showDialog(
      context: context,
      builder: (context) {
        final dialogWidth = MediaQuery.of(context).size.width * 0.85;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: const Color(0xFF1a1a2e),
          contentPadding: EdgeInsets.all(dialogWidth * 0.06),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '❤️ $lives / $maxLives',
                style: TextStyle(
                  fontSize: dialogWidth * 0.13,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                  shadows: [
                    const Shadow(
                      offset: Offset(0, 0),
                      blurRadius: 8,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (lives < maxLives)
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: percent,
                      minHeight: 12,
                      backgroundColor: Colors.red[200]!.withOpacity(0.2),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.redAccent),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Next life in $timeLeftStr',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: dialogWidth * 0.05,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'You are full of lives! 🎉',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: dialogWidth * 0.06,
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    // Stub for watch ad logic
                    Navigator.of(context).pop();
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        content: const Text('Watch Ad feature coming soon!'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text(
                    'Watch Ad for 1 Life',
                    style: TextStyle(
                      fontSize: dialogWidth * 0.06,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void showNoLivesDialog({VoidCallback? onDialogClosed}) {
    final context = game.buildContext;
    if (context == null) {
      // If context is not available yet, schedule to show later
      Future.delayed(const Duration(milliseconds: 500), () {
        if (game.buildContext != null) {
          showNoLivesDialog(onDialogClosed: onDialogClosed);
        }
      });
      return;
    }

    // Calculate progress for next life
    final lives = game.livesManager.lives;
    final maxLives = game.livesManager.maxLives;
    final regenMinutes = game.livesManager.lifeRegenMinutes;
    final lastLifeTimestamp = game.livesManager.lastLifeTimestamp;
    final now = DateTime.now().millisecondsSinceEpoch;
    final regenMillis = regenMinutes * 60 * 1000;
    int millisLeft = 0;
    double percent = 1.0;
    String timeLeftStr = '';

    if (lives < maxLives && lastLifeTimestamp != null) {
      millisLeft = (lastLifeTimestamp + regenMillis) - now;
      if (millisLeft < 0) millisLeft = 0;
      percent = 1.0 - (millisLeft / regenMillis).clamp(0.0, 1.0);
      final secondsLeft = (millisLeft / 1000).ceil();
      final minutes = (secondsLeft ~/ 60).toString().padLeft(2, '0');
      final seconds = (secondsLeft % 60).toString().padLeft(2, '0');
      timeLeftStr = '$minutes:$seconds';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final dialogWidth = MediaQuery.of(context).size.width * 0.85;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: const Color(0xFF1a1a2e),
          contentPadding: EdgeInsets.all(dialogWidth * 0.06),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No Lives Left!',
                style: TextStyle(
                  fontSize: dialogWidth * 0.09,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'You have no lives left. Please wait for a new life or watch an ad to get one instantly.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: dialogWidth * 0.055,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              // Progress bar for next life
              Column(
                children: [
                  LinearProgressIndicator(
                    value: percent,
                    minHeight: 12,
                    backgroundColor: Colors.red[200]!.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Next life in $timeLeftStr',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: dialogWidth * 0.05,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Watch Ad button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    // Simulate watching an ad and gaining a life
                    Navigator.of(context).pop();
                    _simulateWatchAdAndGainLife();
                    if (onDialogClosed != null) onDialogClosed();
                  },
                  child: Text(
                    'Watch Ad for 1 Life',
                    style: TextStyle(
                      fontSize: dialogWidth * 0.06,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      if (onDialogClosed != null) onDialogClosed();
    });
  }

  void _simulateWatchAdAndGainLife() {
    // Show real rewarded ad
    AdManager.showRewardedAd(
      onRewarded: () {
        // Add a life when ad is completed
        game.livesManager.lives =
            (game.livesManager.lives + 1).clamp(0, game.livesManager.maxLives);
        game.livesManager.save();

        // Reset the no lives dialog flag and game state immediately
        game.dismissNoLivesDialog();

        // Show success message
        showDialog(
          context: game.buildContext!,
          builder: (context) {
            final dialogWidth = MediaQuery.of(context).size.width * 0.85;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              backgroundColor: const Color(0xFF1a1a2e),
              contentPadding: EdgeInsets.all(dialogWidth * 0.06),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.greenAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Ad Completed!',
                    style: TextStyle(
                      fontSize: dialogWidth * 0.08,
                      fontWeight: FontWeight.bold,
                      color: Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You gained 1 life!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: dialogWidth * 0.06,
                    ),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true)
                          .popUntil((route) => route.isFirst);
                      // Reset dialog flag and start the game
                      game.noLivesDialogVisible = false;
                      if (game.livesManager.lives > 0) {
                        game.startWaveWithoutConsumingLife(
                            game.waveManager.currentWave);
                      }
                    },
                    child: Text(
                      'Start Playing!',
                      style: TextStyle(
                        fontSize: dialogWidth * 0.06,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
      onFailed: () {},
    );
  }
}
