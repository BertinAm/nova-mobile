/// NOVA Auth Data Source — wraps POST /auth/register, POST /auth/login,
/// POST /auth/refresh and persists tokens to FlutterSecureStorage.
///
/// Time complexity: O(1) per network call (no local collections traversed).
/// Space complexity: O(1) — only scalar JWT strings are stored.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/constants/app_constants.dart';

class AuthRemoteDatasource {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  AuthRemoteDatasource(this._dio, this._storage);

  // ── Register ────────────────────────────────────────────────────────────────
  Future<AuthUser> register({
    required String email,
    required String password,
    String preferredLanguage = 'en-CM',
  }) async {
    final res = await _dio.post(
      AppConstants.authRegisterPath,
      data: {
        'email': email,
        'password': password,
        'preferred_language': preferredLanguage,
      },
    );
    return AuthUser.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Login ───────────────────────────────────────────────────────────────────
  /// Uses x-www-form-urlencoded as required by the OAuth2 password-flow spec.
  Future<AuthTokenPair> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      AppConstants.authLoginPath,
      data: FormData.fromMap({
        'username': email,
        'password': password,
        'grant_type': 'password',
      }),
      options: Options(
          contentType: 'application/x-www-form-urlencoded'),
    );
    final pair = AuthTokenPair.fromJson(res.data as Map<String, dynamic>);
    await _persist(pair);
    return pair;
  }

  // ── Refresh ─────────────────────────────────────────────────────────────────
  Future<AuthTokenPair> refresh() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) {
      throw StateError('No refresh token stored');
    }
    final res = await _dio.post(
      AppConstants.authRefreshPath,
      data: {'refresh_token': refreshToken},
    );
    final pair = AuthTokenPair.fromJson(res.data as Map<String, dynamic>);
    await _persist(pair);
    return pair;
  }

  // ── Logout (local-only) ─────────────────────────────────────────────────────
  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  // ── Read cached tokens ───────────────────────────────────────────────────────
  Future<String?> get accessToken => _storage.read(key: 'access_token');
  Future<bool> get isLoggedIn async {
    final t = await _storage.read(key: 'access_token');
    return t != null && t.isNotEmpty;
  }

  Future<void> _persist(AuthTokenPair pair) async {
    await _storage.write(key: 'access_token', value: pair.accessToken);
    await _storage.write(key: 'refresh_token', value: pair.refreshToken);
    debugPrint('[Auth] Tokens persisted.');
  }
}

// ─── Simple value objects ─────────────────────────────────────────────────────
class AuthUser {
  final String id;
  final String email;
  final String preferredLanguage;

  const AuthUser({
    required this.id,
    required this.email,
    required this.preferredLanguage,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as String,
        email: j['email'] as String,
        preferredLanguage: j['preferred_language'] as String,
      );
}

class AuthTokenPair {
  final String accessToken;
  final String refreshToken;

  const AuthTokenPair({
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthTokenPair.fromJson(Map<String, dynamic> j) => AuthTokenPair(
        accessToken: j['access_token'] as String,
        refreshToken: j['refresh_token'] as String,
      );
}
