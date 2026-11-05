import 'package:fieldops_app/app.dart';
import 'package:fieldops_app/core/sync/connectivity_provider.dart';
import 'package:fieldops_app/features/auth/application/auth_controller.dart';
import 'package:fieldops_app/features/auth/domain/auth_models.dart';
import 'package:fieldops_app/features/orders/application/work_orders_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_work_orders_repository.dart';
import 'support/test_store.dart';

Widget _buildApp(
  FakeAuthRepository repository, {
  required TestStore env,
  FakeWorkOrdersRepository? workOrders,
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      localStoreProvider.overrideWithValue(env.store),
      workOrdersRepositoryProvider.overrideWithValue(
        workOrders ?? FakeWorkOrdersRepository(),
      ),
      connectivityProvider.overrideWith((ref) => Stream<bool>.value(true)),
    ],
    child: const FieldOpsApp(),
  );
}

Future<void> _cleanup(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pump();
}

final _session = AuthSession(
  token: 'test-token',
  user: const AuthUser(
    id: 'user-1',
    email: 'tech@fieldops.dev',
    name: 'Tech Demo',
    role: UserRole.technician,
  ),
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
);

void main() {
  testWidgets('redirects to login when there is no stored session', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    final env = await TestStore.create();
    addTearDown(env.close);

    await tester.pumpWidget(_buildApp(repository, env: env));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);

    await _cleanup(tester);
  });

  testWidgets('redirects to orders when a session is restored', (tester) async {
    final repository = FakeAuthRepository(restoredSession: _session);
    final env = await TestStore.create();
    addTearDown(env.close);

    await tester.pumpWidget(_buildApp(repository, env: env));
    await tester.pumpAndSettle();

    expect(find.text('No work orders assigned'), findsOneWidget);
    expect(find.text('Tech Demo'), findsOneWidget);

    await _cleanup(tester);
  });

  testWidgets('navigates to orders after a successful login', (tester) async {
    final repository = FakeAuthRepository();
    final env = await TestStore.create();
    addTearDown(env.close);

    await tester.pumpWidget(_buildApp(repository, env: env));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'tech@fieldops.dev',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'tech1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('No work orders assigned'), findsOneWidget);
    expect(repository.loginCalls, 1);

    await _cleanup(tester);
  });
}
