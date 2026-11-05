import 'dart:convert';

import 'package:fieldops_app/core/network/api_exception.dart';
import 'package:fieldops_app/core/theme/app_theme.dart';
import 'package:fieldops_app/features/orders/application/photo_picker.dart';
import 'package:fieldops_app/features/orders/application/report_sharer.dart';
import 'package:fieldops_app/features/orders/application/work_orders_controller.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';
import 'package:fieldops_app/features/orders/presentation/work_order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_photo_picker.dart';
import 'support/fake_report_sharer.dart';
import 'support/fake_work_orders_repository.dart';
import 'support/test_store.dart';
import 'support/work_order_fixtures.dart';

const _tinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAFElEQVR4nGMUqchjwAaYsIoOWgkAyAoBCsJdAxsAAAAASUVORK5CYII=';

Widget _buildApp({
  required TestStore env,
  required FakeWorkOrdersRepository remote,
  required String orderId,
  PhotoPicker? picker,
  ReportSharer? sharer,
}) {
  return ProviderScope(
    overrides: [
      localStoreProvider.overrideWithValue(env.store),
      workOrdersRepositoryProvider.overrideWithValue(remote),
      if (picker != null) photoPickerProvider.overrideWithValue(picker),
      if (sharer != null) reportSharerProvider.overrideWithValue(sharer),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: WorkOrderDetailScreen(orderId: orderId),
    ),
  );
}

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _cleanup(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pump();
}

void main() {
  testWidgets('renders the work order details', (tester) async {
    _useTallSurface(tester);
    final order = buildWorkOrder();
    final env = await TestStore.create(orders: [order]);
    addTearDown(env.close);

    await tester.pumpWidget(
      _buildApp(
        env: env,
        remote: FakeWorkOrdersRepository(orders: [order]),
        orderId: order.id,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fix HVAC'), findsOneWidget);
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('Start work'), findsOneWidget);
    expect(find.text('Version 1'), findsOneWidget);

    await _cleanup(tester);
  });

  testWidgets('updates the status and refreshes the order', (tester) async {
    _useTallSurface(tester);
    final order = buildWorkOrder();
    final env = await TestStore.create(orders: [order]);
    addTearDown(env.close);
    final remote = FakeWorkOrdersRepository(orders: [order]);

    await tester.pumpWidget(
      _buildApp(env: env, remote: remote, orderId: order.id),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start work'));
    await tester.pumpAndSettle();

    expect(remote.updateCalls, 1);
    expect(remote.lastUpdatedId, order.id);
    expect(remote.lastStatus, WorkOrderStatus.inProgress);
    expect(remote.lastIdempotencyKey, isNotNull);
    expect(find.text('Mark as done'), findsOneWidget);

    await _cleanup(tester);
  });

  testWidgets('shows a conflict message when the version is stale', (
    tester,
  ) async {
    _useTallSurface(tester);
    final order = buildWorkOrder();
    final env = await TestStore.create(orders: [order]);
    addTearDown(env.close);
    final remote = FakeWorkOrdersRepository(
      orders: [order],
      updateError: const ApiException(
        'This record changed on the server. Refresh and try again.',
        statusCode: 409,
      ),
    );

    await tester.pumpWidget(
      _buildApp(env: env, remote: remote, orderId: order.id),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start work'));
    await tester.pumpAndSettle();

    expect(
      find.text('This work order changed on the server. It was refreshed.'),
      findsOneWidget,
    );

    await _cleanup(tester);
  });

  testWidgets('does not offer an action for a closed order', (tester) async {
    _useTallSurface(tester);
    final order = buildWorkOrder(status: WorkOrderStatus.done);
    final env = await TestStore.create(orders: [order]);
    addTearDown(env.close);

    await tester.pumpWidget(
      _buildApp(
        env: env,
        remote: FakeWorkOrdersRepository(orders: [order]),
        orderId: order.id,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This work order is closed.'), findsOneWidget);
    expect(find.text('Start work'), findsNothing);
    expect(find.text('Mark as done'), findsNothing);

    await _cleanup(tester);
  });

  testWidgets('adds a photo and uploads it', (tester) async {
    _useTallSurface(tester);
    final order = buildWorkOrder();
    final env = await TestStore.create(orders: [order]);
    addTearDown(env.close);
    final remote = FakeWorkOrdersRepository(orders: [order]);
    final picker = FakePhotoPicker(
      PickedPhoto(
        bytes: base64Decode(_tinyPngBase64),
        contentType: 'image/png',
      ),
    );

    await tester.pumpWidget(
      _buildApp(env: env, remote: remote, orderId: order.id, picker: picker),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(remote.uploadCalls, 1);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Photo uploaded.'), findsOneWidget);

    await _cleanup(tester);
  });

  testWidgets('downloads and shares the PDF report', (tester) async {
    _useTallSurface(tester);
    final order = buildWorkOrder();
    final env = await TestStore.create(orders: [order]);
    addTearDown(env.close);
    final remote = FakeWorkOrdersRepository(orders: [order]);
    final sharer = FakeReportSharer();

    await tester.pumpWidget(
      _buildApp(env: env, remote: remote, orderId: order.id, sharer: sharer),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Report PDF'));
    await tester.pumpAndSettle();

    expect(remote.downloadReportCalls, 1);
    expect(sharer.calls, 1);
    expect(sharer.lastFilename, '${order.code}.pdf');
    expect(sharer.lastBytes, isNotNull);

    await _cleanup(tester);
  });
}
