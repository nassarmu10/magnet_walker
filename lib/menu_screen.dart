import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'managers/ad_manager.dart';
import 'dart:ui';

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
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadLives();
    _startRegenTimer();
    _initAnimations();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _regenTimer?.cancel();
    _regenTimer = null;
    _fadeController.dispose();
    _pulseController.dispose();
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
    double blur = 10,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(opacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: blur,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
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
    String? emoji,
    bool isPrimary = false,
    bool isOutlined = false,
  }) {
    return AnimatedBuilder(
      animation: isPrimary ? _pulseAnimation : _fadeAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isPrimary ? _pulseAnimation.value : 1.0,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.75,
            height: 60,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: isOutlined
                ? OutlinedButton.icon(
                    onPressed: onPressed,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: backgroundColor, width: 2.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 8,
                    ),
                    icon: icon != null
                        ? Icon(icon, color: backgroundColor, size: 24)
                        : Text(emoji ?? '',
                            style: const TextStyle(fontSize: 24)),
                    label: Text(
                      text,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: backgroundColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: backgroundColor,
                      foregroundColor: textColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 12,
                      shadowColor: backgroundColor.withOpacity(0.4),
                    ),
                    icon: icon != null
                        ? Icon(icon, color: textColor, size: 24)
                        : Text(emoji ?? '',
                            style: const TextStyle(fontSize: 24)),
                    label: Text(
                      text,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        letterSpacing: 1.2,
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
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.6),
                Colors.black.withOpacity(0.4),
              ],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Title
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Magnet Walker',
                      style: TextStyle(
                        fontSize: screenSize.width * 0.12,
                        fontWeight: FontWeight.w900,
                        foreground: Paint()
                          ..shader = const LinearGradient(
                            colors: [Color(0xFF64B5F6), Color(0xFFE1F5FE)],
                          ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                        letterSpacing: 2.0,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 0),
                            blurRadius: 20,
                            color: Color(0xFF64B5F6).withOpacity(0.8),
                          ),
                          Shadow(
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                            color: Colors.black.withOpacity(0.7),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Lives Display
                  _buildGlassContainer(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.favorite,
                                  color: Colors.redAccent,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '$_lives/$_maxLives Lives',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_lives < _maxLives) ...[
                                const SizedBox(width: 16),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Colors.pinkAccent,
                                        Colors.purpleAccent
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _showGetLivesDialog,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                    ),
                                    child: const Text(
                                      'Get Lives',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (_lives < _maxLives &&
                              _timeUntilNextLife.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    color: Colors.orangeAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Next life: $_timeUntilNextLife',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Buttons
                  Column(
                    children: [
                      _buildAnimatedButton(
                        text: _lives > 0 ? 'PLAY' : 'NO LIVES',
                        onPressed: _lives > 0 ? widget.onPlay : null,
                        backgroundColor:
                            _lives > 0 ? const Color(0xFF00BCD4) : Colors.grey,
                        icon: _lives > 0 ? Icons.play_arrow : Icons.block,
                        isPrimary: _lives > 0,
                      ),
                      _buildAnimatedButton(
                        text: 'SKINS',
                        onPressed: widget.onSkins,
                        backgroundColor: const Color(0xFF9C27B0),
                        emoji: '👕',
                      ),
                      _buildAnimatedButton(
                        text: 'SETTINGS',
                        onPressed: widget.onSettings,
                        backgroundColor: const Color(0xFF00BCD4),
                        icon: Icons.settings,
                        isOutlined: true,
                      ),
                    ],
                  ),

                  const Spacer(flex: 2),
                ],
              ),
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
          opacity: 0.15,
          blur: 20,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.redAccent,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Get More Lives',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Current Lives: $_lives/$_maxLives',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                if (_timeUntilNextLife.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Next free life: $_timeUntilNextLife',
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)],
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
                    icon: const Icon(Icons.play_circle_filled,
                        color: Colors.white),
                    label: const Text(
                      'Watch Ad for 1 Life',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Wait for Free Lives',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
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

        // Show success feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.favorite, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('Life restored!'),
                ],
              ),
              backgroundColor: Colors.green,
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
                  Text('No ad available. Try again later.'),
                ],
              ),
              backgroundColor: Colors.red,
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
