class PostModel {
  final String id;
  final String userId;
  final String username;
  final String fullName;
  final String? userAvatarUrl;
  final String? restaurantId;
  final String restaurantName;
  final String restaurantAddress;
  final String content;
  final double rating;
  final String imageUrl;
  final int likesCount;
  final int commentsCount;
  final bool likedByMe;
  final bool savedByMe;
  final DateTime createdAt;

  PostModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.fullName,
    this.restaurantId,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.content,
    required this.rating,
    required this.imageUrl,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
    this.userAvatarUrl,
    this.likedByMe = false,
    this.savedByMe = false,
  });

  PostModel copyWith({
    int? likesCount,
    bool? likedByMe,
    bool? savedByMe,
  }) {
    return PostModel(
      id: id,
      userId: userId,
      username: username,
      fullName: fullName,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      restaurantAddress: restaurantAddress,
      content: content,
      rating: rating,
      imageUrl: imageUrl,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount,
      createdAt: createdAt,
      userAvatarUrl: userAvatarUrl,
      likedByMe: likedByMe ?? this.likedByMe,
      savedByMe: savedByMe ?? this.savedByMe,
    );
  }

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: (json['id'] as String?) ?? '',
      userId: (json['userId'] ?? json['cliente_id']) as String? ?? '',
      username: (json['username'] ?? json['author_username']) as String? ?? '',
      fullName: (json['fullName'] ?? json['full_name']) as String? ?? '',
      userAvatarUrl: (json['userAvatarUrl'] ?? json['avatar_url']) as String?,
      restaurantId: (json['restaurantId'] ?? json['restaurante_id']) as String?,
      restaurantName: (json['restaurantName'] ?? json['restaurante_nombre']) as String? ?? '',
      restaurantAddress: (json['restaurantAddress'] ?? json['direccion']) as String? ?? '',
      content: (json['content'] ?? json['contenido']) as String? ?? '',
      rating: ((json['rating'] ?? json['calificacion']) as num?)?.toDouble() ?? 0.0,
      imageUrl: (json['imageUrl'] ?? json['image_url']) as String? ?? '',
      likesCount: ((json['likesCount'] ?? json['conteo_likes']) as num?)?.toInt() ?? 0,
      commentsCount: ((json['commentsCount'] ?? json['conteo_comentarios']) as num?)?.toInt() ?? 0,
      likedByMe: (json['likedByMe'] ?? json['liked_by_me']) as bool? ?? false,
      savedByMe: (json['savedByMe'] ?? json['saved_by_me']) as bool? ?? false,
      createdAt: DateTime.tryParse((json['createdAt'] ?? json['created_at']) as String? ?? '') ?? DateTime.now(),
    );
  }
}
