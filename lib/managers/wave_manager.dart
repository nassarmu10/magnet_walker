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
    // Use the same logic as setTarget() for consistency
    setTarget();
  }

  void setTarget() {
    print('WaveManager: Setting target for level $level');
    if (level == 1) {
      waveTarget = 1; // Just 1 coin for level 1
    } else if (level == 2) {
      waveTarget = 2; // 2 coins for level 2
    } else if (level <= 10) {
      // Gradually increase: level 3=3, level 4=4, etc up to level 10=10
      waveTarget = level;
    } else if (level <= 20) {
      // Mid levels: gradual increase from 10-15
      waveTarget = 10 + ((level - 10) ~/ 2); // 10, 11, 12, 13, 14, 15
    } else {
      // High levels: cap at around 15–20
      waveTarget = 15 + ((level - 20) ~/ 5);
      waveTarget = waveTarget.clamp(15, 20); // safety cap
    }
    print('WaveManager: Target set to $waveTarget for level $level');
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
