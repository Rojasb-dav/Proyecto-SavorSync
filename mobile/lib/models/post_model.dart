class PostModel {
  final String id;
  final String userId;
  final String username;
  final String fullName;
  final String? userAvatarUrl;
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
      id: json['id'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String,
      fullName: json['fullName'] as String? ?? '',
      userAvatarUrl: json['userAvatarUrl'] as String?,
      restaurantName: json['restaurantName'] as String? ?? '',
      restaurantAddress: json['restaurantAddress'] as String? ?? '',
      content: json['content'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      imageUrl: json['imageUrl'] as String? ?? '',
      likesCount: json['likesCount'] as int? ?? 0,
      commentsCount: json['commentsCount'] as int? ?? 0,
      likedByMe: json['likedByMe'] as bool? ?? false,
      savedByMe: json['savedByMe'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
