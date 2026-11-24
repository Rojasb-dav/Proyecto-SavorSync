import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

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
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
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

  static const String baseUrl = 'http://localhost:8080/api/v1';

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
      return _getSeedPosts();
    }
  }

  Future<List<PostModel>> getUserPosts(String userId) async {
    try {
      final response = await _dio.get('/posts/user/$userId');
      final list = response.data as List;
      return list.map((e) => PostModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return _getSeedPosts().where((p) => p.userId == userId || userId == 'demo').toList();
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
      return [
        CommentModel(
          id: 'c1',
          postId: postId,
          authorId: 'u1',
          authorName: 'bogota_foodie',
          content: '¡Excelente recomendación en Bogotá!',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        )
      ];
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
      return _getSeedRestaurants();
    }
  }

  Future<void> createRestaurant(Map<String, dynamic> data) async {
    try {
      await _dio.post('/restaurants', data: data);
    } catch (_) {}
  }

  Future<void> updateRestaurantStatus(String id, String status) async {
    try {
      await _dio.put('/restaurants/$id/status', data: {'status': status});
    } catch (_) {}
  }

  Future<List<MenuItemModel>> getMenu(String restaurantId) async {
    try {
      final response = await _dio.get('/restaurants/$restaurantId/menu');
      final list = response.data as List;
      return list.map((e) => MenuItemModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return [
        MenuItemModel(
          id: 'm1',
          name: 'Plato Insignia SavorSync',
          description: 'Especialidad gourmet de la casa',
          category: 'Principales',
          price: 38000,
          isAvailable: true,
        ),
        MenuItemModel(
          id: 'm2',
          name: 'Jugo Natural de Lulo',
          description: 'Bebida artesanal fresca',
          category: 'Bebidas',
          price: 9000,
          isAvailable: true,
        ),
      ];
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
      return [
        ReservationModel(
          id: 'res_1001',
          restaurantId: restaurantId ?? 'rest_1',
          restaurantName: 'Andrés Carne de Res',
          clienteId: userId ?? 'user_1',
          clienteNombre: 'Foodie Cliente',
          fechaReserva: DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1))),
          horaReserva: '19:30',
          numPersonas: 4,
          estado: 'confirmada',
          notas: 'Mesa cerca a la ventana',
          createdAt: DateTime.now(),
        ),
      ];
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
      await _dio.put('/reservations/$reservationId', data: {'status': status});
    } catch (_) {}
  }

  // PQRS
  Future<List<Map<String, dynamic>>> getPQRS() async {
    try {
      final response = await _dio.get('/pqrs');
      return (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [
        {
          'id': 'pqrs_1',
          'type': 'Petición',
          'subject': 'Solicitud de nueva mesa',
          'description': 'Me gustaría reservar una mesa grande para 12 personas.',
          'status': 'En revisión',
          'createdAt': DateTime.now().toIso8601String(),
        }
      ];
    }
  }

  Future<void> createPQRS(Map<String, dynamic> data) async {
    try {
      await _dio.post('/pqrs', data: data);
    } catch (_) {}
  }

  Future<void> updatePQRSStatus(String id, String status) async {
    try {
      await _dio.put('/pqrs/$id', data: {'status': status});
    } catch (_) {}
  }

  // NOTIFICACIONES
  Future<List<NotificationModel>> getNotifications(String userId) async {
    try {
      final response = await _dio.get('/notifications', queryParameters: {'userId': userId});
      final list = response.data as List;
      return list.map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return [
        NotificationModel(
          id: 'n1',
          userId: userId,
          title: '¡Bienvenido a SavorSync!',
          body: 'Explora los mejores restaurantes y experiencias gastronómicas de Bogotá.',
          type: 'system',
          read: false,
          createdAt: DateTime.now(),
        )
      ];
    }
  }

  Future<void> markNotificationRead(String id) async {
    try {
      await _dio.put('/notifications/$id/read');
    } catch (_) {}
  }

  // SEED DATA LOCAL DE RESPALDO
  List<PostModel> _getSeedPosts() {
    return [
      PostModel(
        id: 'post_101',
        userId: 'u_andres',
        username: 'andres_foodie',
        fullName: 'Andrés Rodríguez',
        restaurantName: 'Andrés Carne de Res',
        restaurantAddress: 'Calle 82 # 12-21, Zona T',
        content: '¡Increíble ambiente y los mejores cortes de carne en la Zona T de Bogotá! 100% recomendado.',
        rating: 4.9,
        imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&q=80',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        likesCount: 24,
        commentsCount: 5,
      ),
      PostModel(
        id: 'post_102',
        userId: 'u_maria',
        username: 'maria_gourmet',
        fullName: 'María Paula Gómez',
        restaurantName: 'Crepes & Waffles',
        restaurantAddress: 'Carrera 11 # 85-09',
        content: 'Un crepe de pollo al curry delicioso acompañado de helado artesanal. ¡Clásico imperdible!',
        rating: 4.8,
        imageUrl: 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=800&q=80',
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
        likesCount: 18,
        commentsCount: 2,
      ),
    ];
  }

  List<RestaurantModel> _getSeedRestaurants() {
    return [
      const RestaurantModel(
        id: 'rest_1',
        name: 'Andrés Carne de Res',
        description: 'Icónico restaurante colombiano con música, parrilla y ambiente festivo.',
        address: 'Calle 82 # 12-21, Zona T',
        category: 'Parrilla',
        latitude: 4.6669,
        longitude: -74.0545,
        imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&q=80',
        ratingAverage: 4.8,
        reviewsCount: 120,
        status: 'activo',
      ),
      const RestaurantModel(
        id: 'rest_2',
        name: 'Crepes & Waffles',
        description: 'Arte transformado en helado y crepes artesanales en Bogotá.',
        address: 'Carrera 11 # 85-09',
        category: 'Postres',
        latitude: 4.6702,
        longitude: -74.0583,
        imageUrl: 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=800&q=80',
        ratingAverage: 4.7,
        reviewsCount: 210,
        status: 'activo',
      ),
      const RestaurantModel(
        id: 'rest_3',
        name: 'Wok Zona G',
        description: 'Gastronomía asiática sustentable y variada en Bogotá.',
        address: 'Carrera 5 # 69-10, Zona G',
        category: 'Asiática',
        latitude: 4.6521,
        longitude: -74.0551,
        imageUrl: 'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=800&q=80',
        ratingAverage: 4.6,
        reviewsCount: 90,
        status: 'activo',
      ),
    ];
  }
}
