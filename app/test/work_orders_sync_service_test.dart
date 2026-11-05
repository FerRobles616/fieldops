import 'dart:typed_data';

import 'package:fieldops_app/core/network/api_exception.dart';
import 'package:fieldops_app/features/orders/data/work_orders_sync_service.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';
import 'package:fieldops_app/features/orders/domain/work_order_photo.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_work_orders_repository.dart';
import 'support/test_store.dart';
import 'support/work_order_fixtures.dart';

void main() {
  test('pulls remote orders into the local cache', () async {
    final order = buildWorkOrder();
    final env = await TestStore.create();
    addTearDown(env.close);
    final remote = FakeWorkOrdersRepository(orders: [order]);
    final service = WorkOrdersSyncService(local: env.store, remote: remote);

    final report = await service.sync();

    expect(report.isOnline, isTrue);
    expect(report.pendingOps, 0);
    expect(await env.store.getOrders(), hasLength(1));
    expect(await env.store.getLastSince(), remote.nextSince);
  });

  test('keeps the optimistic update queued while offline', () async {
    final order = buildWorkOrder();
    final env = await TestStore.create(orders: [order]);
    addTearDown(env.close);
    final remote = FakeWorkOrdersRepository(
      orders: [order],
      updateError: const ApiException(
        'Could not reach the server.',
        isNetworkError: true,
      ),
    );
    final service = WorkOrdersSyncService(local: env.store, remote: remote);

    await env.store.enqueueStatusUpdate(
      order: order,
      status: WorkOrderStatus.inProgress,
    );
    final report = await service.sync();

    expect(report.isOnline, isFalse);
    expect(report.pendingOps, 1);

    final localOrder = (await env.store.getOrders()).single;
    expect(localOrder.status, WorkOrderStatus.inProgress);
    expect(localOrder.pendingSync, isTrue);
  });

  test('pushes a queued update with an idempotency key', () async {
    final order = buildWorkOrder();
    final env = await TestStore.create(orders: [order]);
    addTearDown(env.close);
    final remote = FakeWorkOrdersRepository(orders: [order]);
    final service = WorkOrdersSyncService(local: env.store, remote: remote);

    await env.store.enqueueStatusUpdate(
      order: order,
      status: WorkOrderStatus.inProgress,
    );
    final report = await service.sync();

    expect(report.isOnline, isTrue);
    expect(report.pendingOps, 0);
    expect(remote.updateCalls, 1);
    expect(remote.lastIdempotencyKey, isNotNull);

    final localOrder = (await env.store.getOrders()).single;
    expect(localOrder.status, WorkOrderStatus.inProgress);
    expect(localOrder.version, 2);
    expect(localOrder.pendingSync, isFalse);
  });

  test('resolves a version conflict with the server state', () async {
    final localOrder = buildWorkOrder();
    final serverOrder = buildWorkOrder(
      status: WorkOrderStatus.done,
      version: 5,
    );
    final env = await TestStore.create(orders: [localOrder]);
    addTearDown(env.close);
    final remote = FakeWorkOrdersRepository(
      orders: [serverOrder],
      updateError: const ApiException(
        'This record changed on the server.',
        statusCode: 409,
      ),
    );
    final service = WorkOrdersSyncService(local: env.store, remote: remote);

    await env.store.enqueueStatusUpdate(
      order: localOrder,
      status: WorkOrderStatus.inProgress,
    );
    final report = await service.sync();

    expect(report.conflicts, hasLength(1));
    expect(report.conflicts.single.id, localOrder.id);
    expect(report.pendingOps, 0);

    final local = (await env.store.getOrders()).single;
    expect(local.version, 5);
    expect(local.status, WorkOrderStatus.done);
    expect(local.pendingSync, isFalse);
  });

  test('full sync removes orders that are no longer assigned', () async {
    final first = buildWorkOrder(id: 'order-1', code: 'WO-0001');
    final second = buildWorkOrder(
      id: 'order-2',
      code: 'WO-0002',
      title: 'Other order',
    );
    final env = await TestStore.create(orders: [first, second]);
    addTearDown(env.close);
    final remote = FakeWorkOrdersRepository(orders: [first]);
    final service = WorkOrdersSyncService(local: env.store, remote: remote);

    await service.sync(full: true);

    final cached = await env.store.getOrders();
    expect(cached, hasLength(1));
    expect(cached.single.id, first.id);
  });

  test('uploads a queued photo with an idempotency key', () async {
    final order = buildWorkOrder();
    final env = await TestStore.create(orders: [order]);
    addTearDown(env.close);
    final remote = FakeWorkOrdersRepository(orders: [order]);
    final service = WorkOrdersSyncService(local: env.store, remote: remote);

    await env.store.addPhoto(
      workOrderId: order.id,
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      contentType: 'image/png',
      caption: 'Before the repair',
    );
    final report = await service.sync();

    expect(report.isOnline, isTrue);
    expect(report.pendingOps, 0);
    expect(remote.uploadCalls, 1);
    expect(remote.lastUploadedWorkOrderId, order.id);
    expect(remote.lastUploadIdempotencyKey, isNotNull);

    final photo = (await env.store.watchPhotos(order.id).first).single;
    expect(photo.state, PhotoSyncState.uploaded);
    expect(photo.remoteId, 'remote-photo-1');
  });
}
