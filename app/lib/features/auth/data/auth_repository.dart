import 'package:fieldops_app/core/storage/token_storage.dart';
import 'package:fieldops_app/features/auth/data/auth_api.dart';
import 'package:fieldops_app/features/auth/domain/auth_models.dart';

abstract class AuthRepository {
  Future<AuthSession?> restore();

  Future<AuthSession> login({required String email, required String password});

  Future<void> logout();
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({required this.api, required this.storage});

  final AuthApi api;
  final TokenStorage storage;

  @override
  Future<AuthSession?> restore() async {
    final session = await storage.readSession();
    if (session == null) {
      return null;
    }
    if (session.isExpired) {
      await storage.clear();
      return null;
    }
    return session;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final session = await api.login(email: email, password: password);
    await storage.saveSession(session);
    return session;
  }

  @override
  Future<void> logout() => storage.clear();
}
