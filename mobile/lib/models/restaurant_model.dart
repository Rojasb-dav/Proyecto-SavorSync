class RestaurantModel {
  final String id;
  final String name;
  final String description;
  final String address;
  final String category;
  final double latitude;
  final double longitude;
  final double ratingAverage;
  final int reviewsCount;
  final int viewsCount;
  final int favoritesCount;
  final String imageUrl;
  final String phone;
  final String ownerId;
  final List<String> adminIds;
  final String status;
  final bool isFavorite;

  const RestaurantModel({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.ratingAverage,
    required this.reviewsCount,
    this.viewsCount = 0,
    this.favoritesCount = 0,
    required this.imageUrl,
    this.phone = '',
    this.ownerId = '',
    this.adminIds = const [],
    this.status = 'pendiente',
    this.isFavorite = false,
  });

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    String st = (json['status'] as String? ?? 'pendiente').toLowerCase();
    if (st == 'pending') st = 'pendiente';
    if (st == 'active') st = 'activo';

    final rawAdmins = json['adminIds'] as List<dynamic>?;
    final List<String> admins = rawAdmins != null ? rawAdmins.map((e) => e.toString()).toList() : [];

    return RestaurantModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      category: json['category'] as String? ?? 'Gastronomía',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 4.60971,
      longitude: (json['longitude'] as num?)?.toDouble() ?? -74.08175,
      ratingAverage: (json['ratingAverage'] as num?)?.toDouble() ?? 0.0,
      reviewsCount: (json['reviewsCount'] as num?)?.toInt() ?? 0,
      viewsCount: (json['viewsCount'] as num?)?.toInt() ?? 0,
      favoritesCount: (json['favoritesCount'] as num?)?.toInt() ?? 0,
      imageUrl: json['imageUrl'] as String? ??
          'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80',
      phone: json['phone'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? '',
      adminIds: admins,
      status: st,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'address': address,
        'category': category,
        'latitude': latitude,
        'longitude': longitude,
        'ratingAverage': ratingAverage,
        'reviewsCount': reviewsCount,
        'viewsCount': viewsCount,
        'favoritesCount': favoritesCount,
        'imageUrl': imageUrl,
        'phone': phone,
        'ownerId': ownerId,
        'adminIds': adminIds,
        'status': status,
      };
}
