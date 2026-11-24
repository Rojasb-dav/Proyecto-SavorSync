import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../providers/auth_provider.dart';
import '../shell/role_based_shell.dart';

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
  String _selectedRole = 'foodie';
  bool _obscure = true;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      email: _emailCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
      fullName: _fullNameCtrl.text.trim(),
      role: _selectedRole,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleBasedShell()),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(auth.error ?? 'No se pudo completar el registro'),
        ),
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

                // Selector de Rol de Usuario (SÓLO PERFILES PÚBLICOS)
                Text('Tipo de Perfil / Rol *', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                _animated(
                  delay: 100,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedRole,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'foodie',
                            child: Row(
                              children: [
                                Icon(Icons.restaurant_rounded, color: AppColors.primary, size: 20),
                                SizedBox(width: 10),
                                Text('Foodie / Comensal 🥑'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'restaurant_admin',
                            child: Row(
                              children: [
                                Icon(Icons.storefront_rounded, color: Colors.orange, size: 20),
                                SizedBox(width: 10),
                                Text('Administrador de Restaurante 🏪'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedRole = val);
                        },
                      ),
                    ),
                  ),
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
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa tu nombre'
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
                    validator: (v) => (v == null || v.trim().length < 3)
                        ? 'Mínimo 3 caracteres'
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
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Correo inválido' : null,
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
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
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
