import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../config/game_config.dart';

class LivesManager {
  int lives;
  final int maxLives;
  final int lifeRegenMinutes;
  int lastLifeTimestamp; // Epoch millis

  LivesManager({
    this.lives = GameConfig.maxLives,
    this.maxLives = GameConfig.maxLives,
    this.lifeRegenMinutes = GameConfig.lifeRegenMinutes,
    int? lastLifeTimestamp,
  }) : lastLifeTimestamp =
            lastLifeTimestamp ?? DateTime.now().millisecondsSinceEpoch;

  // Load lives and last life timestamp from SharedPreferences
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    lives = prefs.getInt('lives') ?? GameConfig.maxLives;
    lastLifeTimestamp = prefs.getInt('last_life_timestamp') ??
        DateTime.now().millisecondsSinceEpoch;
  }

  // Save lives and last life timestamp to SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lives', lives);
    await prefs.setInt('last_life_timestamp', lastLifeTimestamp);
  }

  // Regenerate lives based on elapsed time
  void regenerateLivesIfNeeded() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lives >= maxLives) {
      // If already at max, reset timer
      lastLifeTimestamp = now;
      save();
      return;
    }
    final regenMillis = lifeRegenMinutes * 60 * 1000;
    int elapsed = now - lastLifeTimestamp;
    int livesToAdd = elapsed ~/ regenMillis;
    if (livesToAdd > 0) {
      lives = (lives + livesToAdd).clamp(0, maxLives);
      // Set timestamp for next life (if not at max)
      if (lives < maxLives) {
        lastLifeTimestamp = lastLifeTimestamp + livesToAdd * regenMillis;
      } else {
        lastLifeTimestamp = now;
      }
      save();
    }
  }

  // Try to consume a life, return true if successful
  bool tryConsumeLife() {
    if (lives > 0) {
      lives--;
      save();
      return true;
    }
    return false;
  }

  // Get time (in ms) until next life
  int millisUntilNextLife() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final regenMillis = lifeRegenMinutes * 60 * 1000;
    final nextLifeAt = lastLifeTimestamp + regenMillis;
    return (nextLifeAt - now).clamp(0, regenMillis);
  }
}
