import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class ModeratorProfileScreen extends StatelessWidget {
  const ModeratorProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil Institucional - Moderador de Gobierno'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera Institucional del Moderador
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.purple, width: 2),
                    ),
                    child: const Icon(Icons.shield_rounded, color: Colors.purple, size: 38),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(user?.fullName ?? 'Moderador Oficial', style: AppTextStyles.headline.copyWith(fontSize: 22)),
                            const SizedBox(width: 10),
                            const Chip(
                              label: Text('MODERADOR SMM 🛡️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                              backgroundColor: Colors.purple,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('@${user?.username ?? 'moderador'} • ${user?.email ?? ''}', style: AppTextStyles.caption),
                        const SizedBox(height: 8),
                        Text(
                          'Funcionario con permisos de supervisión, gobierno de usuarios, aprobación de locales y resolución de PQRS.',
                          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tarjetas de Métricas de Gobierno
            Text('Resumen de Gestión y Supervisión', style: AppTextStyles.title),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _metricCard('Estado del Sistema', '100% Online', Icons.cloud_done_rounded, Colors.green)),
                const SizedBox(width: 16),
                Expanded(child: _metricCard('BD Relacional', 'MySQL 8.0 Aiven', Icons.storage_rounded, Colors.blue)),
                const SizedBox(width: 16),
                Expanded(child: _metricCard('Nivel de Acceso', 'Gobierno Total', Icons.verified_user_rounded, Colors.purple)),
              ],
            ),
            const SizedBox(height: 24),

            // Acciones Directas
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Acciones de Cuenta e Identidad', style: AppTextStyles.title),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.badge_rounded, color: AppColors.primary),
                    title: const Text('Identificador de Empleado'),
                    subtitle: Text(user?.id ?? 'UUID-MODERADOR'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.security_rounded, color: AppColors.primary),
                    title: const Text('Seguridad de la Cuenta'),
                    subtitle: const Text('Autenticación mediante JWT Bearer Token HMAC-SHA256'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                    title: const Text('Cerrar Sesión', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                    onTap: () async {
                      await auth.logout();
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (_) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(value, style: AppTextStyles.title.copyWith(color: color, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
