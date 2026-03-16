import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signup({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  User? currentUser() {
    return _client.auth.currentUser;
  }

  Stream<AuthState> authChanges() {
    return _client.auth.onAuthStateChange;
  }
}
