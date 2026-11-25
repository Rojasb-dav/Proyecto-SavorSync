import 'package:flutter/foundation.dart';

import '../core/services/auth_service.dart';
import '../models/user_model.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, unavailable }

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String? _error;
  bool _loading = false;
  bool _disposed = false;
  String? _sessionNotice;
  RegistrationChallenge? _pendingVerification;
  String? _pendingVerificationEmail;
  String? _pendingRequestedRole;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  bool get loading => _loading;
  String? get sessionNotice => _sessionNotice;
  RegistrationChallenge? get pendingVerification => _pendingVerification;
  String? get pendingVerificationEmail => _pendingVerificationEmail;
  String? get pendingRequestedRole => _pendingRequestedRole;

  Future<void> bootstrap() async {
    if (_loading) return;
    _status = AuthStatus.unknown;
    _setLoading(true);
    try {
      _user = await _authService.restoreSession();
      if (_user == null) {
        final pending = await _authService.restorePendingVerification();
        if (pending != null) {
          final requestedRole = pending['requestedRole'] as String?;
          _pendingVerification = RegistrationChallenge(
            challengeId: pending['challengeId'] as String,
            expiresInMs: pending['expiresInMs'] as int,
            requestedRole: requestedRole == null || requestedRole.isEmpty
                ? null
                : requestedRole,
          );
          _pendingVerificationEmail = pending['email'] as String;
          _pendingRequestedRole = requestedRole?.isNotEmpty == true
              ? requestedRole
              : 'foodie';
        }
      } else {
        await _authService.clearPendingVerification();
      }
      _status = _user == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
    } catch (_) {
      _user = null;
      _status = AuthStatus.unavailable;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login(String email, String password) async {
    if (_loading) return false;
    _setLoading(true);
    try {
      final result = await _authService.login(email, password);
      _user = result.user;
      _status = AuthStatus.authenticated;
      _sessionNotice = null;
      _error = null;
      await _authService.clearPendingVerification();
      _clearPendingVerification();
      return true;
    } catch (error) {
      _error = _message(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> loginWithGoogle() async {
    if (_loading) return false;
    _setLoading(true);
    try {
      final result = await _authService.signInWithGoogle();
      _user = result.user;
      _status = AuthStatus.authenticated;
      _sessionNotice = null;
      _error = null;
      return true;
    } catch (error) {
      _error = _message(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register({
    required String email,
    required String username,
    required String password,
    String? fullName,
    String requestedRole = 'foodie',
  }) async {
    if (_loading) return false;
    _setLoading(true);
    try {
      final challenge = await _authService.register(
        email: email,
        username: username,
        password: password,
        fullName: fullName,
        requestedRole: requestedRole,
      );
      _user = null;
      _status = AuthStatus.unauthenticated;
      _pendingVerification = challenge;
      _pendingVerificationEmail = email.trim();
      _pendingRequestedRole = requestedRole;
      _error = null;
      _sessionNotice = null;
      return true;
    } catch (error) {
      _error = _message(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resendPendingVerification() async {
    final email = _pendingVerificationEmail;
    final challenge = _pendingVerification;
    if (_loading || email == null || challenge == null) return false;
    _setLoading(true);
    try {
      final replacement = await _authService.resendVerificationCode(
        email: email,
        challengeId: challenge.challengeId,
      );
      if (replacement == null) {
        throw Exception('No fue posible renovar el desafío. Intenta registrarte nuevamente.');
      }
      _pendingVerification = replacement;
      _error = null;
      return true;
    } catch (error) {
      _error = _message(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> beginEmailVerification(String email, String password) async {
    if (_loading) return false;
    _setLoading(true);
    try {
      final challenge = await _authService.resendVerificationCode(
        email: email,
        password: password,
      );
      if (challenge == null) {
        throw Exception('No hay un desafío de verificación activo para esta cuenta.');
      }
      _pendingVerification = challenge;
      _pendingVerificationEmail = email.trim();
      _pendingRequestedRole = challenge.requestedRole ?? 'foodie';
      _error = null;
      return true;
    } catch (error) {
      _error = _message(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> abandonPendingVerification() async {
    await _authService.clearPendingVerification();
    _clearPendingVerification();
    if (!_disposed) notifyListeners();
  }

  Future<bool> verifyPendingEmail(String code) async {
    final challenge = _pendingVerification;
    if (_loading || challenge == null) return false;
    _setLoading(true);
    try {
      final result = await _authService.verifyEmail(
        challengeId: challenge.challengeId,
        code: code,
      );
      _user = result.user;
      _status = AuthStatus.authenticated;
      _error = null;
      _sessionNotice = null;
      await _authService.clearPendingVerification();
      _clearPendingVerification();
      return true;
    } catch (error) {
      _error = _message(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    if (_loading) return;
    _setLoading(true);
    try {
      final confirmed = await _authService.logout();
      _sessionNotice = confirmed
          ? null
          : 'Sesión cerrada en este dispositivo. El servidor no confirmó la revocación.';
    } catch (_) {
      _sessionNotice = 'No se pudo confirmar el cierre de sesión.';
    } finally {
      _user = null;
      _status = AuthStatus.unauthenticated;
      _setLoading(false);
    }
  }

  void forceLogout() {
    _user = null;
    _status = AuthStatus.unauthenticated;
    _sessionNotice = 'Tu sesión ya no es válida. Vuelve a iniciar sesión.';
    notifyListeners();
  }

  void updateUser(Map<String, dynamic> json) {
    if (_status != AuthStatus.authenticated) return;
    _user = UserModel.fromJson(json);
    notifyListeners();
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  void _clearPendingVerification() {
    _pendingVerification = null;
    _pendingVerificationEmail = null;
    _pendingRequestedRole = null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _setLoading(bool value) {
    if (_disposed) return;
    _loading = value;
    notifyListeners();
  }
}
