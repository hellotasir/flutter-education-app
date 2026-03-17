import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;
  User? get currentUser => _client.auth.currentUser;

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  bool get isAuthenticated => currentUser != null;
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
    String? emailRedirectTo,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: data,
      emailRedirectTo: emailRedirectTo,
    );
  }

  Future<UserResponse> updatePassword(String newPassword) async {
    return await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signInWithMagicLink({
    required String email,
    String? emailRedirectTo,
  }) async {
    await _client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: emailRedirectTo,
    );
  }

  Future<void> signInWithPhoneOtp({required String phone}) async {
    await _client.auth.signInWithOtp(phone: phone);
  }

  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
    required OtpType type,
  }) async {
    return await _client.auth.verifyOTP(email: email, token: token, type: type);
  }

  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
    required OtpType type,
  }) async {
    return await _client.auth.verifyOTP(phone: phone, token: token, type: type);
  }

  Future<bool> signInWithOAuth(
    OAuthProvider provider, {
    String? redirectTo,
    String? scopes,
    Map<String, String>? queryParams,
  }) async {
    return await _client.auth.signInWithOAuth(
      provider,
      redirectTo: redirectTo,
      scopes: scopes,
      queryParams: queryParams,
    );
  }

  Future<AuthResponse> signInWithIdToken({
    required OAuthProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
  }) async {
    return await _client.auth.signInWithIdToken(
      provider: provider,
      idToken: idToken,
      accessToken: accessToken,
      nonce: nonce,
    );
  }

  Future<void> signInWithSSO({
    String? domain,
    String? providerId,
    String? redirectTo,
  }) async {
    await _client.auth.signInWithSSO(
      domain: domain,
      providerId: providerId,
      redirectTo: redirectTo,
    );
  }

  Future<void> sendPasswordResetEmail({
    required String email,
    String? redirectTo,
  }) async {
    await _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  Future<UserResponse> updateUser({
    String? email,
    String? phone,
    String? password,
    Map<String, dynamic>? data,
  }) async {
    return await _client.auth.updateUser(
      UserAttributes(
        email: email,
        phone: phone,
        password: password,
        data: data,
      ),
    );
  }

  Future<ResendResponse> resendEmailVerification({
    required String email,
  }) async {
    return await _client.auth.resend(type: OtpType.signup, email: email);
  }

  Future<ResendResponse> resendPhoneVerification({
    required String phone,
  }) async {
    return await _client.auth.resend(type: OtpType.sms, phone: phone);
  }

  Future<AuthResponse> refreshSession() async {
    return await _client.auth.refreshSession();
  }

  Future<AuthSessionUrlResponse> exchangeCodeForSession(String authCode) async {
    return await _client.auth.exchangeCodeForSession(authCode);
  }

  Future<AuthResponse> setSession(String refreshToken) async {
    return await _client.auth.setSession(refreshToken);
  }

  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    await _client.auth.signOut(scope: scope);
  }
}
