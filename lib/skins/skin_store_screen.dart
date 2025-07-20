import 'package:flutter/material.dart';
import 'skin_manager.dart';
import 'skin_model.dart';
import '../managers/ad_manager.dart';

class SkinStoreScreen extends StatefulWidget {
  final SkinManager skinManager;
  final VoidCallback onSkinChanged;
  final int currentLevel; // NEW: Current player level

  const SkinStoreScreen({
    Key? key,
    required this.skinManager,
    required this.onSkinChanged,
    required this.currentLevel,
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
    _tabController = TabController(length: 3, vsync: this); // NEW: 3 tabs now
    _initializeAds();
  }

  Future<void> _initializeAds() async {
    if (!AdManager.isAdsInitialized) {
      await AdManager.initialize();
    }
    if (!AdManager.isRewardedAdAvailable()) {
      await AdManager.loadRewardedAd();
    }
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
    final canPurchase = widget.skinManager
        .isSkinAvailableForPurchase(skin.id, widget.currentLevel);

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
          color: isSelected ? Colors.cyanAccent : rarityColor.withOpacity(0.3),
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
                colors: [
                  rarityColor.withOpacity(0.3),
                  rarityColor.withOpacity(0.1)
                ],
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
                  child: ColorFiltered(
                    // Gray out skins that can't be purchased yet
                    colorFilter: (!skin.isUnlocked && !canPurchase)
                        ? const ColorFilter.mode(
                            Colors.grey,
                            BlendMode.saturation,
                          )
                        : const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.multiply,
                          ),
                    child: Image.asset(
                      'assets/images/${skin.imagePath}',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                rarityColor.withOpacity(0.3),
                                rarityColor.withOpacity(0.1)
                              ],
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
                    child: _buildActionButton(
                        skin, canPurchase, isLoadingThisSkin),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      Skin skin, bool canPurchase, bool isLoadingThisSkin) {
    if (skin.isUnlocked) {
      // Already owned
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
    } else if (canPurchase) {
      // Available for purchase via ad
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
            : const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, size: 12),
                    SizedBox(width: 2),
                    Text(
                      'WATCH AD',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
      );
    } else {
      // Locked - show required level
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.grey.withOpacity(0.5),
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 12, color: Colors.grey),
                const SizedBox(width: 2),
                Text(
                  'LV ${skin.price}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
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

    AdManager.showRewardedAd(
      onRewarded: () {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loadingSkinId = '';
          });
          _unlockSkin(skin);
        }
      },
      onFailed: () {},
    );

    // Reset loading state after timeout
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoading && _loadingSkinId == skin.id) {
        setState(() {
          _isLoading = false;
          _loadingSkinId = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Ad request timed out for ${skin.name}. Please try again.'),
            backgroundColor: Colors.orange,
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

  @override
  Widget build(BuildContext context) {
    final unlockedSkins = widget.skinManager.getUnlockedSkins();
    final availableForPurchase =
        widget.skinManager.getAvailableForPurchase(widget.currentLevel);
    final lockedByLevel =
        widget.skinManager.getLockedByLevel(widget.currentLevel);

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Column(
          children: [
            const Text(
              'Skin Store',
              style: TextStyle(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Level ${widget.currentLevel}',
              style: TextStyle(
                color: Colors.cyanAccent.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.cyanAccent),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.cyanAccent),
          onPressed: () {
            // Properly handle back navigation
            Navigator.of(context).pop();
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          indicatorColor: Colors.cyanAccent,
          isScrollable: true,
          tabs: [
            Tab(
              child: Row(
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.store, size: 16),
                  const SizedBox(width: 4),
                  Text('Available (${availableForPurchase.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, size: 16),
                  const SizedBox(width: 4),
                  Text('Locked (${lockedByLevel.length})'),
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

          // Available for purchase tab
          availableForPurchase.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.store,
                        size: 64,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No skins available for purchase',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Keep playing to unlock more!',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: availableForPurchase.length,
                  itemBuilder: (context, index) {
                    return _buildSkinCard(availableForPurchase[index]);
                  },
                ),

          // Locked by level tab
          lockedByLevel.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 64,
                        color: Colors.amber.withOpacity(0.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'All skins unlocked!',
                        style: TextStyle(
                          color: Colors.amber.withOpacity(0.8),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You\'ve reached the highest levels!',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: lockedByLevel.length,
                  itemBuilder: (context, index) {
                    return _buildSkinCard(lockedByLevel[index]);
                  },
                ),
        ],
      ),
    );
  }
}
