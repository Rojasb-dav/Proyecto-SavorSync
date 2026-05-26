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
  final Dio _dio = ApiService().dio;
  final TokenStorage _tokenStorage = TokenStorage();

  Future<AuthResult> login(String email, String password) async {
    final res = await _dio.post('/api/auth/login', data: {
      'email': email,
      'password': password,
    });
    return _handleAuthResponse(res.data as Map<String, dynamic>);
  }

  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
    String? fullName,
  }) async {
    final res = await _dio.post('/api/auth/register', data: {
      'email': email,
      'username': username,
      'password': password,
      if (fullName != null) 'fullName': fullName,
    });
    return _handleAuthResponse(res.data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _dio.post('/api/auth/logout');
    } catch (_) {
      // ignorar errores de red en logout
    } finally {
      await _tokenStorage.clear();
    }
  }

  Future<UserModel> fetchUserById(String id) async {
    final res = await _dio.get('/api/users/$id');
    return UserModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AuthResult> _handleAuthResponse(Map<String, dynamic> data) async {
    final token = data['token'] as String;
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _tokenStorage.saveToken(token);
    await _tokenStorage.saveUserId(user.id);
    return AuthResult(token: token, user: user);
  }
}
