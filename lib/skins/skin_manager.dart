import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'skin_model.dart';

class SkinManager {
  static const String _skinsKey = 'unlocked_skins';
  static const String _selectedSkinKey = 'selected_skin';

  // All available skins in the game - price now represents UNLOCK LEVEL, not ad count
  static final List<Skin> _allSkins = [
    const Skin(
      id: 'default',
      name: 'Earth',
      description: 'The classic blue planet',
      imagePath: 'player.png',
      price: 1, // Available from level 1 (always available)
      isUnlocked: true,
      rarity: 'common',
    ),
    const Skin(
      id: 'white',
      name: 'White Spirit',
      description: 'Pure and elegant essence',
      imagePath: 'whiteSS.png',
      price: 2, // Available for purchase from level 2
      isUnlocked: false,
      rarity: 'common',
    ),
    const Skin(
      id: 'blue_yellow',
      name: 'Ocean Sunset',
      description: 'Where sea meets golden sky',
      imagePath: 'blue-yellow-SS.png',
      price: 4, // Available for purchase from level 4
      isUnlocked: false,
      rarity: 'common',
    ),
    const Skin(
      id: 'red_yellow',
      name: 'Fire Storm',
      description: 'Blazing flames and lightning',
      imagePath: 'red-yellow-SS.png',
      price: 8, // Available for purchase from level 6
      isUnlocked: false,
      rarity: 'common',
    ),
    const Skin(
      id: 'gray',
      name: 'Steel Guardian',
      description: 'Metallic armor of protection',
      imagePath: 'graySS.png',
      price: 13, // Available for purchase from level 7
      isUnlocked: false,
      rarity: 'rare',
    ),
    const Skin(
      id: 'bird',
      name: 'Sky Soarer',
      description: 'Graceful wings of freedom',
      imagePath: 'birdSS.png',
      price: 17, // Available for purchase from level 9
      isUnlocked: false,
      rarity: 'rare',
    ),
    const Skin(
      id: 'dog',
      name: 'Loyal Companion',
      description: 'Faithful friend forever',
      imagePath: 'dogSS.png',
      price: 20, // Available for purchase from level 10
      isUnlocked: false,
      rarity: 'rare',
    ),
    const Skin(
      id: 'dragon',
      name: 'Dragon Champion',
      description: 'Fire Dragon',
      imagePath: 'tenninSS.png',
      price: 25, // Available for purchase from level 11
      isUnlocked: false,
      rarity: 'rare',
    ),
    const Skin(
      id: 'giraffe',
      name: 'Tall Explorer',
      description: 'Reaching for the stars above',
      imagePath: 'GiraffeSS.png',
      price: 29, // Available for purchase from level 13
      isUnlocked: false,
      rarity: 'epic',
    ),
    const Skin(
      id: 'mystery',
      name: 'Dark Mystery',
      description: 'The unknown lurks within',
      imagePath: 'shitSS.png',
      price: 33, // Available for purchase from level 14
      isUnlocked: false,
      rarity: 'epic',
    ),
    const Skin(
      id: 'dolphin',
      name: 'Ocean Dancer',
      description: 'Playful spirit of the seas',
      imagePath: 'dolphinSS.png',
      price: 40, // Available for purchase from level 15
      isUnlocked: false,
      rarity: 'epic',
    ),
    const Skin(
      id: 'hippo',
      name: 'River Giant',
      description: 'Mighty ruler of the waters',
      imagePath: 'hippoSS.png',
      price: 46, // Available for purchase from level 16
      isUnlocked: false,
      rarity: 'epic',
    ),
    const Skin(
      id: 'lion',
      name: 'Jungle King',
      description: 'Majestic ruler of the wild',
      imagePath: 'lionSS.png',
      price: 52, // Available for purchase from level 17
      isUnlocked: false,
      rarity: 'epic',
    ),
    const Skin(
      id: 'pig',
      name: 'Happy Piglet',
      description: 'Joyful and carefree spirit',
      imagePath: 'pigSS.png',
      price: 60, // Available for purchase from level 19
      isUnlocked: false,
      rarity: 'epic',
    ),
    const Skin(
      id: 'star',
      name: 'Celestial Star',
      description: 'Shining bright in the cosmos',
      imagePath: 'starSS.png',
      price: 68, // Available for purchase from level 20
      isUnlocked: false,
      rarity: 'legendary',
    ),
    const Skin(
      id: 'tiger',
      name: 'Fierce Hunter',
      description: 'Striped predator of power',
      imagePath: 'tigerSS.png',
      price: 75, // Available for purchase from level 22
      isUnlocked: false,
      rarity: 'legendary',
    ),
  ];

