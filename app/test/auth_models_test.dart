import 'package:fieldops_app/features/auth/domain/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = AuthUser(
  id: 'user-1',
  email: 'tech@fieldops.dev',
  name: 'Tech Demo',
  role: UserRole.technician,
);

void main() {
  group('AuthSession', () {
    test('parses a login response', () {
      final session = AuthSession.fromLoginResponse({
        'access_token': 'token-123',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': 'user-1',
          'email': 'tech@fieldops.dev',
          'name': 'Tech Demo',
          'role': 'technician',
        },
      });

      expect(session.token, 'token-123');
      expect(session.user.email, 'tech@fieldops.dev');
      expect(session.user.role, UserRole.technician);
      expect(session.isExpired, isFalse);
    });

    test('round-trips through storage JSON', () {
      final session = AuthSession(
        token: 'token-123',
        user: _user,
        expiresAt: DateTime.utc(2030, 1, 1),
      );

      final restored = AuthSession.fromJson(session.toJson());

      expect(restored.token, session.token);
      expect(restored.user.id, _user.id);
      expect(restored.user.role, UserRole.technician);
      expect(restored.expiresAt.toUtc(), session.expiresAt.toUtc());
    });

    test('detects expired sessions', () {
      final session = AuthSession(
        token: 'token-123',
        user: _user,
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      expect(session.isExpired, isTrue);
    });
  });

  group('AuthUser', () {
    test('builds initials from the full name', () {
      expect(_user.initials, 'TD');
    });

    test('handles a single name', () {
      const user = AuthUser(
        id: 'user-2',
        email: 'admin@fieldops.dev',
        name: 'Admin',
        role: UserRole.admin,
      );

      expect(user.initials, 'A');
    });
  });
}
