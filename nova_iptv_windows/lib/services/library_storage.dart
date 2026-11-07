
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LibraryStorage {
  static const String _favoritesKey = 'nova_favorites';
  static const String _historyKey = 'nova_history';

  Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_favoritesKey);

    if (data == null) return [];

    try {
      return List<String>.from(jsonDecode(data));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveFavorites(List<String> items) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _favoritesKey,
      jsonEncode(items),
    );
  }

  Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_historyKey);

    if (data == null) return [];

    try {
      return List<String>.from(jsonDecode(data));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(List<String> items) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _historyKey,
      jsonEncode(items),
    );
  }
}
