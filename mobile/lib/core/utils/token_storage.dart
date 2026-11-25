import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'auth_user_id';
  static const String _favoritesKey = 'user_favorite_restaurant_ids';
  static const String _pendingVerificationEmailKey = 'pending_verification_email';
  static const String _pendingVerificationChallengeKey = 'pending_verification_challenge';
  static const String _pendingVerificationExpiryKey = 'pending_verification_expires_ms';
  static const String _pendingVerificationRoleKey = 'pending_verification_requested_role';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_tokenKey, token)) {
      throw StateError('No se pudo guardar la sesión.');
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> savePendingVerification({
    required String email,
    required String challengeId,
    required int expiresInMs,
    String? requestedRole,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingVerificationEmailKey, email);
    await prefs.setString(_pendingVerificationChallengeKey, challengeId);
    await prefs.setInt(_pendingVerificationExpiryKey, expiresInMs);
    if (requestedRole == null || requestedRole.isEmpty) {
      await prefs.remove(_pendingVerificationRoleKey);
    } else {
      await prefs.setString(_pendingVerificationRoleKey, requestedRole);
    }
  }

  Future<Map<String, Object>?> getPendingVerification() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_pendingVerificationEmailKey);
    final challengeId = prefs.getString(_pendingVerificationChallengeKey);
    final expiresInMs = prefs.getInt(_pendingVerificationExpiryKey);
    if (email == null || challengeId == null || expiresInMs == null) return null;
    return {
      'email': email,
      'challengeId': challengeId,
      'expiresInMs': expiresInMs,
      'requestedRole': prefs.getString(_pendingVerificationRoleKey) ?? '',
    };
  }

  Future<void> clearPendingVerification() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_pendingVerificationEmailKey),
      prefs.remove(_pendingVerificationChallengeKey),
      prefs.remove(_pendingVerificationExpiryKey),
      prefs.remove(_pendingVerificationRoleKey),
    ]);
  }

  // GESTIÓN REAL DE RESTAURANTES FAVORITOS DEL USUARIO
  Future<List<String>> getFavoriteRestaurantIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKey) ?? [];
  }

  Future<void> saveFavoriteRestaurantIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, ids);
  }

  Future<bool> toggleFavoriteRestaurant(String restaurantId) async {
    final current = await getFavoriteRestaurantIds();
    final list = List<String>.from(current);
    bool isFav = false;
    if (list.contains(restaurantId)) {
      list.remove(restaurantId);
      isFav = false;
    } else {
      list.add(restaurantId);
      isFav = true;
    }
    await saveFavoriteRestaurantIds(list);
    return isFav;
  }

  Future<bool> isRestaurantFavorite(String restaurantId) async {
    final current = await getFavoriteRestaurantIds();
    return current.contains(restaurantId);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await _clear(prefs);
  }

  Future<bool> clearIfCurrentToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_tokenKey) != token) return false;
    await _clear(prefs);
    return true;
  }

  Future<void> _clear(SharedPreferences prefs) async {
    final removed = await Future.wait([
      prefs.remove(_tokenKey),
      prefs.remove(_userIdKey),
      prefs.remove(_favoritesKey),
    ]);
    if (removed.contains(false)) {
      throw StateError('No se pudo limpiar la sesión almacenada.');
    }
  }
}
