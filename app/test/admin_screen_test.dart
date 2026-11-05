import 'package:fieldops_app/core/theme/app_theme.dart';
import 'package:fieldops_app/features/admin/application/admin_providers.dart';
import 'package:fieldops_app/features/admin/presentation/admin_screen.dart';
import 'package:fieldops_app/features/auth/application/auth_controller.dart';
import 'package:fieldops_app/features/auth/domain/auth_models.dart';
import 'package:fieldops_app/features/orders/application/work_orders_controller.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_admin_repository.dart';
import 'support/fake_auth_repository.dart';
import 'support/fake_work_orders_repository.dart';
import 'support/test_store.dart';
import 'support/work_order_fixtures.dart';

const _admin = AuthUser(
  id: 'admin-1',
  email: 'admin@fieldops.dev',
  name: 'Admin Demo',
  role: UserRole.admin,
);

final _adminSession = AuthSession(
  token: 'admin-token',
  user: _admin,
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
);

Widget _buildApp({
  required TestStore env,
  required FakeWorkOrdersRepository remote,
  required FakeAdminRepository admin,
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(restoredSession: _adminSession),
      ),
      localStoreProvider.overrideWithValue(env.store),
      workOrdersRepositoryProvider.overrideWithValue(remote),
      adminRepositoryProvider.overrideWithValue(admin),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const AdminScreen()),
  );
}

Future<void> _cleanup(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pump();
}

void _useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('renders admin stats and all orders', (tester) async {
    _useLargeSurface(tester);
    final orders = [
      buildWorkOrder(id: 'order-1', code: 'WO-0001', title: 'Fix HVAC'),
      buildWorkOrder(
        id: 'order-2',
        code: 'WO-0002',
        title: 'Unassigned job',
        assignedTo: null,
      ),
    ];
    final env = await TestStore.create(orders: orders);
    addTearDown(env.close);
    final admin = FakeAdminRepository(
      customers: const [Customer(id: 'customer-1', name: 'Acme')],
      technicians: [testTechnician],
    );

    await tester.pumpWidget(
      _buildApp(
        env: env,
        remote: FakeWorkOrdersRepository(orders: orders),
        admin: admin,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Admin console'), findsOneWidget);
    expect(find.text('Total orders'), findsOneWidget);
    expect(find.text('Unassigned'), findsNWidgets(2));
    expect(find.text('Fix HVAC'), findsOneWidget);
    expect(find.text('Unassigned job'), findsOneWidget);

    await _cleanup(tester);
  });

  testWidgets('assigns a technician from the admin console', (tester) async {
    _useLargeSurface(tester);
    final unassigned = buildWorkOrder(
      id: 'order-2',
      code: 'WO-0002',
      title: 'Unassigned job',
      assignedTo: null,
    );
    final env = await TestStore.create(orders: [unassigned]);
    addTearDown(env.close);
    final technician = const AuthUser(
      id: 'tech-2',
      email: 'tech2@fieldops.dev',
      name: 'Tech Two',
      role: UserRole.technician,
    );
    final admin = FakeAdminRepository(
      customers: const [Customer(id: 'customer-1', name: 'Acme')],
      technicians: [testTechnician, technician],
    );

    await tester.pumpWidget(
      _buildApp(
        env: env,
        remote: FakeWorkOrdersRepository(orders: [unassigned]),
        admin: admin,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Assign'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tech Two').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Assign'));
    await tester.pumpAndSettle();

    expect(admin.assignCalls, 1);
    expect(admin.lastAssignedTechnicianId, technician.id);
    expect(admin.lastBaseVersion, unassigned.version);

    await _cleanup(tester);
  });
}
