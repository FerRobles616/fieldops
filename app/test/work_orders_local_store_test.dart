import 'dart:typed_data';

import 'package:fieldops_app/features/orders/domain/outbox_operation.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';
import 'package:fieldops_app/features/orders/domain/work_order_photo.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_store.dart';
import 'support/work_order_fixtures.dart';

void main() {
  test('caches orders and reads them back', () async {
    final env = await TestStore.create(orders: [buildWorkOrder()]);
    addTearDown(env.close);

    final orders = await env.store.getOrders();

    expect(orders, hasLength(1));
    expect(orders.single.title, 'Fix HVAC');
    expect(orders.single.pendingSync, isFalse);
  });

  test('enqueues a status update and marks the order pending', () async {
    final order = buildWorkOrder();
    final env = await TestStore.create(orders: [order]);
    addTearDown(env.close);

    await env.store.enqueueStatusUpdate(
      order: order,
      status: WorkOrderStatus.inProgress,
    );

    final localOrder = (await env.store.getOrders()).single;
    final operations = await env.store.pendingOperations();

    expect(localOrder.status, WorkOrderStatus.inProgress);
    expect(localOrder.pendingSync, isTrue);
    expect(operations, hasLength(1));
    expect(operations.single.targetStatus, WorkOrderStatus.inProgress);
    expect(operations.single.baseVersion, order.version);
  });

  test('coalesces repeated status updates for the same order', () async {
    final order = buildWorkOrder();
    final env = await TestStore.create(orders: [order]);
    addTearDown(env.close);

    await env.store.enqueueStatusUpdate(
      order: order,
      status: WorkOrderStatus.inProgress,
    );
    await env.store.enqueueStatusUpdate(
      order: order,
      status: WorkOrderStatus.done,
    );

    final operations = await env.store.pendingOperations();

    expect(operations, hasLength(1));
    expect(operations.single.targetStatus, WorkOrderStatus.done);
  });

  test('applies remote tombstones by deleting the local order', () async {
    final order = buildWorkOrder();
    final env = await TestStore.create(orders: [order]);
    addTearDown(env.close);

    await env.store.applyRemoteChanges([
      order.copyWith(deletedAt: DateTime.now()),
    ], full: false);

    expect(await env.store.getOrders(), isEmpty);
  });

  test('full sync removes cached orders that are no longer assigned', () async {
    final first = buildWorkOrder(id: 'order-1', code: 'WO-0001');
    final second = buildWorkOrder(
      id: 'order-2',
      code: 'WO-0002',
      title: 'Other order',
    );
    final env = await TestStore.create(orders: [first, second]);
    addTearDown(env.close);

    await env.store.applyRemoteChanges([first], full: true);

    final cached = await env.store.getOrders();

    expect(cached, hasLength(1));
    expect(cached.single.id, first.id);
  });

  test('stores a photo and queues an upload', () async {
    final order = buildWorkOrder();
    final env = await TestStore.create(orders: [order]);
    addTearDown(env.close);
    final bytes = Uint8List.fromList([1, 2, 3, 4]);

    await env.store.addPhoto(
      workOrderId: order.id,
      bytes: bytes,
      contentType: 'image/png',
      caption: 'Before the repair',
    );

    final photos = await env.store.watchPhotos(order.id).first;
    final operations = await env.store.pendingOperations();

    expect(photos, hasLength(1));
    expect(photos.single.state, PhotoSyncState.pending);
    expect(photos.single.bytes, bytes);
    expect(photos.single.caption, 'Before the repair');
    expect(operations, hasLength(1));
    expect(operations.single.type, OutboxOperationType.uploadPhoto);
  });

  test('completes a photo upload', () async {
    final order = buildWorkOrder();
    final env = await TestStore.create(orders: [order]);
    addTearDown(env.close);

    await env.store.addPhoto(
      workOrderId: order.id,
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      contentType: 'image/png',
    );

    final photo = (await env.store.watchPhotos(order.id).first).single;
    final operation = (await env.store.pendingOperations()).single;

    await env.store.completePhotoUpload(
      opId: operation.id,
      photoId: photo.id,
      remoteId: 'remote-photo-1',
    );

    final updated = (await env.store.watchPhotos(order.id).first).single;

    expect(updated.state, PhotoSyncState.uploaded);
    expect(updated.remoteId, 'remote-photo-1');
    expect(await env.store.pendingOperations(), isEmpty);
  });
}
