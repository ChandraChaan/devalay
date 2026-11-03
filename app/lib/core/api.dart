import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';
import 'static_api.dart';
import 'storage.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status});
  final String message;
  final int? status;
  bool get isOffline => status == null;
  @override
  String toString() => message;
}

/// Tokens live in the Android Keystore-backed secure storage, never in Hive.
class TokenStore {
  static const _storage = FlutterSecureStorage();
  static String? access;
  static String? refresh;

  static Future<void> load() async {
    access = await _storage.read(key: 'access');
    refresh = await _storage.read(key: 'refresh');
  }

  static Future<void> save(String a, String r) async {
    access = a;
    refresh = r;
    await _storage.write(key: 'access', value: a);
    await _storage.write(key: 'refresh', value: r);
  }

  static Future<void> clear() async {
    access = refresh = null;
    await _storage.deleteAll();
  }
}

class Api {
  Api()
    : dio = Dio(
        BaseOptions(
          baseUrl: '${AppConfig.apiBaseUrl}/api/v1',
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Accept': 'application/json'},
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['X-Device-Id'] = deviceId;
          if (TokenStore.access != null) options.headers['Authorization'] = 'Bearer ${TokenStore.access}';
          handler.next(options);
        },
        onError: (error, handler) async {
          final req = error.requestOptions;
          final retried = req.extra['retried'] == true;
          if (error.response?.statusCode == 401 &&
              TokenStore.refresh != null &&
              !retried &&
              !req.path.startsWith('/auth/')) {
            if (await _refresh()) {
              req.extra['retried'] = true;
              req.headers['Authorization'] = 'Bearer ${TokenStore.access}';
              try {
                return handler.resolve(await dio.fetch(req));
              } on DioException catch (e) {
                return handler.next(e);
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio dio;
  Future<bool>? _refreshing;

  Future<bool> _refresh() => _refreshing ??= () async {
    try {
      final r = await Dio(
        BaseOptions(baseUrl: dio.options.baseUrl),
      ).post('/auth/refresh', data: {'refresh_token': TokenStore.refresh});
      await TokenStore.save(r.data['access_token'], r.data['refresh_token']);
      return true;
    } catch (_) {
      await TokenStore.clear();
      return false;
    } finally {
      _refreshing = null;
    }
  }();

  /// GET with an offline fallback: successful responses are cached on device and
  /// served when the network is unavailable.
  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool cache = true}) async {
    if (AppConfig.staticApi) {
      if (path == '/search') {
        return StaticApi.search(await get('/search/index') as Map, '${query?['q']}', query?['limit'] as int? ?? 10);
      }
      path = '/${StaticApi.file(path, query)}';
      query = null;
    }
    final key = '$path?${jsonEncode(query ?? const {})}';
    try {
      final r = await dio.get(path, queryParameters: query);
      if (cache) await Boxes.cache.put(key, jsonEncode(r.data));
      return r.data;
    } on DioException catch (e) {
      final cached = cache ? Boxes.cache.get(key) as String? : null;
      if (cached != null && e.response == null) return jsonDecode(cached);
      throw _wrap(e);
    }
  }

  Future<dynamic> post(String path, {Object? data}) async {
    if (AppConfig.staticApi) {
      final body = (data as Map?) ?? const {};
      if (path == '/ai/status') return StaticApi.status(await get('/ai/status') as Map, body);
      if (path == '/ai/ask') {
        return StaticApi.ask(await get('/search/index') as Map, '${body['question']}', '${body['language']}');
      }
      if (path.endsWith('/play') || path.endsWith('/download')) return null; // no counters without a server
      throw _serverOnly;
    }
    return _send(() => dio.post(path, data: data));
  }

  Future<dynamic> put(String path, {Object? data}) => _send(() => dio.put(path, data: data));
  Future<dynamic> patch(String path, {Object? data}) => _send(() => dio.patch(path, data: data));
  Future<dynamic> delete(String path, {Object? data}) => _send(() => dio.delete(path, data: data));

  static final _serverOnly = ApiException('Accounts and sync are not available in this build.', status: 501);

  Future<dynamic> _send(Future<Response> Function() call) async {
    if (AppConfig.staticApi) throw _serverOnly;
    try {
      return (await call()).data;
    } on DioException catch (e) {
      throw _wrap(e);
    }
  }

  ApiException _wrap(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    var message = 'Could not reach Devalay. Check your internet connection.';
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      message = d is List && d.isNotEmpty ? '${(d.first as Map)['msg']}' : '$d';
    } else if (status == 404 && AppConfig.staticApi) {
      message = 'This is only available for dates near today in the offline build.';
    } else if (status != null) {
      message = 'Something went wrong ($status). Please try again.';
    }
    return ApiException(message, status: status);
  }
}

final apiProvider = Provider<Api>((ref) => Api());
