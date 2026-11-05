import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:fieldops_app/core/database/fieldops_database.dart' as db;
import 'package:fieldops_app/features/auth/domain/auth_models.dart';
import 'package:fieldops_app/features/orders/domain/outbox_operation.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';
import 'package:fieldops_app/features/orders/domain/work_order_photo.dart';
import 'package:uuid/uuid.dart';

class WorkOrdersLocalStore {
  WorkOrdersLocalStore(this._db);

  static const String _lastSinceKey = 'last_since';

  final db.FieldOpsDatabase _db;

  Stream<List<WorkOrder>> watchOrders() {
    final query = _db.select(_db.cachedWorkOrders)
      ..where((table) => table.deletedAt.isNull())
      ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);

    return query.watch().map(
      (rows) => rows.map(_toDomain).toList(growable: false),
    );
  }

  Stream<WorkOrder?> watchOrder(String id) {
    final query = _db.select(_db.cachedWorkOrders)
      ..where((table) => table.id.equals(id));

    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _toDomain(row),
    );
  }

  Stream<int> watchPendingCount() {
    final query = _db.select(_db.outboxOperations)
      ..where((table) => table.state.isIn(const ['pending', 'in_flight']));

    return query.watch().map((rows) => rows.length);
  }

  Future<List<WorkOrder>> getOrders() async {
    final query = _db.select(_db.cachedWorkOrders)
      ..where((table) => table.deletedAt.isNull())
      ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);

    final rows = await query.get();
    return rows.map(_toDomain).toList(growable: false);
  }

  Future<void> applyRemoteChanges(
    List<WorkOrder> orders, {
    required bool full,
  }) async {
    await _db.transaction(() async {
      if (full) {
        final remoteIds = orders.map((order) => order.id).toSet();
        final localRows = await _db.select(_db.cachedWorkOrders).get();

        for (final row in localRows) {
          if (!remoteIds.contains(row.id) && !row.pendingSync) {
            await (_db.delete(
              _db.cachedWorkOrders,
            )..where((table) => table.id.equals(row.id))).go();
          }
        }
      }

      for (final order in orders) {
        if (order.deletedAt != null) {
          await (_db.delete(
            _db.cachedWorkOrders,
          )..where((table) => table.id.equals(order.id))).go();
          await (_db.delete(
            _db.cachedPhotos,
          )..where((table) => table.workOrderId.equals(order.id))).go();
          await (_db.delete(
            _db.outboxOperations,
          )..where((table) => table.workOrderId.equals(order.id))).go();
          continue;
        }

        final existing = await (_db.select(
          _db.cachedWorkOrders,
        )..where((table) => table.id.equals(order.id))).getSingleOrNull();

        if (existing != null && existing.pendingSync) {
          continue;
        }

        await _db
            .into(_db.cachedWorkOrders)
            .insertOnConflictUpdate(
              _toCompanion(order.copyWith(pendingSync: false)),
            );
      }
    });
  }

  Future<void> enqueueStatusUpdate({
    required WorkOrder order,
    required WorkOrderStatus status,
  }) async {
    await _db.transaction(() async {
      await (_db.update(
        _db.cachedWorkOrders,
      )..where((table) => table.id.equals(order.id))).write(
        db.CachedWorkOrdersCompanion(
          status: Value(status.jsonValue),
          pendingSync: const Value(true),
        ),
      );

      final existingOperation =
          await (_db.select(_db.outboxOperations)..where(
                (table) =>
                    table.workOrderId.equals(order.id) &
                    table.type.equals(OutboxOperationType.updateStatus.value) &
                    table.state.isIn(const ['pending', 'in_flight']),
              ))
              .getSingleOrNull();

      final payload = jsonEncode({'status': status.jsonValue});

      if (existingOperation != null) {
        await (_db.update(_db.outboxOperations)
              ..where((table) => table.id.equals(existingOperation.id)))
            .write(db.OutboxOperationsCompanion(payload: Value(payload)));
        return;
      }

      final now = DateTime.now();
      await _db
          .into(_db.outboxOperations)
          .insert(
            db.OutboxOperationsCompanion.insert(
              id: const Uuid().v4(),
              workOrderId: order.id,
              type: OutboxOperationType.updateStatus.value,
              payload: payload,
              baseVersion: order.version,
              createdAt: now,
              nextAttemptAt: now,
            ),
          );
    });
  }

  Future<List<OutboxOperation>> pendingOperations() async {
    final query = _db.select(_db.outboxOperations)
      ..where((table) => table.state.isIn(const ['pending', 'in_flight']))
      ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]);

    final rows = await query.get();
    return rows.map(_toOutboxOperation).toList(growable: false);
  }

  Future<void> completeOperation({
    required String opId,
    required WorkOrder updatedOrder,
  }) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.outboxOperations,
      )..where((table) => table.id.equals(opId))).go();
      await _db
          .into(_db.cachedWorkOrders)
          .insertOnConflictUpdate(
            _toCompanion(updatedOrder.copyWith(pendingSync: false)),
          );
    });
  }

  Future<void> failOperation({
    required String opId,
    required String error,
  }) async {
    final row = await (_db.select(
      _db.outboxOperations,
    )..where((table) => table.id.equals(opId))).getSingleOrNull();

    if (row == null) {
      return;
    }

    final attempts = row.attempts + 1;
    final delaySeconds = 1 << attempts.clamp(0, 6);

    await (_db.update(
      _db.outboxOperations,
    )..where((table) => table.id.equals(opId))).write(
      db.OutboxOperationsCompanion(
        attempts: Value(attempts),
        lastError: Value(error),
        nextAttemptAt: Value(
          DateTime.now().add(Duration(seconds: delaySeconds)),
        ),
        state: Value(OutboxOperationState.pending.value),
      ),
    );
  }

  Future<void> resolveConflict({
    required String opId,
    required WorkOrder currentOrder,
  }) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.outboxOperations,
      )..where((table) => table.id.equals(opId))).go();
      await _db
          .into(_db.cachedWorkOrders)
          .insertOnConflictUpdate(
            _toCompanion(currentOrder.copyWith(pendingSync: false)),
          );
    });
  }

  Future<void> removeOrder(String workOrderId) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.outboxOperations,
      )..where((table) => table.workOrderId.equals(workOrderId))).go();
      await (_db.delete(
        _db.cachedPhotos,
      )..where((table) => table.workOrderId.equals(workOrderId))).go();
      await (_db.delete(
        _db.cachedWorkOrders,
      )..where((table) => table.id.equals(workOrderId))).go();
    });
  }

  Stream<List<WorkOrderPhoto>> watchPhotos(String workOrderId) {
    final query = _db.select(_db.cachedPhotos)
      ..where((table) => table.workOrderId.equals(workOrderId))
      ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]);

    return query.watch().map(
      (rows) => rows.map(_toPhoto).toList(growable: false),
    );
  }

  Future<WorkOrderPhoto?> getPhoto(String photoId) async {
    final row = await (_db.select(
      _db.cachedPhotos,
    )..where((table) => table.id.equals(photoId))).getSingleOrNull();

    return row == null ? null : _toPhoto(row);
  }

  Future<void> addPhoto({
    required String workOrderId,
    required Uint8List bytes,
    required String contentType,
    String? caption,
  }) async {
    final now = DateTime.now();
    final photoId = const Uuid().v4();

    await _db.transaction(() async {
      await _db
          .into(_db.cachedPhotos)
          .insert(
            db.CachedPhotosCompanion.insert(
              id: photoId,
              workOrderId: workOrderId,
              contentType: contentType,
              bytes: bytes,
              createdAt: now,
              caption: Value(caption),
              state: const Value('pending'),
            ),
          );

      await _db
          .into(_db.outboxOperations)
          .insert(
            db.OutboxOperationsCompanion.insert(
              id: const Uuid().v4(),
              workOrderId: workOrderId,
              type: OutboxOperationType.uploadPhoto.value,
              payload: jsonEncode({'photoId': photoId}),
              baseVersion: 0,
              createdAt: now,
              nextAttemptAt: now,
            ),
          );
    });
  }

  Future<void> completePhotoUpload({
    required String opId,
    required String photoId,
    required String remoteId,
  }) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.outboxOperations,
      )..where((table) => table.id.equals(opId))).go();
      await (_db.update(
        _db.cachedPhotos,
      )..where((table) => table.id.equals(photoId))).write(
        db.CachedPhotosCompanion(
          remoteId: Value(remoteId),
          state: Value(PhotoSyncState.uploaded.value),
        ),
      );
    });
  }

  Future<String?> getLastSince() async {
    final row = await (_db.select(
      _db.syncMetadata,
    )..where((table) => table.key.equals(_lastSinceKey))).getSingleOrNull();

    return row?.value;
  }

  Future<void> setLastSince(String since) async {
    await _db
        .into(_db.syncMetadata)
        .insertOnConflictUpdate(
          db.SyncMetadataCompanion.insert(key: _lastSinceKey, value: since),
        );
  }

  Future<void> clearAll() async {
    await _db.transaction(() async {
      await _db.delete(_db.cachedWorkOrders).go();
      await _db.delete(_db.cachedPhotos).go();
      await _db.delete(_db.outboxOperations).go();
      await _db.delete(_db.syncMetadata).go();
    });
  }

  WorkOrder _toDomain(db.CachedWorkOrder row) {
    final assignedTo = row.assignedToId == null
        ? null
        : AuthUser(
            id: row.assignedToId!,
            email: row.assignedToEmail ?? '',
            name: row.assignedToName ?? '',
            role: UserRole.fromJson(row.assignedToRole ?? 'technician'),
          );

    return WorkOrder(
      id: row.id,
      code: row.code,
      customer: Customer(
        id: row.customerId,
        name: row.customerName,
        address: row.customerAddress,
        phone: row.customerPhone,
      ),
      assignedTo: assignedTo,
      title: row.title,
      description: row.description,
      status: WorkOrderStatus.fromJson(row.status),
      priority: WorkOrderPriority.fromJson(row.priority),
      scheduledAt: row.scheduledAt,
      version: row.version,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      pendingSync: row.pendingSync,
    );
  }

  db.CachedWorkOrdersCompanion _toCompanion(WorkOrder order) {
    return db.CachedWorkOrdersCompanion.insert(
      id: order.id,
      code: order.code,
      customerId: order.customer.id,
      customerName: order.customer.name,
      customerAddress: Value(order.customer.address),
      customerPhone: Value(order.customer.phone),
      assignedToId: Value(order.assignedTo?.id),
      assignedToName: Value(order.assignedTo?.name),
      assignedToEmail: Value(order.assignedTo?.email),
      assignedToRole: Value(order.assignedTo?.role.name),
      title: order.title,
      description: Value(order.description),
      status: order.status.jsonValue,
      priority: order.priority.jsonValue,
      scheduledAt: Value(order.scheduledAt),
      version: order.version,
      createdAt: order.createdAt,
      updatedAt: order.updatedAt,
      deletedAt: Value(order.deletedAt),
      pendingSync: Value(order.pendingSync),
    );
  }

  OutboxOperation _toOutboxOperation(db.OutboxOperation row) {
    return OutboxOperation(
      id: row.id,
      workOrderId: row.workOrderId,
      type: OutboxOperationType.fromString(row.type),
      payload: jsonDecode(row.payload) as Map<String, dynamic>,
      baseVersion: row.baseVersion,
      attempts: row.attempts,
      lastError: row.lastError,
      createdAt: row.createdAt,
      nextAttemptAt: row.nextAttemptAt,
      state: OutboxOperationState.fromString(row.state),
    );
  }

  WorkOrderPhoto _toPhoto(db.CachedPhoto row) {
    return WorkOrderPhoto(
      id: row.id,
      workOrderId: row.workOrderId,
      remoteId: row.remoteId,
      caption: row.caption,
      contentType: row.contentType,
      bytes: row.bytes,
      state: PhotoSyncState.fromString(row.state),
      createdAt: row.createdAt,
    );
  }
}
