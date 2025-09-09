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
            print('Banner Ad loaded successfully');
          },
          onAdFailedToLoad: (ad, error) {
            print('Banner Ad failed to load: $error');
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
      body: Column(
        children: [
          // Game area with SafeArea
          Expanded(
            child: SafeArea(
              bottom: false,
              minimum: const EdgeInsets.only(
                  bottom: 8.0), // Optional: add some bottom margin
              child: GameWidget(game: game),
            ),
          ),
          // Banner ad area
          if (_isBannerAdLoaded && _bannerAd != null)
            Container(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              padding: const EdgeInsets.only(
                  bottom: 4.0), // Optional: add some padding
              alignment: Alignment.center,
              child: AdWidget(ad: _bannerAd!),
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
