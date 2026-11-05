import 'package:fieldops_app/core/network/api_exception.dart';
import 'package:fieldops_app/features/orders/data/work_orders_local_store.dart';
import 'package:fieldops_app/features/orders/data/work_orders_repository.dart';
import 'package:fieldops_app/features/orders/domain/outbox_operation.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';

class SyncReport {
  const SyncReport({
    required this.isOnline,
    this.error,
    this.conflicts = const [],
    this.syncedAt,
    this.pendingOps = 0,
  });

  final bool isOnline;
  final String? error;
  final List<WorkOrder> conflicts;
  final DateTime? syncedAt;
  final int pendingOps;

  bool get hasConflicts => conflicts.isNotEmpty;
}

class WorkOrdersSyncService {
  WorkOrdersSyncService({required this.local, required this.remote});

  final WorkOrdersLocalStore local;
  final WorkOrdersRepository remote;

  Future<SyncReport> sync({bool full = false}) async {
    final conflicts = <WorkOrder>[];

    try {
      final canPull = await _pushPending(conflicts);
      if (!canPull) {
        return SyncReport(
          isOnline: false,
          error: 'Offline. Changes are queued.',
          conflicts: conflicts,
          pendingOps: await _pendingCount(),
        );
      }

      final lastSince = full ? null : await local.getLastSince();
      final page = await remote.sync(since: lastSince);
      await local.applyRemoteChanges(page.items, full: lastSince == null);
      await local.setLastSince(page.nextSince);

      return SyncReport(
        isOnline: true,
        conflicts: conflicts,
        syncedAt: DateTime.now(),
        pendingOps: await _pendingCount(),
      );
    } on ApiException catch (error) {
      return SyncReport(
        isOnline: !error.isNetworkError,
        error: error.message,
        conflicts: conflicts,
        pendingOps: await _pendingCount(),
      );
    }
  }

  Future<bool> _pushPending(List<WorkOrder> conflicts) async {
    final operations = await local.pendingOperations();

    for (final operation in operations) {
      if (operation.type == OutboxOperationType.uploadPhoto) {
        final canContinue = await _pushPhoto(operation);
        if (!canContinue) {
          return false;
        }
        continue;
      }

      final status = operation.targetStatus;
      if (status == null) {
        await local.failOperation(
          opId: operation.id,
          error: 'Invalid operation payload',
        );
        continue;
      }

      try {
        final updated = await remote.updateStatus(
          id: operation.workOrderId,
          baseVersion: operation.baseVersion,
          status: status,
          idempotencyKey: operation.id,
        );
        await local.completeOperation(
          opId: operation.id,
          updatedOrder: updated,
        );
      } on ApiException catch (error) {
        if (error.statusCode == 409) {
          try {
            final current = await remote.get(operation.workOrderId);
            await local.resolveConflict(
              opId: operation.id,
              currentOrder: current,
            );
            conflicts.add(current);
          } on ApiException catch (fetchError) {
            if (fetchError.statusCode == 403 || fetchError.statusCode == 404) {
              await local.removeOrder(operation.workOrderId);
              continue;
            }
            await local.failOperation(
              opId: operation.id,
              error: fetchError.message,
            );
            if (fetchError.isNetworkError) {
              return false;
            }
          }
          continue;
        }

        if (error.statusCode == 403 || error.statusCode == 404) {
          await local.removeOrder(operation.workOrderId);
          continue;
        }

        await local.failOperation(opId: operation.id, error: error.message);
        if (error.isNetworkError) {
          return false;
        }
      }
    }

    return true;
  }

  Future<bool> _pushPhoto(OutboxOperation operation) async {
    final photoId = operation.payload['photoId'];
    if (photoId is! String) {
      await local.failOperation(
        opId: operation.id,
        error: 'Invalid photo operation payload',
      );
      return true;
    }

    final photo = await local.getPhoto(photoId);
    if (photo == null) {
      await local.failOperation(
        opId: operation.id,
        error: 'Local photo not found',
      );
      return true;
    }

    try {
      final remoteId = await remote.uploadPhoto(
        workOrderId: operation.workOrderId,
        bytes: photo.bytes,
        filename: '${photo.id}.${_extensionFor(photo.contentType)}',
        contentType: photo.contentType,
        caption: photo.caption,
        idempotencyKey: operation.id,
      );
      await local.completePhotoUpload(
        opId: operation.id,
        photoId: photo.id,
        remoteId: remoteId,
      );
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 403 || error.statusCode == 404) {
        await local.removeOrder(operation.workOrderId);
        return true;
      }
      await local.failOperation(opId: operation.id, error: error.message);
      return !error.isNetworkError;
    }
  }

  String _extensionFor(String contentType) {
    return switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
  }

  Future<int> _pendingCount() async {
    final operations = await local.pendingOperations();
    return operations.length;
  }
}
