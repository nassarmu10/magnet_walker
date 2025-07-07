import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static late BannerAd bannerAd;

  static String get bannerAdUnitId {
    // Replace with your banner ad unit ID
    return Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/9214589741' // test 'ca-app-pub-3940256099942544/9214589741'
        : 'ca-app-pub-4497634353967283/6255642575'; // test ca-app-pub-3940256099942544/6300978111
  }

  static String get interstitialAdUnitId {
    // Replace with your interstitial ad unit ID
    return Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/1033173712' // test 'ca-app-pub-4497634353967283/2665119024'
        : 'ca-app-pub-4497634353967283/6708004493'; // test ca-app-pub-3940256099942544/1033173712
  }

  static String get rewardedAdUnitId {
    // Replace with your rewarded ad unit ID
    return Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/5224354917' // test 'ca-app-pub-3940256099942544/5224354917'
        : 'ca-app-pub-3940256099942544/5224354917'; //  'ca-app-pub-4497634353967283/1357956265';
  }

  static String get rewardedInterstitialAdUnitId {
    // Replace with your rewarded interstitial ad unit ID
    return Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/5354046379' // test 'ca-app-pub-3940256099942544/5354046379'
        : 'ca-app-pub-4497634353967283/3103827050'; // test ca-app-pub-3940256099942544/5354046379
  }

  static InterstitialAd? interstitialAd;
  static RewardedAd? rewardedAd;
  static RewardedInterstitialAd? rewardedInterstitialAd;

  static bool isInterstitialAdReady = false;
  static bool isRewardedAdReady = false;
  static bool isRewardedInterstitialAdReady = false;
  static bool isAdsInitialized = false;
  static bool isLoadingRewardedAd = false;

  // Initialize AdMob
  static Future<void> initialize() async {
    if (!isAdsInitialized) {
      try {
        await MobileAds.instance.initialize();
        isAdsInitialized = true;
        print('AdMob initialized successfully');

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
        onAdLoaded: (ad) {
          print('Banner Ad loaded successfully');
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
    if (!isAdsInitialized) {
      print('Ads not initialized, cannot load interstitial ad');
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
            print('Interstitial Ad loaded successfully');

            interstitialAd!.fullScreenContentCallback =
                FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                print('Interstitial ad dismissed');
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
            interstitialAd = null;
          },
        ),
      );
    } catch (e) {
      print('Exception loading interstitial ad: $e');
      isInterstitialAdReady = false;
      interstitialAd = null;
    }
  }

  // Show Interstitial Ad
  static void showInterstitialAd() {
    if (isInterstitialAdReady && interstitialAd != null) {
      interstitialAd!.show();
    } else {
      print('Interstitial ad not ready yet, attempting to load...');
      loadInterstitialAd();
    }
  }

  // Load Rewarded Ad with retry mechanism
  static Future<void> loadRewardedAd() async {
    if (!isAdsInitialized) {
      print('Ads not initialized, cannot load rewarded ad');
      return;
    }

    if (isLoadingRewardedAd) {
      print('Already loading rewarded ad, skipping...');
      return;
    }

    isLoadingRewardedAd = true;

    try {
      print('Loading rewarded ad...');
      await RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            rewardedAd = ad;
            isRewardedAdReady = true;
            isLoadingRewardedAd = false;
            print('Rewarded Ad loaded successfully');

            rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                print('Rewarded ad dismissed');
                isRewardedAdReady = false;
                ad.dispose();
                rewardedAd = null;
                // Load next ad after a short delay
                Future.delayed(const Duration(seconds: 1), () {
                  loadRewardedAd();
                });
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                print('Failed to show rewarded ad: $error');
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
            print('Rewarded Ad failed to load: $error');
            isRewardedAdReady = false;
            rewardedAd = null;
            isLoadingRewardedAd = false;

            // Retry loading after a delay
            Future.delayed(const Duration(seconds: 3), () {
              print('Retrying to load rewarded ad...');
              loadRewardedAd();
            });
          },
        ),
      );
    } catch (e) {
      print('Exception loading rewarded ad: $e');
      isRewardedAdReady = false;
      rewardedAd = null;
      isLoadingRewardedAd = false;
    }
  }

  // Show Rewarded Ad with improved error handling and preloading
  static Future<void> showRewardedAd({
    required Function onRewarded,
    Function? onAdFailedToShow,
  }) async {
    print('Attempting to show rewarded ad...');
    print('isRewardedAdReady: $isRewardedAdReady');
    print('rewardedAd != null: ${rewardedAd != null}');
    print('isAdsInitialized: $isAdsInitialized');

    if (isRewardedAdReady && rewardedAd != null) {
      try {
        print('Showing rewarded ad...');
        rewardedAd!.show(
          onUserEarnedReward: (ad, reward) {
            print('User earned reward: ${reward.amount} ${reward.type}');
            onRewarded();
          },
        );
      } catch (e) {
        print('Error showing rewarded ad: $e');
        onAdFailedToShow?.call();
        // Try to load a new ad
        loadRewardedAd();
      }
    } else {
      print('Rewarded ad not ready. Loading new ad...');

      // Show user feedback immediately
      onAdFailedToShow?.call();

      // Try to load and show ad if not already loading
      if (!isLoadingRewardedAd) {
        await loadRewardedAd();

        // Wait a bit and try again if ad is now ready
        await Future.delayed(const Duration(seconds: 2));
        if (isRewardedAdReady && rewardedAd != null) {
          print('Ad loaded successfully, showing now...');
          showRewardedAd(
              onRewarded: onRewarded, onAdFailedToShow: onAdFailedToShow);
        } else {
          print('Failed to load ad after retry');
          onAdFailedToShow?.call();
        }
      }
    }
  }

  static Future<void> loadRewardedInterstitialAd() async {
    if (!isAdsInitialized) {
      print('Ads not initialized, cannot load rewarded interstitial ad');
      return;
    }

    try {
      await RewardedInterstitialAd.load(
        adUnitId: rewardedInterstitialAdUnitId,
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            rewardedInterstitialAd = ad;
            isRewardedInterstitialAdReady = true;
            print('Rewarded Interstitial Ad loaded successfully');

            rewardedInterstitialAd!.fullScreenContentCallback =
                FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                print('Rewarded interstitial ad dismissed');
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
            rewardedInterstitialAd = null;
          },
        ),
      );
    } catch (e) {
      print('Exception loading rewarded interstitial ad: $e');
      isRewardedInterstitialAdReady = false;
      rewardedInterstitialAd = null;
    }
  }

  static Future<void> showRewardedInterstitialAd({
    required Function onRewarded,
    Function? onAdDismissed,
    Function? onAdFailedToShow,
  }) async {
    if (isRewardedInterstitialAdReady && rewardedInterstitialAd != null) {
      try {
        rewardedInterstitialAd!.show(
          onUserEarnedReward: (ad, reward) {
            print('User earned reward: ${reward.amount} ${reward.type}');
            onRewarded();
          },
        );

        rewardedInterstitialAd!.fullScreenContentCallback =
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
            onAdFailedToShow?.call();
          },
        );
      } catch (e) {
        print('Error showing rewarded interstitial ad: $e');
        onAdFailedToShow?.call();
      }
    } else {
      print('Rewarded Interstitial ad not ready yet, attempting to load...');
      onAdFailedToShow?.call();
      await loadRewardedInterstitialAd();
    }
  }

  // Check if rewarded ad is available
  static bool isRewardedAdAvailable() {
    bool available =
        isAdsInitialized && isRewardedAdReady && rewardedAd != null;
    print(
        'isRewardedAdAvailable: $available (initialized: $isAdsInitialized, ready: $isRewardedAdReady, notNull: ${rewardedAd != null})');
    return available;
  }

  // Force reload rewarded ad
  static Future<void> forceLoadRewardedAd() async {
    print('Force loading rewarded ad...');
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
      bannerAd.dispose();
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
    isRewardedInterstitialAdReady = false;
    isLoadingRewardedAd = false;
  }
}
