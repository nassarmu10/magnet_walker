import 'dart:math';

class WaveManager {
  int level;
  int currentWave;

  // Wave-specific score management
  int waveScore; // Score for current wave only (resets each wave)
  int waveTarget; // Coins needed to complete current wave

  // Demon level persistence
  int? savedDemonHealth; // Store demon's health when player fails
  int? savedDemonMaxHealth; // Store demon's max health

  WaveManager({
    this.level = 1,
    this.currentWave = 1,
    this.waveScore = 0,
    this.waveTarget = 1, //TODO: Change to formula
  });

  // Start a new wave
  void startWave(int wave) {
    currentWave = wave;
    waveScore = 0;
    // Calculate wave target based on level using the new formula
    waveTarget = 1; //TODO: Change to formula
    // waveTarget = level <= 3
    //     ? (3 + level)
    //     : min(8 + (level * 2), 25 + (level * 0.5)).round();
  }

  // Add score to current wave
  void addWaveScore(int points) {
    waveScore += points;
  }

  // Check if current wave is complete
  bool isWaveComplete() {
    return waveScore >= waveTarget;
  }

  // Reset wave score
  void resetWaveScore() {
    waveScore = 0;
  }

  // Save demon health for continue after ad
  void saveDemonHealth(int health, int maxHealth) {
    savedDemonHealth = health;
    savedDemonMaxHealth = maxHealth;
  }

  // Clear saved demon health (when level is completed or restarted)
  void clearDemonHealth() {
    savedDemonHealth = null;
    savedDemonMaxHealth = null;
  }

  // Check if we have saved demon health
  bool hasSavedDemonHealth() {
    return savedDemonHealth != null && savedDemonMaxHealth != null;
  }
}
