import 'package:fieldops_app/features/admin/data/admin_api.dart';
import 'package:fieldops_app/features/auth/domain/auth_models.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';

abstract class AdminRepository {
  Future<List<Customer>> listCustomers();

  Future<Customer> createCustomer({
    required String name,
    String? address,
    String? phone,
  });

  Future<List<AuthUser>> listTechnicians();

  Future<WorkOrder> createWorkOrder({
    required String customerId,
    String? technicianId,
    required String title,
    String? description,
    required WorkOrderPriority priority,
    DateTime? scheduledAt,
  });

  Future<WorkOrder> assignWorkOrder({
    required String workOrderId,
    required String technicianId,
    required int baseVersion,
  });
}

class ApiAdminRepository implements AdminRepository {
  ApiAdminRepository({required this.api});

  final AdminApi api;

  @override
  Future<List<Customer>> listCustomers() => api.listCustomers();

  @override
  Future<Customer> createCustomer({
    required String name,
    String? address,
    String? phone,
  }) {
    return api.createCustomer(name: name, address: address, phone: phone);
  }

  @override
  Future<List<AuthUser>> listTechnicians() => api.listTechnicians();

  @override
  Future<WorkOrder> createWorkOrder({
    required String customerId,
    String? technicianId,
    required String title,
    String? description,
    required WorkOrderPriority priority,
    DateTime? scheduledAt,
  }) {
    return api.createWorkOrder(
      customerId: customerId,
      technicianId: technicianId,
      title: title,
      description: description,
      priority: priority,
      scheduledAt: scheduledAt,
    );
  }

  @override
  Future<WorkOrder> assignWorkOrder({
    required String workOrderId,
    required String technicianId,
    required int baseVersion,
  }) {
    return api.assignWorkOrder(
      workOrderId: workOrderId,
      technicianId: technicianId,
      baseVersion: baseVersion,
    );
  }
}
