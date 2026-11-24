class UserModel {
  final String id;
  final String email;
  final String username;
  final String? fullName;
  final String? role;
  final String? avatarUrl;
  final String? bio;
  final String? phone;
  final String? restaurantId; // ID del único restaurante al que pertenece este Administrador (1:N)
  final bool isActive;
  final bool emailVerified;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final bool? isFollowing;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    this.fullName,
    this.role = 'foodie',
    this.avatarUrl,
    this.bio,
    this.phone,
    this.restaurantId,
    this.isActive = true,
    this.emailVerified = false,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    this.isFollowing,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      fullName: (json['fullName'] ?? json['full_name']) as String?,
      role: ((json['role'] ?? json['rol']) as String?)?.toLowerCase(),
      avatarUrl: (json['avatarUrl'] ?? json['avatar_url']) as String?,
      bio: json['bio'] as String?,
      phone: json['phone'] as String?,
      restaurantId: (json['restaurantId'] ?? json['restaurant_id']) as String?,
      isActive: (json['isActive'] ?? json['is_active']) as bool? ?? true,
      emailVerified: (json['emailVerified'] ?? json['email_verified']) as bool? ?? false,
      followersCount: ((json['followersCount'] ?? json['followers_count']) as num?)?.toInt() ?? 0,
      followingCount: ((json['followingCount'] ?? json['following_count']) as num?)?.toInt() ?? 0,
      postsCount: ((json['postsCount'] ?? json['posts_count']) as num?)?.toInt() ?? 0,
      isFollowing: (json['isFollowing'] ?? json['is_following']) as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'username': username,
        'fullName': fullName,
        'role': role,
        'avatarUrl': avatarUrl,
        'bio': bio,
        'phone': phone,
        'restaurantId': restaurantId,
        'isActive': isActive,
        'emailVerified': emailVerified,
        'followersCount': followersCount,
        'followingCount': followingCount,
        'postsCount': postsCount,
      };

  UserModel copyWith({
    String? fullName,
    String? username,
    String? bio,
    String? avatarUrl,
    String? phone,
    String? restaurantId,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    bool? isFollowing,
  }) {
    return UserModel(
      id: id,
      email: email,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      role: role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      phone: phone ?? this.phone,
      restaurantId: restaurantId ?? this.restaurantId,
      isActive: isActive,
      emailVerified: emailVerified,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}
