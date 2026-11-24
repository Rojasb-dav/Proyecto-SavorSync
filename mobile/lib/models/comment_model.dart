class CommentModel {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String content;
  final DateTime createdAt;

  const CommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.authorAvatarUrl,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final createdAtField = json['createdAt'] ?? json['created_at'];
    DateTime dt = DateTime.now();
    if (createdAtField is String) {
      dt = DateTime.tryParse(createdAtField) ?? DateTime.now();
    }

    return CommentModel(
      id: json['id'] as String? ?? '',
      postId: (json['postId'] ?? json['publicacion_id']) as String? ?? '',
      authorId: (json['authorId'] ?? json['cliente_id']) as String? ?? '',
      authorName: (json['authorName'] ?? json['author_username']) as String? ?? 'Usuario',
      authorAvatarUrl: (json['authorAvatarUrl'] ?? json['avatar_url']) as String?,
      content: (json['content'] ?? json['contenido']) as String? ?? '',
      createdAt: dt,
    );
  }

  Map<String, dynamic> toJson() => {
        'postId': postId,
        'authorId': authorId,
        'authorName': authorName,
        'authorAvatarUrl': authorAvatarUrl,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };
}
