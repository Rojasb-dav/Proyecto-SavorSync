import 'package:dio/dio.dart';

import '../../models/user_model.dart';
import '../utils/token_storage.dart';
import 'api_service.dart';

class AuthResult {
  final String token;
  final UserModel user;
  AuthResult({required this.token, required this.user});
}

class AuthService {
  final ApiService _apiService = ApiService();
  final TokenStorage _tokenStorage = TokenStorage();

  Future<AuthResult> login(String email, String password) async {
    try {
      final response = await _apiService.dio.post(
        '/api/auth/login',
        data: {
          'email': email.trim(),
          'password': password.trim(),
        },
      );

      final data = response.data;
      final String token = data['token'] ?? '';
      final Map<String, dynamic> userMap = Map<String, dynamic>.from(data['user'] ?? {});
      final user = UserModel.fromJson(userMap);

      await _tokenStorage.saveToken(token);
      await _tokenStorage.saveUserId(user.id);

      return AuthResult(token: token, user: user);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.response?.data?['error'] ?? 'Error al iniciar sesión.';
      throw Exception(msg);
    } catch (e) {
      throw Exception('Error al iniciar sesión: $e');
    }
  }

  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
    String? fullName,
    String role = 'foodie',
  }) async {
    try {
      final response = await _apiService.dio.post(
        '/api/auth/register',
        data: {
          'email': email.trim(),
          'username': username.trim(),
          'password': password.trim(),
          'fullName': fullName?.trim() ?? username.trim(),
          'role': role.trim().toLowerCase(),
        },
      );

      final data = response.data;
      final String token = data['token'] ?? '';
      final Map<String, dynamic> userMap = Map<String, dynamic>.from(data['user'] ?? {});
      final user = UserModel.fromJson(userMap);

      await _tokenStorage.saveToken(token);
      await _tokenStorage.saveUserId(user.id);

      return AuthResult(token: token, user: user);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.response?.data?['error'] ?? 'Error al registrar usuario.';
      throw Exception(msg);
    } catch (e) {
      throw Exception('Error al registrar usuario: $e');
    }
  }

  Future<AuthResult> signInWithGoogle() async {
    final mockEmail = 'foodie.google@savorsync.com';
    final mockUser = UserModel(
      id: 'google_user_101',
      email: mockEmail,
      username: 'foodie_google',
      fullName: 'Foodie Google User',
      role: 'foodie',
      bio: 'Foodie con Google Sign-In en Bogotá',
    );
    const mockToken = 'mock_jwt_token_google_101';

    await _tokenStorage.saveToken(mockToken);
    await _tokenStorage.saveUserId(mockUser.id);

    return AuthResult(token: mockToken, user: mockUser);
  }

  Future<void> logout() async {
    try {
      await _apiService.dio.post('/api/auth/logout');
    } catch (_) {}
    await _tokenStorage.clear();
  }

  Future<UserModel> fetchUserById(String id) async {
    try {
      final response = await _apiService.dio.get('/api/users/$id');
      final data = Map<String, dynamic>.from(response.data);
      return UserModel.fromJson(data);
    } catch (e) {
      return UserModel(
        id: id,
        email: 'usuario@savorsync.com',
        username: 'foodie_user',
        fullName: 'Usuario SavorSync',
        role: 'foodie',
      );
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _apiService.dio.post(
        '/api/auth/forgot-password',
        data: {'email': email.trim()},
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Error al solicitar restablecimiento de contraseña.';
      throw Exception(msg);
    }
  }

  Future<void> resetPassword(String email, String code, String newPassword) async {
    try {
      await _apiService.dio.post(
        '/api/auth/reset-password',
        data: {
          'email': email.trim(),
          'code': code.trim(),
          'newPassword': newPassword.trim(),
        },
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Error al actualizar la contraseña.';
      throw Exception(msg);
    }
  }
}
