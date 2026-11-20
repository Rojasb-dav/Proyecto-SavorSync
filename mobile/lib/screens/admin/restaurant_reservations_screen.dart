import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/notification_service.dart';
import '../../providers/auth_provider.dart';

class RestaurantReservationsScreen extends StatefulWidget {
  final String? restaurantId;
  const RestaurantReservationsScreen({super.key, this.restaurantId});

  @override
  State<RestaurantReservationsScreen> createState() => _RestaurantReservationsScreenState();
}

class _RestaurantReservationsScreenState extends State<RestaurantReservationsScreen> {
  String? _loadedRestaurantId;
  bool _loadingRest = true;
  String _filterStatus = 'todas'; // 'todas', 'pendiente', 'confirmada', 'cancelada'

  @override
  void initState() {
    super.initState();
    if (widget.restaurantId != null && widget.restaurantId!.isNotEmpty) {
      _loadedRestaurantId = widget.restaurantId;
      _loadingRest = false;
    } else {
      _findOwnerRestaurant();
    }
  }

  Future<void> _findOwnerRestaurant() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      setState(() => _loadingRest = false);
      return;
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('restaurants')
          .where('ownerId', isEqualTo: user.id)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        setState(() {
          _loadedRestaurantId = query.docs.first.id;
          _loadingRest = false;
        });
      } else {
        setState(() => _loadingRest = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingRest) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_loadedRestaurantId == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event_seat_outlined, size: 64, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Text('Primero registra tu restaurante', style: AppTextStyles.title),
                const SizedBox(height: 8),
                Text(
                  'Guarda la información de tu establecimiento en la pestaña "Mi Restaurante" para recibir solicitudes de reserva.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtle,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Gestión de Reservas Recibidas', style: AppTextStyles.headline)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Solicitudes de Reserva', style: AppTextStyles.headline),
                const SizedBox(height: 4),
                Text(
                  'Confirma o rechaza reservas enviadas por comensales en tiempo real.',
                  style: AppTextStyles.subtle,
                ),
                const SizedBox(height: 16),

                // Filtro por Estado
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('todas', 'Todas'),
                      const SizedBox(width: 8),
                      _buildFilterChip('pendiente', 'Pendientes ⏳'),
                      const SizedBox(width: 8),
                      _buildFilterChip('confirmada', 'Confirmadas ✅'),
                      const SizedBox(width: 8),
                      _buildFilterChip('cancelada', 'Canceladas ❌'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('reservations')
                        .where('restaurantId', isEqualTo: _loadedRestaurantId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                      }

                      final allDocs = snapshot.data?.docs ?? [];
                      var docs = allDocs;

                      if (_filterStatus != 'todas') {
                        docs = docs.where((d) => (d.data()['estado'] ?? 'pendiente') == _filterStatus).toList();
                      }

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 54, color: AppColors.textSecondary),
                              const SizedBox(height: 12),
                              Text('No hay reservas en esta sección', style: AppTextStyles.title),
                              const SizedBox(height: 4),
                              Text('Las nuevas reservas recibidas aparecerán automáticamente.', style: AppTextStyles.subtle),
                            ],
                          ),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount = 1;
                          if (constraints.maxWidth > 900) {
                            crossAxisCount = 3;
                          } else if (constraints.maxWidth > 600) {
                            crossAxisCount = 2;
                          }

                          return GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.35,
                            ),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final data = doc.data();
                              final estado = data['estado'] as String? ?? 'pendiente';

                              Color estadoColor = Colors.orange;
                              if (estado == 'confirmada') estadoColor = Colors.green;
                              if (estado == 'cancelada') estadoColor = Colors.red;

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.divider),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            data['clienteNombre'] ?? 'Comensal',
                                            style: AppTextStyles.title.copyWith(fontSize: 16),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: estadoColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            estado.toUpperCase(),
                                            style: TextStyle(
                                              color: estadoColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.people_rounded, size: 16, color: AppColors.primary),
                                        const SizedBox(width: 6),
                                        Text('${data['numPersonas'] ?? 2} Personas', style: AppTextStyles.body),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.event_rounded, size: 16, color: AppColors.primary),
                                        const SizedBox(width: 6),
                                        Text('${data['fechaReserva']} a las ${data['horaReserva']}', style: AppTextStyles.body),
                                      ],
                                    ),
                                    if ((data['notas'] as String?)?.isNotEmpty == true) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Notas: ${data['notas']}',
                                        style: AppTextStyles.caption,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const Spacer(),
                                    if (estado == 'pendiente')
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: const BorderSide(color: Colors.red),
                                              minimumSize: const Size(90, 36),
                                            ),
                                            onPressed: () async {
                                              await doc.reference.update({'estado': 'cancelada'});
                                              final clienteId = data['clienteId'] as String? ?? '';
                                              final restName = data['restaurantName'] as String? ?? 'el restaurante';
                                              if (clienteId.isNotEmpty) {
                                                NotificationService.sendNotification(
                                                  targetUserId: clienteId,
                                                  title: 'Reserva Actualizada ❌',
                                                  body: 'Tu solicitud de reserva en $restName no pudo ser confirmada.',
                                                  type: 'reservation',
                                                  targetId: doc.id,
                                                );
                                              }
                                            },
                                            child: const Text('Rechazar'),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              minimumSize: const Size(110, 36),
                                            ),
                                            onPressed: () async {
                                              await doc.reference.update({'estado': 'confirmada'});
                                              final clienteId = data['clienteId'] as String? ?? '';
                                              final restName = data['restaurantName'] as String? ?? 'el restaurante';
                                              final fecha = data['fechaReserva'] as String? ?? '';
                                              if (clienteId.isNotEmpty) {
                                                NotificationService.sendNotification(
                                                  targetUserId: clienteId,
                                                  title: 'Reserva Confirmada 🎟️',
                                                  body: '¡Genial! Tu reserva en $restName para el $fecha fue confirmada. Revisa tu ticket QR.',
                                                  type: 'reservation',
                                                  targetId: doc.id,
                                                );
                                              }
                                            },
                                            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      )
                                    else
                                      Text(
                                        estado == 'confirmada'
                                            ? 'Reserva confirmada ✅'
                                            : 'Reserva rechazada/cancelada ❌',
                                        style: AppTextStyles.caption.copyWith(
                                          color: estadoColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSel = _filterStatus == key;
    return FilterChip(
      selected: isSel,
      label: Text(label),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSel ? AppColors.primary : AppColors.textPrimary,
        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _filterStatus = key),
    );
  }
}
