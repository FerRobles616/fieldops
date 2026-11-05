import 'dart:typed_data';

import 'package:fieldops_app/features/orders/data/work_orders_api.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';

abstract class WorkOrdersRepository {
  Future<WorkOrderPage> list({
    int limit,
    int offset,
    WorkOrderStatus? status,
    WorkOrderPriority? priority,
    String? query,
  });

  Future<WorkOrder> get(String id);

  Future<WorkOrder> updateStatus({
    required String id,
    required int baseVersion,
    required WorkOrderStatus status,
    String? idempotencyKey,
  });

  Future<WorkOrderSyncPage> sync({String? since, int limit});

  Future<String> uploadPhoto({
    required String workOrderId,
    required Uint8List bytes,
    required String filename,
    required String contentType,
    String? caption,
    String? idempotencyKey,
  });

  Future<Uint8List> downloadReport(String workOrderId);
}

class ApiWorkOrdersRepository implements WorkOrdersRepository {
  ApiWorkOrdersRepository({required this.api});

  final WorkOrdersApi api;

  @override
  Future<WorkOrderPage> list({
    int limit = 50,
    int offset = 0,
    WorkOrderStatus? status,
    WorkOrderPriority? priority,
    String? query,
  }) {
    return api.list(
      limit: limit,
      offset: offset,
      status: status,
      priority: priority,
      query: query,
    );
  }

  @override
  Future<WorkOrder> get(String id) => api.get(id);

  @override
  Future<WorkOrder> updateStatus({
    required String id,
    required int baseVersion,
    required WorkOrderStatus status,
    String? idempotencyKey,
  }) {
    return api.updateStatus(
      id: id,
      baseVersion: baseVersion,
      status: status,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<WorkOrderSyncPage> sync({String? since, int limit = 200}) {
    return api.sync(since: since, limit: limit);
  }

  @override
  Future<String> uploadPhoto({
    required String workOrderId,
    required Uint8List bytes,
    required String filename,
    required String contentType,
    String? caption,
    String? idempotencyKey,
  }) {
    return api.uploadPhoto(
      workOrderId: workOrderId,
      bytes: bytes,
      filename: filename,
      contentType: contentType,
      caption: caption,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<Uint8List> downloadReport(String workOrderId) {
    return api.downloadReport(workOrderId);
  }
}
