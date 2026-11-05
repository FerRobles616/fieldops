import 'package:fieldops_app/features/auth/domain/auth_models.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _workOrderJson({
  String status = 'pending',
  int version = 1,
  Object? assignedTo = const {
    'id': 'user-1',
    'email': 'tech@fieldops.dev',
    'name': 'Tech Demo',
    'role': 'technician',
  },
}) {
  return {
    'id': 'order-1',
    'code': 'WO-0001',
    'customer': {
      'id': 'customer-1',
      'name': 'Acme',
      'address': '1 Main St',
      'phone': '555-0100',
    },
    'assigned_to': assignedTo,
    'title': 'Fix HVAC',
    'description': 'Check the unit.',
    'status': status,
    'priority': 'urgent',
    'scheduled_at': '2026-11-04T12:00:00Z',
    'version': version,
    'created_at': '2026-11-04T10:00:00Z',
    'updated_at': '2026-11-04T11:00:00Z',
  };
}

void main() {
  test('parses a work order payload', () {
    final order = WorkOrder.fromJson(_workOrderJson(status: 'in_progress'));

    expect(order.id, 'order-1');
    expect(order.code, 'WO-0001');
    expect(order.customer.name, 'Acme');
    expect(order.assignedTo?.role, UserRole.technician);
    expect(order.status, WorkOrderStatus.inProgress);
    expect(order.priority, WorkOrderPriority.urgent);
    expect(order.version, 1);
    expect(order.scheduledAt, isNotNull);
  });

  test('parses an unassigned work order', () {
    final order = WorkOrder.fromJson(_workOrderJson(assignedTo: null));

    expect(order.assignedTo, isNull);
  });

  test('parses a page of work orders', () {
    final page = WorkOrderPage.fromJson({
      'items': [_workOrderJson()],
      'total': 1,
      'limit': 20,
      'offset': 0,
    });

    expect(page.items, hasLength(1));
    expect(page.total, 1);
    expect(page.limit, 20);
    expect(page.offset, 0);
  });

  test('copyWith updates status and version', () {
    final order = WorkOrder.fromJson(_workOrderJson());
    final updated = order.copyWith(status: WorkOrderStatus.done, version: 2);

    expect(updated.status, WorkOrderStatus.done);
    expect(updated.version, 2);
    expect(updated.id, order.id);
    expect(updated.customer.name, order.customer.name);
  });

  test('status JSON values round-trip', () {
    for (final status in WorkOrderStatus.values) {
      expect(WorkOrderStatus.fromJson(status.jsonValue), status);
    }
  });
}
