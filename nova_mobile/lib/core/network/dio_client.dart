import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

class DioClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage;

  DioClient(this._storage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(_JwtInterceptor(_storage, _dio));
  }

  Dio get client => _dio;
}

class _JwtInterceptor extends QueuedInterceptor {
  final FlutterSecureStorage _storage;
  final Dio _dio;

  _JwtInterceptor(this._storage, this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          err.requestOptions.headers['Authorization'] = 'Bearer $token';
        }
        handler.resolve(await _dio.fetch(err.requestOptions));
        return;
      }
    }
    handler.next(err);
  }

  Future<bool> _refreshToken() async {
    try {
      final refresh = await _storage.read(key: 'refresh_token');
      if (refresh == null || refresh.isEmpty) return false;

      // Use a temporary Dio instance without the JWT interceptor to avoid loops.
      final res = await Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl)).post(
        AppConstants.authRefreshPath,
        data: {'refresh_token': refresh},
      );
      await _storage.write(key: 'access_token', value: res.data['access_token']);
      // The refresh endpoint returns a new token pair — persist both.
      final newRefresh = res.data['refresh_token'];
      if (newRefresh != null && (newRefresh as String).isNotEmpty) {
        await _storage.write(key: 'refresh_token', value: newRefresh);
      }
      return true;
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      return false;
    }
  }
}
