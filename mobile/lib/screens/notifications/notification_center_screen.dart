import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/notification_service.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  String _filter = 'todas';

  IconData _getIconForType(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite_rounded;
      case 'comment':
        return Icons.mode_comment_rounded;
      case 'follow':
        return Icons.person_add_rounded;
      case 'reservation':
        return Icons.confirmation_number_rounded;
      case 'menu':
        return Icons.restaurant_menu_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'like':
        return AppColors.primary;
      case 'comment':
        return Colors.blue;
      case 'follow':
        return Colors.purple;
      case 'reservation':
        return Colors.green;
      case 'menu':
        return Colors.orange;
      default:
        return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Centro de Notificaciones')),
        body: const Center(child: Text('Debes iniciar sesión para ver notificaciones.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de Notificaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: AppColors.primary),
            tooltip: 'Marcar todas como leídas',
            onPressed: () async {
              await NotificationService.markAllAsRead(user.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Todas las notificaciones marcadas como leídas')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
            tooltip: 'Limpiar todas las notificaciones',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Limpiar Notificaciones'),
                  content: const Text('¿Estás seguro de que deseas vaciar tu centro de notificaciones?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Limpiar Todo', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );

              if (confirm == true) {
                await NotificationService.clearAllNotifications(user.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Centro de notificaciones vaciado')),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).cardColor,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('todas', 'Todas'),
                  const SizedBox(width: 8),
                  _buildFilterChip('social', 'Social (Likes/Seguidores)'),
                  const SizedBox(width: 8),
                  _buildFilterChip('reservation', 'Reservas'),
                  const SizedBox(width: 8),
                  _buildFilterChip('menu', 'Novedades y Menús'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: StreamBuilder<List<NotificationModel>>(
              stream: NotificationService.streamNotifications(user.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                List<NotificationModel> notifications = snapshot.data ?? [];

                if (_filter == 'social') {
                  notifications = notifications.where((n) => n.type == 'like' || n.type == 'comment' || n.type == 'follow').toList();
                } else if (_filter == 'reservation') {
                  notifications = notifications.where((n) => n.type == 'reservation').toList();
                } else if (_filter == 'menu') {
                  notifications = notifications.where((n) => n.type == 'menu' || n.type == 'system').toList();
                }

                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.notifications_off_outlined, size: 64, color: AppColors.secondary),
                        const SizedBox(height: 16),
                        Text('No tienes notificaciones', style: AppTextStyles.headline),
                        const SizedBox(height: 6),
                        Text('Las interacciones de la comunidad aparecerán aquí.', style: AppTextStyles.subtle),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final n = notifications[i];
                    final color = _getColorForType(n.type);
                    final icon = _getIconForType(n.type);

                    return Dismissible(
                      key: Key(n.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) {
                        NotificationService.deleteNotification(n.id);
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: n.read ? Theme.of(context).cardColor : AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: n.read ? AppColors.divider : AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: ListTile(
                          onTap: () {
                            if (!n.read) NotificationService.markAsRead(n.id);
                          },
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.15),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  n.title,
                                  style: AppTextStyles.title.copyWith(fontSize: 14, fontWeight: n.read ? FontWeight.normal : FontWeight.bold),
                                ),
                              ),
                              if (!n.read)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(n.body, style: AppTextStyles.body.copyWith(fontSize: 13)),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                            onPressed: () {
                              NotificationService.deleteNotification(n.id);
                            },
                          ),
                        ),
                      ),
                    ).animate(delay: Duration(milliseconds: 30 * i)).fadeIn(duration: 200.ms);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.background,
      onSelected: (_) => setState(() => _filter = key),
    );
  }
}
