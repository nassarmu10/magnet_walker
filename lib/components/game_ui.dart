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

  // Modern UI components
  late RoundedRectComponent headerBg;
  late RoundedRectComponent scoreBg;
  late RoundedRectComponent levelBg;
  late RoundedRectComponent timeBg;
  late ButtonComponent skinStoreButton;
  late RoundedRectComponent targetScoreBg;

  // Animation properties
  double pulseTime = 0.0;
  double glowIntensity = 0.0;

  late ButtonComponent livesButton;

  @override
  Future<void> onLoad() async {
    // Wait for the game to be properly initialized
    await Future.delayed(const Duration(milliseconds: 100));
    _initializeUI();
  }

  void _initializeUI() {
    if (isInitialized) return;

    // Use camera size instead of game size
    final gameSize =
        game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);

    // Responsive header background
    // Old: position: Vector2(8, 25), size: Vector2(gameSize.x - 16, 80)
    // New: 2% margin left/right, 4% from top, 12% of height
    final headerMarginX = gameSize.x * 0.02;
    final headerMarginY = gameSize.y * 0.04;
    final headerWidth = gameSize.x * 0.96;
    final headerHeight = gameSize.y * 0.12;
    headerBg = RoundedRectComponent(
      position: Vector2(headerMarginX, headerMarginY),
      size: Vector2(headerWidth, headerHeight),
      paint: Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1a1a2e).withOpacity(0.95),
            const Color(0xFF16213e).withOpacity(0.90),
            const Color(0xFF0f0f23).withOpacity(0.85),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(
            headerMarginX, headerMarginY, headerWidth, headerHeight)),
      radius: headerHeight * 0.18, // 18% of header height for rounded corners
      priority: -2,
    );
    add(headerBg);

    // Responsive Score container
    // Old: position: Vector2(20, 35), size: Vector2(scoreRectWidth, 35)
    final scorePadding = gameSize.x * 0.04; // 4% of width
    final scoreRectHeight = headerHeight * 0.4;
    final scoreTextStr = 'Score: 0';
    final scoreTextStyle = TextStyle(
      fontFamily: 'Roboto',
      color: const Color(0xFF00ff88),
      fontSize: headerHeight * 0.22, // Responsive font size
      fontWeight: FontWeight.w700,
      shadows: const [
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
    );
    final scoreTextPainter = TextPainter(
      text: TextSpan(text: scoreTextStr, style: scoreTextStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final scoreRectWidth = scoreTextPainter.width + scorePadding * 2;
    final scoreRectY = headerMarginY + headerHeight * 0.15;
    scoreBg = RoundedRectComponent(
      position: Vector2(headerMarginX + headerWidth * 0.02, scoreRectY),
      size: Vector2(scoreRectWidth, scoreRectHeight),
      paint: Paint()..color = const Color(0xFF00ff88).withOpacity(0.15),
      radius: scoreRectHeight * 0.23,
      priority: -1,
    );
    add(scoreBg);

    // Responsive Level container
    // Old: position: Vector2(gameSize.x - levelRectWidth - 20, 35), size: Vector2(levelRectWidth, 35)
    final levelPadding = gameSize.x * 0.04;
    final levelRectHeight = scoreRectHeight;
    final levelTextStr = 'Level: 1 (Wave 1/3)';
    final levelTextStyle = TextStyle(
      fontFamily: 'Roboto',
      color: const Color(0xFF8844ff),
      fontSize: headerHeight * 0.19,
      fontWeight: FontWeight.w700,
      shadows: [
        const Shadow(
          offset: Offset(0, 0),
          blurRadius: 8,
          color: Color(0xFF8844ff),
        ),
        const Shadow(
          offset: Offset(1, 1),
          blurRadius: 4,
          color: Colors.black87,
        ),
      ],
    );
    final levelTextPainter = TextPainter(
      text: TextSpan(text: levelTextStr, style: levelTextStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final levelRectWidth = levelTextPainter.width + levelPadding * 2;
    final levelRectY = scoreRectY;
    levelBg = RoundedRectComponent(
      position: Vector2(
          headerMarginX + headerWidth - levelRectWidth - headerWidth * 0.02,
          levelRectY),
      size: Vector2(levelRectWidth, levelRectHeight),
      paint: Paint()..color = const Color(0xFF8844ff).withOpacity(0.15),
      radius: levelRectHeight * 0.23,
      priority: -1,
    );
    add(levelBg);

    // Responsive Time container
    // Old: position: Vector2(gameSize.x / 2 - timeRectWidth / 2, 75), size: Vector2(timeRectWidth, 25)
    final timePadding = gameSize.x * 0.03;
    final timeRectHeight = headerHeight * 0.32;
    final timeTextStr = 'Time: 00:00';
    final timeTextStyle = TextStyle(
      fontFamily: 'Roboto',
      color: const Color(0xFF44aaff),
      fontSize: headerHeight * 0.16,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      shadows: [
        const Shadow(
          offset: Offset(0, 0),
          blurRadius: 6,
          color: Color(0xFF44aaff),
        ),
        const Shadow(
          offset: Offset(1, 1),
          blurRadius: 3,
          color: Colors.black87,
        ),
      ],
    );
    final timeTextPainter = TextPainter(
      text: TextSpan(text: timeTextStr, style: timeTextStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final timeRectWidth = timeTextPainter.width + timePadding * 2;
    final timeRectY = headerMarginY + headerHeight * 0.62;
    timeBg = RoundedRectComponent(
      position: Vector2((gameSize.x - timeRectWidth) / 2, timeRectY),
      size: Vector2(timeRectWidth, timeRectHeight),
      paint: Paint()..color = const Color(0xFF44aaff).withOpacity(0.15),
      radius: timeRectHeight * 0.3,
      priority: -1,
    );
    add(timeBg);

    // Responsive Target Score container
    final targetScorePadding = gameSize.x * 0.03;
    final targetScoreRectHeight = headerHeight * 0.32;
    final targetScoreTextStr = 'Target: 13';
    final targetScoreTextStyle = TextStyle(
      fontFamily: 'Roboto',
      color: const Color(0xFFff8844),
      fontSize: headerHeight * 0.16,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      shadows: [
        const Shadow(
          offset: Offset(0, 0),
          blurRadius: 6,
          color: Color(0xFFff8844),
        ),
        const Shadow(
          offset: Offset(1, 1),
          blurRadius: 3,
          color: Colors.black87,
        ),
      ],
    );
    final targetScoreTextPainter = TextPainter(
      text: TextSpan(text: targetScoreTextStr, style: targetScoreTextStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final targetScoreRectWidth =
        targetScoreTextPainter.width + targetScorePadding * 2;
    final targetScoreRectY = headerMarginY + headerHeight * 0.62;
    targetScoreBg = RoundedRectComponent(
      position: Vector2(headerMarginX + headerWidth * 0.02, targetScoreRectY),
      size: Vector2(targetScoreRectWidth, targetScoreRectHeight),
      paint: Paint()..color = const Color(0xFFff8844).withOpacity(0.15),
      radius: targetScoreRectHeight * 0.3,
      priority: -1,
    );
    add(targetScoreBg);

    // Score text with neon green theme - centered in score container
    scoreText = TextComponent(
      text: 'Score: 0',
      position: Vector2(
        scoreBg.position.x + scoreBg.size.x / 2,
        scoreBg.position.y + scoreBg.size.y / 2,
      ),
      textRenderer: TextPaint(
        style: scoreTextStyle,
      ),
      anchor: Anchor.center,
    );
    add(scoreText);

    // Level text with cosmic purple theme - centered in level container
    levelText = TextComponent(
      text: 'Level: 1 (Wave 1/3)',
      position: Vector2(
        levelBg.position.x + levelBg.size.x / 2,
        levelBg.position.y + levelBg.size.y / 2,
      ),
      textRenderer: TextPaint(
        style: levelTextStyle,
      ),
      anchor: Anchor.center,
    );
    add(levelText);

    // Play time text with space blue theme - centered in time container
    playTimeText = TextComponent(
      text: 'Time: 00:00',
      position: Vector2(
        timeBg.position.x + timeBg.size.x / 2,
        timeBg.position.y + timeBg.size.y / 2,
      ),
      textRenderer: TextPaint(
        style: timeTextStyle,
      ),
      anchor: Anchor.center,
    );
    add(playTimeText);

    // Target score text with orange theme - centered in target score container
    targetScoreText = TextComponent(
      text: 'Target: 13',
      position: Vector2(
        targetScoreBg.position.x + targetScoreBg.size.x / 2,
        targetScoreBg.position.y + targetScoreBg.size.y / 2,
      ),
      textRenderer: TextPaint(
        style: targetScoreTextStyle,
      ),
      anchor: Anchor.center,
    );
    add(targetScoreText);

    // Modern instructions at the bottom
    instructionsText = TextComponent(
      text: 'Swipe left/right to move • Collect coins • Avoid bombs',
      position: Vector2(gameSize.x / 2, gameSize.y - 45),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: Color(0xFF88aacc),
          fontSize: 14,
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

    // Heart and lives counter (top right)
    livesText = TextComponent(
      text: '❤️ ${game.livesManager.lives}',
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: 'Roboto',
          color: Colors.redAccent,
          fontSize: headerHeight * 0.32,
          fontWeight: FontWeight.bold,
          shadows: [
            const Shadow(
              offset: Offset(0, 0),
              blurRadius: 6,
              color: Colors.black54,
            ),
          ],
        ),
      ),
      priority: 10,
    );
    livesButton = ButtonComponent(
      position: Vector2(headerMarginX + headerWidth - 10, headerMarginY + 10),
      size: Vector2(headerHeight * 1.1, headerHeight * 0.6),
      anchor: Anchor.topRight,
      button: RectangleComponent(
        size: Vector2(headerHeight * 1.1, headerHeight * 0.6),
        paint: Paint()..color = const Color(0x00000000), // transparent
      ),
      children: [livesText],
      onPressed: showLivesDialog,
      priority: 10,
    );
    add(livesButton);

    //   skinStoreButton = ButtonComponent(
    //   position: Vector2(headerMarginX + 10, headerMarginY + 10),
    //   size: Vector2(headerHeight * 0.8, headerHeight * 0.6),
    //   anchor: Anchor.topLeft,
    //   button: RectangleComponent(
    //     size: Vector2(headerHeight * 0.8, headerHeight * 0.6),
    //     paint: Paint()
    //       ..color = const Color(0xFF8844ff).withOpacity(0.8)
    //       ..style = PaintingStyle.fill,
    //   ),
    //   children: [
    //     TextComponent(
    //       text: '👕',
    //       anchor: Anchor.center,
    //       textRenderer: TextPaint(
    //         style: TextStyle(
    //           fontSize: headerHeight * 0.25,
    //         ),
    //       ),
    //       position: Vector2(headerHeight * 0.4, headerHeight * 0.3),
    //     ),
    //   ],
    //   onPressed: showSkinStore,
    //   priority: 10,
    // );
    // add(skinStoreButton);

    isInitialized = true;
  }

  // void showSkinStore() {
  //   final context = game.buildContext;
  //   if (context == null) {
  //     // If context is not available yet, schedule to show later
  //     Future.delayed(const Duration(milliseconds: 500), () {
  //       if (game.buildContext != null) {
  //         showSkinStore();
  //       }
  //     });
  //     return;
  //   }

  //   Navigator.of(context).push(
  //     MaterialPageRoute(
  //       builder: (context) => SkinStoreScreen(
  //         skinManager: game.skinManager,
  //         onSkinChanged: () {
  //           game.onSkinChanged();
  //         },
  //       ),
  //     ),
  //   );
  // }

  @override
  void update(double dt) {
    if (!isInitialized) return;

    // Update animation time
    pulseTime += dt * 2.0;
    glowIntensity = (math.sin(pulseTime) * 0.5 + 0.5) * 0.3 + 0.7;

    // Update text content with wave information
    scoreText.text = 'Total: ${game.totalScore}';
    levelText.text =
        'Level: ${game.waveManager.level} (Wave ${game.waveManager.currentWave}/3)';

    // Update target score display
    targetScoreText.text =
        'Wave: ${game.waveManager.waveScore}/${game.waveManager.waveTarget}';

    // Update level type display
    final currentLevelType =
        LevelTypeConfig.getLevelType(game.waveManager.level);

    // Update instructions based on level type with modern styling
    final instructions = LevelTypeConfig.getLevelInstructions(currentLevelType);
    instructionsText.text = instructions;

    // Update play time display
    final minutes = game.playTime.inMinutes;
    final seconds = game.playTime.inSeconds % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    playTimeText.text = 'Time: $timeString';

    // Update container colors with pulsing effect
    final glowOpacity = (glowIntensity * 0.3).clamp(0.1, 0.3);

    scoreBg.paint.color = Color(0xFF00ff88).withOpacity(glowOpacity);
    levelBg.paint.color = Color(0xFF8844ff).withOpacity(glowOpacity);
    timeBg.paint.color = Color(0xFF44aaff).withOpacity(glowOpacity);
    targetScoreBg.paint.color = Color(0xFFff8844).withOpacity(glowOpacity);

    // Update lives counter
    livesText.text = '❤️ ${game.livesManager.lives}';

    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (!isInitialized) return;

    // Add subtle star field effect to header
    _renderStarField(canvas);

    // Add border glow effects
    _renderGlowEffects(canvas);

    // Show wave message/countdown overlay with modern styling
    if (game.waveMessage != null && game.waveMessage!.isNotEmpty) {
      final gameSize =
          game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);

      // Dynamically size the background for wave message
      final message = game.waveMessage!;
      final messageTextStyle = const TextStyle(
        fontFamily: 'Roboto',
        color: Color(0xFF00ff88),
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        shadows: [
          Shadow(
            offset: Offset(0, 0),
            blurRadius: 10,
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

      final padding = gameSize.x * 0.08; // 8% of width as padding
      final rectWidth = textPainter.width + padding;
      final rectHeight = textPainter.height + padding * 0.7;

      final messageBg = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(gameSize.x / 2, gameSize.y / 2 - 40),
          width: rectWidth,
          height: rectHeight,
        ),
        Radius.circular(rectHeight * 0.3),
      );

      final bgPaint = Paint()
        ..color = const Color(0xFF1a1a2e).withOpacity(0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawRRect(messageBg, bgPaint);

      // Border glow
      final borderPaint = Paint()
        ..color = const Color(0xFF44aaff).withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawRRect(messageBg, borderPaint);

      // Wave message text
      final offset = Offset(
        (gameSize.x - textPainter.width) / 2,
        (gameSize.y - textPainter.height) / 2 - 40,
      );
      textPainter.paint(canvas, offset);
    }
  }

  void _renderStarField(Canvas canvas) {
    final gameSize =
        game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);
    final starPaint = Paint()..color = Colors.white.withOpacity(0.6);

    // Static stars for header background
    final stars = [
      Offset(50, 40),
      Offset(120, 55),
      Offset(200, 35),
      Offset(280, 50),
      Offset(320, 42),
    ];

    for (final star in stars) {
      if (star.dx < gameSize.x - 16 && star.dy > 25 && star.dy < 105) {
        canvas.drawCircle(star, 1.0, starPaint);
      }
    }
  }

  void _renderGlowEffects(Canvas canvas) {
    final gameSize =
        game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);

    // Header border glow
    final glowPaint = Paint()
      ..color = Color(0xFF44aaff).withOpacity(glowIntensity * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final headerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 25, gameSize.x - 16, 80),
      const Radius.circular(15),
    );

    canvas.drawRRect(headerRect, glowPaint);
  }

  // Unified failure dialog that handles all failure scenarios
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

  // Stub for lives dialog
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
    );
  }
}
