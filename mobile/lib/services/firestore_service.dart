import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/post_model.dart';
import '../models/restaurant_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ===========================================================================
  // 1. USUARIOS (users/{uid})
  // ===========================================================================

  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String username,
    required String fullName,
    required String rol,
  }) async {
    final userData = {
      'email': email,
      'username': username,
      'fullName': fullName,
      'rol': rol, // 'foodie' | 'restaurant_admin' | 'moderador' | 'admin_sistema'
      'avatarUrl': null,
      'bio': '',
      'phone': '',
      'isActive': true,
      'followersCount': 0,
      'followingCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _db.collection('users').doc(uid).set(userData, SetOptions(merge: true));
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    return UserModel.fromJson({
      'id': doc.id,
      ...data,
      'role': data['rol'] ?? data['role'] ?? 'foodie',
    });
  }

  // ===========================================================================
  // 2. RESTAURANTES (restaurants/{restaurantId})
  // ===========================================================================

  Stream<List<RestaurantModel>> getActiveRestaurantsStream() {
    return _db
        .collection('restaurants')
        .where('status', isEqualTo: 'activo')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RestaurantModel.fromJson({'id': doc.id, ...doc.data()}))
            .toList());
  }

  Future<void> createRestaurant(Map<String, dynamic> restaurantData) async {
    final docRef = _db.collection('restaurants').doc();
    await docRef.set({
      'status': 'pendiente', // Inicia en estado pendiente de moderación
      'ratingAverage': 0.0,
      'reviewsCount': 0,
      'galeriaUrls': [],
      'menu': [],
      'promociones': [],
      'analytics': {
        'visitasPerfil': 0,
        'totalLikes': 0,
        'totalComentarios': 0,
        'totalReservas': 0,
      },
      'createdAt': FieldValue.serverTimestamp(),
      ...restaurantData,
    });
  }

  /// Recálculo automático de Rating Average y ReviewsCount
  Future<void> recalculateRestaurantRating(String restaurantId) async {
    final postsQuery = await _db
        .collection('posts')
        .where('restaurantId', isEqualTo: restaurantId)
        .where('estado', isEqualTo: 'publicada')
        .get();

    if (postsQuery.docs.isEmpty) {
      await _db.collection('restaurants').doc(restaurantId).update({
        'ratingAverage': 0.0,
        'reviewsCount': 0,
      });
      return;
    }

    double totalRating = 0.0;
    for (final doc in postsQuery.docs) {
      final rating = (doc.data()['calificacion'] as num?)?.toDouble() ?? 0.0;
      totalRating += rating;
    }

    final double average = totalRating / postsQuery.docs.length;

    await _db.collection('restaurants').doc(restaurantId).update({
      'ratingAverage': double.parse(average.toStringAsFixed(1)),
      'reviewsCount': postsQuery.docs.length,
    });
  }

  // ===========================================================================
  // 3. PUBLICACIONES (posts/{postId})
  // ===========================================================================

  Stream<List<PostModel>> getPublicFeedStream() {
    return _db
        .collection('posts')
        .where('estado', isEqualTo: 'publicada')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              final createdAtField = data['createdAt'];
              DateTime dt = DateTime.now();
              if (createdAtField is Timestamp) {
                dt = createdAtField.toDate();
              }
              return PostModel.fromJson({
                'id': doc.id,
                'userId': data['clienteId'] ?? data['userId'] ?? '',
                'username': data['authorUsername'] ?? data['username'] ?? '',
                'fullName': data['authorName'] ?? data['fullName'] ?? '',
                'userAvatarUrl': data['authorAvatar'],
                'restaurantName': data['restaurantName'] ?? '',
                'restaurantAddress': data['restaurantAddress'] ?? 'Bogotá',
                'content': data['contenido'] ?? data['content'] ?? '',
                'rating': (data['calificacion'] as num?)?.toDouble() ?? 0.0,
                'imageUrl': (data['imagenesUrls'] as List?)?.isNotEmpty == true
                    ? data['imagenesUrls'][0]
                    : data['imageUrl'] ?? '',
                'likesCount': data['likesCount'] ?? 0,
                'commentsCount': data['comentariosCount'] ?? 0,
                'createdAt': dt.toIso8601String(),
              });
            }).toList());
  }

  Future<void> createPost(Map<String, dynamic> postData) async {
    final docRef = _db.collection('posts').doc();
    final data = {
      'likesCount': 0,
      'comentariosCount': 0,
      'estado': 'publicada',
      'createdAt': FieldValue.serverTimestamp(),
      ...postData,
    };
    await docRef.set(data);

    // Recalcular rating si el post está asociado a un restaurante
    final String? restaurantId = postData['restaurantId'];
    if (restaurantId != null && restaurantId.isNotEmpty) {
      await recalculateRestaurantRating(restaurantId);
    }
  }

  // ===========================================================================
  // 4. LIKES (likes/{clienteId_postId}) & COMENTARIOS (comments/{commentId})
  // ===========================================================================

  Future<void> toggleLike({required String clienteId, required String postId}) async {
    final likeId = '${clienteId}_$postId';
    final likeRef = _db.collection('likes').doc(likeId);
    final postRef = _db.collection('posts').doc(postId);

    final doc = await likeRef.get();
    if (doc.exists) {
      await likeRef.delete();
      await postRef.update({'likesCount': FieldValue.increment(-1)});
    } else {
      await likeRef.set({
        'clienteId': clienteId,
        'postId': postId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await postRef.update({'likesCount': FieldValue.increment(1)});
    }
  }

  Future<void> addComment({
    required String postId,
    required String clienteId,
    required String authorUsername,
    required String contenido,
    String? parentId,
  }) async {
    final commentRef = _db.collection('comments').doc();
    final postRef = _db.collection('posts').doc(postId);

    await commentRef.set({
      'postId': postId,
      'clienteId': clienteId,
      'authorUsername': authorUsername,
      'parentId': parentId,
      'contenido': contenido,
      'estado': 'activo',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await postRef.update({'comentariosCount': FieldValue.increment(1)});
  }

  // ===========================================================================
  // 5. SEEDER DE DATOS INICIALES (Restaurantes y Publicaciones en Bogotá)
  // ===========================================================================

  Future<void> seedInitialData() async {
    try {
      final snapshot = await _db.collection('restaurants').limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        debugPrint('Seeder: Ya existen restaurantes en Firestore.');
        return;
      }

      debugPrint('Seeder: Poblando datos iniciales de Bogotá...');

      final seedRestaurants = [
        {
          'name': 'Andrés Carne de Res',
          'description': 'Icónico restaurante colombiano con música, parrilla y ambiente festivo.',
          'address': 'Calle 82 # 12-21, Zona T',
          'city': 'Bogotá',
          'latitude': 4.6669,
          'longitude': -74.0545,
          'category': 'Parrilla',
          'priceRange': 3,
          'imageUrl': 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&q=80',
          'ratingAverage': 4.8,
          'reviewsCount': 120,
          'status': 'activo',
        },
        {
          'name': 'Crepes & Waffles',
          'description': 'Arte transformado en helado y crepes artesanales en Bogotá.',
          'address': 'Carrera 11 # 85-09',
          'city': 'Bogotá',
          'latitude': 4.6702,
          'longitude': -74.0583,
          'category': 'Postres',
          'priceRange': 2,
          'imageUrl': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=800&q=80',
          'ratingAverage': 4.7,
          'reviewsCount': 210,
          'status': 'activo',
        },
        {
          'name': 'Wok Zona G',
          'description': 'Gastronomía asiática sustentable y variada en Bogotá.',
          'address': 'Carrera 5 # 69-10, Zona G',
          'city': 'Bogotá',
          'latitude': 4.6521,
          'longitude': -74.0551,
          'category': 'Asiática',
          'priceRange': 3,
          'imageUrl': 'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=800&q=80',
          'ratingAverage': 4.6,
          'reviewsCount': 90,
          'status': 'activo',
        },
      ];

      for (final r in seedRestaurants) {
        await _db.collection('restaurants').add({
          ...r,
          'ownerId': 'seed_admin_uid',
          'phone': '+57 601 3000000',
          'email': 'contacto@restaurante.com',
          'galeriaUrls': [r['imageUrl']],
          'horario': 'Lunes a Domingo: 12:00 PM - 10:00 PM',
          'menu': [
            {'nombre': 'Plato Especial Foodies', 'descripcion': 'Plato insignia de la casa', 'categoria': 'Principales', 'precio': 35000, 'disponible': true}
          ],
          'promociones': [],
          'analytics': {'visitasPerfil': 150, 'totalLikes': 80, 'totalComentarios': 25, 'totalReservas': 12},
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('Seeder completado exitosamente.');
    } catch (e) {
      debugPrint('Error en Seeder: $e');
    }
  }
}
