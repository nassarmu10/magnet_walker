import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'skin_model.dart';
import '../config/game_config.dart';

class SkinManager {
  static const String _skinsKey = 'unlocked_skins';
  static const String _selectedSkinKey = 'selected_skin';

  // All available skins in the game - price now represents UNLOCK LEVEL, not ad count
  static List<Skin> get _allSkins {
    return GameConfig.skinData
        .map((skinData) => Skin(
              id: skinData['id'],
              name: skinData['name'],
              description: skinData['description'],
              imagePath: skinData['imagePath'],
              price: skinData['price'],
              isUnlocked: skinData['id'] ==
                  'default', // Only default is unlocked initially
              rarity: skinData['rarity'],
            ))
        .toList();
  }

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
