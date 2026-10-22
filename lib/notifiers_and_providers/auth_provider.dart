import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String baseUrl = 'http://127.0.0.1:8000';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

class AuthState {
  final bool isAuthenticated;
  final String? token;
  final String? errorMessage;
  final bool isLoading;

  AuthState({
    required this.isAuthenticated,
    this.token,
    this.errorMessage,
    this.isLoading = false,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? token,
    String? errorMessage,
    bool? isLoading,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  static const _tokenKey = 'jwt_token';

  @override
  AuthState build() {
    final prefs = ref.read(sharedPrefsProvider);
    final token = prefs.getString(_tokenKey);
    return AuthState(isAuthenticated: token != null, token: token);
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': username, 'password': password},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        await ref.read(sharedPrefsProvider).setString(_tokenKey, token);
        state = state.copyWith(isAuthenticated: true, token: token, isLoading: false);
        return true;
      } else {
        state = state.copyWith(isLoading: false, errorMessage: 'Invalid credentials');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Connection error');
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        state = state.copyWith(isLoading: false);
        return await login(username, password);
      } else {
        final data = jsonDecode(response.body);
        state = state.copyWith(
            isLoading: false, errorMessage: data['detail'] ?? 'Registration failed');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Connection error');
      return false;
    }
  }

  Future<void> logout() async {
    await ref.read(sharedPrefsProvider).remove(_tokenKey);
    state = AuthState(isAuthenticated: false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
