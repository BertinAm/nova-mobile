import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/settings/settings_service.dart';

// ─── Events ───────────────────────────────────────────────────────────────────
abstract class AuthEvent {
  const AuthEvent();
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  const AuthLoginRequested(this.email, this.password);
}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  const AuthRegisterRequested(this.email, this.password);
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

// ─── States ───────────────────────────────────────────────────────────────────
abstract class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

class AuthRegisterSuccess extends AuthState {
  final String message;
  const AuthRegisterSuccess(this.message);
}

// ─── Bloc ─────────────────────────────────────────────────────────────────────
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;
  final SettingsService _settings;

  AuthBloc(this._repo, this._settings) : super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onCheckRequested(
      AuthCheckRequested event, Emitter<AuthState> emit) async {
    final loggedIn = await _repo.isLoggedIn;
    if (loggedIn) {
      emit(const AuthAuthenticated());
      await _settings.syncConsentState();
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
      AuthLoginRequested event, Emitter<AuthState> emit) async {
    // ── Client-side validation ──────────────────────────────────────────────
    if (event.email.trim().isEmpty || event.password.isEmpty) {
      emit(const AuthError('Please fill in both your email and password.'));
      emit(const AuthUnauthenticated());
      return;
    }

    emit(const AuthLoading());
    try {
      await _repo.login(event.email.trim(), event.password);
      emit(const AuthAuthenticated());
      await _settings.syncConsentState();
    } catch (e) {
      emit(AuthError(_friendlyError(e, fallback: 'We couldn\'t log you in. Please double-check your email and password.')));
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onRegisterRequested(
      AuthRegisterRequested event, Emitter<AuthState> emit) async {
    // ── Client-side validation ──────────────────────────────────────────────
    if (event.email.trim().isEmpty || event.password.isEmpty) {
      emit(const AuthError('Please fill in both your email and password.'));
      emit(const AuthUnauthenticated());
      return;
    }
    if (event.password.length < 8) {
      emit(const AuthError('Your password needs to be at least 8 characters long.'));
      emit(const AuthUnauthenticated());
      return;
    }

    emit(const AuthLoading());
    try {
      await _repo.register(event.email.trim(), event.password);
      emit(const AuthRegisterSuccess(
          'Great, your account has been created! You can now log in.'));
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(_friendlyError(e, fallback: 'Registration didn\'t go through. That email might already be taken.')));
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLogoutRequested(
      AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _repo.logout();
    emit(const AuthUnauthenticated());
  }

  /// Tries to pull a readable message from a DioException's response body.
  /// Falls back to [fallback] for network errors, timeouts, etc.
  String _friendlyError(Object error, {required String fallback}) {
    if (error is DioException) {
      // Server returned a JSON body with "detail"
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first.containsKey('msg')) {
            return first['msg'] as String;
          }
        }
      }
      if (data is String && data.isNotEmpty) return data;

      // Network-level issues
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'The server is taking too long to respond. Please try again in a moment.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'It looks like you\'re offline. Please check your internet and try again.';
      }
    }
    return fallback;
  }
}
