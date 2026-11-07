
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/xtream_account.dart';

class XtreamService {
  XtreamService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  String _safeUrl(Uri uri) {
    return uri.replace(query: null, fragment: null).toString();
  }

  void _checkResponse(http.Response response, Uri uri) {
    if (response.statusCode != 200) {
      throw Exception(
        'HTTP ${response.statusCode}\n'
        'Request: ${_safeUrl(uri)}',
      );
    }
  }

  Future<Map<String, dynamic>> authenticate(
    XtreamAccount account,
  ) async {
    final uri = account.apiUri.replace(queryParameters: {
      'username': account.username,
      'password': account.password,
    });

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 20));

    _checkResponse(response, uri);

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

  Future<List<dynamic>> liveCategories(XtreamAccount account) {
    return _getList(account, 'get_live_categories');
  }

  Future<List<dynamic>> liveStreams(
    XtreamAccount account, {
    String? categoryId,
  }) {
    return _getList(
      account,
      'get_live_streams',
      categoryId: categoryId,
    );
  }

  Future<List<dynamic>> vodCategories(XtreamAccount account) {
    return _getList(account, 'get_vod_categories');
  }

  Future<List<dynamic>> vodStreams(
    XtreamAccount account, {
    String? categoryId,
  }) {
    return _getList(
      account,
      'get_vod_streams',
      categoryId: categoryId,
    );
  }

  Future<Map<String, dynamic>> vodInfo(
    XtreamAccount account,
    String vodId,
  ) {
    return _getMap(
      account,
      'get_vod_info',
      extra: {'vod_id': vodId},
    );
  }

  Future<List<dynamic>> seriesCategories(XtreamAccount account) {
    return _getList(account, 'get_series_categories');
  }

  Future<List<dynamic>> series(
    XtreamAccount account, {
    String? categoryId,
  }) {
    return _getList(
      account,
      'get_series',
      categoryId: categoryId,
    );
  }

  Future<Map<String, dynamic>> seriesInfo(
    XtreamAccount account,
    String seriesId,
  ) {
    return _getMap(
      account,
      'get_series_info',
      extra: {'series_id': seriesId},
    );
  }

  Future<List<dynamic>> _getList(
    XtreamAccount account,
    String action, {
    String? categoryId,
  }) async {
    final params = <String, String>{
      'username': account.username,
      'password': account.password,
      'action': action,
    };

    if (categoryId != null && categoryId.isNotEmpty) {
      params['category_id'] = categoryId;
    }

    final uri = account.apiUri.replace(queryParameters: params);

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 30));

    _checkResponse(response, uri);

    final data = jsonDecode(response.body);

    if (data is! List) {
      throw const FormatException(
        'Unexpected catalogue response',
      );
    }

    return data;
  }

  Future<Map<String, dynamic>> _getMap(
    XtreamAccount account,
    String action, {
    Map<String, String> extra = const {},
  }) async {
    final params = <String, String>{
      'username': account.username,
      'password': account.password,
      'action': action,
      ...extra,
    };

    final uri = account.apiUri.replace(queryParameters: params);

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 30));

    _checkResponse(response, uri);

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'Unexpected details response',
      );
    }

    return data;
  }

  void close() => _client.close();
}
