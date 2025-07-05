import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'skin_model.dart';

class SkinManager {
  static const String _skinsKey = 'unlocked_skins';
  static const String _selectedSkinKey = 'selected_skin';

  // All available skins in the game
  static final List<Skin> _allSkins = [
    const Skin(
      id: 'default',
      name: 'Earth',
      description: 'The classic blue planet',
      imagePath: 'player.png',
      price: 0,
      isUnlocked: true,
      rarity: 'common',
    ),
    const Skin(
      id: 'mars',
      name: 'Mars',
      description: 'The red planet of war',
      imagePath: 'player_mars.png',
      price: 1,
      isUnlocked: false,
      rarity: 'common',
    ),
    const Skin(
      id: 'venus',
      name: 'Venus',
      description: 'The beautiful morning star',
      imagePath: 'player_venus.png',
      price: 1,
      isUnlocked: false,
      rarity: 'common',
    ),
    const Skin(
      id: 'jupiter',
      name: 'Jupiter',
      description: 'The gas giant with storms',
      imagePath: 'player_jupiter.png',
      price: 2,
      isUnlocked: false,
      rarity: 'rare',
    ),
    const Skin(
      id: 'saturn',
      name: 'Saturn',
      description: 'The ringed beauty',
      imagePath: 'player_saturn.png',
      price: 2,
      isUnlocked: false,
      rarity: 'rare',
    ),
    const Skin(
      id: 'neptune',
      name: 'Neptune',
      description: 'The mysterious ice giant',
      imagePath: 'player_neptune.png',
      price: 3,
      isUnlocked: false,
      rarity: 'epic',
    ),
    const Skin(
      id: 'sun',
      name: 'The Sun',
      description: 'The blazing star itself',
      imagePath: 'player_sun.png',
      price: 5,
      isUnlocked: false,
      rarity: 'legendary',
    ),
    const Skin(
      id: 'blackhole',
      name: 'Black Hole',
      description: 'The ultimate cosmic mystery',
      imagePath: 'player_blackhole.png',
      price: 7,
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
    final unlockedSkinIds = _skins
        .where((skin) => skin.isUnlocked)
        .map((skin) => skin.id)
        .toList();
    
    await prefs.setStringList(_skinsKey, unlockedSkinIds);
    await prefs.setString(_selectedSkinKey, _selectedSkinId);
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
}
