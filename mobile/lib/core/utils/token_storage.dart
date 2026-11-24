import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'auth_user_id';
  static const String _favoritesKey = 'user_favorite_restaurant_ids';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
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
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_favoritesKey);
  }
}
