import 'package:shared_preferences/shared_preferences.dart';
import '../config/game_config.dart';

class GameProgressManager {
  // Singleton pattern
  static final GameProgressManager _instance = GameProgressManager._internal();
  factory GameProgressManager() => _instance;
  GameProgressManager._internal();

  // Save keys
  static const String _levelKey = 'saved_level';
  static const String _totalScoreKey = 'saved_total_score';
  static const String _currentWaveKey = 'saved_current_wave';
  static const String _wavesCompletedKey = 'saved_waves_completed';
  static const String _musicEnabledKey = 'music_enabled';
  static const String _menuMusicEnabledKey = 'menu_music_enabled';
  static const String _sfxEnabledKey = 'sfx_enabled';

  // Save game progress
  Future<void> saveGameProgress({
    required int level,
    required int totalScore,
    required int currentWave,
    required int wavesCompletedInLevel,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setInt(_levelKey, level),
        prefs.setInt(_totalScoreKey, totalScore),
        prefs.setInt(_currentWaveKey, currentWave),
        prefs.setInt(_wavesCompletedKey, wavesCompletedInLevel),
      ]);
    } catch (e) {
      print('Failed to save game progress: $e');
    }
  }

  // Load game progress
  Future<Map<String, dynamic>> loadGameProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'level': prefs.getInt(_levelKey) ?? 1,
        'totalScore': prefs.getInt(_totalScoreKey) ?? 0,
        'currentWave': prefs.getInt(_currentWaveKey) ?? 1,
        'wavesCompletedInLevel': prefs.getInt(_wavesCompletedKey) ?? 0,
      };
    } catch (e) {
      print('Failed to load game progress: $e');
      return {
        'level': 1,
        'totalScore': 0,
        'currentWave': 1,
        'wavesCompletedInLevel': 0,
      };
    }
  }

  // Save audio settings
  Future<void> saveAudioSettings({
    required bool musicEnabled,
    required bool menuMusicEnabled,
    required bool sfxEnabled,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setBool(_musicEnabledKey, musicEnabled),
        prefs.setBool(_menuMusicEnabledKey, menuMusicEnabled),
        prefs.setBool(_sfxEnabledKey, sfxEnabled),
      ]);
    } catch (e) {
      print('Failed to save audio settings: $e');
    }
  }

  // Load audio settings
  Future<Map<String, bool>> loadAudioSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'musicEnabled': prefs.getBool(_musicEnabledKey) ?? true,
        'menuMusicEnabled': prefs.getBool(_menuMusicEnabledKey) ?? true,
        'sfxEnabled': prefs.getBool(_sfxEnabledKey) ?? true,
      };
    } catch (e) {
      print('Failed to load audio settings: $e');
      return {
        'musicEnabled': true,
        'menuMusicEnabled': true,
        'sfxEnabled': true,
      };
    }
  }

  // Clear all progress (for testing or reset)
  Future<void> clearAllProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      print('Failed to clear progress: $e');
    }
  }

  // Validate saved data
  bool validateProgressData(Map<String, dynamic> data) {
    final level = data['level'] as int? ?? 1;
    final totalScore = data['totalScore'] as int? ?? 0;
    final currentWave = data['currentWave'] as int? ?? 1;
    final wavesCompleted = data['wavesCompletedInLevel'] as int? ?? 0;

    // Basic validation
    if (level < 1) return false;
    if (totalScore < 0) return false;
    if (currentWave < 1 || currentWave > GameConfig.wavesPerLevel) return false;
    if (wavesCompleted < 0 || wavesCompleted >= GameConfig.wavesPerLevel)
      return false;

    return true;
  }

  // Get progress summary for UI
  Map<String, dynamic> getProgressSummary(Map<String, dynamic> progressData) {
    final level = progressData['level'] as int? ?? 1;
    final totalScore = progressData['totalScore'] as int? ?? 0;

    return {
      'level': level,
      'totalScore': totalScore,
      'levelType': level % 2 == 1 ? 'Gravity' : 'Survival',
      'nextLevelType': (level + 1) % 2 == 1 ? 'Gravity' : 'Survival',
    };
  }
}
