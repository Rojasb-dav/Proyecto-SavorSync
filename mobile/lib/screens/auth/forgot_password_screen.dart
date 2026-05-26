import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _loading = false;
  int _step = 1; // 1: Pedir correo, 2: Pedir código y nueva clave

  Future<void> _requestEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un correo válido')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ApiService().dio.post('/api/auth/forgot-password', data: {'email': email});
      setState(() {
        _loading = false;
        _step = 2;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al procesar la solicitud')),
      );
    }
  }

  Future<void> _resetPassword() async {
    if (_codeController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El código debe ser de 6 dígitos')),
      );
      return;
    }
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La nueva contraseña debe tener al menos 6 caracteres')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ApiService().dio.post('/api/auth/reset-password', data: {
        'email': _emailController.text.trim(),
        'code': _codeController.text.trim(),
        'newPassword': _passwordController.text,
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada con éxito'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      print('DEBUG ERROR: $e'); // Esto nos dirá qué pasa en el celular
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código incorrecto o expirado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_step == 1) ...[
              Text('¿Olvidaste tu contraseña?', style: AppTextStyles.headline),
              const SizedBox(height: 12),
              Text(
                'Ingresa tu correo electrónico y te enviaremos un código de 6 dígitos para restablecerla.',
                style: AppTextStyles.subtle,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _requestEmail,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Enviar código'),
              ),
            ] else ...[
              Text('Restablecer contraseña', style: AppTextStyles.headline),
              const SizedBox(height: 12),
              Text(
                'Ingresa el código que enviamos a ${_emailController.text} y tu nueva contraseña.',
                style: AppTextStyles.subtle,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  hintText: 'Código de 6 dígitos',
                  prefixIcon: Icon(Icons.pin_rounded),
                  counterText: "",
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Nueva contraseña',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _resetPassword,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Actualizar contraseña'),
              ),
              TextButton(
                onPressed: () => setState(() => _step = 1),
                child: const Text('Volver a enviar código'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
