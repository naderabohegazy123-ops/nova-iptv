
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/channel.dart';

class LibraryStorage {
  static const String _favoritesKey = 'nova_favorites';
  static const String _historyKey = 'nova_history';
  static const String _m3uChannelsKey = 'nova_m3u_channels';

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

  Future<void> saveM3uChannels(List<Channel> channels) async {
    final prefs = await SharedPreferences.getInstance();

    final data = channels.map((channel) {
      return {
        'name': channel.name,
        'url': channel.url,
        'logo': channel.logo,
        'group': channel.group,
        'tvgId': channel.tvgId,
        'id': channel.id,
        'categoryId': channel.categoryId,
        'extension': channel.extension,
        'contentType': channel.contentType,
      };
    }).toList();

    await prefs.setString(
      _m3uChannelsKey,
      jsonEncode(data),
    );
  }

  Future<List<Channel>> getM3uChannels() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_m3uChannelsKey);

    if (data == null) return [];

    try {
      final decoded = jsonDecode(data);

      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((item) {
            return Channel(
              name: item['name']?.toString() ?? 'Unnamed channel',
              url: item['url']?.toString() ?? '',
              logo: item['logo']?.toString(),
              group: item['group']?.toString() ?? 'Other',
              tvgId: item['tvgId']?.toString(),
              id: item['id']?.toString(),
              categoryId: item['categoryId']?.toString(),
              extension: item['extension']?.toString(),
              contentType: item['contentType']?.toString() ?? 'm3u',
            );
          })
          .where((channel) => channel.url.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearM3uChannels() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_m3uChannelsKey);
  }
}
