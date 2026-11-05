import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fieldops_app/core/network/api_exception.dart';
import 'package:fieldops_app/core/network/dio_error_mapper.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';

class WorkOrdersApi {
  WorkOrdersApi(this._dio);

  final Dio _dio;

  Future<WorkOrderPage> list({
    int limit = 50,
    int offset = 0,
    WorkOrderStatus? status,
    WorkOrderPriority? priority,
    String? query,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/work-orders',
        queryParameters: {
          'limit': limit,
          'offset': offset,
          if (status != null) 'status': status.jsonValue,
          if (priority != null) 'priority': priority.jsonValue,
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        },
      );

      final data = response.data;
      if (data == null) {
        throw const ApiException('The server returned an empty response.');
      }
      return WorkOrderPage.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<WorkOrder> get(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/work-orders/$id');

      final data = response.data;
      if (data == null) {
        throw const ApiException('The server returned an empty response.');
      }
      return WorkOrder.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<WorkOrder> updateStatus({
    required String id,
    required int baseVersion,
    required WorkOrderStatus status,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/work-orders/$id',
        data: {'base_version': baseVersion, 'status': status.jsonValue},
        options: idempotencyKey == null
            ? null
            : Options(headers: {'Idempotency-Key': idempotencyKey}),
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

  Future<WorkOrderSyncPage> sync({String? since, int limit = 200}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/sync',
        queryParameters: {
          if (since != null && since.isNotEmpty) 'since': since,
          'limit': limit,
        },
      );

      final data = response.data;
      if (data == null) {
        throw const ApiException('The server returned an empty response.');
      }
      return WorkOrderSyncPage.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<String> uploadPhoto({
    required String workOrderId,
    required Uint8List bytes,
    required String filename,
    required String contentType,
    String? caption,
    String? idempotencyKey,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType.parse(contentType),
        ),
        if (caption != null && caption.trim().isNotEmpty)
          'caption': caption.trim(),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/work-orders/$workOrderId/photos',
        data: form,
        options: idempotencyKey == null
            ? null
            : Options(headers: {'Idempotency-Key': idempotencyKey}),
      );

      final data = response.data;
      if (data == null || data['id'] is! String) {
        throw const ApiException('The server returned an invalid photo.');
      }
      return data['id'] as String;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<Uint8List> downloadReport(String workOrderId) async {
    try {
      final response = await _dio.get<List<int>>(
        '/work-orders/$workOrderId/report.pdf',
        options: Options(responseType: ResponseType.bytes),
      );

      final data = response.data;
      if (data == null || data.isEmpty) {
        throw const ApiException('The server returned an empty report.');
      }
      return Uint8List.fromList(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}
