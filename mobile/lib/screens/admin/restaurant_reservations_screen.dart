import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';

class RestaurantReservationsScreen extends StatelessWidget {
  final String restaurantId;
  const RestaurantReservationsScreen({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de Reservas')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('reservations')
            .where('restaurantId', isEqualTo: restaurantId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 52, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text('Aún no tienes solicitudes de reserva', style: AppTextStyles.headline),
                  const SizedBox(height: 4),
                  Text('Las solicitudes de comensales aparecerán aquí.', style: AppTextStyles.subtle),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final doc = docs[i];
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
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(data['clienteNombre'] ?? 'Cliente', style: AppTextStyles.title),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: estadoColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            estado.toUpperCase(),
                            style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold, fontSize: 11),
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
                        const SizedBox(width: 16),
                        const Icon(Icons.event_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text('${data['fechaReserva']} a las ${data['horaReserva']}', style: AppTextStyles.body),
                      ],
                    ),
                    if ((data['notas'] as String?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text('Notas: ${data['notas']}', style: AppTextStyles.subtle),
                    ],
                    if (estado == 'pendiente') ...[
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            onPressed: () {
                              doc.reference.update({'estado': 'cancelada'});
                            },
                            child: const Text('Rechazar'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: () {
                              doc.reference.update({'estado': 'confirmada'});
                            },
                            child: const Text('Confirmar Reserva'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
