import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'magnet_walker_game.dart';
import 'managers/ad_manager.dart';

class GameScreen extends StatefulWidget {
  final bool musicEnabled;
  final bool sfxEnabled;
  final bool menuMusicEnabled;

  const GameScreen({
    super.key,
    required this.musicEnabled,
    required this.sfxEnabled,
    required this.menuMusicEnabled,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late MagnetWalkerGame game;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    game = MagnetWalkerGame();
    FlameAudio.bgm.stop();
    game.setExitCallback(() async {
      // Stop game music completely
      FlameAudio.bgm.stop();

      // Navigate back to menu - the main app will handle restarting menu music
      Navigator.pushReplacementNamed(context, '/');
    });

    if (widget.musicEnabled) {
      FlameAudio.bgm.stop();
      FlameAudio.bgm.play('game_music.mp3');
    }

    // Initialize and load banner ad
    _initializeAds();
  }

  Future<void> _initializeAds() async {
    try {
      // Initialize AdMob if not already initialized
      if (!AdManager.isAdsInitialized) {
        await AdManager.initialize();
      }

      // Create banner ad with listener
      _bannerAd = BannerAd(
        adUnitId:
            AdManager.bannerAdUnitId, // Make sure this is public in AdManager
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            setState(() {
              _isBannerAdLoaded = true;
            });
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            _bannerAd = null;
          },
          onAdOpened: (ad) => print('Banner Ad opened'),
          onAdClosed: (ad) => print('Banner Ad closed'),
        ),
      );

      // Load the ad
      _bannerAd?.load();
    } catch (e) {
      print('Failed to initialize ads: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar:
          true, // Game can render under the AppBar background
      appBar: AppBar(
        backgroundColor: Colors.transparent, // So image shows
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                  'assets/images/background-2.jpg'), // your image path
              fit: BoxFit.cover, // fills the AppBar area
            ),
          ),
        ),
        title: Text(
          'MAGNET LORD',
          style: TextStyle(
            fontFamily: 'Roboto', // More professional font
            fontWeight: FontWeight.w800, // Bolder weight
            color: Colors.white,
            letterSpacing: 4.5, // Increased spacing for premium feel
            fontSize: 24, // Larger, more impactful size
            height: 1.2, // Better line height
            shadows: [
              // Primary electric blue glow
              const Shadow(
                offset: Offset.zero,
                color: Color(0xFF00E5FF),
                blurRadius: 15, // Wider, more diffuse glow
              ),
              // Secondary purple glow for depth
              const Shadow(
                offset: Offset.zero,
                color: Color(0xFF7C3AED),
                blurRadius: 12,
              ),
              // Tertiary cyan accent
              const Shadow(
                offset: Offset.zero,
                color: Color(0xFF00FFFF),
                blurRadius: 8,
              ),
              // Strong drop shadow for depth
              Shadow(
                offset: const Offset(0, 3),
                blurRadius: 12,
                color: const Color(0xFF000000).withValues(alpha: 0.8),
              ),
              // Subtle inner shadow effect
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 4,
                color: Color(0xFF000000)..withValues(alpha: 0.6),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),

      body: Stack(
        children: [
          // Full-screen game (background will cover entire display)
          SafeArea(
            bottom: false, // so game goes under banner
            child: GameWidget(game: game),
          ),
          // Banner ad overlaid at bottom
          if (_isBannerAdLoaded && _bannerAd != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                margin: const EdgeInsets.only(bottom: 4.0),
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    FlameAudio.bgm.stop();
    // Dispose of the banner ad
    _bannerAd?.dispose();
    super.dispose();
  }
}
