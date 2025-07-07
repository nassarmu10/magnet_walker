// // Replace the SkinManager in lib/managers/skin_manager.dart:

// import 'package:shared_preferences/shared_preferences.dart';

// class SkinData {
//   final String id;
//   final String name;
//   final String description;
//   final String imagePath;
//   final int price; // Price in ads to watch (0 = free/default)
//   final bool isUnlocked;

//   SkinData({
//     required this.id,
//     required this.name,
//     required this.description,
//     required this.imagePath,
//     required this.price,
//     required this.isUnlocked,
//   });

//   SkinData copyWith({
//     String? id,
//     String? name,
//     String? description,
//     String? imagePath,
//     int? price,
//     bool? isUnlocked,
//   }) {
//     return SkinData(
//       id: id ?? this.id,
//       name: name ?? this.name,
//       description: description ?? this.description,
//       imagePath: imagePath ?? this.imagePath,
//       price: price ?? this.price,
//       isUnlocked: isUnlocked ?? this.isUnlocked,
//     );
//   }
// }

// class SkinManager {
//   static const String _currentSkinKey = 'current_skin';
//   static const String _unlockedSkinsKey = 'unlocked_skins';
  
//   String _currentSkinId = 'default';
//   final Map<String, SkinData> _skins = {};
//   bool _initialized = false;
  
//   SkinManager() {
//     _initializeSkins();
//   }

//   void _initializeSkins() {
//     // Default skin (free) - uses existing player.png
//     _skins['default'] = SkinData(
//       id: 'default',
//       name: 'Earth Explorer',
//       description: 'The classic blue marble spaceship',
//       imagePath: 'player.png',
//       price: 0,
//       isUnlocked: true,
//     );

//     // For now, all premium skins use the same image but with different names
//     // You can replace these with actual skin images later
//     _skins['fire'] = SkinData(
//       id: 'fire',
//       name: 'Fire Phoenix',
//       description: 'A blazing red spaceship with fiery trails',
//       imagePath: 'player.png', // Fallback to default for now
//       price: 3,
//       isUnlocked: false,
//     );

//     _skins['ice'] = SkinData(
//       id: 'ice',
//       name: 'Frost Guardian',
//       description: 'A cool blue spaceship with icy crystals',
//       imagePath: 'player.png', // Fallback to default for now
//       price: 3,
//       isUnlocked: false,
//     );

//     _skins['gold'] = SkinData(
//       id: 'gold',
//       name: 'Golden Voyager',
//       description: 'A luxurious golden spaceship for elite pilots',
//       imagePath: 'player.png', // Fallback to default for now
//       price: 5,
//       isUnlocked: false,
//     );

//     _skins['rainbow'] = SkinData(
//       id: 'rainbow',
//       name: 'Rainbow Rider',
//       description: 'A colorful spaceship that shifts through all colors',
//       imagePath: 'player.png', // Fallback to default for now
//       price: 7,
//       isUnlocked: false,
//     );

//     _skins['stealth'] = SkinData(
//       id: 'stealth',
//       name: 'Shadow Stealth',
//       description: 'A dark, mysterious spaceship for ninja pilots',
//       imagePath: 'player.png', // Fallback to default for now
//       price: 4,
//       isUnlocked: false,
//     );

//     _initialized = true;
//   }

//   // Load saved data
//   Future<void> load() async {
//     if (!_initialized) {
//       _initializeSkins();
//     }
    
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       _currentSkinId = prefs.getString(_currentSkinKey) ?? 'default';
      
//       final unlockedSkinsJson = prefs.getStringList(_unlockedSkinsKey) ?? ['default'];
      
//       // Update unlocked status
//       for (final skinId in unlockedSkinsJson) {
//         if (_skins.containsKey(skinId)) {
//           _skins[skinId] = _skins[skinId]!.copyWith(isUnlocked: true);
//         }
//       }
      
//       print('SkinManager loaded successfully. Current skin: $_currentSkinId');
//     } catch (e) {
//       print('Error loading SkinManager: $e');
//       // Use defaults
//       _currentSkinId = 'default';
//     }
//   }

//   // Save data
//   Future<void> save() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString(_currentSkinKey, _currentSkinId);
      
//       final unlockedSkins = _skins.entries
//           .where((entry) => entry.value.isUnlocked)
//           .map((entry) => entry.key)
//           .toList();
      
//       await prefs.setStringList(_unlockedSkinsKey, unlockedSkins);
//       print('SkinManager saved successfully');
//     } catch (e) {
//       print('Error saving SkinManager: $e');
//     }
//   }

//   // Getters
//   String get currentSkinId => _currentSkinId;
//   SkinData get currentSkin => _skins[_currentSkinId] ?? _skins['default']!;
//   List<SkinData> get allSkins => _skins.values.toList();
  
//   // Set current skin
//   void setCurrentSkin(String skinId) {
//     if (_skins.containsKey(skinId) && _skins[skinId]!.isUnlocked) {
//       _currentSkinId = skinId;
//       save();
//       print('Current skin changed to: $skinId');
//     }
//   }

//   // Unlock a skin
//   void unlockSkin(String skinId) {
//     if (_skins.containsKey(skinId)) {
//       _skins[skinId] = _skins[skinId]!.copyWith(isUnlocked: true);
//       save();
//       print('Skin unlocked: $skinId');
//     }
//   }

//   // Check if skin is unlocked
//   bool isSkinUnlocked(String skinId) {
//     return _skins[skinId]?.isUnlocked ?? false;
//   }

//   // Get skin by ID
//   SkinData? getSkin(String skinId) {
//     return _skins[skinId];
//   }

//   // Check if initialized
//   bool get isInitialized => _initialized;
// }
