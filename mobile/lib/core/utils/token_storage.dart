import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'auth_user_id';
  static const String _favoritesKey = 'user_favorite_restaurant_ids';

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
