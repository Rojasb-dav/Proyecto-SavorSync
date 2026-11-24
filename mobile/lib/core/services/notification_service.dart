import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../models/notification_model.dart';
import 'api_service.dart';

class NotificationService {
  static final ApiService _api = ApiService();

  static Future<void> sendNotification({
    required String targetUserId,
    required String title,
    required String body,
    required String type,
    String? targetId,
  }) async {
    if (targetUserId.isEmpty) return;
    try {
      await _api.dio.post('/api/notifications', data: {
        'userId': targetUserId,
        'title': title,
        'body': body,
        'type': type,
        'read': false,
        'targetId': targetId,
      });
    } catch (e) {
      debugPrint('Error enviando notificación: $e');
    }
  }

  static Future<void> sendBroadcastNotification({
    required String title,
    required String body,
    required String type,
    String? targetId,
  }) async {
    try {
      await _api.dio.post('/api/notifications/broadcast', data: {
        'title': title,
        'body': body,
        'type': type,
        'targetId': targetId,
      });
    } catch (e) {
      debugPrint('Error en broadcast de notificación: $e');
    }
  }

  static Stream<List<NotificationModel>> streamNotifications(String userId) async* {
    final list = await _api.getNotifications(userId);
    yield list;
  }

  static Future<void> markAsRead(String notificationId) async {
    await _api.markNotificationRead(notificationId);
  }

  static Future<void> markAllAsRead(String userId) async {
    try {
      await _api.dio.put('/api/notifications/user/$userId/read-all');
    } catch (_) {}
  }

  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _api.dio.delete('/api/notifications/$notificationId');
    } catch (_) {}
  }

  static Future<void> clearAllNotifications(String userId) async {
    try {
      await _api.dio.delete('/api/notifications/user/$userId');
    } catch (_) {}
  }

  static void showFloatingBanner(
    BuildContext context, {
    required String title,
    required String body,
    required String type,
  }) {
    IconData icon = Icons.notifications_active_rounded;
    Color color = AppColors.primary;
    if (type == 'like') { icon = Icons.favorite_rounded; color = AppColors.primary; }
    if (type == 'comment') { icon = Icons.mode_comment_rounded; color = Colors.blue; }
    if (type == 'follow') { icon = Icons.person_add_rounded; color = Colors.purple; }
    if (type == 'reservation') { icon = Icons.confirmation_number_rounded; color = Colors.green; }
    if (type == 'menu') { icon = Icons.restaurant_menu_rounded; color = Colors.orange; }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        elevation: 6,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppTextStyles.title.copyWith(fontSize: 14, color: AppColors.textPrimary)),
                  Text(body, style: AppTextStyles.caption.copyWith(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
