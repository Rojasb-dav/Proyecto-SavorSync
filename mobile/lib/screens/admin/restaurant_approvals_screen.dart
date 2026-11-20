import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../providers/auth_provider.dart';

class RestaurantApprovalsScreen extends StatelessWidget {
  const RestaurantApprovalsScreen({super.key});

  void _showInspectModal(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc, String? currentUserId) {
    final data = doc.data();
    final name = data['name'] as String? ?? 'Restaurante';
    final category = data['category'] as String? ?? 'Gastronomía';
    final address = data['address'] as String? ?? 'Bogotá';
    final phone = data['phone'] as String? ?? 'No especificado';
    final hours = data['openingHours'] as String? ?? 'No especificado';
    final description = data['description'] as String? ?? 'Sin descripción';
    final imageUrl = data['imageUrl'] as String? ?? 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80';
    final lat = data['latitude'];
    final lng = data['longitude'];
    final ownerId = data['ownerId'] as String? ?? 'No disponible';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppColors.background),
                      errorWidget: (_, __, ___) => Container(color: AppColors.background, child: const Icon(Icons.broken_image)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(name, style: AppTextStyles.headline.copyWith(fontSize: 20))),
                          Chip(
                            label: const Text('PENDIENTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                            backgroundColor: Colors.orange.shade800,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _detailRow(Icons.category_rounded, 'Categoría', category),
                      _detailRow(Icons.location_on_rounded, 'Dirección', address),
                      if (lat != null && lng != null)
                        _detailRow(Icons.gps_fixed_rounded, 'Coordenadas GPS', 'Lat: $lat, Lng: $lng'),
                      _detailRow(Icons.phone_rounded, 'Teléfono', phone),
                      _detailRow(Icons.access_time_rounded, 'Horarios', hours),
                      _detailRow(Icons.badge_rounded, 'ID Propietario', ownerId),
                      const SizedBox(height: 12),
                      Text('Descripción y Concepto Culinario:', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(description, style: AppTextStyles.body),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              await doc.reference.update({'status': 'suspendido'});
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Solicitud rechazada')),
              );
            },
            child: const Text('Rechazar Solicitud'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            label: const Text('Aprobar y Activar Local', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              await doc.reference.update({
                'status': 'activo',
                'aprobadoPor': currentUserId ?? 'moderador',
                'fechaAprobacion': FieldValue.serverTimestamp(),
              });
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Restaurante aprobado y publicado en vivo para Foodies'), backgroundColor: Colors.green),
              );
            },
          ),
        ],
      ),
    );
  }

  static Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('$label: ', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: AppTextStyles.body.copyWith(fontSize: 13), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aprobación y Gobierno de Restaurantes'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('restaurants')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final allDocs = snapshot.data?.docs ?? [];

          if (allDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.storefront_rounded, size: 64, color: AppColors.secondary),
                  const SizedBox(height: 16),
                  Text('No hay restaurantes registrados', style: AppTextStyles.headline),
                  const SizedBox(height: 6),
                  Text('Los nuevos registros de restaurantes aparecerán aquí para tu aprobación.', style: AppTextStyles.subtle),
                ],
              ),
            );
          }

          // Separar pendientes de activos y suspendidos
          final pendingDocs = allDocs.where((d) {
            final st = (d.data()['status'] as String?)?.toLowerCase();
            return st == 'pendiente' || st == 'pending' || st == 'pendiente_aprobacion' || st == null || st.isEmpty;
          }).toList();

          final activeDocs = allDocs.where((d) {
            final st = (d.data()['status'] as String?)?.toLowerCase();
            return st == 'activo' || st == 'active';
          }).toList();

          final suspendedDocs = allDocs.where((d) {
            final st = (d.data()['status'] as String?)?.toLowerCase();
            return st == 'suspendido' || st == 'rechazado';
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pending_actions_rounded, color: Colors.orange, size: 24),
                    const SizedBox(width: 8),
                    Text('Solicitudes Pendientes de Aprobación (${pendingDocs.length})', style: AppTextStyles.title),
                  ],
                ),
                const SizedBox(height: 12),
                if (pendingDocs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.green),
                        const SizedBox(width: 12),
                        Text('No hay solicitudes pendientes en este momento.', style: AppTextStyles.body),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pendingDocs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final doc = pendingDocs[i];
                      final data = doc.data();

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.shade300, width: 1.5),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(data['name'] ?? 'Restaurante', style: AppTextStyles.title.copyWith(fontSize: 16)),
                                const Spacer(),
                                Chip(
                                  label: const Text('PENDIENTE DE REVISIÓN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                  backgroundColor: Colors.orange.shade800,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Categoría: ${data['category'] ?? 'Gastronomía'}', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                            Text('Dirección: ${data['address'] ?? 'Bogotá'}', style: AppTextStyles.subtle),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _showInspectModal(context, doc, user?.id),
                                  icon: const Icon(Icons.search_rounded, size: 18),
                                  label: const Text('Inspeccionar Solicitud 🔍'),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                  onPressed: () async {
                                    await doc.reference.update({'status': 'suspendido'});
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Solicitud rechazada correctamente')),
                                    );
                                  },
                                  child: const Text('Rechazar'),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  icon: const Icon(Icons.check_rounded, color: Colors.white),
                                  label: const Text('Aprobar y Activar Local', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    await doc.reference.update({
                                      'status': 'activo',
                                      'aprobadoPor': user?.id ?? 'moderador',
                                      'fechaAprobacion': FieldValue.serverTimestamp(),
                                    });
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Restaurante aprobado y publicado en vivo para Foodies'), backgroundColor: Colors.green),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 32),

                Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: Colors.green, size: 24),
                    const SizedBox(width: 8),
                    Text('Restaurantes Activos y Verificados (${activeDocs.length})', style: AppTextStyles.title),
                  ],
                ),
                const SizedBox(height: 12),
                if (activeDocs.isNotEmpty)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activeDocs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final doc = activeDocs[i];
                      final data = doc.data();

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.storefront_rounded, color: Colors.green, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['name'] ?? 'Restaurante', style: AppTextStyles.title),
                                  Text('${data['category'] ?? 'Gastronomía'} • ${data['address'] ?? 'Bogotá'}', style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showInspectModal(context, doc, user?.id),
                              icon: const Icon(Icons.search_rounded, size: 16),
                              label: const Text('Ver Ficha 🔍', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade800),
                              onPressed: () async {
                                await doc.reference.update({'status': 'pendiente'});
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Restaurante puesto en revisión')),
                                );
                              },
                              child: const Text('Marcar Pendiente', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                if (suspendedDocs.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      const Icon(Icons.block_rounded, color: Colors.red, size: 24),
                      const SizedBox(width: 8),
                      Text('Restaurantes Rechazados / Suspendidos (${suspendedDocs.length})', style: AppTextStyles.title),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: suspendedDocs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final doc = suspendedDocs[i];
                      final data = doc.data();

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cancel_rounded, color: Colors.red, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['name'] ?? 'Restaurante', style: AppTextStyles.title),
                                  Text('Estado: Rechazado / Suspendido', style: AppTextStyles.caption.copyWith(color: Colors.red)),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
                              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                              label: const Text('Revisar Nuevamente', style: TextStyle(color: Colors.white, fontSize: 12)),
                              onPressed: () async {
                                await doc.reference.update({'status': 'pendiente'});
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Restaurante retornado a cola de pendientes')),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
