import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../core/services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _loading = false;
  bool _sent = false;
  bool _obscurePassword = true;
  int _resendWaitSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendWaitSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
      } else if (_resendWaitSeconds <= 1) {
        timer.cancel();
        setState(() => _resendWaitSeconds = 0);
      } else {
        setState(() => _resendWaitSeconds--);
      }
    });
  }

  Future<void> _sendResetCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || email.length > 191) {
      _showMessage('Ingresa un correo válido');
      return;
    }
    await _run(() async {
      await _authService.forgotPassword(email);
      if (!mounted) return;
      setState(() => _sent = true);
      _startResendTimer();
    });
  }

  Future<void> _resendResetCode() async {
    if (_resendWaitSeconds > 0) return;
    await _sendResetCode();
  }

  Future<void> _resetPassword() async {
    final code = _codeController.text;
    final password = _passwordController.text;
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      _showMessage('Ingresa el código de seis dígitos.');
      return;
    }
    if (password.length < 8 || password.length > 100 ||
        utf8.encode(password).length > 72) {
      _showMessage('Usa una contraseña de 8 a 100 caracteres dentro del límite seguro admitido.');
      return;
    }
    await _run(() async {
      await _authService.resetPassword(
        _emailController.text.trim(),
        code,
        password,
      );
      if (!mounted) return;
      _showMessage('Contraseña actualizada. Inicia sesión con tu nueva contraseña.');
      Navigator.pop(context);
    });
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.error,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_sent) ...[
                Text('¿Olvidaste tu contraseña?', style: AppTextStyles.headline),
                const SizedBox(height: 12),
                Text(
                  'Ingresa tu correo. Si existe una cuenta, recibirás un código para crear una contraseña nueva.',
                  style: AppTextStyles.subtle,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _sendResetCode,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Enviar código de recuperación'),
                ),
              ] else ...[
                const Icon(Icons.mark_email_read_rounded,
                    size: 64, color: AppColors.primary),
                const SizedBox(height: 16),
                Text('Revisa tu correo',
                    textAlign: TextAlign.center, style: AppTextStyles.headline),
                const SizedBox(height: 12),
                Text(
                  'Si el correo corresponde a una cuenta, recibirá un código de seis dígitos. El código caduca en 15 minutos.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtle,
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Código de recuperación',
                    prefixIcon: Icon(Icons.password_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _resetPassword,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Actualizar contraseña'),
                ),
                TextButton(
                  onPressed: _loading || _resendWaitSeconds > 0
                      ? null
                      : _resendResetCode,
                  child: Text(_resendWaitSeconds > 0
                      ? 'Solicitar otro código en $_resendWaitSeconds s'
                      : 'Solicitar otro código'),
                ),
                TextButton(
                  onPressed: _loading ? null : () => Navigator.pop(context),
                  child: const Text('Volver al inicio de sesión'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
