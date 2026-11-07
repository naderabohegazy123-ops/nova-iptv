
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
    try {
      final value = await _storage.read(key: _accountKey);

      if (value == null || value.isEmpty) {
        return null;
      }

      final data = jsonDecode(value);

      if (data is! Map<String, dynamic>) {
        return null;
      }

      final server = data['server']?.toString() ?? '';
      final username = data['username']?.toString() ?? '';
      final password = data['password']?.toString() ?? '';

      if (server.isEmpty ||
          username.isEmpty ||
          password.isEmpty) {
        return null;
      }

      return XtreamAccount(
        server: server,
        username: username,
        password: password,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> delete() async {
    await _storage.delete(key: _accountKey);
  }
}
