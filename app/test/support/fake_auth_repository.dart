import 'package:fieldops_app/features/auth/data/auth_repository.dart';
import 'package:fieldops_app/features/auth/domain/auth_models.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.onLogin, this.restoredSession});

  final Future<AuthSession> Function(String email, String password)? onLogin;
  final AuthSession? restoredSession;

  int loginCalls = 0;
  String? lastEmail;
  String? lastPassword;
  bool logoutCalled = false;

  @override
  Future<AuthSession?> restore() async => restoredSession;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    lastEmail = email;
    lastPassword = password;

    final handler = onLogin;
    if (handler != null) {
      return handler(email, password);
    }

    return AuthSession(
      token: 'test-token',
      user: const AuthUser(
        id: 'user-1',
        email: 'tech@fieldops.dev',
        name: 'Tech Demo',
        role: UserRole.technician,
      ),
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }
}
