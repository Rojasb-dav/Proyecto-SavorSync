import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../shell/role_based_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  AuthProvider? _auth;
  Timer? _introTimer;
  bool _introComplete = false;
  bool _redirected = false;

  @override
  void initState() {
    super.initState();
    _introTimer = Timer(const Duration(milliseconds: 1400), () {
      _introComplete = true;
      _redirectWhenReady();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (_auth == auth) return;
    _auth?.removeListener(_redirectWhenReady);
    _auth = auth..addListener(_redirectWhenReady);
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _auth?.removeListener(_redirectWhenReady);
    super.dispose();
  }

  void _redirectWhenReady() {
    final status = _auth?.status;
    if (!_introComplete ||
        _redirected ||
        (status != AuthStatus.authenticated &&
            status != AuthStatus.unauthenticated)) {
      return;
    }
    final hasPendingVerification = _auth?.pendingVerification != null;
    _open(status == AuthStatus.authenticated || hasPendingVerification
        ? const RoleBasedShell()
        : const LoginScreen());
  }

  void _open(Widget next) {
    if (_redirected) return;
    _redirected = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.4),
                ),
                child: const Icon(Icons.restaurant_menu_rounded,
                    color: Colors.white, size: 48),
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack),
              const SizedBox(height: 24),
              Text(
                'SavorSync',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ).animate(delay: 200.ms).fadeIn(duration: 700.ms).slideY(begin: 0.2),
              const SizedBox(height: 8),
              Text(
                'Sabores de Bogotá, en tu bolsillo',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ).animate(delay: 400.ms).fadeIn(duration: 700.ms),
              if (auth.status == AuthStatus.unavailable) ...[
                const SizedBox(height: 24),
                const Text(
                  'No pudimos comprobar tu sesión. Verifica tu conexión e inténtalo de nuevo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: auth.bootstrap,
                  child: const Text('Reintentar'),
                ),
                TextButton(
                  onPressed: () => _open(const LoginScreen()),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Ir a iniciar sesión'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
