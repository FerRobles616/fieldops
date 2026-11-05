import 'dart:typed_data';

import 'package:fieldops_app/features/orders/data/work_orders_repository.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';

class FakeWorkOrdersRepository implements WorkOrdersRepository {
  FakeWorkOrdersRepository({
    List<WorkOrder> orders = const [],
    this.listError,
    this.syncError,
    this.getError,
    this.updateError,
    this.nextSince = '2026-01-01T00:00:00Z',
  }) : orders = [...orders];

  List<WorkOrder> orders;
  Object? listError;
  Object? syncError;
  Object? getError;
  Object? updateError;
  Object? uploadError;
  String nextSince;

  int listCalls = 0;
  int syncCalls = 0;
  int getCalls = 0;
  int updateCalls = 0;
  int uploadCalls = 0;
  int _remotePhotoCounter = 0;
  int downloadReportCalls = 0;
  String? lastSince;
  String? lastUpdatedId;
  String? lastIdempotencyKey;
  String? lastUploadedWorkOrderId;
  String? lastUploadIdempotencyKey;
  WorkOrderStatus? lastStatus;
  Uint8List reportBytes = Uint8List.fromList('%PDF-1.4'.codeUnits);

  @override
  Future<WorkOrderPage> list({
    int limit = 50,
    int offset = 0,
    WorkOrderStatus? status,
    WorkOrderPriority? priority,
    String? query,
  }) async {
    listCalls++;
    if (listError != null) {
      throw listError!;
    }

    var filtered = orders;
    if (status != null) {
      filtered = filtered.where((order) => order.status == status).toList();
    }
    if (priority != null) {
      filtered = filtered.where((order) => order.priority == priority).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final needle = query.toLowerCase();
      filtered = filtered
          .where(
            (order) =>
                order.title.toLowerCase().contains(needle) ||
                order.code.toLowerCase().contains(needle),
          )
          .toList();
    }

    return WorkOrderPage(
      items: filtered,
      total: filtered.length,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<WorkOrderSyncPage> sync({String? since, int limit = 200}) async {
    syncCalls++;
    lastSince = since;
    if (syncError != null) {
      throw syncError!;
    }
    return WorkOrderSyncPage(items: [...orders], nextSince: nextSince);
  }

  @override
  Future<WorkOrder> get(String id) async {
    getCalls++;
    if (getError != null) {
      throw getError!;
    }
    return orders.firstWhere((order) => order.id == id);
  }

  @override
  Future<WorkOrder> updateStatus({
    required String id,
    required int baseVersion,
    required WorkOrderStatus status,
    String? idempotencyKey,
  }) async {
    updateCalls++;
    lastUpdatedId = id;
    lastStatus = status;
    lastIdempotencyKey = idempotencyKey;

    if (updateError != null) {
      throw updateError!;
    }

    final index = orders.indexWhere((order) => order.id == id);
    final updated = orders[index].copyWith(
      status: status,
      version: baseVersion + 1,
      updatedAt: DateTime.now(),
      pendingSync: false,
    );
    orders = [...orders]..[index] = updated;
    return updated;
  }

  @override
  Future<String> uploadPhoto({
    required String workOrderId,
    required Uint8List bytes,
    required String filename,
    required String contentType,
    String? caption,
    String? idempotencyKey,
  }) async {
    uploadCalls++;
    lastUploadedWorkOrderId = workOrderId;
    lastUploadIdempotencyKey = idempotencyKey;

    if (uploadError != null) {
      throw uploadError!;
    }

    _remotePhotoCounter++;
    return 'remote-photo-$_remotePhotoCounter';
  }

  @override
  Future<Uint8List> downloadReport(String workOrderId) async {
    downloadReportCalls++;
    return reportBytes;
  }
}
