import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'managers/ad_manager.dart';

class MenuScreen extends StatefulWidget {
  final VoidCallback onPlay;
  final VoidCallback onSettings;
  final VoidCallback onSkins;

  const MenuScreen({
    Key? key,
    required this.onPlay,
    required this.onSettings,
    required this.onSkins,
  }) : super(key: key);

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _lives = 5;
  int _maxLives = 5;
  int _lifeRegenMinutes = 1;
  int? _lastLifeTimestamp;
  Timer? _regenTimer;
  String _timeUntilNextLife = '';

  @override
  void initState() {
    super.initState();
    _loadLives();
    _startRegenTimer();
  }

  @override
  void dispose() {
    _regenTimer?.cancel();
    _regenTimer = null;
    super.dispose();
  }

  @override
  void deactivate() {
    _regenTimer?.cancel();
    super.deactivate();
  }

  Future<void> _loadLives() async {
    final prefs = await SharedPreferences.getInstance();
    final newLives = prefs.getInt('lives') ?? 5;
    final newTimestamp = prefs.getInt('last_life_timestamp');
    // Always update state, even if values seem the same
    setState(() {
      _lives = newLives;
      _lastLifeTimestamp = newTimestamp;
    });
    _regenerateLivesIfNeeded();
  }

  @override
  void didUpdateWidget(MenuScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload lives when returning to this screen
    _loadLives();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload lives when screen becomes active
    _loadLives();
  }

  void _startRegenTimer() {
    _regenTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _regenerateLivesIfNeeded();
      _updateTimeDisplay();
    });
  }

  void _regenerateLivesIfNeeded() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (_lastLifeTimestamp == null) {
      _lastLifeTimestamp = now;
      await _saveLives();
      return;
    }

    if (_lives >= _maxLives) {
      _lastLifeTimestamp = now;
      await _saveLives();
      return;
    }

    final regenMillis = _lifeRegenMinutes * 60 * 1000;
    int elapsed = now - _lastLifeTimestamp!;
    int livesToAdd = elapsed ~/ regenMillis;
    
    if (livesToAdd > 0) {
      setState(() {
        _lives = (_lives + livesToAdd).clamp(0, _maxLives);
        if (_lives < _maxLives) {
          _lastLifeTimestamp = _lastLifeTimestamp! + livesToAdd * regenMillis;
        } else {
          _lastLifeTimestamp = now;
        }
      });
      await _saveLives();
    }
  }

  void _updateTimeDisplay() {
    if (_lives >= _maxLives) {
      setState(() {
        _timeUntilNextLife = '';
      });
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final regenMillis = _lifeRegenMinutes * 60 * 1000;
    final nextLifeAt = (_lastLifeTimestamp ?? now) + regenMillis;
    final millisLeft = (nextLifeAt - now).clamp(0, regenMillis);
    
    if (millisLeft > 0) {
      final secondsLeft = (millisLeft / 1000).ceil();
      final minutes = (secondsLeft ~/ 60).toString().padLeft(2, '0');
      final seconds = (secondsLeft % 60).toString().padLeft(2, '0');
      setState(() {
        _timeUntilNextLife = '$minutes:$seconds';
      });
    } else {
      setState(() {
        _timeUntilNextLife = '';
      });
    }
  }

  Future<void> _saveLives() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lives', _lives);
    await prefs.setInt('last_life_timestamp', _lastLifeTimestamp ?? DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Text(
              'Magnet Walker',
              style: TextStyle(
                fontSize: screenSize.width * 0.12,
                fontWeight: FontWeight.bold,
                color: Colors.cyanAccent,
                letterSpacing: 2.0,
                shadows: [
                  Shadow(
                    offset: Offset(0, 0),
                    blurRadius: 16,
                    color: Colors.cyanAccent.withOpacity(0.5),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 20),
            
            // Enhanced Lives display with regeneration info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '❤️ $_lives/$_maxLives',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_lives < _maxLives) ...[
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _showGetLivesDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pinkAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          child: const Text(
                            'Get Lives',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Show regeneration timer if not at max lives
                  if (_lives < _maxLives && _timeUntilNextLife.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Next life in: $_timeUntilNextLife',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const Spacer(),
            
            // Play button - disabled if no lives
            SizedBox(
              width: screenSize.width * 0.7,
              child: ElevatedButton(
                onPressed: _lives > 0 ? widget.onPlay : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _lives > 0 ? Colors.pinkAccent : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                ),
                child: Text(
                  _lives > 0 ? 'Play' : 'No Lives',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: screenSize.width * 0.7,
              child: ElevatedButton.icon(
                onPressed: widget.onSkins,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8844ff),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                ),
                icon: const Text(
                  '👕',
                  style: TextStyle(fontSize: 20),
                ),
                label: const Text(
                  'Skins',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: screenSize.width * 0.7,
              child: OutlinedButton(
                onPressed: widget.onSettings,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.cyanAccent, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.cyanAccent,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  void _showGetLivesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text(
          'Get More Lives',
          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current Lives: $_lives/$_maxLives',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            if (_timeUntilNextLife.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Next life in: $_timeUntilNextLife',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _watchAdForLife();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
              child: const Text('Watch Ad for 1 Life'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Wait for Free Lives', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  void _watchAdForLife() {
    AdManager.showRewardedAd(
      onRewarded: () async {
        setState(() {
          _lives = (_lives + 1).clamp(0, _maxLives);
          _lastLifeTimestamp = DateTime.now().millisecondsSinceEpoch;
        });
        await _saveLives();
      },
      onFailed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No ad available. Try again later.'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }
}
