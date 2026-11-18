import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../providers/auth_provider.dart';

import '../admin/analytics_dashboard.dart';
import '../admin/moderation_screen.dart';
import '../admin/pqrs_management_screen.dart';
import '../admin/restaurant_admin_dashboard.dart';
import '../admin/restaurant_approvals_screen.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';
import '../map/restaurant_map_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';

class RoleBasedShell extends StatefulWidget {
  const RoleBasedShell({super.key});

  @override
  State<RoleBasedShell> createState() => _RoleBasedShellState();
}

class _RoleBasedShellState extends State<RoleBasedShell> {
  int _webRailIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.status == AuthStatus.unknown) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final user = auth.user;
    final role = user?.role ?? 'foodie';

    // 1. Foodie o Visitante -> Renderiza la App Móvil con BottomNavigationBar
    if (user == null || role == 'foodie' || role == 'visitante') {
      return const HomeScreen();
    }

    // 2. Administrador de Restaurante -> Panel Web / Adaptativo (NavigationRail)
    if (role == 'restaurant_admin') {
      return _buildAdminWebShell(
        title: 'Panel de Restaurante',
        railItems: const [
          NavigationRailDestination(
            icon: Icon(Icons.storefront_rounded),
            label: Text('Mi Restaurante'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.bar_chart_rounded),
            label: Text('Analítica BI'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.person_rounded),
            label: Text('Mi Perfil'),
          ),
        ],
        bodyPages: [
          const RestaurantAdminDashboard(),
          const AnalyticsDashboard(
            restaurant: null, // Carga dinámica del restaurante del admin
          ),
          const ProfileScreen(),
        ],
      );
    }

    // 3. Moderador o Admin del Sistema -> Panel Web de Moderación
    if (role == 'moderador' || role == 'admin_sistema') {
      return _buildAdminWebShell(
        title: 'Panel de Moderación Global',
        railItems: const [
          NavigationRailDestination(
            icon: Icon(Icons.gavel_rounded),
            label: Text('Reportes'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.verified_rounded),
            label: Text('Aprobar Locales'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.support_agent_rounded),
            label: Text('PQRS'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.person_rounded),
            label: Text('Mi Perfil'),
          ),
        ],
        bodyPages: const [
          ModerationScreen(),
          RestaurantApprovalsScreen(),
          PqrsManagementScreen(),
          ProfileScreen(),
        ],
      );
    }

    return const HomeScreen();
  }

  Widget _buildAdminWebShell({
    required String title,
    required List<NavigationRailDestination> railItems,
    required List<Widget> bodyPages,
  }) {
    final auth = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: AppTextStyles.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar Sesión',
            onPressed: () async {
              await auth.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _webRailIndex,
            onDestinationSelected: (int index) {
              setState(() => _webRailIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: const IconThemeData(color: AppColors.primary),
            selectedLabelTextStyle: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
            destinations: railItems,
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: bodyPages[_webRailIndex],
          ),
        ],
      ),
    );
  }
}
