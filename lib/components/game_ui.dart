import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import '../magnet_walker_game.dart';
import '../managers/ad_manager.dart';
import '../level_types.dart';
import '../utils/screen_utils.dart';
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
  // late TextComponent playTimeText;
  late TextComponent targetScoreText;
  late TextComponent instructionsText;
  bool gameOverVisible = false;
  bool isInitialized = false;

  // Modern UI components - redesigned layout
  late RoundedRectComponent headerBg;
  late RoundedRectComponent topRowBg;
  late RoundedRectComponent bottomRowBg;
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

    final gameSize = game.canvasSize;
    final isLandscape = ScreenUtils.isLandscape(gameSize);
    final scaleFactor = ScreenUtils.getScaleFactor(gameSize);

    // IMPROVED: Enhanced pause button with responsive positioning (moved up to avoid ad bar)
    final pauseButtonSize = ScreenUtils.responsive(45.0, gameSize);
    final pauseMargin = ScreenUtils.responsive(15.0, gameSize);
    final adBarHeight = ScreenUtils.responsive(55.0, gameSize); // Height of ad bar
    final extraMargin = ScreenUtils.responsive(10.0, gameSize); // Extra spacing
    pauseButton = ButtonComponent(
      position: Vector2(gameSize.x - pauseMargin, gameSize.y - pauseMargin - adBarHeight - extraMargin),
      size: Vector2(pauseButtonSize, pauseButtonSize),
      anchor: Anchor.bottomRight,
      button: RectangleComponent(
        size: Vector2(pauseButtonSize, pauseButtonSize),
        paint: Paint()..color = Colors.transparent,
      ),
      children: [
        // Enhanced background with subtle animation potential
        CircleComponent(
          radius: pauseButtonSize / 2,
          paint: Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xFF1a1a2e).withOpacity(0.98),
                const Color(0xFF0f0f23).withOpacity(0.95),
              ],
              stops: const [0.0, 1.0],
            ).createShader(
                Rect.fromLTWH(0, 0, pauseButtonSize, pauseButtonSize)),
          position: Vector2(pauseButtonSize / 2, pauseButtonSize / 2),
          anchor: Anchor.center,
        ),
        // Glowing border effect
        CircleComponent(
          radius: pauseButtonSize / 2,
          paint: Paint()
            ..color = const Color(0xFF00ff88).withOpacity(0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 * scaleFactor,
          position: Vector2(pauseButtonSize / 2, pauseButtonSize / 2),
          anchor: Anchor.center,
        ),
        // Inner glow
        CircleComponent(
          radius: pauseButtonSize / 2 - 3 * scaleFactor,
          paint: Paint()
            ..color = const Color(0xFF00ff88).withOpacity(0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1 * scaleFactor,
          position: Vector2(pauseButtonSize / 2, pauseButtonSize / 2),
          anchor: Anchor.center,
        ),
        // Enhanced pause icon - responsive sizing
        RectangleComponent(
          position: Vector2(pauseButtonSize * 0.35, pauseButtonSize * 0.33),
          size: Vector2(pauseButtonSize * 0.12, pauseButtonSize * 0.35),
          paint: Paint()..color = Colors.white.withOpacity(0.95),
        ),
        RectangleComponent(
          position: Vector2(pauseButtonSize * 0.55, pauseButtonSize * 0.33),
          size: Vector2(pauseButtonSize * 0.12, pauseButtonSize * 0.35),
          paint: Paint()..color = Colors.white.withOpacity(0.95),
        ),
      ],
      onPressed: () {
        showPauseDialog();
      },
      priority: 25,
    );
    add(pauseButton);

    // IMPROVED: Better header dimensions and positioning
    // Responsive margins and dimensions
    final headerMarginX = ScreenUtils.getUIMargin(gameSize);
    final headerMarginY = ScreenUtils.getUIMargin(gameSize);
    final headerWidth = gameSize.x - (headerMarginX * 2);
    final headerHeight = ScreenUtils.getHeaderHeight(gameSize);

    // Check if we're in landscape mode for layout adjustments
    final needsCompact = ScreenUtils.needsCompactUI(gameSize);

    // IMPROVED: Enhanced header background with better gradient
    headerBg = RoundedRectComponent(
      position: Vector2((gameSize.x - headerWidth) / 2, headerMarginY),
      size: Vector2(headerWidth, headerHeight),
      paint: Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1a1a2e).withOpacity(0.95),
            const Color(0xFF16213e).withOpacity(0.92),
            const Color(0xFF0f0f23).withOpacity(0.88),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromLTWH(
            headerMarginX, headerMarginY, headerWidth, headerHeight)),
      radius: 18,
      priority: -2,
    );
    add(headerBg);

    // IMPROVED: Add subtle border to header
    final headerBorder = RoundedRectComponent(
      position: Vector2(headerMarginX, headerMarginY),
      size: Vector2(headerWidth, headerHeight),
      paint: Paint()
        ..color = const Color(0xFF00ff88).withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
      radius: 18,
      priority: -1,
    );
    add(headerBorder);

    // IMPROVED: More balanced row heights
    final topRowHeight = headerHeight * 0.48;
    final topRowY = headerMarginY + headerHeight * 0.06;

    topRowBg = RoundedRectComponent(
      position: Vector2(headerMarginX + 10, topRowY),
      size: Vector2(headerWidth - 20, topRowHeight),
      paint: Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF000000).withOpacity(0.15),
            const Color(0xFF1a1a2e).withOpacity(0.25),
            const Color(0xFF000000).withOpacity(0.15),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(
            headerMarginX + 10, topRowY, headerWidth - 20, topRowHeight)),
      radius: 14,
      priority: 0,
    );
    add(topRowBg);

    final bottomRowHeight = headerHeight * 0.38;
    final bottomRowY = topRowY + topRowHeight + 6;

    bottomRowBg = RoundedRectComponent(
      position: Vector2(headerMarginX + 10, bottomRowY),
      size: Vector2(headerWidth - 20, bottomRowHeight),
      paint: Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF000000).withOpacity(0.15),
            const Color(0xFF1a1a2e).withOpacity(0.25),
            const Color(0xFF000000).withOpacity(0.15),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(
            headerMarginX + 10, bottomRowY, headerWidth - 20, bottomRowHeight)),
      radius: 14,
      priority: 0,
    );
    add(bottomRowBg);

    // IMPROVED: Better text positioning and styling
    final topRowCenterY = topRowY + topRowHeight / 2;
    final topRowLeftX = headerMarginX + 28;
    final topRowRightX = headerMarginX + headerWidth - 28;

    // IMPROVED: Enhanced score text with responsive sizing
    final fontSize = isLandscape
        ? ScreenUtils.responsive(12.0, gameSize)
        : ScreenUtils.responsive(14.0, gameSize);
    scoreText = TextComponent(
      text: '⭐ Score: 0',
      position: Vector2(topRowLeftX, topRowCenterY),
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: 'Roboto',
          color: const Color(0xFF00ff88),
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8 * scaleFactor,
          shadows: [
            Shadow(
              offset: const Offset(0, 0),
              blurRadius: 12 * scaleFactor,
              color: const Color(0xFF00ff88),
            ),
            Shadow(
              offset: Offset(2 * scaleFactor, 2 * scaleFactor),
              blurRadius: 6 * scaleFactor,
              color: Colors.black87,
            ),
          ],
        ),
      ),
      anchor: Anchor.centerLeft,
    );
    add(scoreText);

    // IMPROVED: Enhanced level text with responsive sizing
    levelText = TextComponent(
      text: '🏆 Level 1 • Wave 1/1',
      position: Vector2(topRowRightX, topRowCenterY),
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: 'Roboto',
          color: const Color(0xFF8844ff),
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8 * scaleFactor,
          shadows: [
            Shadow(
              offset: const Offset(0, 0),
              blurRadius: 12 * scaleFactor,
              color: const Color(0xFF8844ff),
            ),
            Shadow(
              offset: Offset(2 * scaleFactor, 2 * scaleFactor),
              blurRadius: 6 * scaleFactor,
              color: Colors.black87,
            ),
          ],
        ),
      ),
      anchor: Anchor.centerRight,
    );
    add(levelText);

    // IMPROVED: Enhanced target score with progress indicator feel
    final bottomRowCenterY = bottomRowY + bottomRowHeight / 2;
    final bottomRowCenterX = headerMarginX + headerWidth / 2;

    targetScoreText = TextComponent(
      text: '🎯 Target: 13',
      position: Vector2(bottomRowCenterX, bottomRowCenterY),
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: 'Roboto',
          color: const Color(0xFFff8844),
          fontSize: isLandscape
              ? ScreenUtils.responsive(13.0, gameSize)
              : ScreenUtils.responsive(15.0, gameSize),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0 * scaleFactor,
          shadows: [
            Shadow(
              offset: const Offset(0, 0),
              blurRadius: 10 * scaleFactor,
              color: const Color(0xFFff8844),
            ),
            Shadow(
              offset: Offset(2 * scaleFactor, 2 * scaleFactor),
              blurRadius: 5 * scaleFactor,
              color: Colors.black87,
            ),
          ],
        ),
      ),
      anchor: Anchor.center,
    );
    add(targetScoreText);

    // IMPROVED: Better instructions positioning and styling with landscape adjustments
    final adHeight = ScreenUtils.responsive(55.0, gameSize);
    final instructionsY = isLandscape
        ? gameSize.y - ScreenUtils.responsive(25.0, gameSize) - adHeight
        : gameSize.y - ScreenUtils.responsive(35.0, gameSize) - adHeight;

    instructionsText = TextComponent(
      text: 'Collect ⭐ coins • Avoid 💣 bombs',
      position: Vector2(gameSize.x / 2, instructionsY),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: 'Roboto',
          color: const Color(0xFF88aacc),
          fontSize: isLandscape
              ? ScreenUtils.responsive(12.0, gameSize)
              : ScreenUtils.responsive(14.0, gameSize),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8 * scaleFactor,
          shadows: [
            Shadow(
              offset: const Offset(0, 0),
              blurRadius: 6 * scaleFactor,
              color: const Color(0xFF44aaff),
            ),
            Shadow(
              offset: Offset(1 * scaleFactor, 1 * scaleFactor),
              blurRadius: 3 * scaleFactor,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );

    if (game.waveManager.level < 5) {
      add(instructionsText);
    }
    if (game.waveManager.level < 20 &&
        game.currentLevelType == LevelType.demon) {
      add(instructionsText);
    }

    isInitialized = true;
  }

  // Add this method to initialize the exit callback
  void setExitCallback(VoidCallback callback) {
    onExitToMenu = callback;
  }

  void showPauseDialog() {
    if (isPaused) {
      return; // Prevent multiple dialogs
    }

    // Pause the game immediately
    isPaused = true;
    game.pauseGame();

    // Use a post-frame callback to ensure the context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = game.buildContext;

      if (context == null) {
        // If context is not available, try again after a short delay
        Future.delayed(const Duration(milliseconds: 100), () {
          final retryContext = game.buildContext;
          if (retryContext != null) {
            _showPauseDialogWithContext(retryContext);
          } else {
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
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext dialogContext) {
        final screenSize = MediaQuery.of(dialogContext).size;
        final isLandscape = screenSize.width > screenSize.height;
        final dialogWidth =
            isLandscape ? screenSize.width * 0.7 : screenSize.width * 0.8;
        final padding = dialogWidth * 0.06;
        final titleFontSize =
            isLandscape ? dialogWidth * 0.06 : dialogWidth * 0.08;
        final buttonFontSize =
            isLandscape ? dialogWidth * 0.045 : dialogWidth * 0.055;
        final buttonPaddingV =
            isLandscape ? dialogWidth * 0.035 : dialogWidth * 0.045;
        final buttonPaddingH =
            isLandscape ? dialogWidth * 0.06 : dialogWidth * 0.08;

        return WillPopScope(
          onWillPop: () async =>
              false, // Prevent back button from closing dialog
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
                        _buildStatRow(
                            'WAVE',
                            '${game.waveManager.currentWave}/${game.wavesNeededToNextLevel}',
                            const Color(0xFFff8844),
                            buttonFontSize * 0.9),
                        SizedBox(height: padding * 0.3),
                        _buildStatRow('SCORE', '${game.totalScore}',
                            const Color(0xFF00ff88), buttonFontSize * 0.9),
                      ],
                    ),
                  ),
                  SizedBox(height: padding),
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
      double paddingV) {
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
          padding:
              EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
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
    scoreText.text = '⭐Score: ${game.totalScore}';
    if (game.currentLevelType != LevelType.demon) {
      levelText.text =
          '🏆Level ${game.waveManager.level} • Wave ${game.waveManager.currentWave}/${game.wavesNeededToNextLevel}';
    } else {
      levelText.text = '🏆Level ${game.waveManager.level}';
    }
    // Update target score display
    if (game.currentLevelType != LevelType.demon) {
      targetScoreText.text =
          '🎯${game.waveManager.waveScore}/${game.waveManager.waveTarget}';
    } else {
      targetScoreText.text = "⚔️ Boss Battle";
    }

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
      final isLandscape = ScreenUtils.isLandscape(gameSize);
      final scaleFactor = ScreenUtils.getScaleFactor(gameSize);

      // Modern wave message design with responsive sizing
      final message = game.waveMessage!;
      final messageFontSize = isLandscape
          ? ScreenUtils.responsive(24.0, gameSize)
          : ScreenUtils.responsive(32.0, gameSize);
      final messageTextStyle = TextStyle(
        fontFamily: 'Roboto',
        color: const Color(0xFF00ff88),
        fontSize: messageFontSize,
        fontWeight: FontWeight.bold,
        letterSpacing: 2.0 * scaleFactor,
        shadows: [
          Shadow(
            offset: const Offset(0, 0),
            blurRadius: 12 * scaleFactor,
            color: const Color(0xFF00ff88),
          ),
          Shadow(
            offset: Offset(2 * scaleFactor, 2 * scaleFactor),
            blurRadius: 8 * scaleFactor,
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

      // Adjust message position for landscape
      final messageYOffset =
          isLandscape ? -25 * scaleFactor : -50 * scaleFactor;
      final messageBg = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(gameSize.x / 2, gameSize.y / 2 + messageYOffset),
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
        (gameSize.y - textPainter.height) / 2 + messageYOffset,
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
    required VoidCallback onRestartLevel,
    required VoidCallback onWatchAd,
  }) {
    gameOverVisible = true;

    // Show unified failure dialog using Flutter's overlay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = game.buildContext;
      if (context == null) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          final screenSize = MediaQuery.of(context).size;
          final isLandscape = screenSize.width > screenSize.height;
          final dialogWidth =
              isLandscape ? screenSize.width * 0.75 : screenSize.width * 0.85;
          final padding = dialogWidth * 0.06;
          final titleFontSize =
              isLandscape ? dialogWidth * 0.06 : dialogWidth * 0.08;
          final statFontSize =
              isLandscape ? dialogWidth * 0.05 : dialogWidth * 0.06;
          final bodyFontSize =
              isLandscape ? dialogWidth * 0.04 : dialogWidth * 0.05;
          final buttonFontSize =
              isLandscape ? dialogWidth * 0.045 : dialogWidth * 0.055;
          final buttonPaddingV =
              isLandscape ? dialogWidth * 0.035 : dialogWidth * 0.045;
          final buttonPaddingH =
              isLandscape ? dialogWidth * 0.06 : dialogWidth * 0.08;
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
            content: SingleChildScrollView(
              //width: dialogWidth,
              padding: EdgeInsets.all(padding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Stats section
                  SizedBox(height: dialogWidth * 0.04),
                  _buildStatRow('⭐ SCORE', '$score', const Color(0xFF00ff88),
                      statFontSize),
                  SizedBox(height: dialogWidth * 0.04),
                  _buildStatRow('🏆 LEVEL', '$level', const Color(0xFF8844ff),
                      statFontSize),
                  SizedBox(height: dialogWidth * 0.04),

                  // Show wave row only for non-demon levels
                  if (LevelTypeConfig.getLevelType(game.waveManager.level) !=
                      LevelType.demon) ...[
                    _buildStatRow('🌊 WAVE', '$wave/3', const Color(0xFFff8844),
                        statFontSize),
                    SizedBox(height: dialogWidth * 0.04),
                  ],

                  SizedBox(height: dialogWidth * 0.05),

                  // Explanation section with different text based on level type
                  Container(
                    padding: EdgeInsets.all(dialogWidth * 0.025),
                    decoration: BoxDecoration(
                      color: const Color(0xFF44aaff).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(dialogWidth * 0.04),
                      border: Border.all(
                        color: const Color(0xFF44aaff).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _getFailureMessage(level, wave),
                      style: TextStyle(
                        fontSize: bodyFontSize,
                        color: const Color(0xFF44aaff),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      softWrap: true,
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

  void showLevelCompleted(int finalScore, int finalLevel) {
    gameOverVisible = true;

    // Show level completion dialog using Flutter's overlay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = game.buildContext;
      if (context == null) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          final screenSize = MediaQuery.of(context).size;
          final isLandscape = screenSize.width > screenSize.height;
          final dialogWidth =
              isLandscape ? screenSize.width * 0.75 : screenSize.width * 0.85;
          final padding = dialogWidth * 0.06;
          final titleFontSize =
              isLandscape ? dialogWidth * 0.06 : dialogWidth * 0.08;
          final statFontSize =
              isLandscape ? dialogWidth * 0.05 : dialogWidth * 0.06;
          final buttonFontSize =
              isLandscape ? dialogWidth * 0.045 : dialogWidth * 0.055;
          final buttonPaddingV =
              isLandscape ? dialogWidth * 0.035 : dialogWidth * 0.045;
          final buttonPaddingH =
              isLandscape ? dialogWidth * 0.06 : dialogWidth * 0.08;
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
                  SizedBox(height: dialogWidth * 0.04),
                  _buildStatRow('⭐ SCORE', '$finalScore',
                      const Color(0xFF00ff88), statFontSize),
                  SizedBox(height: dialogWidth * 0.04),
                  _buildStatRow('🏆 LEVEL', '$finalLevel',
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
                  SizedBox(width: dialogWidth * 0.04),
                  Expanded(
                    child: _buildActionButton(
                      'NEXT LEVEL',
                      const Color(0xFF00ff88),
                      () {
                        Navigator.of(context).pop();
                        game.nextLevel();
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
        final screenSize = MediaQuery.of(context).size;
        final isLandscape = screenSize.width > screenSize.height;
        final dialogWidth =
            isLandscape ? screenSize.width * 0.7 : screenSize.width * 0.85;
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
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final screenSize = MediaQuery.of(context).size;
        final isLandscape = screenSize.width > screenSize.height;
        final dialogWidth =
            isLandscape ? screenSize.width * 0.7 : screenSize.width * 0.85;
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
                'Return to main menu to get more lives or wait for them to regenerate.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: dialogWidth * 0.055,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Return to Menu button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    game.exitToMainMenu();
                  },
                  child: Text(
                    'Return to Main Menu',
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
                // Start Playing button
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
                      Navigator.of(context).pop();
                      game.noLivesDialogVisible = false;
                      if (game.livesManager.lives > 0) {
                        game.currentState = GameState.countdown;
                        game.prepareWave();
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
                const SizedBox(height: 12), // Space between buttons
                // Return to Main Menu button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the dialog first
                      // Call the exit to menu callback
                      onExitToMenu?.call();
                    },
                    child: Text(
                      'Return to Main Menu',
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

  String _getFailureMessage(int level, int wave) {
    final currentLevelType =
        LevelTypeConfig.getLevelType(game.waveManager.level);

    if (currentLevelType == LevelType.demon) {
      return 'The demon defeated you at level $level. Choose your next action:';
    } else {
      return 'You failed wave $wave of level $level. Choose your next action:';
    }
  }
}
