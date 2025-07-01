import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import '../magnet_walker_game.dart';
import '../level_types.dart';

class GameUI extends Component with HasGameRef<MagnetWalkerGame> {
  late TextComponent scoreText;
  late TextComponent levelText;
  late TextComponent levelTypeText;
  late TextComponent playTimeText;
  late TextComponent instructionsText;
  bool gameOverVisible = false;
  bool isInitialized = false;

  // Rectangle background for top bar
  late RectangleComponent topBarBg;

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

    // Top bar background
    topBarBg = RectangleComponent(
      position: Vector2(12, 28),
      size: Vector2(gameSize.x - 24, 70),
      paint: Paint()..color = Colors.black.withOpacity(0.35),
      priority: -1,
    );
    add(topBarBg);

    final leftPadding = gameSize.x * 0.07;
    final rightPadding = gameSize.x * 0.07;
    final topPadding = gameSize.y * 0.06;
    final fontSize =
        (gameSize.x * 0.06).clamp(18.0, 28.0); // Responsive font size

    // Score text
    scoreText = TextComponent(
      text: 'Score: 0',
      position: Vector2(leftPadding, topPadding),
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: 'Roboto',
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(offset: Offset(2, 2), blurRadius: 6, color: Colors.black54),
          ],
        ),
      ),
      anchor: Anchor.topLeft,
    );
    add(scoreText);

    // Level text
    levelText = TextComponent(
      text: 'Level: 1 (Wave 1/3)',
      position: Vector2(gameSize.x - rightPadding, topPadding),
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: 'Roboto',
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(offset: Offset(2, 2), blurRadius: 6, color: Colors.black54),
          ],
        ),
      ),
      anchor: Anchor.topRight,
    );
    add(levelText);

    // Play time text (centered, below mode)
    playTimeText = TextComponent(
      text: 'Time: 00:00',
      position: Vector2(gameSize.x / 2, 78),
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(offset: Offset(2, 2), blurRadius: 6, color: Colors.black54),
          ],
        ),
      ),
      anchor: Anchor.topCenter,
    );
    add(playTimeText);

    // Instructions at the bottom
    instructionsText = TextComponent(
      text: 'Swipe left/right to move • Collect coins • Avoid bombs',
      position: Vector2(gameSize.x / 2, gameSize.y - 50),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: Colors.white,
          fontSize: 16,
          shadows: [
            Shadow(offset: Offset(2, 2), blurRadius: 4, color: Colors.black54),
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

    scoreText.text = 'Score: ${game.score}';
    levelText.text = 'Level: ${game.level} (Wave ${game.currentWave}/3)';

    // Update level type display
    final currentLevelType = LevelTypeConfig.getLevelType(game.level);

    // Update instructions based on level type
    instructionsText.text =
        LevelTypeConfig.getLevelInstructions(currentLevelType);

    // Update play time display
    final minutes = game.playTime.inMinutes;
    final seconds = game.playTime.inSeconds % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    playTimeText.text = 'Time: $timeString';

    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Show wave message/countdown overlay
    if (game.waveMessage != null && game.waveMessage!.isNotEmpty) {
      final gameSize =
          game.camera.viewfinder.visibleGameSize ?? Vector2(375, 667);
      final textPainter = TextPainter(
        text: TextSpan(
          text: game.waveMessage,
          style: const TextStyle(
            fontFamily: 'Roboto',
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                  offset: Offset(2, 2), blurRadius: 8, color: Colors.black87),
            ],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      final offset = Offset(
        (gameSize.x - textPainter.width) / 2,
        (gameSize.y - textPainter.height) / 2 - 40,
      );
      textPainter.paint(canvas, offset);
    }
  }

  void showGameOver(int finalScore, int finalLevel, Duration playTime) {
    gameOverVisible = true;
    // Format play time
    final minutes = playTime.inMinutes;
    final seconds = playTime.inSeconds % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: game.buildContext!,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Game Over!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Text(
                  'Play Time: $timeString',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Final Score: $finalScore',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Level Reached: $finalLevel',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    game.restartGame();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Play Again',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: game.buildContext!,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Level Complete!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Text(
                  'Play Time: $timeString',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Score: $finalScore',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Level: $finalLevel',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Objects will move faster in the next level!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.purple,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      game.restartGame();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Restart',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      game.continueToNextLevel();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Next Level',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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

  void hideGameOver() {
    gameOverVisible = false;
  }

  void hideLevelCompleted() {
    gameOverVisible = false;
  }

  void showWaveFailedDialog(int level, int wave, VoidCallback onRestartLevel,
      VoidCallback onWatchAd) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: game.buildContext!,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Wave Failed!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'You failed wave $wave of level $level.',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Would you like to restart the level or watch an ad to retry this wave?',
                  style: TextStyle(fontSize: 15, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onRestartLevel();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Restart Level',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onWatchAd();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Watch Ad',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
}
