import 'package:cloud_firestore/cloud_firestore.dart';

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
    final createdAtField = json['createdAt'];
    DateTime dt = DateTime.now();
    if (createdAtField is Timestamp) {
      dt = createdAtField.toDate();
    } else if (createdAtField is String) {
      dt = DateTime.tryParse(createdAtField) ?? DateTime.now();
    }

    return CommentModel(
      id: json['id'] as String? ?? '',
      postId: json['postId'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? 'Usuario',
      authorAvatarUrl: json['authorAvatarUrl'] as String?,
      content: json['content'] as String? ?? '',
      createdAt: dt,
    );
  }

  Map<String, dynamic> toJson() => {
        'postId': postId,
        'authorId': authorId,
        'authorName': authorName,
        'authorAvatarUrl': authorAvatarUrl,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
