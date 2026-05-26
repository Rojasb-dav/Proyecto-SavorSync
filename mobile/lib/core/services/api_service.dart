import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../utils/token_storage.dart';

class ApiService {
  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          if (e.response?.statusCode == 401) {
            await _tokenStorage.clear();
            onUnauthorized?.call();
          }
          handler.next(e);
        },
      ),
    );
  }

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  /// IMPORTANTE: cambia esta IP por la IPv4 de tu PC en la red Wi-Fi.
  /// El dispositivo físico y el PC deben estar en la MISMA red.
  /// - Emulador Android:  http://10.0.2.2:8080
  /// - iOS Simulator:     http://localhost:8080
  /// - Dispositivo real:  http://<IP_LAN_DEL_PC>:8080  (ej. 192.168.1.50)
  static const String baseUrl = 'http://192.168.2.12:8080';

  late final Dio _dio;
  final TokenStorage _tokenStorage = TokenStorage();

  /// Hook llamado cuando el backend devuelve 401 para forzar logout.
  VoidCallback? onUnauthorized;

  Dio get dio => _dio;
}
