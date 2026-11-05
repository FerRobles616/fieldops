import 'package:fieldops_app/core/network/api_exception.dart';
import 'package:fieldops_app/core/theme/app_theme.dart';
import 'package:fieldops_app/features/auth/application/auth_controller.dart';
import 'package:fieldops_app/features/auth/domain/auth_models.dart';
import 'package:fieldops_app/features/orders/application/work_orders_controller.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';
import 'package:fieldops_app/features/orders/presentation/orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_work_orders_repository.dart';
import 'support/test_store.dart';
import 'support/work_order_fixtures.dart';

final _session = AuthSession(
  token: 'test-token',
  user: testTechnician,
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
);

Widget _buildApp({
  required TestStore env,
  required FakeWorkOrdersRepository remote,
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(restoredSession: _session),
      ),
      localStoreProvider.overrideWithValue(env.store),
      workOrdersRepositoryProvider.overrideWithValue(remote),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const OrdersScreen()),
  );
}

Future<void> _cleanup(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pump();
}

void main() {
  testWidgets('renders the assigned work orders', (tester) async {
    final orders = [
      buildWorkOrder(code: 'WO-0001', title: 'Fix HVAC'),
      buildWorkOrder(
        id: 'order-2',
        code: 'WO-0002',
        title: 'Repair lights',
        status: WorkOrderStatus.done,
      ),
    ];
    final env = await TestStore.create(orders: orders);
    addTearDown(env.close);

    await tester.pumpWidget(
      _buildApp(
        env: env,
        remote: FakeWorkOrdersRepository(orders: orders),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tech Demo'), findsOneWidget);
    expect(find.text('WO-0001'), findsOneWidget);
    expect(find.text('Fix HVAC'), findsOneWidget);
    expect(find.text('Repair lights'), findsOneWidget);

    await _cleanup(tester);
  });

  testWidgets('filters the list by status', (tester) async {
    final orders = [
      buildWorkOrder(code: 'WO-0001', title: 'Fix HVAC'),
      buildWorkOrder(
        id: 'order-2',
        code: 'WO-0002',
        title: 'Repair lights',
        status: WorkOrderStatus.done,
      ),
    ];
    final env = await TestStore.create(orders: orders);
    addTearDown(env.close);

    await tester.pumpWidget(
      _buildApp(
        env: env,
        remote: FakeWorkOrdersRepository(orders: orders),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Pending'));
    await tester.pumpAndSettle();

    expect(find.text('Fix HVAC'), findsOneWidget);
    expect(find.text('Repair lights'), findsNothing);

    await _cleanup(tester);
  });

  testWidgets('shows the empty state when there are no orders', (tester) async {
    final env = await TestStore.create();
    addTearDown(env.close);

    await tester.pumpWidget(
      _buildApp(env: env, remote: FakeWorkOrdersRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('No work orders assigned'), findsOneWidget);

    await _cleanup(tester);
  });

  testWidgets('shows an error state with a retry action', (tester) async {
    final env = await TestStore.create();
    addTearDown(env.close);
    final remote = FakeWorkOrdersRepository(
      syncError: const ApiException(
        'Could not reach the server.',
        isNetworkError: true,
      ),
    );

    await tester.pumpWidget(_buildApp(env: env, remote: remote));
    await tester.pumpAndSettle();

    expect(find.text('Could not load work orders'), findsOneWidget);
    expect(find.text('Could not reach the server.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await _cleanup(tester);
  });
}
