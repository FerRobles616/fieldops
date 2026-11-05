import 'package:fieldops_app/features/orders/domain/work_order_models.dart';

enum OutboxOperationType {
  updateStatus,
  uploadPhoto;

  static OutboxOperationType fromString(String value) {
    return switch (value) {
      'update_status' => OutboxOperationType.updateStatus,
      'upload_photo' => OutboxOperationType.uploadPhoto,
      _ => OutboxOperationType.updateStatus,
    };
  }

  String get value => switch (this) {
    OutboxOperationType.updateStatus => 'update_status',
    OutboxOperationType.uploadPhoto => 'upload_photo',
  };
}

enum OutboxOperationState {
  pending,
  inFlight,
  conflict,
  failed;

  static OutboxOperationState fromString(String value) {
    return switch (value) {
      'pending' => OutboxOperationState.pending,
      'in_flight' => OutboxOperationState.inFlight,
      'conflict' => OutboxOperationState.conflict,
      'failed' => OutboxOperationState.failed,
      _ => OutboxOperationState.pending,
    };
  }

  String get value => switch (this) {
    OutboxOperationState.pending => 'pending',
    OutboxOperationState.inFlight => 'in_flight',
    OutboxOperationState.conflict => 'conflict',
    OutboxOperationState.failed => 'failed',
  };
}

class OutboxOperation {
  const OutboxOperation({
    required this.id,
    required this.workOrderId,
    required this.type,
    required this.payload,
    required this.baseVersion,
    required this.attempts,
    required this.createdAt,
    required this.nextAttemptAt,
    required this.state,
    this.lastError,
  });

  final String id;
  final String workOrderId;
  final OutboxOperationType type;
  final Map<String, dynamic> payload;
  final int baseVersion;
  final int attempts;
  final String? lastError;
  final DateTime createdAt;
  final DateTime nextAttemptAt;
  final OutboxOperationState state;

  WorkOrderStatus? get targetStatus {
    final status = payload['status'];
    if (status is! String) {
      return null;
    }
    return WorkOrderStatus.fromJson(status);
  }
}
