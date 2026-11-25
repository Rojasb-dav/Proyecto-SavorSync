import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../providers/auth_provider.dart';

import '../admin/analytics_dashboard.dart';
import '../admin/menu_management_screen.dart';
import '../admin/moderation_screen.dart';
import '../admin/moderator_profile_screen.dart';
import '../admin/pqrs_management_screen.dart';
import '../admin/restaurant_admin_dashboard.dart';
import '../admin/restaurant_approvals_screen.dart';
import '../admin/restaurant_profile_screen.dart';
import '../admin/restaurant_reservations_screen.dart';
import '../admin/user_governance_screen.dart';
import '../auth/email_verification_screen.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';

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

    final pending = auth.pendingVerification;
    if (auth.user == null && pending != null) {
      return EmailVerificationScreen(
        email: auth.pendingVerificationEmail ?? '',
        requestedRole: auth.pendingRequestedRole ?? 'foodie',
      );
    }

    final user = auth.user;
    final role = user?.role ?? 'foodie';

    // 1. Foodie o Visitante -> Renderiza la App Móvil con BottomNavigationBar
    if (user == null || role == 'foodie' || role == 'visitante') {
      return const HomeScreen();
    }

    // 2. Administrador de Restaurante -> Panel Web / Adaptativo completo (NavigationRail)
    if (role == 'restaurant_admin') {
      final pages = [
        const RestaurantAdminDashboard(),
        const MenuManagementScreen(),
        const RestaurantReservationsScreen(),
        const AnalyticsDashboard(),
        const RestaurantProfileScreen(),
      ];

      final currentIndex = _webRailIndex >= pages.length ? 0 : _webRailIndex;

      return _buildAdminWebShell(
        title: 'Panel SavorSync - Administrador de Restaurante',
        userEmail: user.email,
        railIndex: currentIndex,
        railItems: const [
          NavigationRailDestination(
            icon: Icon(Icons.storefront_rounded),
            selectedIcon: Icon(Icons.storefront_rounded, color: AppColors.primary),
            label: Text('Mi Local'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.restaurant_menu_rounded),
            selectedIcon: Icon(Icons.restaurant_menu_rounded, color: AppColors.primary),
            label: Text('Menú / Carta'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.event_seat_rounded),
            selectedIcon: Icon(Icons.event_seat_rounded, color: AppColors.primary),
            label: Text('Reservas'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.bar_chart_rounded),
            selectedIcon: Icon(Icons.bar_chart_rounded, color: AppColors.primary),
            label: Text('Analítica BI'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.store_rounded),
            selectedIcon: Icon(Icons.store_rounded, color: AppColors.primary),
            label: Text('Perfil Local'),
          ),
        ],
        bodyPages: pages,
      );
    }

    // 3. Moderador o Admin del Sistema -> Panel Web de Moderación y Gobierno
    if (role == 'moderador' || role == 'admin_sistema') {
      final pages = const [
        ModerationScreen(),
        RestaurantApprovalsScreen(),
        UserGovernanceScreen(),
        PqrsManagementScreen(),
        ModeratorProfileScreen(),
      ];

      final currentIndex = _webRailIndex >= pages.length ? 0 : _webRailIndex;

      return _buildAdminWebShell(
        title: 'Panel SavorSync - Moderación & Gobierno',
        userEmail: user.email,
        railIndex: currentIndex,
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
            icon: Icon(Icons.people_alt_rounded),
            label: Text('Gestión Usuarios'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.support_agent_rounded),
            label: Text('PQRS'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.shield_rounded),
            label: Text('Perfil Moderador'),
          ),
        ],
        bodyPages: pages,
      );
    }

    return const HomeScreen();
  }

  Widget _buildAdminWebShell({
    required String title,
    required String userEmail,
    required int railIndex,
    required List<NavigationRailDestination> railItems,
    required List<Widget> bodyPages,
  }) {
    final auth = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.restaurant_menu_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Text(title, style: AppTextStyles.title.copyWith(fontSize: 18)),
          ],
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Chip(
                avatar: const Icon(Icons.account_circle_rounded, size: 18, color: AppColors.primary),
                label: Text(userEmail, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                backgroundColor: AppColors.background,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
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
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: railIndex,
            onDestinationSelected: (int index) {
              setState(() => _webRailIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            minWidth: 90,
            selectedIconTheme: const IconThemeData(color: AppColors.primary, size: 28),
            unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary, size: 24),
            selectedLabelTextStyle: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelTextStyle: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            destinations: railItems,
          ),
          const VerticalDivider(thickness: 1, width: 1, color: AppColors.divider),
          Expanded(
            child: Container(
              color: const Color(0xFFF8F9FA),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: bodyPages[railIndex],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
