import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/notification_service.dart';
import '../../providers/auth_provider.dart';

class PqrsManagementScreen extends StatelessWidget {
  const PqrsManagementScreen({super.key});

  void _showResponseModal(BuildContext context, String pqrsId, Map<String, dynamic> data) {
    final responseCtrl = TextEditingController(text: data['respuesta'] as String? ?? '');
    final user = context.read<AuthProvider>().user;
    final clienteId = data['clienteId'] as String? ?? '';
    final asunto = data['asunto'] as String? ?? 'tu caso';
    String selectedEstado = 'resuelta';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Container(
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
              Row(
                children: [
                  const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 26),
                  const SizedBox(width: 10),
                  Text('Atender y Responder PQRS', style: AppTextStyles.headline),
                ],
              ),
              const SizedBox(height: 14),
              Text('Estado de Cierre:', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Resuelta ✅'),
                    selected: selectedEstado == 'resuelta',
                    onSelected: (_) => setDlgState(() => selectedEstado = 'resuelta'),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text('En Gestión ⚙️'),
                    selected: selectedEstado == 'en_gestion',
                    onSelected: (_) => setDlgState(() => selectedEstado = 'en_gestion'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: responseCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Escribe la respuesta oficial al cliente...',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    label: const Text('Guardar y Notificar al Cliente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final responseText = responseCtrl.text.trim();
                      if (responseText.isEmpty) return;

                      await FirebaseFirestore.instance.collection('pqrs').doc(pqrsId).update({
                        'respuesta': responseText,
                        'estado': selectedEstado,
                        'empleadoId': user?.id,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                      if (clienteId.isNotEmpty) {
                        NotificationService.sendNotification(
                          targetUserId: clienteId,
                          title: 'Respuesta a tu PQRS 🎧',
                          body: 'Tu caso "$asunto" ha recibido respuesta oficial: "$responseText"',
                          type: 'system',
                          targetId: pqrsId,
                        );
                      }

                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Respuesta enviada y cliente notificado'), backgroundColor: Colors.green),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bandeja de Gestión PQRS')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('pqrs')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              final docs = snapshot.data?.docs ?? [];
              docs.sort((a, b) {
                final aTime = a.data()['createdAt'] as Timestamp?;
                final bTime = b.data()['createdAt'] as Timestamp?;
                if (aTime == null || bTime == null) return 0;
                return bTime.compareTo(aTime);
              });

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox_rounded, size: 64, color: AppColors.secondary),
                      const SizedBox(height: 16),
                      Text('No hay radicación de PQRS', style: AppTextStyles.headline),
                      const SizedBox(height: 6),
                      Text('Las solicitudes de los clientes aparecerán aquí.', style: AppTextStyles.subtle),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final data = doc.data();
                  final estado = data['estado'] as String? ?? 'recibida';
                  final isClosed = estado == 'resuelta' || estado == 'cerrada';

                  Color estadoColor = Colors.orange;
                  if (estado == 'en_gestion') estadoColor = Colors.blue;
                  if (estado == 'resuelta' || estado == 'cerrada') estadoColor = Colors.green;

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                data['tipo']?.toString().toUpperCase() ?? 'PQRS',
                                style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Spacer(),
                            Chip(
                              label: Text(
                                estado.toUpperCase(),
                                style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                              backgroundColor: estadoColor.withValues(alpha: 0.15),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(data['asunto'] ?? 'Sin Asunto', style: AppTextStyles.title.copyWith(fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('Cliente: ${data['clienteNombre'] ?? data['clienteEmail'] ?? 'Anónimo'} (${data['clienteEmail'] ?? ''})', style: AppTextStyles.caption),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(data['descripcion'] ?? '', style: AppTextStyles.body),
                        ),
                        if ((data['respuesta'] as String?)?.isNotEmpty == true) ...[
                          const Divider(height: 24),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Respuesta Enviada al Cliente:', style: AppTextStyles.caption.copyWith(color: Colors.green.shade900, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(data['respuesta'], style: AppTextStyles.body.copyWith(color: Colors.green.shade900)),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: isClosed ? AppColors.secondary : AppColors.primary),
                              icon: Icon(isClosed ? Icons.edit_note_rounded : Icons.reply_rounded, color: Colors.white, size: 18),
                              label: Text(isClosed ? 'Editar Respuesta' : 'Responder Caso', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              onPressed: () => _showResponseModal(context, doc.id, data),
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
        ),
      ),
    );
  }
}