  List<Skin> _skins = [];
  String _selectedSkinId = 'default';

  List<Skin> get skins => List.unmodifiable(_skins);
  String get selectedSkinId => _selectedSkinId;

  Skin get selectedSkin => _skins.firstWhere(
        (skin) => skin.id == _selectedSkinId,
        orElse: () => _skins.first,
      );

  Future<void> initialize() async {
    await _loadSkins();
  }

  Future<void> _loadSkins() async {
    final prefs = await SharedPreferences.getInstance();

    // Load unlocked skins
    final unlockedSkinIds = prefs.getStringList(_skinsKey) ?? ['default'];

    // Load selected skin
    _selectedSkinId = prefs.getString(_selectedSkinKey) ?? 'default';

    // Create skin list with unlock status
    _skins = _allSkins.map((skin) {
      return skin.copyWith(isUnlocked: unlockedSkinIds.contains(skin.id));
    }).toList();
  }

  Future<void> _saveSkins() async {
    final prefs = await SharedPreferences.getInstance();

    // Save unlocked skin IDs
    final unlockedSkinIds =
        _skins.where((skin) => skin.isUnlocked).map((skin) => skin.id).toList();

    await prefs.setStringList(_skinsKey, unlockedSkinIds);
    await prefs.setString(_selectedSkinKey, _selectedSkinId);
  }

  // NEW: Check if a skin is available for purchase based on player level
  bool isSkinAvailableForPurchase(String skinId, int playerLevel) {
    final skin = _skins.firstWhere(
      (skin) => skin.id == skinId,
      orElse: () => _skins.first,
    );
    return !skin.isUnlocked && playerLevel >= skin.price;
  }

  // NEW: Get skins that are available for purchase (unlocked by level but not owned)
  List<Skin> getAvailableForPurchase(int playerLevel) {
    return _skins
        .where((skin) => !skin.isUnlocked && playerLevel >= skin.price)
        .toList();
  }

  // NEW: Get skins that are locked (not yet available for purchase)
  List<Skin> getLockedByLevel(int playerLevel) {
    return _skins
        .where((skin) => !skin.isUnlocked && playerLevel < skin.price)
        .toList();
  }

  Future<bool> unlockSkin(String skinId) async {
    final skinIndex = _skins.indexWhere((skin) => skin.id == skinId);
    if (skinIndex == -1) return false;

    _skins[skinIndex] = _skins[skinIndex].copyWith(isUnlocked: true);
    await _saveSkins();
    return true;
  }

  Future<bool> selectSkin(String skinId) async {
    final skin = _skins.firstWhere(
      (skin) => skin.id == skinId,
      orElse: () => _skins.first,
    );

    if (!skin.isUnlocked) return false;

    _selectedSkinId = skinId;
    await _saveSkins();
    return true;
  }

  List<Skin> getSkinsByRarity(String rarity) {
    return _skins.where((skin) => skin.rarity == rarity).toList();
  }

  List<Skin> getUnlockedSkins() {
    return _skins.where((skin) => skin.isUnlocked).toList();
  }

  List<Skin> getLockedSkins() {
    return _skins.where((skin) => !skin.isUnlocked).toList();
  }

  bool isSkinUnlocked(String skinId) {
    return _skins.any((skin) => skin.id == skinId && skin.isUnlocked);
  }

  // Get required level for a skin to become available for purchase
  int getRequiredLevel(String skinId) {
    final skin = _skins.firstWhere(
      (skin) => skin.id == skinId,
      orElse: () => _skins.first,
    );
    return skin.price;
  }
}
