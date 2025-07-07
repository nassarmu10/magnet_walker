import 'package:flutter/material.dart';
import 'skin_manager.dart';
import 'skin_model.dart';
import '../managers/ad_manager.dart';

class SkinStoreScreen extends StatefulWidget {
  final SkinManager skinManager;
  final VoidCallback onSkinChanged;

  const SkinStoreScreen({
    Key? key,
    required this.skinManager,
    required this.onSkinChanged,
  }) : super(key: key);

  @override
  State<SkinStoreScreen> createState() => _SkinStoreScreenState();
}

class _SkinStoreScreenState extends State<SkinStoreScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String _loadingSkinId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize ads properly when store opens
    _initializeAds();
  }

  Future<void> _initializeAds() async {
    print('=== Initializing ads in skin store ===');
    
    // Ensure AdManager is initialized
    if (!AdManager.isAdsInitialized) {
      print('AdManager not initialized, initializing now...');
      await AdManager.initialize();
    }
    
    // Load rewarded ads
    if (!AdManager.isRewardedAdAvailable()) {
      print('Loading rewarded ads...');
      await AdManager.loadRewardedAd();
    }
    
    // Wait a bit and check status
    await Future.delayed(const Duration(seconds: 2));
    print('Ad initialization complete:');
    print('- Ads initialized: ${AdManager.isAdsInitialized}');
    print('- Rewarded ad ready: ${AdManager.isRewardedAdReady}');
    print('- Ad available: ${AdManager.isRewardedAdAvailable()}');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getRarityColor(String rarity) {
    switch (rarity) {
      case 'common':
        return Colors.grey;
      case 'rare':
        return Colors.blue;
      case 'epic':
        return Colors.purple;
      case 'legendary':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getRarityEmoji(String rarity) {
    switch (rarity) {
      case 'common':
        return '⭐';
      case 'rare':
        return '💎';
      case 'epic':
        return '🔮';
      case 'legendary':
        return '👑';
      default:
        return '⭐';
    }
  }

  Widget _buildSkinCard(Skin skin) {
    final rarityColor = _getRarityColor(skin.rarity);
    final rarityEmoji = _getRarityEmoji(skin.rarity);
    final isSelected = widget.skinManager.selectedSkinId == skin.id;
    final isLoadingThisSkin = _isLoading && _loadingSkinId == skin.id;

    return Container(
      margin: const EdgeInsets.all(6.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1a1a2e),
            const Color(0xFF16213e),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected 
              ? Colors.cyanAccent 
              : rarityColor.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: rarityColor.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with rarity
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [rarityColor.withOpacity(0.3), rarityColor.withOpacity(0.1)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '$rarityEmoji ${skin.rarity.toUpperCase()}',
                    style: TextStyle(
                      color: rarityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: Colors.cyanAccent,
                    size: 14,
                  ),
              ],
            ),
          ),
          
          // Skin image
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: rarityColor.withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/${skin.imagePath}',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [rarityColor.withOpacity(0.3), rarityColor.withOpacity(0.1)],
                          ),
                        ),
                        child: Icon(
                          Icons.public,
                          color: rarityColor,
                          size: 30,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          
          // Skin info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    skin.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Text(
                      skin.description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 10,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Action button
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: _buildActionButton(skin, isLoadingThisSkin),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(Skin skin, bool isLoadingThisSkin) {
    if (skin.isUnlocked) {
      final isSelected = widget.skinManager.selectedSkinId == skin.id;
      return ElevatedButton(
        onPressed: isSelected ? null : () => _selectSkin(skin),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.cyanAccent : Colors.green,
          disabledBackgroundColor: Colors.cyanAccent.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            isSelected ? 'EQUIPPED' : 'EQUIP',
            style: TextStyle(
              color: isSelected ? Colors.white.withOpacity(0.7) : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      );
    } else {
      return ElevatedButton(
        onPressed: isLoadingThisSkin ? null : () => _buySkin(skin),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.pinkAccent,
          disabledBackgroundColor: Colors.pinkAccent.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: isLoadingThisSkin 
            ? const SizedBox(
                width: 12, 
                height: 12, 
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      '${skin.price}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
      );
    }
  }

  void _selectSkin(Skin skin) async {
    final success = await widget.skinManager.selectSkin(skin.id);
    if (success) {
      setState(() {});
      widget.onSkinChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${skin.name} equipped!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _buySkin(Skin skin) async {
    setState(() {
      _isLoading = true;
      _loadingSkinId = skin.id;
    });

    print('=== Starting skin purchase for ${skin.name} ===');
    print('Initial ad availability: ${AdManager.isRewardedAdAvailable()}');

    // Simple approach - just try to show the ad like the game screen does
    AdManager.showRewardedAd(
      onRewarded: () {
        print('✅ Ad completed successfully for ${skin.name}!');
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loadingSkinId = '';
          });
          
          // For now, unlock immediately after one ad (you can modify this for multiple ads later)
          _unlockSkin(skin);
        }
      },
    );

    // Reset loading state after timeout in case ad doesn't show
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoading && _loadingSkinId == skin.id) {
        setState(() {
          _isLoading = false;
          _loadingSkinId = '';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ad request timed out for ${skin.name}. Please try again.'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'RETRY',
              onPressed: () => _buySkin(skin),
            ),
          ),
        );
      }
    });
  }

  void _unlockSkin(Skin skin) async {
    final success = await widget.skinManager.unlockSkin(skin.id);
    setState(() {
      _isLoading = false;
      _loadingSkinId = '';
    });
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(_getRarityEmoji(skin.rarity)),
              const SizedBox(width: 8),
              Text('${skin.name} unlocked!'),
            ],
          ),
          backgroundColor: _getRarityColor(skin.rarity),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // // Debug method - add this temporarily
  // void _debugAdStatus() {
  //   print('=== AD DEBUG STATUS ===');
  //   print('AdManager.isAdsInitialized: ${AdManager.isAdsInitialized}');
  //   print('AdManager.isRewardedAdReady: ${AdManager.isRewardedAdReady}');
  //   print('AdManager.isRewardedAdAvailable(): ${AdManager.isRewardedAdAvailable()}');
  //   print('========================');
    
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       backgroundColor: const Color(0xFF1a1a2e),
  //       title: const Text('Ad Debug Info', style: TextStyle(color: Colors.white)),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text('Ads Initialized: ${AdManager.isAdsInitialized}', style: const TextStyle(color: Colors.white)),
  //           Text('Rewarded Ad Ready: ${AdManager.isRewardedAdReady}', style: const TextStyle(color: Colors.white)),
  //           Text('Ad Available: ${AdManager.isRewardedAdAvailable()}', style: const TextStyle(color: Colors.white)),
  //           const SizedBox(height: 16),
  //           ElevatedButton(
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //               AdManager.forceLoadRewardedAd();
  //               ScaffoldMessenger.of(context).showSnackBar(
  //                 const SnackBar(content: Text('Forced ad reload...')),
  //               );
  //             },
  //             child: const Text('Force Load Ad'),
  //           ),
  //         ],
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.of(context).pop(),
  //           child: const Text('Close', style: TextStyle(color: Colors.cyanAccent)),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final unlockedSkins = widget.skinManager.getUnlockedSkins();
    final lockedSkins = widget.skinManager.getLockedSkins();

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text(
          'Skin Store',
          style: TextStyle(
            color: Colors.cyanAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.cyanAccent),
        // actions: [
        //   // Debug button - remove this after testing
        //   IconButton(
        //     icon: const Icon(Icons.bug_report),
        //     onPressed: _debugAdStatus,
        //   ),
        // ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          indicatorColor: Colors.cyanAccent,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory, size: 16),
                  const SizedBox(width: 4),
                  Text('Owned (${unlockedSkins.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.store, size: 16),
                  const SizedBox(width: 4),
                  Text('Store (${lockedSkins.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Owned skins tab
          GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: unlockedSkins.length,
            itemBuilder: (context, index) {
              return _buildSkinCard(unlockedSkins[index]);
            },
          ),
          
          // Store tab
          GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: lockedSkins.length,
            itemBuilder: (context, index) {
              return _buildSkinCard(lockedSkins[index]);
            },
          ),
        ],
      ),
    );
  }
}
