import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../providers/auth_provider.dart';
import 'email_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  String _requestedRole = 'foodie';

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _showAuthAlert({
    required String title,
    required String message,
    IconData icon = Icons.info_outline_rounded,
    Color color = AppColors.primary,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: AppTextStyles.title.copyWith(fontSize: 18))),
          ],
        ),
        content: Text(
          message,
          style: AppTextStyles.body.copyWith(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      email: _emailCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
      fullName: _fullNameCtrl.text.trim(),
      requestedRole: _requestedRole,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            email: _emailCtrl.text.trim(),
            requestedRole: _requestedRole,
          ),
        ),
        (_) => false,
      );
    } else {
      _showAuthAlert(
        title: 'Aviso de Registro',
        message: auth.error ?? 'No se pudo completar el registro. Verifica los datos ingresados.',
        icon: Icons.person_add_disabled_rounded,
        color: AppColors.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Cuenta'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Únete a SavorSync', style: AppTextStyles.displayMedium)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2),
                const SizedBox(height: 6),
                Text(
                  'Descubre, comparte y gestiona la gastronomía de Bogotá.',
                  style: AppTextStyles.subtle,
                ).animate(delay: 80.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 24),

                Text(
                  'Elige tu tipo de cuenta. Las solicitudes de administración de restaurante requieren verificación del correo y aprobación del equipo.',
                  style: AppTextStyles.subtle,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _requestedRole,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de cuenta',
                    prefixIcon: Icon(Icons.manage_accounts_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'foodie', child: Text('Comensal')),
                    DropdownMenuItem(
                      value: 'restaurant_admin',
                      child: Text('Administrador de restaurante'),
                    ),
                  ],
                  onChanged: auth.loading
                      ? null
                      : (value) => setState(() {
                            if (value != null) _requestedRole = value;
                          }),
                ),
                const SizedBox(height: 16),

                _animated(
                  delay: 140,
                  child: TextFormField(
                    controller: _fullNameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Nombre completo',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty || v.trim().length > 100)
                        ? 'Ingresa un nombre de hasta 100 caracteres'
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                _animated(
                  delay: 200,
                  child: TextFormField(
                    controller: _usernameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Nombre de usuario (@ejemplo)',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().length < 3 || v.trim().length > 50)
                        ? 'Usa entre 3 y 50 caracteres'
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                _animated(
                  delay: 260,
                  child: TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (v) => (v == null ||
                            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim()) ||
                            v.trim().length > 191)
                        ? 'Correo inválido'
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                _animated(
                  delay: 320,
                  child: TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
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
                    validator: (v) {
                      if (v == null || v.length < 8 || v.length > 100) {
                        return 'Usa entre 8 y 100 caracteres';
                      }
                      if (utf8.encode(v).length > 72) {
                        return 'La contraseña excede el límite seguro admitido';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 24),
                _animated(
                  delay: 380,
                  child: ElevatedButton(
                    onPressed: auth.loading ? null : _submit,
                    child: auth.loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Text('Crear cuenta'),
                  ),
                ),
              ],
            ),
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
