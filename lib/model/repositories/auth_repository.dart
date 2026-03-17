import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class AuthRepository {
  final AuthService _service = AuthService();

  User? get currentUser => _service.currentUser;

  Session? get currentSession => _service.currentSession;

  Stream<AuthState> get authChanges => _service.authChanges;

  bool get isAuthenticated => _service.isAuthenticated;

  Future<void> login(String email, String password) async {
    final response = await _service.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user == null) throw Exception('Login failed');
  }

  Future<void> signup(
    String email,
    String password, {
    Map<String, dynamic>? data,
  }) async {
    final response = await _service.signUp(
      email: email,
      password: password,
      data: data,
    );
    if (response.user == null) throw Exception('Signup failed');
  }

  Future<void> signInWithMagicLink(String email) async {
    await _service.signInWithMagicLink(email: email);
  }

  Future<void> signInWithPhoneOtp(String phone) async {
    await _service.signInWithPhoneOtp(phone: phone);
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String token,
    required OtpType type,
  }) async {
    final response = await _service.verifyEmailOtp(
      email: email,
      token: token,
      type: type,
    );
    if (response.user == null) throw Exception('Email OTP verification failed');
  }

  Future<void> verifyPhoneOtp({
    required String phone,
    required String token,
    required OtpType type,
  }) async {
    final response = await _service.verifyPhoneOtp(
      phone: phone,
      token: token,
      type: type,
    );
    if (response.user == null) throw Exception('Phone OTP verification failed');
  }

  Future<void> signInWithOAuth(
    OAuthProvider provider, {
    String? redirectTo,
    String? scopes,
    Map<String, String>? queryParams,
  }) async {
    final launched = await _service.signInWithOAuth(
      provider,
      redirectTo: redirectTo,
      scopes: scopes,
      queryParams: queryParams,
    );
    if (!launched) throw Exception('OAuth sign-in failed to launch');
  }

  Future<void> signInWithIdToken({
    required OAuthProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
  }) async {
    final response = await _service.signInWithIdToken(
      provider: provider,
      idToken: idToken,
      accessToken: accessToken,
      nonce: nonce,
    );
    if (response.user == null) throw Exception('ID token sign-in failed');
  }

  Future<void> signInWithSSO({
    String? domain,
    String? providerId,
    String? redirectTo,
  }) async {
    await _service.signInWithSSO(
      domain: domain,
      providerId: providerId,
      redirectTo: redirectTo,
    );
  }

  Future<void> sendPasswordResetEmail(
    String email, {
    String? redirectTo,
  }) async {
    await _service.sendPasswordResetEmail(email: email, redirectTo: redirectTo);
  }

  Future<void> updatePassword(String newPassword) async {
    await _service.updatePassword(newPassword);
  }

  Future<void> updateUser({
    String? email,
    String? phone,
    String? password,
    Map<String, dynamic>? data,
  }) async {
    await _service.updateUser(
      email: email,
      phone: phone,
      password: password,
      data: data,
    );
  }

  Future<void> resendEmailVerification(String email) async {
    await _service.resendEmailVerification(email: email);
  }

  Future<void> resendPhoneVerification(String phone) async {
    await _service.resendPhoneVerification(phone: phone);
  }

  Future<void> refreshSession() async {
    final response = await _service.refreshSession();
    if (response.session == null) throw Exception('Session refresh failed');
  }

  Future<AuthSessionUrlResponse> exchangeCodeForSession(String authCode) async {
    return await _service.exchangeCodeForSession(authCode);
  }

  Future<void> setSession(String refreshToken) async {
    final response = await _service.setSession(refreshToken);
    if (response.session == null) throw Exception('Set session failed');
  }

  Future<void> logout({SignOutScope scope = SignOutScope.local}) async {
    await _service.signOut(scope: scope);
  }
}
