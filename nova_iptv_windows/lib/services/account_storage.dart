
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/xtream_account.dart';

class AccountStorage {
  static const FlutterSecureStorage _storage =
      FlutterSecureStorage();

  static const String _accountKey = 'nova_xtream_account';

  Future<void> save(XtreamAccount account) async {
    final data = {
      'server': account.server,
      'username': account.username,
      'password': account.password,
    };

    await _storage.write(
      key: _accountKey,
      value: jsonEncode(data),
    );
  }

  Future<XtreamAccount?> read() async {
    final data = await _storage.read(key: _accountKey);

    if (data == null || data.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(data);

      if (decoded is! Map) {
        return null;
      }

      return XtreamAccount(
        server: decoded['server']?.toString() ?? '',
        username: decoded['username']?.toString() ?? '',
        password: decoded['password']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> delete() async {
    await _storage.delete(key: _accountKey);
  }
}
