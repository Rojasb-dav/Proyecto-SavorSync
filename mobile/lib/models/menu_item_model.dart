class MenuItemModel {
  final String id;
  final String? restaurantId;
  final String name;
  final String description;
  final double price;
  final String category;
  final String? imageUrl;
  final bool isAvailable;

  const MenuItemModel({
    required this.id,
    this.restaurantId,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.imageUrl,
    this.isAvailable = true,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      id: json['id'] ?? '',
      restaurantId: json['restaurantId'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] ?? 'Platos Fuertes',
      imageUrl: json['imageUrl'],
      isAvailable: json['isAvailable'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (restaurantId != null) 'restaurantId': restaurantId,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'isAvailable': isAvailable,
    };
  }

  MenuItemModel copyWith({
    String? id,
    String? restaurantId,
    String? name,
    String? description,
    double? price,
    String? category,
    String? imageUrl,
    bool? isAvailable,
  }) {
    return MenuItemModel(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}
