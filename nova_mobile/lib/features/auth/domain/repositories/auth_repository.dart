import 'package:flutter/foundation.dart';
import '../../data/datasources/auth_remote_datasource.dart';

abstract class AuthRepository {
  Future<bool> get isLoggedIn;
  Future<AuthUser> register(String email, String password);
  Future<AuthTokenPair> login(String email, String password);
  Future<void> logout();
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _remote;

  AuthRepositoryImpl(this._remote);

  @override
  Future<bool> get isLoggedIn => _remote.isLoggedIn;

  @override
  Future<AuthUser> register(String email, String password) async {
    try {
      return await _remote.register(email: email, password: password);
    } catch (e) {
      debugPrint('Registration failed: $e');
      rethrow;
    }
  }

  @override
  Future<AuthTokenPair> login(String email, String password) async {
    try {
      return await _remote.login(email: email, password: password);
    } catch (e) {
      debugPrint('Login failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    await _remote.logout();
  }
}
