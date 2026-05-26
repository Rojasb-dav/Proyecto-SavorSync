import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _redirectWhenReady();
  }

  Future<void> _redirectWhenReady() async {
    // Espera mínima para que se vea la animación.
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    while (auth.status == AuthStatus.unknown) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
    }
    if (!mounted) return;
    final next = auth.status == AuthStatus.authenticated
        ? const HomeScreen()
        : const LoginScreen();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
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
          ],
        ),
      ),
    );
  }
}
