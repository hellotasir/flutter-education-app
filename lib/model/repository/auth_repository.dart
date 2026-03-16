import '../services/auth_service.dart';

class AuthRepository {
  final AuthService _service = AuthService();

  Future<void> login(String email, String password) async {
    final response = await _service.login(email: email, password: password);

    if (response.user == null) {
      throw Exception("Login failed");
    }
  }

  Future<void> signup(String email, String password) async {
    final response = await _service.signup(email: email, password: password);

    if (response.user == null) {
      throw Exception("Signup failed");
    }
  }

  Future<void> logout() {
    return _service.logout();
  }
}
