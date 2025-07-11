import 'dart:async';
import 'package:flutter/material.dart';
import '../config/game_config.dart';

enum GameState {
  initializing,
  menu,
  paused,
  waveCountdown,
  waveActive,
  waveComplete,
  levelComplete,
  gameOver,
  exiting,
}

enum LevelType {
  gravity,
  survival,
}

class GameStateManager {
  // Singleton pattern for global access
  static final GameStateManager _instance = GameStateManager._internal();
  factory GameStateManager() => _instance;
  GameStateManager._internal();

  // State variables
  GameState _currentState = GameState.initializing;
  bool _isPaused = false;
  bool _isWaveActive = false;
  bool _isLevelComplete = false;
  bool _gameRunning = false;

  // Wave and level management
  int _level = 1;
  int _currentWave = 1;
  int _wavesCompletedInLevel = 0;
  int _totalScore = 0;
  int _waveScore = 0;
  int _waveTarget = 1;

  // Play time tracking
  DateTime? _gameStartTime;
  DateTime? _pauseStartTime;
  Duration _playTime = Duration.zero;
  Duration _pausedTime = Duration.zero;
  Timer? _playTimeTimer;

  // Wave countdown
  double _waveCountdown = 0.0;
  String? _waveMessage;

  // Callbacks
  VoidCallback? onStateChanged;
  VoidCallback? onWaveStarted;
  VoidCallback? onWaveCompleted;
  VoidCallback? onLevelCompleted;
  VoidCallback? onGameOver;
  VoidCallback? onPause;
  VoidCallback? onResume;

  // Getters
  GameState get currentState => _currentState;
  bool get isPaused => _isPaused;
  bool get isWaveActive => _isWaveActive;
  bool get isLevelComplete => _isLevelComplete;
  bool get gameRunning => _gameRunning;
  int get level => _level;
  int get currentWave => _currentWave;
  int get wavesCompletedInLevel => _wavesCompletedInLevel;
  int get totalScore => _totalScore;
  int get waveScore => _waveScore;
  int get waveTarget => _waveTarget;
  Duration get playTime => _playTime;
  double get waveCountdown => _waveCountdown;
  String? get waveMessage => _waveMessage;

  // Level type calculation
  LevelType get currentLevelType =>
      _level % 2 == 1 ? LevelType.gravity : LevelType.survival;

  // State transition methods
  void setState(GameState newState) {
    if (_currentState == newState) return;

    final oldState = _currentState;
    _currentState = newState;

    // Handle state-specific logic
    _handleStateTransition(oldState, newState);

    // Notify listeners
    onStateChanged?.call();
  }

  void _handleStateTransition(GameState oldState, GameState newState) {
    switch (newState) {
      case GameState.waveCountdown:
        _startWaveCountdown();
        break;
      case GameState.waveActive:
        _startWave();
        break;
      case GameState.waveComplete:
        _completeWave();
        break;
      case GameState.levelComplete:
        _completeLevel();
        break;
      case GameState.paused:
        _pauseGame();
        break;
      case GameState.menu:
        _exitToMenu();
        break;
      default:
        break;
    }
  }

  // Wave management
  void startWave(int wave) {
    _currentWave = wave;
    _waveScore = 0;
    _waveTarget = GameConfig.calculateWaveTarget(_level);
    _waveCountdown = 3.0;
    _isWaveActive = false;
    _gameRunning = false;
    _waveMessage = 'Wave $wave/${GameConfig.wavesPerLevel} starting in 3';

    setState(GameState.waveCountdown);
  }

  void _startWaveCountdown() {
    // Countdown logic will be handled in update method
  }

  void _startWave() {
    _isWaveActive = true;
    _gameRunning = true;
    _waveMessage = null;
    _waveCountdown = 0.0;
    onWaveStarted?.call();
  }

  void _completeWave() {
    _isWaveActive = false;
    _gameRunning = false;
    _wavesCompletedInLevel++;
    onWaveCompleted?.call();

    if (_wavesCompletedInLevel >= GameConfig.wavesPerLevel) {
      setState(GameState.levelComplete);
    } else {
      _currentWave++;
      startWave(_currentWave);
    }
  }

  void _completeLevel() {
    _isLevelComplete = true;
    _level++;
    _currentWave = 1;
    _wavesCompletedInLevel = 0;
    onLevelCompleted?.call();
  }

