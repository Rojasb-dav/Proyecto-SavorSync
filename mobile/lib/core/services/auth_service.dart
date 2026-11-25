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

class RegistrationChallenge {
  final String challengeId;
  final int expiresInMs;
  final String? requestedRole;

  const RegistrationChallenge({
    required this.challengeId,
    required this.expiresInMs,
    this.requestedRole,
  });

  factory RegistrationChallenge.fromJson(Map<String, dynamic> json) {
    final id = json['challengeId'];
    final expiry = json['expiresInMs'];
    if (id is! String || id.isEmpty || expiry is! num || expiry <= 0) {
      throw const FormatException('El servidor no confirmó el envío del código.');
    }
    return RegistrationChallenge(
      challengeId: id,
      expiresInMs: expiry.toInt(),
      requestedRole: json['requestedRole'] as String?,
    );
  }
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
        data: {'email': email.trim(), 'password': password},
      );
      return await _acceptSession(response.data);
    } on DioException catch (error) {
      throw Exception(_authError(error, 'Error al iniciar sesión.'));
    } on FormatException {
      rethrow;
    } catch (_) {
      throw Exception('No se pudo iniciar sesión correctamente.');
    }
  }

  Future<RegistrationChallenge> register({
    required String email,
    required String username,
    required String password,
    String? fullName,
    String requestedRole = 'foodie',
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        options: ApiService.authRequestOptions(),
        data: {
          'email': email.trim(),
          'username': username.trim(),
          'password': password,
          'fullName': fullName?.trim() ?? username.trim(),
          'role': requestedRole,
        },
      );
      final challenge = RegistrationChallenge.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      await _savePendingVerification(email.trim(), challenge);
      return challenge;
    } on DioException catch (error) {
      throw Exception(_authError(error, 'Error al registrar usuario.'));
    } on FormatException {
      rethrow;
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
        'password': password,
        'fullName': fullName.trim(),
      });
      if (response.statusCode != 201 ||
          _authenticatedUser(response.data, requireVerified: false).role != 'moderador') {
        throw const FormatException('El servidor no confirmó el alta del moderador.');
      }
    } on DioException catch (error) {
      throw Exception(_authError(error, 'No se pudo crear el moderador.'));
    }
  }

  Future<RegistrationChallenge?> resendVerificationCode({
    required String email,
    String? challengeId,
    String? password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/email/verification',
        options: ApiService.authRequestOptions(),
        data: {
          'email': email.trim(),
          if (challengeId != null) 'challengeId': challengeId,
          if (password != null) 'password': password,
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['challengeId'] == null) return null;
      final challenge = RegistrationChallenge.fromJson(data);
      await _savePendingVerification(email.trim(), challenge);
      return challenge;
    } on DioException catch (error) {
      throw Exception(_authError(error, 'No se pudo enviar el código.'));
    } on FormatException {
      rethrow;
    }
  }

  Future<AuthResult> verifyEmail({
    required String challengeId,
    required String code,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/email/verify',
        options: ApiService.authRequestOptions(),
        data: {'challengeId': challengeId, 'code': code},
      );
      final result = await _acceptSession(response.data);
      if (!result.user.emailVerified) {
        await _tokenStorage.clearIfCurrentToken(result.token);
        throw const FormatException('El servidor no confirmó la verificación.');
      }
      await _tokenStorage.clearPendingVerification();
      return result;
    } on DioException catch (error) {
      throw Exception(_authError(error, 'No se pudo verificar el correo.'));
    } on FormatException {
      rethrow;
    } catch (_) {
      throw Exception('No se pudo verificar el correo.');
    }
  }

  Future<Map<String, Object>?> restorePendingVerification() =>
      _tokenStorage.getPendingVerification();

  Future<void> clearPendingVerification() =>
      _tokenStorage.clearPendingVerification();

  Future<void> _savePendingVerification(
    String email,
    RegistrationChallenge challenge,
  ) => _tokenStorage.savePendingVerification(
        email: email,
        challengeId: challenge.challengeId,
        expiresInMs: challenge.expiresInMs,
        requestedRole: challenge.requestedRole,
      );

  Future<void> requestRestaurantAdmin(String description) async {
    try {
      final response = await _dio.post('/auth/restaurant-admin/request', data: {
        'description': description.trim(),
      });
      final ticket = response.data;
      if (ticket is! Map || ticket['id'] is! String) {
        throw const FormatException('El servidor no confirmó la solicitud.');
      }
    } on DioException catch (error) {
      throw Exception(_authError(error, 'No se pudo registrar la solicitud.'));
    }
  }

  Future<void> approveRestaurantAdmin(String requestId) async {
    try {
      final id = Uri.encodeComponent(requestId);
      final response = await _dio.post('/auth/restaurant-admin/requests/$id/approve');
      if (_authenticatedUser(response.data).role != 'restaurant_admin') {
        throw const FormatException('El servidor no confirmó la aprobación.');
      }
    } on DioException catch (error) {
      throw Exception(_authError(error, 'No se pudo aprobar la solicitud.'));
    }
  }

  Future<AuthResult> _acceptSession(Object? data) async {
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respuesta de sesión inválida.');
    }

    final token = data['token'];
    final tokenType = data['tokenType'];
    final expiresInMs = data['expiresInMs'];
    if (token is! String ||
        token.isEmpty ||
        tokenType is! String ||
        tokenType.toLowerCase() != 'bearer' ||
        expiresInMs is! num ||
        expiresInMs <= 0) {
      throw const FormatException('Respuesta de sesión inválida.');
    }

    final user = _authenticatedUser(data['user']);
    await _tokenStorage.saveToken(token);
    return AuthResult(
      token: token,
      user: user,
      tokenType: tokenType,
      expiresInMs: expiresInMs.toInt(),
    );
  }

  UserModel _authenticatedUser(
    Object? data, {
    bool requireVerified = true,
  }) {
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respuesta de usuario inválida.');
    }
    final user = UserModel.fromJson(data);
    if (user.id.isEmpty ||
        user.role?.isNotEmpty != true ||
        !user.isActive ||
        (requireVerified && !user.emailVerified)) {
      throw const FormatException('Respuesta de usuario inválida.');
    }
    return user;
  }

  String _authError(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map) {
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
    } on DioException catch (error) {
      return error.response?.statusCode == 401;
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
      return _authenticatedUser(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) rethrow;
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
    } on DioException catch (error) {
      throw Exception(_authError(
        error,
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
          'code': code,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (error) {
      throw Exception(_authError(error, 'Error al actualizar la contraseña.'));
    }
  }
}
