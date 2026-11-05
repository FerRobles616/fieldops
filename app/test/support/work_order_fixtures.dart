import 'package:fieldops_app/features/auth/domain/auth_models.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';

const testTechnician = AuthUser(
  id: 'user-1',
  email: 'tech@fieldops.dev',
  name: 'Tech Demo',
  role: UserRole.technician,
);

WorkOrder buildWorkOrder({
  String id = 'order-1',
  String code = 'WO-0001',
  String title = 'Fix HVAC',
  WorkOrderStatus status = WorkOrderStatus.pending,
  WorkOrderPriority priority = WorkOrderPriority.high,
  int version = 1,
  DateTime? scheduledAt,
  DateTime? updatedAt,
  AuthUser? assignedTo = testTechnician,
}) {
  final now = DateTime.utc(2026, 11, 4, 12);

  return WorkOrder(
    id: id,
    code: code,
    customer: const Customer(
      id: 'customer-1',
      name: 'Acme',
      address: '1 Main St',
      phone: '555-0100',
    ),
    assignedTo: assignedTo,
    title: title,
    description: 'Check the unit.',
    status: status,
    priority: priority,
    scheduledAt: scheduledAt ?? now,
    version: version,
    createdAt: now,
    updatedAt: updatedAt ?? now,
  );
}
