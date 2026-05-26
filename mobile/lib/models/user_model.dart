class UserModel {
  final String id;
  final String email;
  final String username;
  final String? fullName;
  final String? role;
  final String? avatarUrl;
  final String? bio;
  final String? phone;
  final bool isActive;
  final bool emailVerified;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final bool? isFollowing;

  const UserModel({
    required this.id,
    required this.email,
    required this.username,
    this.fullName,
    this.role,
    this.avatarUrl,
    this.bio,
    this.phone,
    this.isActive = true,
    this.emailVerified = false,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    this.isFollowing,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      fullName: json['fullName'] as String?,
      role: json['role'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      phone: json['phone'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      emailVerified: json['emailVerified'] as bool? ?? false,
      followersCount: json['followersCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
      postsCount: json['postsCount'] as int? ?? 0,
      isFollowing: json['isFollowing'] as bool?,
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
        'isActive': isActive,
        'emailVerified': emailVerified,
      };
}
