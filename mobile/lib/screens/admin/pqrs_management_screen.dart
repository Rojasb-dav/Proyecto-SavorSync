import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../providers/auth_provider.dart';

class PqrsManagementScreen extends StatelessWidget {
  const PqrsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bandeja de PQRS')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('pqrs')
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
                  const Icon(Icons.inbox_rounded, size: 52, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text('No hay radicación de PQRS', style: AppTextStyles.headline),
                  const SizedBox(height: 4),
                  Text('Los casos de clientes aparecerán aquí.', style: AppTextStyles.subtle),
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
              final estado = data['estado'] as String? ?? 'recibida';
              final isClosed = estado == 'cerrada';

              Color estadoColor = Colors.orange;
              if (estado == 'en_gestion') estadoColor = Colors.blue;
              if (estado == 'resuelta') estadoColor = Colors.green;
              if (estado == 'cerrada') estadoColor = Colors.grey;

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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            data['tipo']?.toString().toUpperCase() ?? 'PQRS',
                            style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
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
                    const SizedBox(height: 10),
                    Text(data['asunto'] ?? 'Sin Asunto', style: AppTextStyles.title),
                    const SizedBox(height: 4),
                    Text('Cliente: ${data['clienteEmail'] ?? 'Anónimo'}', style: AppTextStyles.caption),
                    const SizedBox(height: 8),
                    Text(data['descripcion'] ?? '', style: AppTextStyles.body),
                    if ((data['respuesta'] as String?)?.isNotEmpty == true) ...[
                      const Divider(height: 20),
                      Text('Respuesta del Empleado:', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(data['respuesta'], style: AppTextStyles.body.copyWith(color: Colors.green[800])),
                    ],
                    if (!isClosed) ...[
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            icon: const Icon(Icons.reply_rounded, color: Colors.white, size: 18),
                            label: const Text('Responder Caso'),
                            onPressed: () => _showResponseModal(context, doc.id, data['respuesta'] ?? ''),
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

  void _showResponseModal(BuildContext context, String pqrsId, String initialResponse) {
    final responseCtrl = TextEditingController(text: initialResponse);
    final user = context.read<AuthProvider>().user;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Responder Radicado PQRS', style: AppTextStyles.headline),
            const SizedBox(height: 12),
            TextField(
              controller: responseCtrl,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Escribe la respuesta oficial al cliente...'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    if (responseCtrl.text.trim().isEmpty) return;
                    await FirebaseFirestore.instance.collection('pqrs').doc(pqrsId).update({
                      'respuesta': responseCtrl.text.trim(),
                      'estado': 'cerrada', // Radicado cerrado
                      'empleadoId': user?.id,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                  },
                  child: const Text('Guardar y Cerrar Caso'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
