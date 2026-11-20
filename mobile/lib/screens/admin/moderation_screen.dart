import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  Future<void> _showCreateInternalModeratorDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary, size: 26),
              const SizedBox(width: 10),
              Text('Crear Moderador Interno', style: AppTextStyles.title),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre completo'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: usernameCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre de usuario'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Correo electrónico'),
                    validator: (v) => !v!.contains('@') ? 'Correo inválido' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                    validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDlgState(() => loading = true);
                      try {
                        final creds = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                          email: emailCtrl.text.trim(),
                          password: passwordCtrl.text,
                        );
                        final uid = creds.user!.uid;
                        await FirebaseFirestore.instance.collection('users').doc(uid).set({
                          'id': uid,
                          'email': emailCtrl.text.trim(),
                          'username': usernameCtrl.text.trim(),
                          'fullName': nameCtrl.text.trim(),
                          'role': 'moderador',
                          'avatarUrl': null,
                          'bio': 'Moderador Oficial de la Comunidad SavorSync',
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cuenta de moderador creada con éxito'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        setDlgState(() => loading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al crear moderador: $e')),
                        );
                      }
                    },
              child: loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Crear Moderador', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cola de Moderación de Contenidos'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => _showCreateInternalModeratorDialog(context),
              icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
              label: const Text('Crear Nuevo Moderador', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('reports')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_user_rounded, size: 64, color: Colors.green),
                      const SizedBox(height: 16),
                      Text('No hay reportes pendientes', style: AppTextStyles.headline),
                      const SizedBox(height: 6),
                      Text('Todo el contenido de la comunidad cumple con las normas.', style: AppTextStyles.subtle),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, i) {
                  final reportDoc = docs[i];
                  final data = reportDoc.data();
                  final reportId = reportDoc.id;
                  final postId = data['postId'] as String? ?? '';
                  final postContent = data['postContent'] as String? ?? 'Sin contenido';
                  final restaurantName = data['restaurantName'] as String? ?? '';
                  final reason = data['reason'] as String? ?? 'Infracción de normas';

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Motivo: $reason',
                                  style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              const Spacer(),
                              Text('Restaurante: $restaurantName', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('Contenido denunciado:', style: AppTextStyles.caption),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(postContent, style: AppTextStyles.body),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade700),
                                onPressed: () async {
                                  await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
                                    'status': 'dismissed',
                                  });
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Reporte desestimado')),
                                  );
                                },
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: const Text('Desestimar Reporte'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                onPressed: () async {
                                  if (postId.isNotEmpty) {
                                    await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
                                  }
                                  await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
                                    'status': 'deleted',
                                  });
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Publicación eliminada y reporte resuelto'), backgroundColor: Colors.red),
                                  );
                                },
                                icon: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 18),
                                label: const Text('Eliminar Publicación Definitivamente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
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
