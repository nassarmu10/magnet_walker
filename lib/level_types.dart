enum LevelType {
  gravity, // Objects fall from top, player drags horizontally
  survival, // Objects spawn from edges, move toward player, click to destroy bombs
  demon
}

class LevelTypeConfig {
  static LevelType getLevelType(int level) {
    if (level <= 10) {
      // Early levels: mostly Gravity & Survival, no Demon
      return (level % 2 == 1) ? LevelType.gravity : LevelType.survival;
    } else if (level < 20) {
      // Introduce Demon occasionally: 1 Demon every 4 levels
      final mod = level % 4;
      if (mod == 0) return LevelType.demon;
      return (mod.isOdd) ? LevelType.gravity : LevelType.survival;
    } else if (level <= 40) {
      // Demon more common: 1 Demon every 3 levels
      final mod = level % 3;
      if (mod == 0) return LevelType.demon;
      return (mod == 1) ? LevelType.gravity : LevelType.survival;
    } else {
      // Late game: Demon appears often, but still cycling
      final mod = level % 3;
      if (mod == 0) return LevelType.demon;
      return (mod == 1) ? LevelType.gravity : LevelType.survival;
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
}
