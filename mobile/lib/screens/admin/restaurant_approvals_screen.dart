import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../providers/auth_provider.dart';

class RestaurantApprovalsScreen extends StatelessWidget {
  const RestaurantApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aprobación de Restaurantes'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('restaurants')
            .where('status', isEqualTo: 'pendiente')
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
                  const Icon(Icons.check_circle_outline_rounded, size: 54, color: Colors.green),
                  const SizedBox(height: 16),
                  Text('No hay solicitudes pendientes', style: AppTextStyles.headline),
                  const SizedBox(height: 6),
                  Text('Todos los restaurantes están verificados y activos.', style: AppTextStyles.subtle),
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
                        Text(data['name'] ?? 'Restaurante', style: AppTextStyles.title),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('PENDIENTE', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Categoría: ${data['category'] ?? 'Gastronomía'}', style: AppTextStyles.caption.copyWith(color: AppColors.primary)),
                    Text('Dirección: ${data['address'] ?? 'Bogotá'}', style: AppTextStyles.subtle),
                    if ((data['description'] as String?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(data['description'], style: AppTextStyles.body),
                    ],
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          onPressed: () {
                            doc.reference.update({'status': 'suspendido'});
                          },
                          child: const Text('Rechazar'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          icon: const Icon(Icons.check_rounded, color: Colors.white),
                          label: const Text('Aprobar y Activar'),
                          onPressed: () {
                            doc.reference.update({
                              'status': 'activo',
                              'aprobadoPor': user?.id ?? 'moderador',
                              'fechaAprobacion': FieldValue.serverTimestamp(),
                            });
                          },
                        ),
                      ],
                    ),
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