  // Score management
  void addScore(int points) {
    _totalScore += points;
    _waveScore += points;

    if (_waveScore >= _waveTarget && _isWaveActive) {
      setState(GameState.waveComplete);
    }
  }

  void resetWaveScore() {
    _waveScore = 0;
  }

  // Pause/Resume management
  void pauseGame() {
    if (_currentState == GameState.paused) return;
    setState(GameState.paused);
  }

  void resumeGame() {
    if (_currentState != GameState.paused) return;

    _isPaused = false;
    _pauseStartTime = null;
    _resumePlayTime();

    // Return to previous state
    if (_isWaveActive) {
      setState(GameState.waveActive);
    } else if (_waveCountdown > 0) {
      setState(GameState.waveCountdown);
    }

    onResume?.call();
  }

  void _pauseGame() {
    _isPaused = true;
    _pauseStartTime = DateTime.now();
    _pausePlayTime();
    onPause?.call();
  }

  // Play time management
  void startPlayTimeTracking() {
    if (_gameStartTime == null) {
      _gameStartTime = DateTime.now();
    }

    _playTimeTimer?.cancel();
    _playTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_gameRunning && _gameStartTime != null && !_isPaused) {
        final totalTime = DateTime.now().difference(_gameStartTime!);
        _playTime = totalTime - _pausedTime;
        if (_playTime.isNegative) _playTime = Duration.zero;
      }
    });
  }

  void _pausePlayTime() {
    _playTimeTimer?.cancel();
  }

  void _resumePlayTime() {
    if (_pauseStartTime != null) {
      final pauseDuration = DateTime.now().difference(_pauseStartTime!);
      _pausedTime += pauseDuration;
      _pauseStartTime = null;

      // Clamp paused time
      if (_gameStartTime != null) {
        final totalTime = DateTime.now().difference(_gameStartTime!);
        if (_pausedTime > totalTime) {
          _pausedTime = totalTime;
        }
      }

      startPlayTimeTracking();
    }
  }

  void resetPlayTime() {
    _playTime = Duration.zero;
    _pausedTime = Duration.zero;
    _gameStartTime = null;
    _pauseStartTime = null;
    _playTimeTimer?.cancel();
  }

  // Wave countdown update
  void updateWaveCountdown(double dt) {
    if (_currentState == GameState.waveCountdown && _waveCountdown > 0) {
      _waveCountdown -= dt;

      if (_waveCountdown <= 0) {
        setState(GameState.waveActive);
      } else {
        _waveMessage =
            'Wave $_currentWave/${GameConfig.wavesPerLevel} starting in ${_waveCountdown.ceil()}';
      }
    }
  }

  // Game over
  void gameOver() {
    _gameRunning = false;
    _isWaveActive = false;
    setState(GameState.gameOver);
    onGameOver?.call();
  }

  // Exit to menu
  void _exitToMenu() {
    _gameRunning = false;
    _isWaveActive = false;
    _isPaused = false;
    _playTimeTimer?.cancel();
    resetPlayTime();
  }

  // Reset game state
  void resetGame() {
    _currentWave = 1;
    _wavesCompletedInLevel = 0;
    _waveScore = 0;
    _waveTarget = GameConfig.calculateWaveTarget(_level);
    _isLevelComplete = false;
    resetPlayTime();
    setState(GameState.waveCountdown);
  }

  // Load/Save state
  void loadState({
    required int level,
    required int totalScore,
    required int currentWave,
    required int wavesCompletedInLevel,
  }) {
    _level = level;
    _totalScore = totalScore;
    _currentWave = currentWave;
    _wavesCompletedInLevel = wavesCompletedInLevel;
    _waveTarget = GameConfig.calculateWaveTarget(_level);
  }

  Map<String, dynamic> getStateForSaving() {
    return {
      'level': _level,
      'totalScore': _totalScore,
      'currentWave': _currentWave,
      'wavesCompletedInLevel': _wavesCompletedInLevel,
    };
  }

  // Cleanup
  void dispose() {
    _playTimeTimer?.cancel();
    onStateChanged = null;
    onWaveStarted = null;
    onWaveCompleted = null;
    onLevelCompleted = null;
    onGameOver = null;
    onPause = null;
    onResume = null;
  }
}
