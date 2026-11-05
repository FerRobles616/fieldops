import 'package:fieldops_app/features/admin/application/admin_providers.dart';
import 'package:fieldops_app/features/admin/presentation/admin_new_order_screen.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fake_admin_repository.dart';
import 'support/work_order_fixtures.dart';

void main() {
  testWidgets('creates a work order from the admin form', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final admin = FakeAdminRepository(
      customers: const [Customer(id: 'customer-1', name: 'Acme')],
      technicians: [testTechnician],
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.push('/admin/new-order'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/admin/new-order',
          builder: (context, state) => const AdminNewOrderScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminRepositoryProvider.overrideWithValue(admin)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acme').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Install panel');
    await tester.tap(find.text('Create work order'));
    await tester.pumpAndSettle();

    expect(admin.createWorkOrderCalls, 1);
    expect(admin.lastCustomerId, 'customer-1');
    expect(admin.lastTitle, 'Install panel');
    expect(find.text('Open'), findsOneWidget);
  });
}
