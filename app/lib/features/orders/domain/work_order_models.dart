import 'package:fieldops_app/features/auth/domain/auth_models.dart';

class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.address,
    this.phone,
  });

  final String id;
  final String name;
  final String? address;
  final String? phone;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
    );
  }
}

enum WorkOrderStatus {
  pending,
  inProgress,
  done,
  cancelled;

  static WorkOrderStatus fromJson(String value) {
    return switch (value) {
      'pending' => WorkOrderStatus.pending,
      'in_progress' => WorkOrderStatus.inProgress,
      'done' => WorkOrderStatus.done,
      'cancelled' => WorkOrderStatus.cancelled,
      _ => WorkOrderStatus.pending,
    };
  }

  String get jsonValue => switch (this) {
    WorkOrderStatus.pending => 'pending',
    WorkOrderStatus.inProgress => 'in_progress',
    WorkOrderStatus.done => 'done',
    WorkOrderStatus.cancelled => 'cancelled',
  };

  String get label => switch (this) {
    WorkOrderStatus.pending => 'Pending',
    WorkOrderStatus.inProgress => 'In progress',
    WorkOrderStatus.done => 'Done',
    WorkOrderStatus.cancelled => 'Cancelled',
  };

  bool get isOpen =>
      this == WorkOrderStatus.pending || this == WorkOrderStatus.inProgress;
}

enum WorkOrderPriority {
  low,
  medium,
  high,
  urgent;

  static WorkOrderPriority fromJson(String value) {
    return switch (value) {
      'low' => WorkOrderPriority.low,
      'medium' => WorkOrderPriority.medium,
      'high' => WorkOrderPriority.high,
      'urgent' => WorkOrderPriority.urgent,
      _ => WorkOrderPriority.medium,
    };
  }

  String get label => switch (this) {
    WorkOrderPriority.low => 'Low',
    WorkOrderPriority.medium => 'Medium',
    WorkOrderPriority.high => 'High',
    WorkOrderPriority.urgent => 'Urgent',
  };

  String get jsonValue => switch (this) {
    WorkOrderPriority.low => 'low',
    WorkOrderPriority.medium => 'medium',
    WorkOrderPriority.high => 'high',
    WorkOrderPriority.urgent => 'urgent',
  };
}

class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.code,
    required this.customer,
    required this.assignedTo,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.scheduledAt,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.pendingSync = false,
  });

  final String id;
  final String code;
  final Customer customer;
  final AuthUser? assignedTo;
  final String title;
  final String? description;
  final WorkOrderStatus status;
  final WorkOrderPriority priority;
  final DateTime? scheduledAt;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool pendingSync;

  factory WorkOrder.fromJson(Map<String, dynamic> json) {
    final assignedTo = json['assigned_to'];

    return WorkOrder(
      id: json['id'] as String,
      code: json['code'] as String,
      customer: Customer.fromJson(json['customer'] as Map<String, dynamic>),
      assignedTo: assignedTo is Map<String, dynamic>
          ? AuthUser.fromJson(assignedTo)
          : null,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: WorkOrderStatus.fromJson(json['status'] as String),
      priority: WorkOrderPriority.fromJson(json['priority'] as String),
      scheduledAt: _parseDate(json['scheduled_at']),
      version: (json['version'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      deletedAt: _parseDate(json['deleted_at']),
    );
  }

  WorkOrder copyWith({
    WorkOrderStatus? status,
    int? version,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? pendingSync,
  }) {
    return WorkOrder(
      id: id,
      code: code,
      customer: customer,
      assignedTo: assignedTo,
      title: title,
      description: description,
      status: status ?? this.status,
      priority: priority,
      scheduledAt: scheduledAt,
      version: version ?? this.version,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String) {
      return null;
    }
    return DateTime.parse(value).toLocal();
  }
}

class WorkOrderPage {
  const WorkOrderPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<WorkOrder> items;
  final int total;
  final int limit;
  final int offset;

  factory WorkOrderPage.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>)
        .map((item) => WorkOrder.fromJson(item as Map<String, dynamic>))
        .toList();

    return WorkOrderPage(
      items: items,
      total: (json['total'] as num).toInt(),
      limit: (json['limit'] as num).toInt(),
      offset: (json['offset'] as num).toInt(),
    );
  }
}

class WorkOrderSyncPage {
  const WorkOrderSyncPage({required this.items, required this.nextSince});

  final List<WorkOrder> items;
  final String nextSince;

  factory WorkOrderSyncPage.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>)
        .map((item) => WorkOrder.fromJson(item as Map<String, dynamic>))
        .toList();

    return WorkOrderSyncPage(
      items: items,
      nextSince: json['next_since'] as String,
    );
  }
}
