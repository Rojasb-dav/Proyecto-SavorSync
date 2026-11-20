import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../models/notification_model.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Enviar una notificación a un usuario objetivo
  static Future<void> sendNotification({
    required String targetUserId,
    required String title,
    required String body,
    required String type, // 'like', 'comment', 'follow', 'reservation', 'system', 'menu'
    String? targetId,
  }) async {
    if (targetUserId.isEmpty) return;
    try {
      await _firestore.collection('notifications').add({
        'userId': targetUserId,
        'title': title,
        'body': body,
        'type': type,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'targetId': targetId,
      });
    } catch (e) {
      debugPrint('Error enviando notificación: $e');
    }
  }

  /// Notificación masiva para toda la comunidad Foodie
  static Future<void> sendBroadcastNotification({
    required String title,
    required String body,
    required String type,
    String? targetId,
  }) async {
    try {
      final foodiesSnap = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'foodie')
          .get();

      final batch = _firestore.batch();
      for (final userDoc in foodiesSnap.docs) {
        final notifRef = _firestore.collection('notifications').doc();
        batch.set(notifRef, {
          'userId': userDoc.id,
          'title': title,
          'body': body,
          'type': type,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'targetId': targetId,
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error en broadcast de notificación: $e');
    }
  }

  /// Stream en tiempo real de notificaciones de un usuario
  static Stream<List<NotificationModel>> streamNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        final createdAtField = data['createdAt'];
        DateTime dt = DateTime.now();
        if (createdAtField is Timestamp) {
          dt = createdAtField.toDate();
        }
        return NotificationModel.fromJson({
          'id': doc.id,
          ...data,
          'createdAt': dt.toIso8601String(),
        });
      }).toList();

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Marcar una notificación como leída
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({'read': true});
    } catch (_) {}
  }

  /// Marcar todas las notificaciones como leídas
  static Future<void> markAllAsRead(String userId) async {
    try {
      final snap = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  /// Eliminar una notificación individual
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (_) {}
  }

  /// Limpiar/Eliminar todas las notificaciones del usuario
  static Future<void> clearAllNotifications(String userId) async {
    try {
      final snap = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }

  /// Mostrar banner flotante emergente en pantalla (In-App Floating Banner Toast)
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
