import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fieldops_app/core/network/api_exception.dart';
import 'package:fieldops_app/features/orders/data/work_orders_api.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioReturning(ResponseBody Function(RequestOptions options) handler) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
  dio.httpClientAdapter = _FakeAdapter(handler);
  return dio;
}

ResponseBody _json(Object body, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Map<String, dynamic> _workOrderJson({
  String status = 'pending',
  int version = 1,
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
    'assigned_to': {
      'id': 'user-1',
      'email': 'tech@fieldops.dev',
      'name': 'Tech Demo',
      'role': 'technician',
    },
    'title': 'Fix HVAC',
    'description': 'Check the unit.',
    'status': status,
    'priority': 'high',
    'scheduled_at': null,
    'version': version,
    'created_at': '2026-11-04T10:00:00Z',
    'updated_at': '2026-11-04T11:00:00Z',
  };
}

void main() {
  test('lists work orders with filters', () async {
    RequestOptions? captured;
    final api = WorkOrdersApi(
      _dioReturning((options) {
        captured = options;
        return _json({
          'items': [_workOrderJson()],
          'total': 1,
          'limit': 20,
          'offset': 0,
        }, 200);
      }),
    );

    final page = await api.list(
      status: WorkOrderStatus.pending,
      priority: WorkOrderPriority.high,
      query: 'HVAC',
    );

    expect(page.items, hasLength(1));
    expect(page.items.first.title, 'Fix HVAC');
    expect(captured?.path, '/work-orders');
    expect(captured?.queryParameters['status'], 'pending');
    expect(captured?.queryParameters['priority'], 'high');
    expect(captured?.queryParameters['q'], 'HVAC');
  });

  test('updates a work order status with the base version', () async {
    RequestOptions? captured;
    final api = WorkOrdersApi(
      _dioReturning((options) {
        captured = options;
        return _json(_workOrderJson(status: 'in_progress', version: 2), 200);
      }),
    );

    final updated = await api.updateStatus(
      id: 'order-1',
      baseVersion: 1,
      status: WorkOrderStatus.inProgress,
    );

    expect(updated.status, WorkOrderStatus.inProgress);
    expect(updated.version, 2);
    expect(captured?.method, 'PATCH');
    expect(captured?.path, '/work-orders/order-1');
    expect(captured?.data, {'base_version': 1, 'status': 'in_progress'});
  });

  test('maps a version conflict to a friendly error', () async {
    final api = WorkOrdersApi(
      _dioReturning((options) => _json({'detail': 'Version conflict'}, 409)),
    );

    expect(
      () => api.updateStatus(
        id: 'order-1',
        baseVersion: 1,
        status: WorkOrderStatus.done,
      ),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 409)
            .having(
              (error) => error.message,
              'message',
              contains('changed on the server'),
            ),
      ),
    );
  });
}
