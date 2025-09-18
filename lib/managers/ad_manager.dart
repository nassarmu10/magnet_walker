import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static late BannerAd bannerAd;

  static String get bannerAdUnitId {
    // Replace with your banner ad unit ID
    return Platform.isAndroid
        ? 'ca-app-pub-4497634353967283/1784471212' // test 'ca-app-pub-3940256099942544/9214589741'
        : 'ca-app-pub-4497634353967283/6092306954'; // prod ca-app-pub-4497634353967283/6092306954
  }

  static String get interstitialAdUnitId {
    // Replace with your interstitial ad unit ID
    return Platform.isAndroid
        ? 'ca-app-pub-4497634353967283/8708972212' // test 'ca-app-pub-4497634353967283/2665119024'
        : 'ca-app-pub-4497634353967283/5089097885'; // test ca-app-pub-3940256099942544/1033173712
  }

  static String get rewardedAdUnitId {
    // Replace with your rewarded ad unit ID
    return Platform.isAndroid
        ? 'ca-app-pub-4497634353967283/5284678621' // test 'ca-app-pub-3940256099942544/5224354917'
        : 'ca-app-pub-4497634353967283/1357956265'; //  'ca-app-pub-4497634353967283/1357956265';
  }

  static InterstitialAd? interstitialAd;
  static RewardedAd? rewardedAd;
  static RewardedInterstitialAd? rewardedInterstitialAd;

  static bool isInterstitialAdReady = false;
  static bool isRewardedAdReady = false;
  static bool isAdsInitialized = false;
  static bool isLoadingRewardedAd = false;

  // Initialize AdMob
  static Future<void> initialize() async {
    if (!isAdsInitialized) {
      try {
        await MobileAds.instance.initialize();
        isAdsInitialized = true;

        // Load ads immediately after initialization
        await loadRewardedAd();
        await loadInterstitialAd();
      } catch (e) {
        print('Failed to initialize AdMob: $e');
        isAdsInitialized = false;
      }
    }
  }

  // Load Banner Ad
  static BannerAd createBannerAd() {
    bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {},
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );

    return bannerAd;
  }

  // Load Interstitial Ad
  static Future<void> loadInterstitialAd() async {
    if (!isAdsInitialized) {
      return;
    }

    try {
      await InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            interstitialAd = ad;
            isInterstitialAdReady = true;

            interstitialAd!.fullScreenContentCallback =
                FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                isInterstitialAdReady = false;
                ad.dispose();
                loadInterstitialAd(); // Load next ad
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                isInterstitialAdReady = false;
                ad.dispose();
                loadInterstitialAd(); // Try loading again
              },
            );
          },
          onAdFailedToLoad: (error) {
            isInterstitialAdReady = false;
            interstitialAd = null;
          },
        ),
      );
    } catch (e) {
      isInterstitialAdReady = false;
      interstitialAd = null;
    }
  }

  // Show Interstitial Ad
  static void showInterstitialAd() {
    if (isInterstitialAdReady && interstitialAd != null) {
      interstitialAd!.show();
    } else {
      loadInterstitialAd();
    }
  }

  // Load Rewarded Ad with retry mechanism
  static Future<void> loadRewardedAd() async {
    if (!isAdsInitialized) {
      return;
    }

    if (isLoadingRewardedAd) {
      return;
    }

    isLoadingRewardedAd = true;

    try {
      await RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            rewardedAd = ad;
            isRewardedAdReady = true;
            isLoadingRewardedAd = false;

            rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                isRewardedAdReady = false;
                ad.dispose();
                rewardedAd = null;
                // Load next ad after a short delay
                Future.delayed(const Duration(seconds: 1), () {
                  loadRewardedAd();
                });
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                isRewardedAdReady = false;
                ad.dispose();
                rewardedAd = null;
                isLoadingRewardedAd = false;
                // Try loading again
                Future.delayed(const Duration(seconds: 2), () {
                  loadRewardedAd();
                });
              },
            );
          },
          onAdFailedToLoad: (error) {
            isRewardedAdReady = false;
            rewardedAd = null;
            isLoadingRewardedAd = false;

            // Retry loading after a delay
            Future.delayed(const Duration(seconds: 3), () {
              loadRewardedAd();
            });
          },
        ),
      );
    } catch (e) {
      isRewardedAdReady = false;
      rewardedAd = null;
      isLoadingRewardedAd = false;
    }
  }

  // Show Rewarded Ad with improved error handling and preloading
  static Future<void> showRewardedAd({
    required Function onRewarded,
    required Function onFailed,
    Function? onAdDismissed, // Add this parameter
  }) async {
    if (isRewardedAdReady && rewardedAd != null) {
      try {
        // Set up the full screen content callback BEFORE showing the ad
        rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (RewardedAd ad) {
            onAdDismissed?.call(); // Call when ad is dismissed
            ad.dispose();
            rewardedAd = null;
            isRewardedAdReady = false;
            // Preload next ad
            loadRewardedAd();
          },
          onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
            ad.dispose();
            rewardedAd = null;
            isRewardedAdReady = false;
            onFailed();
            // Try to load a new ad
            loadRewardedAd();
          },
          onAdShowedFullScreenContent: (RewardedAd ad) {},
        );

        rewardedAd!.show(
          onUserEarnedReward: (ad, reward) {
            onRewarded();
          },
        );
      } catch (e) {
        onFailed();
        // Try to load a new ad
        loadRewardedAd();
      }
    } else {
      // Show user feedback immediately
      onFailed();
      // Try to load and show ad if not already loading
      if (!isLoadingRewardedAd) {
        await loadRewardedAd();
        // Wait a bit and try again if ad is now ready
        await Future.delayed(const Duration(seconds: 2));
        if (isRewardedAdReady && rewardedAd != null) {
          showRewardedAd(
            onRewarded: onRewarded,
            onFailed: onFailed,
            onAdDismissed: onAdDismissed, // Pass it through
          );
        } else {
          onFailed();
        }
      }
    }
  }

  // Check if rewarded ad is available
  static bool isRewardedAdAvailable() {
    bool available =
        isAdsInitialized && isRewardedAdReady && rewardedAd != null;

    return available;
  }

  // Force reload rewarded ad
  static Future<void> forceLoadRewardedAd() async {
    isRewardedAdReady = false;
    isLoadingRewardedAd = false;
    if (rewardedAd != null) {
      rewardedAd!.dispose();
      rewardedAd = null;
    }
    await loadRewardedAd();
  }

  // Dispose Ads
  static void disposeAds() {
    try {
      bannerAd?.dispose();
    } catch (e) {
      print('Error disposing banner ad: $e');
    }

    try {
      if (interstitialAd != null) {
        interstitialAd!.dispose();
        interstitialAd = null;
      }
    } catch (e) {
      print('Error disposing interstitial ad: $e');
    }

    try {
      if (rewardedAd != null) {
        rewardedAd!.dispose();
        rewardedAd = null;
      }
    } catch (e) {
      print('Error disposing rewarded ad: $e');
    }

    try {
      if (rewardedInterstitialAd != null) {
        rewardedInterstitialAd!.dispose();
        rewardedInterstitialAd = null;
      }
    } catch (e) {
      print('Error disposing rewarded interstitial ad: $e');
    }

    isInterstitialAdReady = false;
    isRewardedAdReady = false;
    isLoadingRewardedAd = false;
  }
}
