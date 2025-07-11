class GameConfig {
  // Player Configuration
  static const double playerRadius = 15.0;
  static const double baseMagnetRadius = 80.0;
  static const double magnetRadiusPerLevel = 3.0;
  static const double maxMagnetRadius = 120.0;

  // Player Position
  static const double gravityModeBottomOffset = 117.0;
  static const double playerAnimationDuration = 2.7;

  // Object Configuration
  static const double coinRadius = 8.0;
  static const double bombRadius = 12.0;
  static const double objectGlowRadius = 5.0;
  static const double rocketSpriteScale = 4.0;

  // Spawn Configuration
  static const double baseGravitySpawnRate = 2.0;
  static const double baseSurvivalSpawnRate = 1.5;
  static const double levelSpawnReductionGravity = 0.15;
  static const double levelSpawnReductionSurvival = 0.1;
  static const double waveSpawnReductionGravity = 0.3;
  static const double waveSpawnReductionSurvival = 0.2;
  static const double minSpawnRateGravity = 0.3;
  static const double minSpawnRateSurvival = 0.2;

  // Object Speed Configuration
  static const double baseGravitySpeed = 50.0;
  static const double gravitySpeedMultiplier = 0.3;
  static const double baseSurvivalSpeed = 80.0;
  static const double survivalSpeedPerLevel = 10.0;
  static const double waveSpeedMultiplier = 0.2;

  // Bomb/Coin Ratios
  static const double baseGravityBombChance = 0.3;
  static const double gravityBombChancePerWave = 0.2;
  static const double baseSurvivalBombChance = 0.6;
  static const double survivalBombChancePerWave = 0.15;

  // Wave Configuration
  static const int wavesPerLevel = 3;
  static const int baseWaveTarget = 3;
  static const double waveTargetMultiplier = 2.0;
  static const int maxWaveTarget = 25;
  static const double waveTargetLevelMultiplier = 0.5;

  // Lives Configuration
  static const int maxLives = 5;
  static const int lifeRegenMinutes = 1;

  // UI Configuration
  static const double headerMarginX = 0.03; // 3% of screen width
  static const double headerMarginY = 0.02; // 2% of screen height
  static const double headerWidth = 0.94; // 94% of screen width
  static const double headerHeight = 0.14; // 14% of screen height
  static const double uiBorderRadius = 16.0;
  static const double uiInnerBorderRadius = 12.0;

  // Audio Configuration
  static const String gameMusicFile = 'game_music.mp3';
  static const String menuMusicFile = 'menu_music.mp3';
  static const String coinSoundFile = 'coin.wav';
  static const String bombSoundFile = 'bomb.wav';
  static const String winSoundFile = 'win.mp3';
  static const String loseSoundFile = 'lose.mp3';
  static const String buttonSoundFile = 'button.mp3';

  // Animation Configuration
  static const double pulseSpeed = 3.0;
  static const double pulseScale = 0.1;
  static const double glowIntensity = 0.3;

  // Collision Configuration
  static const double collisionBuffer = 15.0;
  static const double offscreenBuffer = 50.0;
  static const double survivalDistanceMultiplier = 1.5;

  // Magnetic Force Configuration
  static const double magneticForce = 1000.0;

  // Particle Configuration
  static const int particlesPerExplosion = 8;
  static const double particleVelocityRange = 200.0;

  // Skin Configuration
  static const List<Map<String, dynamic>> skinData = [
    {
      'id': 'default',
      'name': 'Earth',
      'description': 'The classic blue planet',
      'imagePath': 'player.png',
      'price': 1,
      'rarity': 'common',
    },
    {
      'id': 'mars',
      'name': 'Mars',
      'description': 'The red planet of war',
      'imagePath': 'player_mars.png',
      'price': 3,
      'rarity': 'common',
    },
    {
      'id': 'venus',
      'name': 'Venus',
      'description': 'The beautiful morning star',
      'imagePath': 'player_venus.png',
      'price': 5,
      'rarity': 'common',
    },
    {
      'id': 'jupiter',
      'name': 'Jupiter',
      'description': 'The gas giant with storms',
      'imagePath': 'player_jupiter.png',
      'price': 8,
      'rarity': 'rare',
    },
    {
      'id': 'saturn',
      'name': 'Saturn',
      'description': 'The ringed beauty',
      'imagePath': 'player_saturn.png',
      'price': 12,
      'rarity': 'rare',
    },
    {
      'id': 'neptune',
      'name': 'Neptune',
      'description': 'The mysterious ice giant',
      'imagePath': 'player_neptune.png',
      'price': 18,
      'rarity': 'epic',
    },
    {
      'id': 'sun',
      'name': 'The Sun',
      'description': 'The blazing star itself',
      'imagePath': 'player_sun.png',
      'price': 25,
      'rarity': 'legendary',
    },
    {
      'id': 'blackhole',
      'name': 'Black Hole',
      'description': 'The ultimate cosmic mystery',
      'imagePath': 'player_blackhole.png',
      'price': 35,
      'rarity': 'legendary',
    },
  ];

  // Wave Target Calculation
  static int calculateWaveTarget(int level) {
    if (level <= 3) {
      return baseWaveTarget + level;
    } else {
      final calculated =
          (baseWaveTarget + (level * waveTargetMultiplier)).round();
      final maxTarget =
          (maxWaveTarget + (level * waveTargetLevelMultiplier)).round();
      return calculated.clamp(baseWaveTarget, maxTarget);
    }
  }

  // Spawn Rate Calculation
  static double calculateGravitySpawnRate(int level, int wave) {
    final levelReduction = level * levelSpawnReductionGravity;
    final waveReduction = wave * waveSpawnReductionGravity;
    return (baseGravitySpawnRate - levelReduction - waveReduction)
        .clamp(minSpawnRateGravity, baseGravitySpawnRate);
  }

  static double calculateSurvivalSpawnRate(int level, int wave) {
    final levelReduction = level * levelSpawnReductionSurvival;
    final waveReduction = wave * waveSpawnReductionSurvival;
    return (baseSurvivalSpawnRate - levelReduction - waveReduction)
        .clamp(minSpawnRateSurvival, baseSurvivalSpawnRate);
  }

  // Bomb Chance Calculation
  static double calculateGravityBombChance(int wave) {
    return (baseGravityBombChance + (gravityBombChancePerWave * (wave - 1)))
        .clamp(0.0, 1.0);
  }

  static double calculateSurvivalBombChance(int wave) {
    return (baseSurvivalBombChance + (survivalBombChancePerWave * (wave - 1)))
        .clamp(0.0, 1.0);
  }

  // Object Speed Calculation
  static double calculateGravitySpeed(int level, int wave) {
    final baseSpeed =
        baseGravitySpeed * (1.0 + (level * gravitySpeedMultiplier));
    return baseSpeed * (1.0 + (waveSpeedMultiplier * (wave - 1)));
  }

  static double calculateSurvivalSpeed(int level, int wave) {
    final baseSpeed = baseSurvivalSpeed + (level * survivalSpeedPerLevel);
    return baseSpeed * (1.0 + (waveSpeedMultiplier * (wave - 1)));
  }
}
