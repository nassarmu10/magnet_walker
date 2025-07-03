class WaveManager {
  int level;
  int currentWave;
  int score;
  int scoreThisWave;
  int levelProgress;
  int targetScore;
  int wavesPerLevel;

  WaveManager({
    this.level = 1,
    this.currentWave = 1,
    this.score = 0,
    this.scoreThisWave = 0,
    this.levelProgress = 0,
    this.wavesPerLevel = 3,
  }) : targetScore = 10;

  // Start a new wave
  void startWave(int wave) {
    currentWave = wave;
    scoreThisWave = 0;
  }

  // End the current wave
  void endWave() {
    // Logic for ending a wave can be added here
  }

  // Progress to the next wave or level
  void progress() {
    if (currentWave < wavesPerLevel) {
      startWave(currentWave + 1);
    } else {
      nextLevel();
    }
  }

  // Move to the next level
  void nextLevel() {
    level++;
    currentWave = 1;
    score = 0;
    scoreThisWave = 0;
    levelProgress = 0;
    targetScore = level * 8 + 5;
  }

  // Reset all progress
  void reset() {
    level = 1;
    currentWave = 1;
    score = 0;
    scoreThisWave = 0;
    levelProgress = 0;
    targetScore = 10;
  }
}
