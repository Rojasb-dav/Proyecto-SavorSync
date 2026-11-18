import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Moderación'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .where('status', isEqualTo: 'pending')
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
                  const Icon(Icons.verified_user_rounded, size: 54, color: Colors.green),
                  const SizedBox(height: 16),
                  Text('No hay reportes pendientes', style: AppTextStyles.headline),
                  const SizedBox(height: 6),
                  Text('Todo el contenido cumple con las políticas de la comunidad.', style: AppTextStyles.subtle),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            data['contentType']?.toString().toUpperCase() ?? 'REPORTE',
                            style: AppTextStyles.caption.copyWith(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                          tooltip: 'Aprobar/Desestimar',
                          onPressed: () {
                            doc.reference.update({'status': 'resolved'});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Motivo: ${data['reason'] ?? 'Contenido inapropiado'}', style: AppTextStyles.title),
                    const SizedBox(height: 4),
                    Text('Reportado por UID: ${data['reporterId'] ?? 'Anónimo'}', style: AppTextStyles.caption),
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
