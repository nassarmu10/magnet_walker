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
  int _lifeRegenMinutes = 5;
  int? _lastLifeTimestamp;
  Timer? _regenTimer;
  String _timeUntilNextLife = '';
  bool _soundEnabled = true;

  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _titleController;
  late AnimationController _staggerController;
  late AnimationController _breathingController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _titleSlideAnimation;
  late Animation<double> _titleFadeAnimation;
  late Animation<double> _buttonStaggerAnimation;
  late Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _loadLives();
    _startRegenTimer();
    _initAnimations();
    _ensureMenuMusicPlaying();
  }

  Future<void> _ensureMenuMusicPlaying() async {
    final prefs = await SharedPreferences.getInstance();
    final menuMusicEnabled = prefs.getBool('menu_music_enabled') ?? true;

    if (menuMusicEnabled) {
      await Future.delayed(const Duration(milliseconds: 200));
      FlameAudio.bgm.stop();
      await Future.delayed(const Duration(milliseconds: 100));
      if (menuMusicEnabled) {
        FlameAudio.bgm.play('menu_music.mp3');
      }
    }
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _titleController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    );
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 2000),
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
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _titleSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: Curves.elasticOut,
    ));

    _titleFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeOut,
    ));

    _buttonStaggerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _staggerController,
      curve: Curves.easeOutCubic,
    ));

    _breathingAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));

    // Start animations with delays
    Future.delayed(const Duration(milliseconds: 300), () {
      _titleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      _fadeController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      _staggerController.forward();
    });
    _pulseController.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      _breathingController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _regenTimer?.cancel();
    _regenTimer = null;
    _fadeController.dispose();
    _pulseController.dispose();
    _titleController.dispose();
    _staggerController.dispose();
    _breathingController.dispose();
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
    double opacity = 0.1,
    Color color = Colors.white,
    double blur = 20,
    double borderRadius = 20,
    bool hasShadow = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(opacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: blur * 0.8,
                  offset: const Offset(0, 6),
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: blur * 0.4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
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
    int animationDelay = 0,
  }) {
    return AnimatedBuilder(
      animation: _buttonStaggerAnimation,
      builder: (context, child) {
        final delayedProgress = Curves.easeOutCubic.transform(
          ((_buttonStaggerAnimation.value * 3) - animationDelay)
              .clamp(0.0, 1.0),
        );

        final screenSize = MediaQuery.of(context).size;
        final isLandscape = screenSize.width > screenSize.height;

        return Transform.translate(
          offset: Offset(0, 30 * (1 - delayedProgress)),
          child: Opacity(
            opacity: delayedProgress,
            child: AnimatedBuilder(
              animation: isPrimary ? _pulseAnimation : _fadeAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: isPrimary ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: isLandscape
                        ? screenSize.width * 0.35
                        : screenSize.width * 0.85,
                    height: isLandscape ? 50 : 60,
                    margin: EdgeInsets.symmetric(vertical: isLandscape ? 6 : 8),
                    child: Material(
                      elevation: onPressed != null ? (isPrimary ? 12 : 8) : 0,
                      shadowColor: backgroundColor.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.transparent,
                      child: isOutlined
                          ? OutlinedButton.icon(
                              onPressed: onPressed,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: backgroundColor, width: 2.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                backgroundColor:
                                    backgroundColor.withOpacity(0.12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                              ),
                              icon: icon != null
                                  ? Icon(icon, color: backgroundColor, size: 22)
                                  : const SizedBox.shrink(),
                              label: Text(
                                text,
                                style: TextStyle(
                                  fontSize: isLandscape ? 14 : 17,
                                  fontWeight: FontWeight.w700,
                                  color: backgroundColor,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: onPressed,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: backgroundColor,
                                foregroundColor: textColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 0,
                                disabledBackgroundColor:
                                    Colors.grey.withOpacity(0.4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                              ),
                              icon: icon != null
                                  ? Icon(icon, color: textColor, size: 22)
                                  : const SizedBox.shrink(),
                              label: Text(
                                text,
                                style: TextStyle(
                                  fontSize: isLandscape ? 14 : 17,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    final isLandscape = screenSize.width > screenSize.height;

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
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.5),
                Colors.black.withOpacity(0.4),
              ],
            ),
          ),
          child: SafeArea(
            child: isLandscape
                ? Row(
                    children: [
                      // Left side - Logo and title
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Lives display at top in landscape
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: _buildLivesDisplay(),
                            ),
                            // Logo
                            _buildLogoSection(
                                isLandscape, isSmallScreen, screenSize),
                            // Title
                            _buildTitleSection(
                                isLandscape, isSmallScreen, screenSize),
                          ],
                        ),
                      ),
                      // Right side - Buttons
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _buildButtons(),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      // Enhanced status bar with better spacing
                      if (!isLandscape)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              24, isSmallScreen ? 12 : 20, 24, 0),
                          child: _buildLivesDisplay(),
                        ),

                      if (!isLandscape)
                        SizedBox(height: isSmallScreen ? 20 : 30),

                      // Logo and title section
                      if (!isLandscape)
                        _buildLogoSection(
                            isLandscape, isSmallScreen, screenSize),
                      if (!isLandscape)
                        _buildTitleSection(
                            isLandscape, isSmallScreen, screenSize),

                      if (!isLandscape)
                        SizedBox(height: isSmallScreen ? 20 : 30),

                      // Enhanced buttons with staggered animation
                      if (!isLandscape)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _buildButtons(),
                            ),
                          ),
                        ),

                      // Bottom spacing
                      if (!isLandscape)
                        SizedBox(height: isSmallScreen ? 20 : 40),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _toggleSound() async {
    final prefs = await SharedPreferences.getInstance();
    final currentEnabled = prefs.getBool('menu_music_enabled') ?? true;
    await prefs.setBool('menu_music_enabled', !currentEnabled);

    if (!currentEnabled) {
      FlameAudio.bgm.play('menu_music.mp3');
    } else {
      FlameAudio.bgm.stop();
    }
    setState(() {
      _soundEnabled = currentEnabled;
    });
  }

  void _showGetLivesDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.transparent,
        child: _buildGlassContainer(
          opacity: 0.15,
          blur: 25,
          borderRadius: 28,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53E3E).withOpacity(0.25),
                    borderRadius: BorderRadius.circular(60),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE53E3E).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Color(0xFFE53E3E),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Restore Lives',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '$_lives/$_maxLives lives',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_timeUntilNextLife.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      'Next free life: $_timeUntilNextLife',
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
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
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    icon: const Icon(Icons.play_circle_outline,
                        color: Colors.white, size: 24),
                    label: const Text(
                      'Watch Ad (+1 Life)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'Wait for Free Lives',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
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

  Widget _buildLivesDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left placeholder (you can add coins, score, etc.)
        const SizedBox(width: 40),

        // Center Lives
        FadeTransition(
          opacity: _fadeAnimation,
          child: _buildGlassContainer(
            borderRadius: 24,
            opacity: 0.12,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53E3E).withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE53E3E).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (_lives < _maxLives && _timeUntilNextLife.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _timeUntilNextLife,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Right Side Button (+ or Sound)
        if (_lives < _maxLives)
          FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              onTap: _showGetLivesDialog,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF3B82F6).withOpacity(0.35),
                      const Color(0xFF1E3A8A).withOpacity(0.35),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF3B82F6),
                  size: 26,
                ),
              ),
            ),
          )
        else
          FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              onTap: _toggleSound,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  (_soundEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded),
                  key: ValueKey<bool>(_soundEnabled),
                  color: Colors.white.withOpacity(0.85),
                  size: 26,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLogoSection(
      bool isLandscape, bool isSmallScreen, Size screenSize) {
    return SlideTransition(
      position: _titleSlideAnimation,
      child: FadeTransition(
        opacity: _titleFadeAnimation,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseAnimation, _breathingAnimation]),
          builder: (context, child) {
            final pulseScale = 1.0 + (_pulseAnimation.value * 0.05);
            final breathingScale = _breathingController.isAnimating
                ? _breathingAnimation.value
                : 1.0;
            final combinedScale = pulseScale * breathingScale;
            return Transform.scale(
              scale: combinedScale,
              child: Container(
                width: isLandscape
                    ? screenSize.width * 0.25
                    : screenSize.width * (isSmallScreen ? 0.6 : 0.5),
                height: isLandscape
                    ? screenSize.width * 0.25 * 0.8
                    : screenSize.width * (isSmallScreen ? 0.6 : 0.5) * 0.8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/MagnetLogo_no_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTitleSection(
      bool isLandscape, bool isSmallScreen, Size screenSize) {
    return Column(
      children: [
        // "Magnet Lord" text underneath with animations
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _titleController,
            curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
          )),
          child: FadeTransition(
            opacity: Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: _titleController,
              curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
            )),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final shimmer = (_pulseAnimation.value * 2.0).clamp(0.0, 1.0);
                return ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      colors: [
                        const Color(0xFF00F5FF)
                            .withOpacity(0.8 + (0.2 * shimmer)),
                        const Color(0xFF0084FF).withOpacity(0.9),
                        const Color(0xFF7C3AED)
                            .withOpacity(0.8 + (0.2 * shimmer)),
                      ],
                      stops: [
                        0.0,
                        0.5 + (0.3 * shimmer),
                        1.0,
                      ],
                    ).createShader(bounds);
                  },
                  child: Text(
                    'Magnet Lord',
                    style: TextStyle(
                      fontSize: isLandscape
                          ? screenSize.width * 0.04
                          : screenSize.width * (isSmallScreen ? 0.08 : 0.09),
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 3.0,
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 0),
                          blurRadius: 20 + (10 * _pulseAnimation.value),
                          color: const Color(0xFF00E5FF).withOpacity(0.6),
                        ),
                        Shadow(
                          offset: const Offset(0, 0),
                          blurRadius: 30 + (15 * _pulseAnimation.value),
                          color: const Color(0xFF7C3AED).withOpacity(0.4),
                        ),
                        const Shadow(
                          offset: Offset(0, 2),
                          blurRadius: 8,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Subtitle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            'RULE THE MAGNETIC FIELD 🧲',
            style: TextStyle(
              fontSize: isLandscape ? 10 : (isSmallScreen ? 12 : 14),
              color: Colors.white.withOpacity(0.85),
              fontWeight: FontWeight.w400,
              letterSpacing: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildButtons() {
    return [
      _buildAnimatedButton(
        text: _lives > 0 ? 'PLAY GAME' : 'NO LIVES LEFT',
        onPressed: _lives > 0 ? widget.onPlay : null,
        backgroundColor:
            _lives > 0 ? const Color(0xFF059669) : Colors.grey.shade600,
        icon: _lives > 0 ? Icons.play_arrow_rounded : Icons.block_rounded,
        isPrimary: _lives > 0,
        animationDelay: 0,
      ),
      _buildAnimatedButton(
        text: 'CHARACTER SKINS',
        onPressed: widget.onSkins,
        backgroundColor: const Color(0xFF7C3AED),
        icon: Icons.palette_outlined,
        animationDelay: 1,
      ),
      _buildAnimatedButton(
        text: 'SETTINGS',
        onPressed: widget.onSettings,
        backgroundColor: const Color(0xFF475569),
        icon: Icons.settings_outlined,
        isOutlined: true,
        animationDelay: 2,
      ),
    ];
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
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.favorite,
                        color: Color(0xFFE53E3E), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Life restored!',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      )),
                ],
              ),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      },
      onFailed: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.error_outline,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Ad not available. Try again later.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      )),
                ],
              ),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      },
    );
  }
}
