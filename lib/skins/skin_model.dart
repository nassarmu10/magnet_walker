class Skin {
  final String id;
  final String name;
  final String description;
  final String imagePath;
  final int price; // Price in ads to watch (0 = free/default)
  final bool isUnlocked;
  final String rarity; // 'common', 'rare', 'epic', 'legendary'

  const Skin({
    required this.id,
    required this.name,
    required this.description,
    required this.imagePath,
    required this.price,
    required this.isUnlocked,
    required this.rarity,
  });

  Skin copyWith({
    String? id,
    String? name,
    String? description,
    String? imagePath,
    int? price,
    bool? isUnlocked,
    String? rarity,
  }) {
    return Skin(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      price: price ?? this.price,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      rarity: rarity ?? this.rarity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imagePath': imagePath,
      'price': price,
      'isUnlocked': isUnlocked,
      'rarity': rarity,
    };
  }

  factory Skin.fromJson(Map<String, dynamic> json) {
    return Skin(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      imagePath: json['imagePath'],
      price: json['price'],
      isUnlocked: json['isUnlocked'],
      rarity: json['rarity'],
    );
  }
}
