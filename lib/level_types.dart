enum LevelType {
  gravity, // Objects fall from top, player drags horizontally
  survival // Objects spawn from edges, move toward player, click to destroy bombs
}

class LevelTypeConfig {
  static LevelType getLevelType(int level) {
    // Alternate between gravity and survival every level
    return level % 2 == 1 ? LevelType.gravity : LevelType.survival;
  }

  static String getLevelTypeName(LevelType type) {
    switch (type) {
      case LevelType.gravity:
        return 'Gravity Mode';
      case LevelType.survival:
        return 'Survival Mode';
    }
  }

  static String getLevelInstructions(LevelType type) {
    switch (type) {
      case LevelType.gravity:
        return 'Swipe left/right to move • Collect coins • Avoid bombs';
      case LevelType.survival:
        return 'Click bombs to destroy • Collect coins • Survive!';
    }
  }
}
