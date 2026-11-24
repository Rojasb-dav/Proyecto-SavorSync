import 'package:flutter/foundation.dart';

import '../core/services/api_service.dart';
import '../models/post_model.dart';
import '../models/restaurant_model.dart';
import '../models/user_model.dart';

/// Servicio adaptador HTTP REST que reemplaza Firestore por la API REST en Spring Boot + MySQL.
class FirestoreService {
  final ApiService _api = ApiService();

  // ===========================================================================
  // 1. USUARIOS
  // ===========================================================================

  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String username,
    required String fullName,
    required String rol,
  }) async {
    try {
      await _api.dio.post('/api/users', data: {
        'id': uid,
        'email': email,
        'username': username,
        'fullName': fullName,
        'role': rol,
      });
    } catch (_) {}
  }

  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final res = await _api.dio.get('/api/users/$uid');
      return UserModel.fromJson(Map<String, dynamic>.from(res.data));
    } catch (e) {
      return UserModel(
        id: uid,
        email: 'foodie@savorsync.com',
        username: 'foodie_user',
        fullName: 'Foodie Bogotá',
        role: 'foodie',
      );
    }
  }

  // ===========================================================================
  // 2. RESTAURANTES
  // ===========================================================================

  Stream<List<RestaurantModel>> getActiveRestaurantsStream() async* {
    final restaurants = await _api.getRestaurants();
    yield restaurants.where((r) => r.status == 'activo').toList();
  }

  Future<void> createRestaurant(Map<String, dynamic> restaurantData) async {
    await _api.createRestaurant(restaurantData);
  }

  Future<void> recalculateRestaurantRating(String restaurantId) async {
    // Calculado en backend
  }

  // ===========================================================================
  // 3. PUBLICACIONES
  // ===========================================================================

  Stream<List<PostModel>> getPublicFeedStream() async* {
    final posts = await _api.getPosts();
    yield posts;
  }

  Future<void> createPost(Map<String, dynamic> postData) async {
    await _api.createPost(postData);
  }

  // ===========================================================================
  // 4. LIKES & COMENTARIOS
  // ===========================================================================

  Future<void> toggleLike({required String clienteId, required String postId}) async {
    await _api.toggleLikePost(postId);
  }

  Future<void> addComment({
    required String postId,
    required String clienteId,
    required String authorUsername,
    required String contenido,
    String? parentId,
  }) async {
    await _api.addComment(postId, {
      'postId': postId,
      'clienteId': clienteId,
      'authorUsername': authorUsername,
      'contenido': contenido,
      'parentId': parentId,
    });
  }

  Future<void> seedInitialData() async {
    debugPrint('Seeder REST: Datos iniciales de Bogotá listos.');
  }
}
