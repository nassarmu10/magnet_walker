import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import '../magnet_walker_game.dart';
import '../level_types.dart';
import 'dart:math' as math;

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
  late TextComponent instructionsText;
  bool gameOverVisible = false;
  bool isInitialized = false;

  // Modern UI components
  late RoundedRectComponent headerBg;
  late RoundedRectComponent scoreBg;
  late RoundedRectComponent levelBg;
  late RoundedRectComponent timeBg;
  
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
    final gameSize =
        game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);

    // Main header background with gradient effect
    headerBg = RoundedRectComponent(
      position: Vector2(8, 25),
      size: Vector2(gameSize.x - 16, 80),
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
        ).createShader(Rect.fromLTWH(8, 25, gameSize.x - 16, 80)),
      radius: 15.0,
      priority: -2,
    );
    add(headerBg);

    // Score container with neon effect
    scoreBg = RoundedRectComponent(
      position: Vector2(20, 35),
      size: Vector2(100, 35),
      paint: Paint()
        ..color = const Color(0xFF00ff88).withOpacity(0.15),
      radius: 8.0,
      priority: -1,
    );
    add(scoreBg);

    // Level container with cosmic effect
    levelBg = RoundedRectComponent(
      position: Vector2(gameSize.x - 120, 35),
      size: Vector2(100, 35),
      paint: Paint()
        ..color = const Color(0xFF8844ff).withOpacity(0.15),
      radius: 8.0,
      priority: -1,
    );
    add(levelBg);

    // Time container with space effect
    timeBg = RoundedRectComponent(
      position: Vector2(gameSize.x / 2 - 50, 75),
      size: Vector2(100, 25),
      paint: Paint()
        ..color = const Color(0xFF44aaff).withOpacity(0.15),
      radius: 6.0,
      priority: -1,
    );
    add(timeBg);

    // Score text with neon green theme - centered in score container
    scoreText = TextComponent(
      text: 'Score: 0',
      position: Vector2(70, 52.5), // Center of score container (20 + 100/2, 35 + 35/2)
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
      anchor: Anchor.center,
    );
    add(scoreText);

    // Level text with cosmic purple theme - centered in level container
    levelText = TextComponent(
      text: 'Level: 1',
      position: Vector2(gameSize.x - 70, 52.5), // Center of level container
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

    // Play time text with space blue theme - centered in time container
    playTimeText = TextComponent(
      text: 'TIME: 00:00',
      position: Vector2(gameSize.x / 2, 87.5), // Center of time container (75 + 25/2)
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: Color(0xFF44aaff),
          fontSize: 12,
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
      anchor: Anchor.center,
    );
    add(playTimeText);

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

    isInitialized = true;
  }

  @override
  void update(double dt) {
    if (!isInitialized) return;

    // Update animation time
    pulseTime += dt * 2.0;
    glowIntensity = (math.sin(pulseTime) * 0.5 + 0.5) * 0.3 + 0.7;

    // Update text content
    scoreText.text = 'SCORE: ${game.score}';
    levelText.text = 'LVL: ${game.level}';

    // Update level type display
    final currentLevelType = LevelTypeConfig.getLevelType(game.level);

    // Update instructions based on level type with modern styling
    final instructions = LevelTypeConfig.getLevelInstructions(currentLevelType);
    instructionsText.text = instructions.toUpperCase();

    // Update play time display
    final minutes = game.playTime.inMinutes;
    final seconds = game.playTime.inSeconds % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    playTimeText.text = 'TIME: $timeString';

    // Update container colors with pulsing effect
    final glowOpacity = (glowIntensity * 0.3).clamp(0.1, 0.3);
    
    scoreBg.paint.color = Color(0xFF00ff88).withOpacity(glowOpacity);
    levelBg.paint.color = Color(0xFF8844ff).withOpacity(glowOpacity);
    timeBg.paint.color = Color(0xFF44aaff).withOpacity(glowOpacity);

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
  }

  void _renderStarField(Canvas canvas) {
    final gameSize = game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);
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
    final gameSize = game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);
    
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

  // Enhanced dialog methods with modern styling
  void showGameOver(int finalScore, int finalLevel, Duration playTime) {
    gameOverVisible = true;

    // Format play time
    final minutes = playTime.inMinutes;
    final seconds = playTime.inSeconds % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    // Show game over dialog using Flutter's overlay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: game.buildContext!,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1a1a2e),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
              side: BorderSide(
                color: const Color(0xFF44aaff).withOpacity(0.5),
                width: 2,
              ),
            ),
            title: const Text(
              'GAME OVER',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFFff4444),
                letterSpacing: 2.0,
                shadows: [
                  Shadow(
                    offset: Offset(0, 0),
                    blurRadius: 10,
                    color: Color(0xFFff4444),
                  ),
                ],
              ),
            ),
            content: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatRow('⏱️ TIME', timeString, const Color(0xFF44aaff)),
                  const SizedBox(height: 15),
                  _buildStatRow('⭐ SCORE', '$finalScore', const Color(0xFF00ff88)),
                  const SizedBox(height: 15),
                  _buildStatRow('🚀 LEVEL', '$finalLevel', const Color(0xFF8844ff)),
                  const SizedBox(height: 25),
                ],
              ),
            ),
            actions: [
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF44aaff), Color(0xFF0088cc)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF44aaff).withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      game.restartGame();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'PLAY AGAIN',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
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
      showDialog(
        context: game.buildContext!,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1a1a2e),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
              side: BorderSide(
                color: const Color(0xFF00ff88).withOpacity(0.5),
                width: 2,
              ),
            ),
            title: const Text(
              'LEVEL COMPLETE! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00ff88),
                letterSpacing: 1.5,
                shadows: [
                  Shadow(
                    offset: Offset(0, 0),
                    blurRadius: 10,
                    color: Color(0xFF00ff88),
                  ),
                ],
              ),
            ),
            content: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatRow('⏱️ TIME', timeString, const Color(0xFF44aaff)),
                  const SizedBox(height: 15),
                  _buildStatRow('⭐ SCORE', '$finalScore', const Color(0xFF00ff88)),
                  const SizedBox(height: 15),
                  _buildStatRow('🚀 LEVEL', '$finalLevel', const Color(0xFF8844ff)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8844ff).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFF8844ff).withOpacity(0.3),
                      ),
                    ),
                    child: const Text(
                      'NEXT LEVEL WILL BE FASTER!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8844ff),
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
                  _buildActionButton(
                    'RESTART',
                    const Color(0xFF666666),
                    () {
                      Navigator.of(context).pop();
                      game.restartGame();
                    },
                  ),
                  _buildActionButton(
                    'NEXT LEVEL',
                    const Color(0xFF00ff88),
                    () {
                      Navigator.of(context).pop();
                      game.continueToNextLevel();
                    },
                  ),
                ],
              ),
            ],
          );
        },
      );
    });
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color.withOpacity(0.8),
            letterSpacing: 1.0,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
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

  Widget _buildActionButton(String text, Color color, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
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
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.0,
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
}
