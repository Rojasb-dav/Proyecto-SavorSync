import 'package:dio/dio.dart';

import '../../models/user_model.dart';
import '../utils/token_storage.dart';
import 'api_service.dart';

class AuthResult {
  final String token;
  final UserModel user;
  final String tokenType;
  final int? expiresInMs;

  AuthResult({
    required this.token,
    required this.user,
    this.tokenType = 'Bearer',
    this.expiresInMs,
  });
}

class AuthService {
  AuthService({Dio? dio, TokenStorage? tokenStorage})
      : _dio = dio ?? ApiService().dio,
        _tokenStorage = tokenStorage ?? TokenStorage();

  final Dio _dio;
  final TokenStorage _tokenStorage;

  Future<AuthResult> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        options: ApiService.authRequestOptions(),
        data: {
          'email': email.trim(),
          'password': password.trim(),
        },
      );

      return await _acceptSession(response.data);
    } on DioException catch (e) {
      throw Exception(_authError(e, 'Error al iniciar sesión.'));
    } catch (_) {
      throw Exception('No se pudo iniciar sesión correctamente.');
    }
  }

  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        options: ApiService.authRequestOptions(),
        data: {
          'email': email.trim(),
          'username': username.trim(),
          'password': password.trim(),
          'fullName': fullName?.trim() ?? username.trim(),
        },
      );

      return await _acceptSession(response.data, expectedRole: 'foodie');
    } on DioException catch (e) {
      throw Exception(_authError(e, 'Error al registrar usuario.'));
    } catch (_) {
      throw Exception('No se pudo completar el registro correctamente.');
    }
  }

  Future<void> createModerator({
    required String email,
    required String username,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _dio.post('/auth/moderators', data: {
        'email': email.trim(),
        'username': username.trim(),
        'password': password.trim(),
        'fullName': fullName.trim(),
      });
      if (response.statusCode != 201 ||
          _authenticatedUser(response.data).role != 'moderador') {
        throw const FormatException('El servidor no confirmó el alta del moderador.');
      }
    } on DioException catch (e) {
      throw Exception(_authError(e, 'No se pudo crear el moderador.'));
    }
  }

  Future<void> sendVerificationCode() async {
    try {
      await _dio.post('/auth/email/verification');
    } on DioException catch (e) {
      throw Exception(_authError(e, 'No se pudo enviar el código.'));
    }
  }

  Future<Map<String, dynamic>> verifyEmail(String code) async {
    try {
      final response = await _dio.post('/auth/email/verify', data: {'code': code.trim()});
      if (!_authenticatedUser(response.data).emailVerified) {
        throw const FormatException('El servidor no confirmó la verificación.');
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw Exception(_authError(e, 'No se pudo verificar el correo.'));
    }
  }

  Future<void> requestRestaurantAdmin(String code, String description) async {
    try {
      final response = await _dio.post('/auth/restaurant-admin/request', data: {
        'code': code.trim(),
        'description': description.trim(),
      });
      final ticket = response.data;
      if (ticket is! Map<String, dynamic> || ticket['id'] is! String) {
        throw const FormatException('El servidor no confirmó la solicitud.');
      }
    } on DioException catch (e) {
      throw Exception(_authError(e, 'No se pudo registrar la solicitud.'));
    }
  }

  Future<void> approveRestaurantAdmin(String requestId) async {
    try {
      final id = Uri.encodeComponent(requestId);
      final response = await _dio.post('/auth/restaurant-admin/requests/$id/approve');
      if (_authenticatedUser(response.data).role != 'restaurant_admin') {
        throw const FormatException('El servidor no confirmó la aprobación.');
      }
    } on DioException catch (e) {
      throw Exception(_authError(e, 'No se pudo aprobar la solicitud.'));
    }
  }

  Future<AuthResult> _acceptSession(Object? data, {String? expectedRole}) async {
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respuesta de sesión inválida.');
    }

    final token = data['token'];
    final tokenType = data['tokenType'] ?? 'Bearer';
    final expiresInMs = data['expiresInMs'];
    if (token is! String ||
        token.trim().isEmpty ||
        tokenType is! String ||
        tokenType.toLowerCase() != 'bearer' ||
        expiresInMs is! int || expiresInMs <= 0) {
      throw const FormatException('Respuesta de sesión inválida.');
    }

    final user = _authenticatedUser(data['user']);
    if (expectedRole != null && user.role != expectedRole) {
      throw const FormatException('El servidor devolvió un rol inesperado.');
    }
    await _tokenStorage.saveToken(token);
    return AuthResult(
      token: token,
      user: user,
      tokenType: tokenType,
      expiresInMs: expiresInMs as int?,
    );
  }

  UserModel _authenticatedUser(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respuesta de usuario inválida.');
    }

    final user = UserModel.fromJson(data);
    if (user.id.isEmpty || user.role?.isNotEmpty != true || !user.isActive) {
      throw const FormatException('Respuesta de usuario inválida.');
    }
    return user;
  }

  String _authError(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'] ?? data['error'];
      if (message is String && message.isNotEmpty) return message;
    }
    return fallback;
  }

  Future<AuthResult> signInWithGoogle() {
    return Future.error(
      StateError('El inicio de sesión con Google está temporalmente deshabilitado.'),
    );
  }

  Future<bool> logout() async {
    final token = await _tokenStorage.getToken();
    if (token == null || token.isEmpty) {
      await _tokenStorage.clear();
      return true;
    }

    try {
      await _dio.post(
        '/auth/logout',
        options: ApiService.authRequestOptions(token),
      );
      return true;
    } on DioException catch (e) {
      return e.response?.statusCode == 401;
    } finally {
      await _tokenStorage.clearIfCurrentToken(token);
    }
  }

  Future<UserModel?> restoreSession() async {
    final token = await _tokenStorage.getToken();
    if (token == null || token.isEmpty) return null;

    try {
      final response = await _dio.get(
        '/auth/me',
        options: ApiService.authRequestOptions(token),
      );
      if (await _tokenStorage.getToken() != token) return null;
      return _authenticatedUser(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) rethrow;
      await _tokenStorage.clearIfCurrentToken(token);
      return null;
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post(
        '/auth/forgot-password',
        options: ApiService.authRequestOptions(),
        data: {'email': email.trim()},
      );
    } on DioException catch (e) {
      throw Exception(_authError(
        e,
        'Error al solicitar restablecimiento de contraseña.',
      ));
    }
  }

  Future<void> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    try {
      await _dio.post(
        '/auth/reset-password',
        options: ApiService.authRequestOptions(),
        data: {
          'email': email.trim(),
          'code': code.trim(),
          'newPassword': newPassword.trim(),
        },
      );
    } on DioException catch (e) {
      throw Exception(_authError(e, 'Error al actualizar la contraseña.'));
    }
  }
}
