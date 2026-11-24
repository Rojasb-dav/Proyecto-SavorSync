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
    try {
      final response = await _dio.post('/posts', data: data);
      return PostModel.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      return PostModel.fromJson({
        'id': 'post_${DateTime.now().millisecondsSinceEpoch}',
        'userId': data['userId'] ?? 'user_demo',
        'username': data['username'] ?? 'FoodieUser',
        'fullName': data['fullName'] ?? 'Foodie Demo',
        'restaurantName': data['restaurantName'] ?? 'Restaurante Bogotá',
        'restaurantAddress': data['restaurantAddress'] ?? 'Bogotá',
        'content': data['content'] ?? data['contenido'] ?? '',
        'rating': (data['rating'] ?? data['calificacion'] ?? 4.5).toDouble(),
        'imageUrl': data['imageUrl'] ?? 'https://images.unsplash.com/photo-1544025162-d76694265947',
        'createdAt': DateTime.now().toIso8601String(),
        'likesCount': 0,
        'commentsCount': 0,
      });
    }
  }

  Future<void> deletePost(String id) async {
    try {
      await _dio.delete('/posts/$id');
    } catch (_) {}
  }

  Future<void> toggleLikePost(String postId) async {
    try {
      await _dio.post('/posts/$postId/like');
    } catch (_) {}
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
    try {
      await _dio.post('/posts/$postId/comments', data: commentData);
    } catch (_) {}
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
    try {
      await _dio.post('/restaurants', data: data);
    } catch (_) {}
  }

  Future<void> updateRestaurantStatus(String id, String status) async {
    try {
      await _dio.put('/restaurants/$id/status', data: {'status': status, 'estado': status});
    } catch (_) {}
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
    try {
      final response = await _dio.post('/reservations', data: data);
      return ReservationModel.fromJson(Map<String, dynamic>.from(response.data));
    } catch (e) {
      return ReservationModel.fromJson({
        'id': 'res_${DateTime.now().millisecondsSinceEpoch}',
        'restaurantId': data['restaurantId'] ?? 'r1',
        'restaurantName': data['restaurantName'] ?? 'Restaurante Bogotá',
        'clienteId': data['userId'] ?? 'u1',
        'clienteNombre': data['userName'] ?? 'Foodie',
        'fechaReserva': data['date'] ?? '2025-03-30',
        'horaReserva': data['time'] ?? '20:00',
        'numPersonas': data['guests'] ?? 2,
        'estado': 'pendiente',
        'notas': data['specialNotes'] ?? '',
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> updateReservationStatus(String reservationId, String status) async {
    try {
      final cleanStatus = status.trim().toLowerCase();
      await _dio.put('/reservations/$reservationId', data: {
        'status': cleanStatus,
        'estado': cleanStatus,
      });
    } catch (_) {}
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
    try {
      await _dio.post('/pqrs', data: data);
    } catch (_) {}
  }

  Future<void> updatePQRSStatus(String id, String status) async {
    try {
      await _dio.put('/pqrs/$id', data: {'status': status, 'estado': status});
    } catch (_) {}
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
    try {
      await _dio.put('/notifications/$id/read');
    } catch (_) {}
  }
}
