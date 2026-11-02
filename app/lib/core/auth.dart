import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'favorites.dart';
import 'models.dart';

class AuthState {
  const AuthState({this.user, this.loading = false});
  final UserProfile? user;
  final bool loading;
  bool get signedIn => user != null;
  bool get isPremium => user?.isPremium ?? false;
}

class AuthController extends Notifier<AuthState> {
  Api get _api => ref.read(apiProvider);

  @override
  AuthState build() {
    if (TokenStore.access != null) Future.microtask(refreshProfile);
    return const AuthState();
  }

  Future<void> refreshProfile() async {
    try {
      state = AuthState(user: UserProfile(await _api.get('/auth/me', cache: false) as Map));
    } on ApiException catch (e) {
      if (e.status == 401) {
        await TokenStore.clear();
        state = const AuthState();
      }
    }
  }

  Future<void> _afterAuth(Map tokens) async {
    await TokenStore.save(tokens['access_token'], tokens['refresh_token']);
    await refreshProfile();
    await ref.read(favoritesProvider.notifier).syncWithServer();
  }

  Future<void> login(String email, String password) async {
    state = AuthState(user: state.user, loading: true);
    try {
      await _afterAuth(await _api.post('/auth/login', data: {'email': email, 'password': password}) as Map);
    } finally {
      state = AuthState(user: state.user);
    }
  }

  Future<void> register(String email, String password, String name) async {
    state = AuthState(user: state.user, loading: true);
    try {
      await _afterAuth(
        await _api.post('/auth/register', data: {'email': email, 'password': password, 'display_name': name}) as Map,
      );
    } finally {
      state = AuthState(user: state.user);
    }
  }

  Future<void> forgotPassword(String email) => _api.post('/auth/forgot-password', data: {'email': email});

  Future<void> resetPassword(String email, String code, String password) =>
      _api.post('/auth/reset-password', data: {'email': email, 'code': code, 'new_password': password});

  Future<void> logout() async {
    final refresh = TokenStore.refresh;
    if (refresh != null) {
      try {
        await _api.post('/auth/logout', data: {'refresh_token': refresh});
      } catch (_) {}
    }
    await TokenStore.clear();
    state = const AuthState();
  }

  Future<void> deleteAccount(String password) async {
    await _api.delete('/auth/me', data: {'password': password});
    await TokenStore.clear();
    state = const AuthState();
  }

  Future<void> updateProfile(Map<String, dynamic> fields) async {
    if (!state.signedIn) return;
    state = AuthState(user: UserProfile(await _api.patch('/auth/me', data: fields) as Map));
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
