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
    this.waveTarget = 10,
  });

  // Start a new wave
  void startWave(int wave) {
    currentWave = wave;
    waveScore = 0;
    waveTarget = 10; // Each wave needs 10 coins to complete
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
