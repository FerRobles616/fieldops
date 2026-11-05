import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fieldops_app/features/admin/data/admin_api.dart';
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
  String title = 'Install panel',
  String? assignedTo = 'tech-1',
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
    'assigned_to': assignedTo == null
        ? null
        : {
            'id': assignedTo,
            'email': 'tech@fieldops.dev',
            'name': 'Tech Demo',
            'role': 'technician',
          },
    'title': title,
    'description': 'Check the unit.',
    'status': 'pending',
    'priority': 'high',
    'scheduled_at': null,
    'version': 1,
    'created_at': '2026-11-04T10:00:00Z',
    'updated_at': '2026-11-04T11:00:00Z',
  };
}

void main() {
  test('creates a work order with the admin payload', () async {
    RequestOptions? captured;
    final api = AdminApi(
      _dioReturning((options) {
        captured = options;
        return _json(_workOrderJson(), 201);
      }),
    );

    final order = await api.createWorkOrder(
      customerId: 'customer-1',
      technicianId: 'tech-1',
      title: 'Install panel',
      description: 'Install and test.',
      priority: WorkOrderPriority.high,
      scheduledAt: DateTime.utc(2026, 11, 10, 9),
    );

    expect(captured?.path, '/work-orders');
    expect(captured?.method, 'POST');
    final body = captured?.data as Map<String, dynamic>;
    expect(body['customer_id'], 'customer-1');
    expect(body['assigned_to'], 'tech-1');
    expect(body['title'], 'Install panel');
    expect(body['priority'], 'high');
    expect(body['scheduled_at'], '2026-11-10T09:00:00.000Z');
    expect(order.title, 'Install panel');
  });

  test('assigns a work order with the base version', () async {
    RequestOptions? captured;
    final api = AdminApi(
      _dioReturning((options) {
        captured = options;
        return _json(_workOrderJson(), 200);
      }),
    );

    await api.assignWorkOrder(
      workOrderId: 'order-1',
      technicianId: 'tech-2',
      baseVersion: 3,
    );

    expect(captured?.path, '/admin/work-orders/order-1/assign');
    expect(captured?.method, 'PATCH');
    expect(captured?.data, {'assigned_to': 'tech-2', 'base_version': 3});
  });

  test('lists customers and technicians', () async {
    final api = AdminApi(
      _dioReturning((options) {
        if (options.path == '/customers') {
          return _json([
            {
              'id': 'customer-1',
              'name': 'Acme',
              'address': '1 Main St',
              'phone': '555-0100',
            },
          ], 200);
        }
        return _json([
          {
            'id': 'user-1',
            'email': 'tech@fieldops.dev',
            'name': 'Tech Demo',
            'role': 'technician',
          },
        ], 200);
      }),
    );

    final customers = await api.listCustomers();
    final technicians = await api.listTechnicians();

    expect(customers.single.name, 'Acme');
    expect(technicians.single.role.name, 'technician');
  });

  test('creates a customer', () async {
    RequestOptions? captured;
    final api = AdminApi(
      _dioReturning((options) {
        captured = options;
        return _json({
          'id': 'customer-2',
          'name': 'New Co',
          'address': '2 Main St',
          'phone': '555-0199',
        }, 201);
      }),
    );

    final customer = await api.createCustomer(
      name: 'New Co',
      address: '2 Main St',
      phone: '555-0199',
    );

    expect(captured?.path, '/customers');
    expect(captured?.data, {
      'name': 'New Co',
      'address': '2 Main St',
      'phone': '555-0199',
    });
    expect(customer.name, 'New Co');
  });
}
