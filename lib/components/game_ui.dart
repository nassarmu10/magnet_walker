import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import '../magnet_walker_game.dart';

class GameUI extends Component with HasGameRef<MagnetWalkerGame> {
  late TextComponent scoreText;
  late TextComponent levelText;
  late TextComponent playTimeText;
  late TextComponent instructionsText;
  bool gameOverVisible = false;
  bool isInitialized = false;

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

    // Score text
    scoreText = TextComponent(
      text: 'Score: 0',
      position: Vector2(20, 50),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: Offset(2, 2),
              blurRadius: 4,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );
    add(scoreText);

    // Level text
    levelText = TextComponent(
      text: 'Level: 1',
      position: Vector2(gameSize.x - 120, 50),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: Offset(2, 2),
              blurRadius: 4,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );
    add(levelText);

    // Play time text
    playTimeText = TextComponent(
      text: 'Time: 00:00',
      position: Vector2(gameSize.x / 2, 50),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(
              offset: Offset(2, 2),
              blurRadius: 4,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );
    add(playTimeText);

    // Instructions
    instructionsText = TextComponent(
      text: 'Swipe left/right to move • Collect coins • Avoid bombs',
      position: Vector2(gameSize.x / 2, gameSize.y - 50),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          shadows: [
            Shadow(
              offset: Offset(2, 2),
              blurRadius: 4,
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

    scoreText.text = 'Score: ${game.score}';
    levelText.text = 'Level: ${game.level}';

    // Update play time display
    final minutes = game.playTime.inMinutes;
    final seconds = game.playTime.inSeconds % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    playTimeText.text = 'Time: $timeString';

    super.update(dt);
  }

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

  void hideGameOver() {
    gameOverVisible = false;
  }
}
