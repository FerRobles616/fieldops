import 'package:fieldops_app/features/orders/application/photo_picker.dart';
import 'package:fieldops_app/features/orders/application/work_orders_controller.dart';
import 'package:fieldops_app/features/orders/data/work_orders_sync_service.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncStatus {
  const SyncStatus({
    this.isSyncing = false,
    this.isOnline = true,
    this.lastError,
    this.lastSyncedAt,
  });

  final bool isSyncing;
  final bool isOnline;
  final String? lastError;
  final DateTime? lastSyncedAt;
}

class SyncUpdateResult {
  const SyncUpdateResult({
    required this.queued,
    required this.conflict,
    this.error,
  });

  final bool queued;
  final bool conflict;
  final String? error;
}

class PhotoUploadResult {
  const PhotoUploadResult({required this.queued, this.error});

  final bool queued;
  final String? error;
}

class SyncController extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => const SyncStatus();

  Future<SyncReport> sync({bool full = false}) async {
    if (state.isSyncing) {
      final pending = await ref.read(localStoreProvider).pendingOperations();
      return SyncReport(isOnline: state.isOnline, pendingOps: pending.length);
    }

    state = const SyncStatus(isSyncing: true, isOnline: true);

    final report = await ref.read(syncServiceProvider).sync(full: full);

    state = SyncStatus(
      isSyncing: false,
      isOnline: report.isOnline,
      lastError: report.error,
      lastSyncedAt: report.syncedAt ?? state.lastSyncedAt,
    );

    return report;
  }

  Future<SyncUpdateResult> updateStatus(
    WorkOrder order,
    WorkOrderStatus status,
  ) async {
    await ref
        .read(localStoreProvider)
        .enqueueStatusUpdate(order: order, status: status);

    final report = await sync();

    return SyncUpdateResult(
      queued: report.pendingOps > 0,
      conflict: report.conflicts.any((item) => item.id == order.id),
      error: report.error,
    );
  }

  Future<PhotoUploadResult> addPhoto(
    WorkOrder order,
    PickedPhoto picked, {
    String? caption,
  }) async {
    await ref
        .read(localStoreProvider)
        .addPhoto(
          workOrderId: order.id,
          bytes: picked.bytes,
          contentType: picked.contentType,
          caption: caption,
        );

    final report = await sync();

    return PhotoUploadResult(
      queued: report.pendingOps > 0,
      error: report.error,
    );
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);
