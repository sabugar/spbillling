import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

class AuthState {
  final bool loading;
  final bool authenticated;
  final String? role;
  final String? fullName;
  final String? error;

  const AuthState({
    this.loading = false,
    this.authenticated = false,
    this.role,
    this.fullName,
    this.error,
  });

  AuthState copyWith({
    bool? loading,
    bool? authenticated,
    String? role,
    String? fullName,
    String? error,
    bool clearError = false,
  }) =>
      AuthState(
        loading: loading ?? this.loading,
        authenticated: authenticated ?? this.authenticated,
        role: role ?? this.role,
        fullName: fullName ?? this.fullName,
        error: clearError ? null : (error ?? this.error),
      );
}

class AuthController extends StateNotifier<AuthState> {
  final Ref _ref;
  AuthController(this._ref) : super(const AuthState()) {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final storage = _ref.read(authStorageProvider);
    final token = await storage.readToken();
    if (token != null && token.isNotEmpty) {
      final role = await storage.readRole();
      final name = await storage.readFullName();
      state = state.copyWith(authenticated: true, role: role, fullName: name);
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final repo = _ref.read(authRepoProvider);
      final resp = await repo.login(username, password);
      await _ref.read(authStorageProvider).saveSession(
            token: resp.accessToken,
            role: resp.role,
            userId: resp.userId,
            fullName: resp.fullName,
          );
      state = AuthState(
        loading: false,
        authenticated: true,
        role: resp.role,
        fullName: resp.fullName,
      );
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString().replaceFirst('ApiError(', '').replaceFirst('): ', ' — ').replaceAll(')', ''));
      return false;
    }
  }

  Future<void> logout() async {
    await _ref.read(authStorageProvider).clear();
    state = const AuthState();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) => AuthController(ref));
