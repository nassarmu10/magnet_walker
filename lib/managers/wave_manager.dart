import 'dart:math';

class WaveManager {
  int level;
  int currentWave;

  // Wave-specific score management
  int waveScore; // Score for current wave only (resets each wave)
  int waveTarget; // Coins needed to complete current wave

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
}
