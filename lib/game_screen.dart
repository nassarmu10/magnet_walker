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
      // extendBodyBehindAppBar: true, // Game renders behind AppBar
      // appBar: AppBar(
      //   backgroundColor: Colors.transparent, // Completely transparent
      //   elevation: 0, // No shadow
      //   toolbarHeight: 0, // No height - just for safe area
      //   automaticallyImplyLeading: false, // No back button
      // ),
      body: Stack(
        children: [
          // Full-screen game with top safe area only
          SafeArea(
            top: false,
            bottom: false, // Game goes under banner
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
