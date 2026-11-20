class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type; // 'like', 'comment', 'follow', 'reservation', 'system'
  final bool read;
  final DateTime createdAt;
  final String? targetId;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.read = false,
    required this.createdAt,
    this.targetId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    DateTime dt = DateTime.now();
    final rawCreated = json['createdAt'];
    if (rawCreated is String) {
      dt = DateTime.tryParse(rawCreated) ?? DateTime.now();
    }

    return NotificationModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String? ?? 'Notificación SavorSync',
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'system',
      read: json['read'] as bool? ?? false,
      createdAt: dt,
      targetId: json['targetId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'read': read,
        'createdAt': createdAt.toIso8601String(),
        'targetId': targetId,
      };
}
