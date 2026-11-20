import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsAllowed = true;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes y Configuración'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Apariencia y Tema', style: AppTextStyles.title.copyWith(fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  secondary: const Icon(Icons.wb_sunny_rounded, color: Colors.orange),
                  title: const Text('Modo Claro (Predeterminado)'),
                  subtitle: const Text('Interfaz clara ideal para el día'),
                  value: ThemeMode.light,
                  groupValue: themeProvider.themeMode,
                  onChanged: (mode) {
                    if (mode != null) themeProvider.setThemeMode(mode);
                  },
                ),
                const Divider(height: 1),
                RadioListTile<ThemeMode>(
                  secondary: const Icon(Icons.nightlight_round, color: Colors.indigo),
                  title: const Text('Modo Oscuro (Dark Theme)'),
                  subtitle: const Text('Fondo oscuro para descansar la vista'),
                  value: ThemeMode.dark,
                  groupValue: themeProvider.themeMode,
                  onChanged: (mode) {
                    if (mode != null) themeProvider.setThemeMode(mode);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          Text('Permisos y Notificaciones', style: AppTextStyles.title.copyWith(fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
                  title: const Text('Notificaciones en Tiempo Real'),
                  subtitle: const Text('Alertas para Likes, Comentarios, Reservas y PQRS'),
                  value: _notificationsAllowed,
                  onChanged: (val) {
                    setState(() => _notificationsAllowed = val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(val ? 'Notificaciones activadas 🔔' : 'Notificaciones pausadas 🔕')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.gps_fixed_rounded, color: Colors.blue),
                  title: const Text('Permisos de Ubicación GPS'),
                  subtitle: const Text('Para calcular distancia real a restaurantes en Bogotá'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final perm = await Geolocator.requestPermission();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Permiso de GPS: ${perm.name}')),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          Text('Cuenta y Sesión', style: AppTextStyles.title.copyWith(fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              subtitle: const Text('Salir de tu cuenta en este dispositivo'),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.red),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Cerrar Sesión'),
                    content: const Text('¿Estás seguro de que deseas salir de tu cuenta en SavorSync?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  final auth = context.read<AuthProvider>();
                  await auth.logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
