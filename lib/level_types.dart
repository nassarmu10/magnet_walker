enum LevelType {
  gravity, // Objects fall from top, player drags horizontally
  survival, // Objects spawn from edges, move toward player, click to destroy bombs
  demon
}

class LevelTypeConfig {
  static LevelType getLevelType(int level) {
    // Alternate between gravity and survival every level

    switch (level % 3) {
      case 1:
        return LevelType.gravity;
      case 2:
        return LevelType.demon;
      case 0:
      default:
        return LevelType.survival; // Replace with your third type
    }
  }

  static String getLevelTypeName(LevelType type) {
    switch (type) {
      case LevelType.gravity:
        return 'Gravity Mode';
      case LevelType.survival:
        return 'Survival Mode';
      case LevelType.demon:
        return 'Demon Mode';
    }
  }

  static String getLevelInstructions(LevelType type) {
    switch (type) {
      case LevelType.gravity:
        return 'Swipe left/right to move • Collect coins • Avoid bombs';
      case LevelType.survival:
        return 'Click bombs to destroy • Collect coins • Survive!';
      case LevelType.demon:
        return 'Launch back rockets on demon • Avoid bombs • Collect coins • Survive!';
    }
  }
}
