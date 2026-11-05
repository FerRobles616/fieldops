import 'package:fieldops_app/features/admin/data/admin_repository.dart';
import 'package:fieldops_app/features/auth/domain/auth_models.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';

import 'work_order_fixtures.dart';

class FakeAdminRepository implements AdminRepository {
  FakeAdminRepository({this.customers = const [], this.technicians = const []});

  List<Customer> customers;
  List<AuthUser> technicians;
  Object? error;

  int listCustomersCalls = 0;
  int listTechniciansCalls = 0;
  int createCustomerCalls = 0;
  int createWorkOrderCalls = 0;
  int assignCalls = 0;

  String? lastCustomerId;
  String? lastTechnicianId;
  String? lastTitle;
  String? lastAssignedTechnicianId;
  int? lastBaseVersion;
  int _customerCounter = 0;

  @override
  Future<List<Customer>> listCustomers() async {
    listCustomersCalls++;
    if (error != null) {
      throw error!;
    }
    return customers;
  }

  @override
  Future<List<AuthUser>> listTechnicians() async {
    listTechniciansCalls++;
    if (error != null) {
      throw error!;
    }
    return technicians;
  }

  @override
  Future<Customer> createCustomer({
    required String name,
    String? address,
    String? phone,
  }) async {
    createCustomerCalls++;
    if (error != null) {
      throw error!;
    }
    _customerCounter++;
    final customer = Customer(
      id: 'customer-$_customerCounter',
      name: name,
      address: address,
      phone: phone,
    );
    customers = [...customers, customer];
    return customer;
  }

  @override
  Future<WorkOrder> createWorkOrder({
    required String customerId,
    String? technicianId,
    required String title,
    String? description,
    required WorkOrderPriority priority,
    DateTime? scheduledAt,
  }) async {
    createWorkOrderCalls++;
    lastCustomerId = customerId;
    lastTechnicianId = technicianId;
    lastTitle = title;
    if (error != null) {
      throw error!;
    }
    return buildWorkOrder(
      id: 'created-order',
      code: 'WO-NEW',
      title: title,
      priority: priority,
      scheduledAt: scheduledAt,
    );
  }

  @override
  Future<WorkOrder> assignWorkOrder({
    required String workOrderId,
    required String technicianId,
    required int baseVersion,
  }) async {
    assignCalls++;
    lastAssignedTechnicianId = technicianId;
    lastBaseVersion = baseVersion;
    if (error != null) {
      throw error!;
    }
    return buildWorkOrder();
  }
}
