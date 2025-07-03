import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static late BannerAd bannerAd;

  static String get bannerAdUnitId {
    // Replace with your banner ad unit ID
    return Platform.isAndroid
        ? 'ca-app-pub-4497634353967283/1603522056' // test 'ca-app-pub-3940256099942544/9214589741'
        : 'ca-app-pub-4497634353967283/6255642575'; // test ca-app-pub-3940256099942544/6300978111
  }

  static String get interstitialAdUnitId {
    // Replace with your interstitial ad unit ID
    return Platform.isAndroid
        ? 'ca-app-pub-4497634353967283/2665119024' // test 'ca-app-pub-4497634353967283/2665119024'
        : 'ca-app-pub-4497634353967283/6708004493'; // test ca-app-pub-3940256099942544/1033173712
  }

  static String get rewardedAdUnitId {
    // Replace with your rewarded ad unit ID
    return Platform.isAndroid
        ? 'ca-app-pub-4497634353967283/6838141635' // test 'ca-app-pub-3940256099942544/5224354917'
        : 'ca-app-pub-4497634353967283/3424656608'; // test ca-app-pub-3940256099942544/5224354917
  }

  static String get rewardedInterstitialAdUnitId {
    // Replace with your rewarded interstitial ad unit ID
    return Platform.isAndroid
        ? 'ca-app-pub-4497634353967283/5102388136' // test 'ca-app-pub-3940256099942544/5354046379'
        : 'ca-app-pub-4497634353967283/3103827050'; // test ca-app-pub-3940256099942544/5354046379
  }

  static late InterstitialAd interstitialAd;
  static late RewardedAd rewardedAd;
  static late RewardedInterstitialAd rewardedInterstitialAd;

  static bool isInterstitialAdReady = false;
  static bool isRewardedAdReady = false;
  static bool isRewardedInterstitialAdReady = false;
  static bool isAdsInitialized = false;

  // Initialize AdMob
  static Future<void> initialize() async {
    if (isAdsInitialized == false) {
      await MobileAds.instance.initialize();
      isAdsInitialized = true;
    }
  }

  // Load Banner Ad
  static BannerAd createBannerAd() {
    bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          //print('Banner Ad loaded successfully');
        },
        onAdFailedToLoad: (ad, error) {
          print('Banner Ad failed to load: $error');
          ad.dispose();
        },
      ),
    );

    return bannerAd;
  }

  // Load Interstitial Ad
  static Future<void> loadInterstitialAd() async {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          interstitialAd = ad;
          isInterstitialAdReady = true;
          print('Interstitial Ad loaded successfully');

          // Set callback for when ad is closed
          interstitialAd.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              isInterstitialAdReady = false;
              ad.dispose();
              loadInterstitialAd(); // Load next ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('Failed to show interstitial ad: $error');
              isInterstitialAdReady = false;
              ad.dispose();
              loadInterstitialAd(); // Try loading again
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('Interstitial Ad failed to load: $error');
          isInterstitialAdReady = false;
        },
      ),
    );
  }

  // Show Interstitial Ad
  static void showInterstitialAd() {
    if (isInterstitialAdReady) {
      interstitialAd.show();
    } else {
      print('Interstitial ad not ready yet');
      loadInterstitialAd();
    }
  }

  // Load Rewarded Ad
  static Future<void> loadRewardedAd() async {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          rewardedAd = ad;
          isRewardedAdReady = true;
          print('Rewarded Ad loaded successfully');

          // Set callback for when ad is closed
          rewardedAd.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              isRewardedAdReady = false;
              ad.dispose();
              loadRewardedAd(); // Load next ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('Failed to show rewarded ad: $error');
              isRewardedAdReady = false;
              ad.dispose();
              loadRewardedAd(); // Try loading again
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('Rewarded Ad failed to load: $error');
          isRewardedAdReady = false;
        },
      ),
    );
  }

  // Show Rewarded Ad
  static Future<void> showRewardedAd({
    required Function onRewarded,
  }) async {
    if (isRewardedAdReady) {
      rewardedAd.show(
        onUserEarnedReward: (ad, reward) {
          onRewarded();
        },
      );
    } else {
      print('Rewarded ad not ready yet');
      loadRewardedAd();
    }
  }

  static Future<void> loadRewardedInterstitialAd() async {
    RewardedInterstitialAd.load(
      adUnitId: rewardedInterstitialAdUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          rewardedInterstitialAd = ad;
          isRewardedInterstitialAdReady = true;
          print('Rewarded Interstitial Ad loaded successfully');

          // Set callback for when ad is closed
          rewardedInterstitialAd.fullScreenContentCallback =
              FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              isRewardedInterstitialAdReady = false;
              ad.dispose();
              loadRewardedInterstitialAd(); // Load next ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('Failed to show rewarded interstitial ad: $error');
              isRewardedInterstitialAdReady = false;
              ad.dispose();
              loadRewardedInterstitialAd(); // Try loading again
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('Rewarded Interstitial Ad failed to load: $error');
          isRewardedInterstitialAdReady = false;
        },
      ),
    );
  }

  static Future<void> showRewardedInterstitialAd({
    required Function onRewarded,
    Function? onAdDismissed,
  }) async {
    if (isRewardedInterstitialAdReady) {
      rewardedInterstitialAd.show(
        onUserEarnedReward: (ad, reward) {
          onRewarded();
        },
      );

      // Set a callback for when the ad is dismissed
      rewardedInterstitialAd.fullScreenContentCallback =
          FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          isRewardedInterstitialAdReady = false;
          ad.dispose();
          loadRewardedInterstitialAd(); // Load next ad
          onAdDismissed?.call(); // Call the optional dismiss callback
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          print('Failed to show rewarded interstitial ad: $error');
          isRewardedInterstitialAdReady = false;
          ad.dispose();
          loadRewardedInterstitialAd(); // Try loading again
        },
      );
    } else {
      print('Rewarded Interstitial ad not ready yet');
      await loadRewardedInterstitialAd();
    }
  }

  // Dispose Ads
  static void disposeAds() {
    bannerAd.dispose();
    if (isInterstitialAdReady) interstitialAd.dispose();
    if (isRewardedAdReady) rewardedAd.dispose();
    if (isRewardedInterstitialAdReady) rewardedInterstitialAd.dispose();
  }
}
