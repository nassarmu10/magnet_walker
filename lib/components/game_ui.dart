import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../magnet_walker_game.dart';

class GameUI extends Component with HasGameRef<MagnetWalkerGame> {
  late TextComponent scoreText;
  late TextComponent levelText;
  late TextComponent instructionsText;
  bool gameOverVisible = false;

  @override
  Future<void> onLoad() async {
    // final game = gameReference;
    // if (game == null) return;
    
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
      position: Vector2(game.size.x - 120, 50),
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
    
    // Instructions
    instructionsText = TextComponent(
      text: 'Swipe left/right to move • Collect coins • Avoid bombs',
      position: Vector2(game.size.x / 2, game.size.y - 50),
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
  }

  @override
  void update(double dt) {
    // final game = gameReference;
    // if (game == null) return;
    
    scoreText.text = 'Score: ${game.score}';
    levelText.text = 'Level: ${game.level}';
    super.update(dt);
  }

  void showGameOver(int finalScore, int finalLevel) {
    gameOverVisible = true;
    // In a real implementation, you'd show a Flutter overlay here
    print('Game Over! Score: $finalScore, Level: $finalLevel');
  }

  void hideGameOver() {
    gameOverVisible = false;
  }
}
