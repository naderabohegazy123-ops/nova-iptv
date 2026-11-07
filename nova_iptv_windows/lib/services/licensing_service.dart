import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class LicensingService {
  LicensingService._();

  static const _supabaseUrl = 'https://uarcfellfyidoixwxion.supabase.co';
  static const _publishableKey = 'sb_publishable_9vOROenbqCRdFqSoA6vXsA_r1r_r2OC';
  static const _deviceKey = 'nova_device_id';
  static const _licenseKey = 'nova_license_key';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<String> _deviceId() async {
    var id = await _storage.read(key: _deviceKey);
    if (id != null && id.isNotEmpty) return id;

    final random = Random.secure();
    id = List<int>.generate(32, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    await _storage.write(key: _deviceKey, value: id);
    return id;
  }

  static Future<Map<String, dynamic>> _post(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_supabaseUrl/functions/v1/$functionName'),
          headers: {
            'Content-Type': 'application/json',
            'apikey': _publishableKey,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception('استجابة غير مفهومة من خادم التراخيص');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? (decoded['error'] ?? decoded['message'] ?? 'تعذر إتمام الطلب')
          : 'تعذر الاتصال بخادم التراخيص';
      throw Exception(message.toString());
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('استجابة غير صحيحة من خادم التراخيص');
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> activate(String licenseKey) async {
    final deviceId = await _deviceId();
    final result = await _post('activate-license', {
      'licenseKey': licenseKey.trim(),
      'deviceId': deviceId,
    });

    final accepted = result['success'] == true ||
        result['activated'] == true ||
        result['entitled'] == true;

    if (!accepted) {
      throw Exception(
        (result['error'] ?? result['message'] ?? 'المفتاح غير صالح أو مستخدم على جهاز آخر')
            .toString(),
      );
    }

    await _storage.write(key: _licenseKey, value: licenseKey.trim());
    return result;
  }

  static Future<bool> validate() async {
    final key = await _storage.read(key: _licenseKey);
    if (key == null || key.isEmpty) return false;

    final deviceId = await _deviceId();
    final result = await _post('validate-entitlement', {
      'deviceId': deviceId,
    });
    return result['entitled'] == true;
  }

  static Future<void> clearLocalLicense() async {
    await _storage.delete(key: _licenseKey);
  }
}
