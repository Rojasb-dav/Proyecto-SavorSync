import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/text_styles.dart';
import '../../providers/auth_provider.dart';
import '../shell/role_based_shell.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.requestedRole,
  });

  final String email;
  final String requestedRole;

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _codeController = TextEditingController();
  Timer? _timer;
  int _resendWaitSeconds = 60;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
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

  Future<void> _verify() async {
    final code = _codeController.text;
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      _showMessage('Ingresa el código de seis dígitos.');
      return;
    }
    final auth = context.read<AuthProvider>();
    final verified = await auth.verifyPendingEmail(code);
    if (!mounted) return;
    if (!verified) {
      _showMessage(auth.error ?? 'No se pudo verificar el correo.');
      return;
    }
    if (widget.requestedRole == 'restaurant_admin') {
      _showMessage('Correo verificado. Tu cuenta seguirá como comensal hasta que se apruebe tu solicitud de restaurante.');
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleBasedShell()),
      (_) => false,
    );
  }

  Future<void> _resend() async {
    if (_resendWaitSeconds > 0) return;
    final auth = context.read<AuthProvider>();
    final sent = await auth.resendPendingVerification();
    if (!mounted) return;
    if (!sent) {
      _showMessage(auth.error ?? 'No se pudo reenviar el código.');
      return;
    }
    _codeController.clear();
    _startResendTimer();
    _showMessage('Si la cuenta requiere verificación, se envió un nuevo código.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Verificar correo')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.mark_email_unread_outlined,
                      size: 64, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text('Confirma tu correo', style: AppTextStyles.headline,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'Escribimos a ${widget.email}. Ingresa el código de seis dígitos. Caduca en 15 minutos.',
                    style: AppTextStyles.subtle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Código de verificación',
                      prefixIcon: Icon(Icons.password_rounded),
                    ),
                    onSubmitted: (_) => _verify(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: auth.loading ? null : _verify,
                    child: auth.loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Verificar y continuar'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: auth.loading || _resendWaitSeconds > 0 ? null : _resend,
                    child: Text(_resendWaitSeconds > 0
                        ? 'Reenviar en $_resendWaitSeconds s'
                        : 'Reenviar código'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
