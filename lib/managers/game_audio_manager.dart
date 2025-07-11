import 'package:flame_audio/flame_audio.dart';
import '../config/game_config.dart';

class GameAudioManager {
  // Singleton pattern
  static final GameAudioManager _instance = GameAudioManager._internal();
  factory GameAudioManager() => _instance;
  GameAudioManager._internal();

  // Audio state
  bool _sfxEnabled = true;
  bool _musicEnabled = true;
  bool _menuMusicEnabled = true;

  // Current music track
  String? _currentMusicTrack;
  bool _isMusicPlaying = false;

  // Getters
  bool get sfxEnabled => _sfxEnabled;
  bool get musicEnabled => _musicEnabled;
  bool get menuMusicEnabled => _menuMusicEnabled;
  bool get isMusicPlaying => _isMusicPlaying;
  String? get currentMusicTrack => _currentMusicTrack;

  // SFX Methods
  void setSfxEnabled(bool enabled) {
    _sfxEnabled = enabled;
  }

  void playSound(String fileName) {
    if (!_sfxEnabled) return;

    try {
      FlameAudio.play(fileName);
    } catch (e) {
      print('Failed to play sound $fileName: $e');
    }
  }

  void playCoinSound() {
    playSound(GameConfig.coinSoundFile);
  }

  void playBombSound() {
    playSound(GameConfig.bombSoundFile);
  }

  void playWinSound() {
    playSound(GameConfig.winSoundFile);
  }

  void playLoseSound() {
    playSound(GameConfig.loseSoundFile);
  }

  void playButtonSound() {
    playSound(GameConfig.buttonSoundFile);
  }

  // Music Methods
  void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
    if (!enabled) {
      stopMusic();
    }
  }

  void setMenuMusicEnabled(bool enabled) {
    _menuMusicEnabled = enabled;
    if (!enabled && _currentMusicTrack == GameConfig.menuMusicFile) {
      stopMusic();
    }
  }

  void playGameMusic() {
    if (!_musicEnabled) return;

    try {
      if (_currentMusicTrack != GameConfig.gameMusicFile) {
        stopMusic();
        FlameAudio.bgm.play(GameConfig.gameMusicFile);
        _currentMusicTrack = GameConfig.gameMusicFile;
        _isMusicPlaying = true;
      }
    } catch (e) {
      print('Failed to play game music: $e');
    }
  }

  void playMenuMusic() {
    if (!_menuMusicEnabled) return;

    try {
      if (_currentMusicTrack != GameConfig.menuMusicFile) {
        stopMusic();
        FlameAudio.bgm.play(GameConfig.menuMusicFile);
        _currentMusicTrack = GameConfig.menuMusicFile;
        _isMusicPlaying = true;
      }
    } catch (e) {
      print('Failed to play menu music: $e');
    }
  }

  void stopMusic() {
    try {
      FlameAudio.bgm.stop();
      _currentMusicTrack = null;
      _isMusicPlaying = false;
    } catch (e) {
      print('Failed to stop music: $e');
    }
  }

  void pauseMusic() {
    try {
      FlameAudio.bgm.pause();
      _isMusicPlaying = false;
    } catch (e) {
      print('Failed to pause music: $e');
    }
  }

  void resumeMusic() {
    try {
      if (_currentMusicTrack != null && !_isMusicPlaying) {
        FlameAudio.bgm.resume();
        _isMusicPlaying = true;
      }
    } catch (e) {
      print('Failed to resume music: $e');
    }
  }

  // Volume control methods removed - not supported by current Flame Audio version
  // These can be added back when volume control is needed and supported

  // Cleanup
  void dispose() {
    stopMusic();
  }
}
