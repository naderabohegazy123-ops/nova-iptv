import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/xtream_account.dart';

class XtreamService {
  XtreamService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<Map<String, dynamic>> authenticate(XtreamAccount account) async {
    final uri = account.apiUri.replace(queryParameters: {
      'username': account.username,
      'password': account.password,
    });
    final response = await _client.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Server returned HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected server response');
    }
    if (data['user_info'] is Map &&
        data['user_info']['auth']?.toString() == '0') {
      throw Exception('Invalid subscription credentials');
    }
    return data;
  }

  Future<List<dynamic>> liveCategories(XtreamAccount account) =>
      _getList(account, 'get_live_categories');

  Future<List<dynamic>> liveStreams(XtreamAccount account,
      {String? categoryId}) =>
      _getList(account, 'get_live_streams', categoryId: categoryId);

  Future<List<dynamic>> _getList(XtreamAccount account, String action,
      {String? categoryId}) async {
    final params = <String, String>{
      'username': account.username,
      'password': account.password,
      'action': action,
    };
    if (categoryId != null) params['category_id'] = categoryId;
    final response = await _client.get(
      account.apiUri.replace(queryParameters: params),
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('Server returned HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    if (data is! List) throw const FormatException('Unexpected catalogue response');
    return data;
  }

  void close() => _client.close();
}
