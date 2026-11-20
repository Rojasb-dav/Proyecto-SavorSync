import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../providers/auth_provider.dart';
import '../shell/role_based_shell.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  String _activeTab = 'foodie'; // 'foodie' | 'admin'

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RoleBasedShell()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(auth.error ?? 'No se pudo iniciar sesión'),
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final auth = context.read<AuthProvider>();
    try {
      final ok = await auth.loginWithGoogle();
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RoleBasedShell()),
        );
      } else {
        if (auth.error != null && auth.error!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(auth.error!),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Error al conectar con Google: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Bienvenido de nuevo', style: AppTextStyles.displayMedium)
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.2),
                      const SizedBox(height: 6),
                      Text(
                        'Selecciona tu perfil de acceso a la plataforma SavorSync.',
                        style: AppTextStyles.subtle,
                      ).animate(delay: 80.ms).fadeIn(duration: 400.ms),
                      const SizedBox(height: 20),

                      // Selector de Pestaña de Acceso (Foodie vs Admin)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _activeTab = 'foodie'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _activeTab == 'foodie' ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '🥑 Foodie / Comensal',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _activeTab == 'foodie' ? Colors.white : AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _activeTab = 'admin'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _activeTab == 'admin' ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '🏪 Admin / Moderador',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _activeTab == 'admin' ? Colors.white : AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      _animated(
                        delay: 160,
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: _activeTab == 'foodie' ? 'Correo electrónico' : 'Correo institucional / admin',
                            prefixIcon: const Icon(Icons.alternate_email_rounded),
                          ),
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Correo inválido'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _animated(
                        delay: 240,
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'Mínimo 6 caracteres'
                              : null,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          child: Text(
                            '¿Olvidaste tu contraseña?',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _animated(
                        delay: 320,
                        child: _PressableScale(
                          onTap: auth.loading ? null : _submit,
                          child: ElevatedButton(
                            onPressed: auth.loading ? null : _submit,
                            child: auth.loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.4, color: Colors.white),
                                  )
                                : Text(_activeTab == 'foodie' ? 'Iniciar Sesión como Foodie' : 'Ingresar al Panel de Gestión'),
                          ),
                        ),
                      ),

                      // Botón de Google Sign-In (SÓLO PARA FOODIES)
                      if (_activeTab == 'foodie') ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('o ingresa con', style: AppTextStyles.caption),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _animated(
                          delay: 360,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              side: const BorderSide(color: AppColors.divider),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: auth.loading ? null : _handleGoogleSignIn,
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.g_mobiledata_rounded, color: Colors.red, size: 24),
                            ),
                            label: const Text(
                              'Continuar con Google (Solo Foodies)',
                              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      _animated(
                        delay: 400,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('¿No tienes cuenta?', style: AppTextStyles.subtle),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'Regístrate',
                                style: AppTextStyles.button.copyWith(
                                  fontSize: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _animated({required int delay, required Widget child}) {
    return child
        .animate(delay: Duration(milliseconds: delay))
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.25, curve: Curves.easeOutCubic);
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 240,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFB37A), AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.background.withValues(alpha: 0.0),
                  AppColors.background,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          left: 24,
          top: 24,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.restaurant_menu_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'SavorSync',
                style: AppTextStyles.title.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _PressableScale({required this.child, this.onTap});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapCancel: () => setState(() => _scale = 1),
      onTapUp: (_) => setState(() => _scale = 1),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
