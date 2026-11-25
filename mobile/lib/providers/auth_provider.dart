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

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  bool get loading => _loading;
  String? get sessionNotice => _sessionNotice;

  Future<void> bootstrap() async {
    if (_loading) return;
    _status = AuthStatus.unknown;
    _setLoading(true);
    try {
      _user = await _authService.restoreSession();
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
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
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
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
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
  }) async {
    if (_loading) return false;
    _setLoading(true);
    try {
      final result = await _authService.register(
        email: email,
        username: username,
        password: password,
        fullName: fullName,
      );
      _user = result.user;
      _status = AuthStatus.authenticated;
      _sessionNotice = null;
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _setLoading(bool v) {
    if (_disposed) return;
    _loading = v;
    notifyListeners();
  }
}
