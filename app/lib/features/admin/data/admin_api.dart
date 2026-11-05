import 'package:dio/dio.dart';
import 'package:fieldops_app/core/network/api_exception.dart';
import 'package:fieldops_app/core/network/dio_error_mapper.dart';
import 'package:fieldops_app/features/auth/domain/auth_models.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';

class AdminApi {
  AdminApi(this._dio);

  final Dio _dio;

  Future<List<Customer>> listCustomers() async {
    try {
      final response = await _dio.get<List<dynamic>>('/customers');
      final data = response.data ?? const <dynamic>[];
      return data
          .map((item) => Customer.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<Customer> createCustomer({
    required String name,
    String? address,
    String? phone,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/customers',
        data: {
          'name': name,
          if (address != null && address.trim().isNotEmpty)
            'address': address.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        },
      );

      final data = response.data;
      if (data == null) {
        throw const ApiException('The server returned an empty response.');
      }
      return Customer.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<List<AuthUser>> listTechnicians() async {
    try {
      final response = await _dio.get<List<dynamic>>('/admin/technicians');
      final data = response.data ?? const <dynamic>[];
      return data
          .map((item) => AuthUser.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<WorkOrder> createWorkOrder({
    required String customerId,
    String? technicianId,
    required String title,
    String? description,
    required WorkOrderPriority priority,
    DateTime? scheduledAt,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/work-orders',
        data: {
          'customer_id': customerId,
          'assigned_to': ?technicianId,
          'title': title,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          'priority': priority.jsonValue,
          if (scheduledAt != null)
            'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        },
      );

      final data = response.data;
      if (data == null) {
        throw const ApiException('The server returned an empty response.');
      }
      return WorkOrder.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<WorkOrder> assignWorkOrder({
    required String workOrderId,
    required String technicianId,
    required int baseVersion,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/admin/work-orders/$workOrderId/assign',
        data: {'assigned_to': technicianId, 'base_version': baseVersion},
      );

      final data = response.data;
      if (data == null) {
        throw const ApiException('The server returned an empty response.');
      }
      return WorkOrder.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}
