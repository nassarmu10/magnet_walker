import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'managers/ad_manager.dart';
import 'dart:ui';
import 'package:flame_audio/flame_audio.dart';

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

class _MenuScreenState extends State<MenuScreen> with TickerProviderStateMixin {
  int _lives = 5;
  int _maxLives = 5;
  int _lifeRegenMinutes = 1;
  int? _lastLifeTimestamp;
  Timer? _regenTimer;
  String _timeUntilNextLife = '';

  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _titleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _titleSlideAnimation;
  late Animation<double> _titleFadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadLives();
    _startRegenTimer();
    _initAnimations();
    _ensureMenuMusicPlaying();
  }

  Future<void> _ensureMenuMusicPlaying() async {
    // Check if menu music is enabled via SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final menuMusicEnabled = prefs.getBool('menu_music_enabled') ?? true;

    if (menuMusicEnabled) {
      // Add delay to ensure clean transition from game screen
      await Future.delayed(const Duration(milliseconds: 200));

      // Stop any existing music and start menu music
      FlameAudio.bgm.stop();
      await Future.delayed(const Duration(milliseconds: 100));

      // Start menu music if still enabled
      if (menuMusicEnabled) {
        FlameAudio.bgm.play('menu_music.mp3');
      }
    }
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _titleController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _titleSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeOutCubic,
    ));

    _titleFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeOut,
    ));

    _titleController.forward();
    _fadeController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _regenTimer?.cancel();
    _regenTimer = null;
    _fadeController.dispose();
    _pulseController.dispose();
    _titleController.dispose();
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
    setState(() {
      _lives = newLives;
      _lastLifeTimestamp = newTimestamp;
    });
    _regenerateLivesIfNeeded();
  }

  @override
  void didUpdateWidget(MenuScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadLives();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    await prefs.setInt('last_life_timestamp',
        _lastLifeTimestamp ?? DateTime.now().millisecondsSinceEpoch);
  }

  Widget _buildGlassContainer({
    required Widget child,
    double opacity = 0.08,
    Color color = Colors.white,
    double blur = 15,
    double borderRadius = 20,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(opacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: blur,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: child,
        ),
      ),
    );
  }

  Widget _buildAnimatedButton({
    required String text,
    required VoidCallback? onPressed,
    required Color backgroundColor,
    Color textColor = Colors.white,
    IconData? icon,
    bool isPrimary = false,
    bool isOutlined = false,
  }) {
    return AnimatedBuilder(
      animation: isPrimary ? _pulseAnimation : _fadeAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isPrimary ? _pulseAnimation.value : 1.0,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: 56,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: isOutlined
                ? OutlinedButton.icon(
                    onPressed: onPressed,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: backgroundColor, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: backgroundColor.withOpacity(0.1),
                    ),
                    icon: icon != null
                        ? Icon(icon, color: backgroundColor, size: 20)
                        : const SizedBox.shrink(),
                    label: Text(
                      text,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: backgroundColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: backgroundColor,
                      foregroundColor: textColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: onPressed != null ? 8 : 0,
                      shadowColor: backgroundColor.withOpacity(0.3),
                      disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                    ),
                    icon: icon != null
                        ? Icon(icon, color: textColor, size: 20)
                        : const SizedBox.shrink(),
                    label: Text(
                      text,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.4),
                Colors.black.withOpacity(0.6),
                Colors.black.withOpacity(0.5),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Status bar area and lives - positioned at top
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Empty space for balance
                      const SizedBox(width: 50),

                      // Lives display - centered at top
                      _buildGlassContainer(
                        borderRadius: 25,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFE53E3E).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.favorite,
                                  color: Color(0xFFE53E3E),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '$_lives/$_maxLives',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Get Lives button when needed
                      if (_lives < _maxLives)
                        GestureDetector(
                          onTap: _showGetLivesDialog,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF3B82F6).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.add_circle_outline,
                              color: Color(0xFF3B82F6),
                              size: 24,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 50),
                    ],
                  ),
                ),

                // Timer display if applicable
                if (_lives < _maxLives && _timeUntilNextLife.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule,
                            color: Color(0xFFF59E0B),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _timeUntilNextLife,
                            style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const Spacer(flex: 2),

                // Game Title - Better positioned and designed
                SlideTransition(
                  position: _titleSlideAnimation,
                  child: FadeTransition(
                    opacity: _titleFadeAnimation,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // Main title
                          Text(
                            'MAGNET',
                            style: TextStyle(
                              fontSize: screenSize.width * 0.14,
                              fontWeight: FontWeight.w900,
                              height: 0.9,
                              foreground: Paint()
                                ..shader = const LinearGradient(
                                  colors: [
                                    Color(0xFF1E40AF),
                                    Color(0xFF3B82F6),
                                    Color(0xFF60A5FA),
                                  ],
                                ).createShader(
                                    const Rect.fromLTWH(0, 0, 300, 80)),
                              letterSpacing: 4.0,
                              shadows: [
                                Shadow(
                                  offset: const Offset(0, 0),
                                  blurRadius: 30,
                                  color:
                                      const Color(0xFF3B82F6).withOpacity(0.5),
                                ),
                                const Shadow(
                                  offset: Offset(0, 2),
                                  blurRadius: 6,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'Lord',
                            style: TextStyle(
                              fontSize: screenSize.width * 0.14,
                              fontWeight: FontWeight.w900,
                              height: 0.9,
                              foreground: Paint()
                                ..shader = const LinearGradient(
                                  colors: [
                                    Color(0xFF1E40AF),
                                    Color(0xFF3B82F6),
                                    Color(0xFF60A5FA),
                                  ],
                                ).createShader(
                                    const Rect.fromLTWH(0, 0, 300, 80)),
                              letterSpacing: 4.0,
                              shadows: [
                                Shadow(
                                  offset: const Offset(0, 0),
                                  blurRadius: 30,
                                  color:
                                      const Color(0xFF3B82F6).withOpacity(0.5),
                                ),
                                const Shadow(
                                  offset: Offset(0, 2),
                                  blurRadius: 6,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          // Subtle tagline
                          const SizedBox(height: 8),
                          Text(
                            'Navigate the magnetic field',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.w400,
                              letterSpacing: 1.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Buttons with better spacing and colors
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildAnimatedButton(
                          text: _lives > 0 ? 'PLAY GAME' : 'NO LIVES LEFT',
                          onPressed: _lives > 0 ? widget.onPlay : null,
                          backgroundColor: _lives > 0
                              ? const Color(0xFF059669)
                              : Colors.grey,
                          icon: _lives > 0
                              ? Icons.play_arrow_rounded
                              : Icons.block,
                          isPrimary: _lives > 0,
                        ),
                        _buildAnimatedButton(
                          text: 'CHARACTER SKINS',
                          onPressed: widget.onSkins,
                          backgroundColor: const Color(0xFF7C3AED),
                          icon: Icons.palette_outlined,
                        ),
                        _buildAnimatedButton(
                          text: 'SETTINGS',
                          onPressed: widget.onSettings,
                          backgroundColor: const Color(0xFF475569),
                          icon: Icons.settings_outlined,
                          isOutlined: true,
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGetLivesDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: _buildGlassContainer(
          opacity: 0.12,
          blur: 20,
          borderRadius: 24,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53E3E).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Color(0xFFE53E3E),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Restore Lives',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Current: $_lives/$_maxLives lives',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
                if (_timeUntilNextLife.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Next free life: $_timeUntilNextLife',
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _watchAdForLife();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.play_circle_outline,
                        color: Colors.white),
                    label: const Text(
                      'Watch Ad (+1 Life)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Wait for Free Lives',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.favorite, color: Color(0xFFE53E3E)),
                  SizedBox(width: 8),
                  Text('Life restored!',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      onFailed: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Ad not available. Try again later.',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
    );
  }
}
