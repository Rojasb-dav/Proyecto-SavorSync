import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/services/auth_service.dart';
import '../core/utils/token_storage.dart';
import '../models/user_model.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final TokenStorage _tokenStorage = TokenStorage();

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String? _error;
  bool _loading = false;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  bool get loading => _loading;

  Future<void> bootstrap() async {
    final token = await _tokenStorage.getToken();
    final userId = await _tokenStorage.getUserId();
    if (token == null || userId == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      _user = await _authService.fetchUserById(userId);
      _status = AuthStatus.authenticated;
    } catch (_) {
      await _tokenStorage.clear();
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      final result = await _authService.login(email, password);
      _user = result.user;
      _status = AuthStatus.authenticated;
      _error = null;
      return true;
    } on DioException catch (e) {
      _error = _extractError(e);
      return false;
    } catch (e) {
      _error = 'Error inesperado: $e';
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
      _error = null;
      return true;
    } on DioException catch (e) {
      _error = _extractError(e);
      return false;
    } catch (e) {
      _error = 'Error inesperado: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void forceLogout() {
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'No se pudo conectar al servidor. Verifica tu red.';
    }
    return e.message ?? 'Error de autenticación';
  }
}
