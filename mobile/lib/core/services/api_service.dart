import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/comment_model.dart';
import '../../models/menu_item_model.dart';
import '../../models/notification_model.dart';
import '../../models/post_model.dart';
import '../../models/reservation_model.dart';
import '../../models/restaurant_model.dart';
import '../utils/token_storage.dart';

class ApiService {
  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'X-Platform': kIsWeb ? 'web' : 'mobile',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['X-Platform'] = kIsWeb ? 'web' : 'mobile';
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

  static const String baseUrl = 'https://proyecto-savorsync.onrender.com/api/v1';

  late final Dio _dio;
  final TokenStorage _tokenStorage = TokenStorage();

  VoidCallback? onUnauthorized;

  Dio get dio => _dio;

  // ===========================================================================
  // 1. PUBLICACIONES (POSTS)
  // ===========================================================================
  Future<List<PostModel>> getPosts() async {
    try {
      final response = await _dio.get('/posts');
      final list = response.data as List;
      return list.map((e) => PostModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<PostModel>> getUserPosts(String userId) async {
    try {
      final response = await _dio.get('/posts/user/$userId');
      final list = response.data as List;
      return list.map((e) => PostModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<PostModel> createPost(Map<String, dynamic> data) async {
    final response = await _dio.post('/posts', data: data);
    return PostModel.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<void> deletePost(String id) async {
    await _dio.delete('/posts/$id');
  }

  Future<void> toggleLikePost(String postId) async {
    await _dio.post('/posts/$postId/like');
  }

  Future<List<CommentModel>> getComments(String postId) async {
    try {
      final response = await _dio.get('/posts/$postId/comments');
      final list = response.data as List;
      return list.map((e) => CommentModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addComment(String postId, Map<String, dynamic> commentData) async {
    await _dio.post('/posts/$postId/comments', data: commentData);
  }

  // ===========================================================================
  // 2. RESTAURANTES & MENÚ
  // ===========================================================================
  Future<List<RestaurantModel>> getRestaurants() async {
    try {
      final response = await _dio.get('/restaurants');
      final list = response.data as List;
      return list.map((e) => RestaurantModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> createRestaurant(Map<String, dynamic> data) async {
    await _dio.post('/restaurants', data: data);
  }

  Future<void> updateRestaurantStatus(String id, String status) async {
    await _dio.put('/restaurants/$id/status', data: {'status': status, 'estado': status});
  }

  Future<List<MenuItemModel>> getMenu(String restaurantId) async {
    try {
      final response = await _dio.get('/restaurants/$restaurantId/menu');
      final list = response.data as List;
      return list.map((e) => MenuItemModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return [];
    }
  }

  // ===========================================================================
  // 3. RESERVAS & PQRS
  // ===========================================================================
  Future<List<ReservationModel>> getReservations({String? userId, String? restaurantId}) async {
    try {
      final response = await _dio.get('/reservations', queryParameters: {
        if (userId != null) 'userId': userId,
        if (restaurantId != null) 'restaurantId': restaurantId,
      });
      final list = response.data as List;
      return list.map((e) => ReservationModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<ReservationModel> createReservation(Map<String, dynamic> data) async {
    final response = await _dio.post('/reservations', data: data);
    return ReservationModel.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<void> updateReservationStatus(String reservationId, String status) async {
    final cleanStatus = status.trim().toLowerCase();
    await _dio.put('/reservations/$reservationId', data: {
      'status': cleanStatus,
      'estado': cleanStatus,
    });
  }

  // PQRS
  Future<List<Map<String, dynamic>>> getPQRS() async {
    try {
      final response = await _dio.get('/pqrs');
      return (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> createPQRS(Map<String, dynamic> data) async {
    await _dio.post('/pqrs', data: data);
  }

  Future<void> updatePQRSStatus(String id, String status) async {
    await _dio.put('/pqrs/$id', data: {'status': status, 'estado': status});
  }

  // NOTIFICACIONES
  Future<List<NotificationModel>> getNotifications(String userId) async {
    try {
      final response = await _dio.get('/notifications', queryParameters: {'userId': userId});
      final list = response.data as List;
      return list.map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> markNotificationRead(String id) async {
    await _dio.put('/notifications/$id/read');
  }
}
