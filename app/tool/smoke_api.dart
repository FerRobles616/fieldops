import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fieldops_app/core/network/api_exception.dart';
import 'package:fieldops_app/features/auth/data/auth_api.dart';
import 'package:fieldops_app/features/orders/data/work_orders_api.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';

Future<void> main(List<String> args) async {
  final baseUrl = args.isNotEmpty ? args.first : 'http://localhost:8000';
  final dio = Dio(BaseOptions(baseUrl: baseUrl));

  final session = await AuthApi(dio).login(
    email: 'tech@fieldops.dev',
    password: 'tech1234',
  );
  dio.options.headers['Authorization'] = 'Bearer ${session.token}';

  final workOrdersApi = WorkOrdersApi(dio);
  final page = await workOrdersApi.list();

  stdout.writeln(
    'Logged in as ${session.user.email}; '
    'loaded ${page.total} work orders.',
  );

  if (page.items.isEmpty) {
    return;
  }

  final order = page.items.first;
  stdout.writeln(
    'Updating ${order.code} from version ${order.version}...',
  );

  final updated = await workOrdersApi.updateStatus(
    id: order.id,
    baseVersion: order.version,
    status: WorkOrderStatus.inProgress,
  );
  stdout.writeln(
    'Updated ${updated.code} to ${updated.status.label} '
    '(version ${updated.version}).',
  );

  try {
    await workOrdersApi.updateStatus(
      id: order.id,
      baseVersion: order.version,
      status: WorkOrderStatus.done,
    );
  } on ApiException catch (error) {
    stdout.writeln(
      'Expected stale-version error: ${error.statusCode} ${error.message}',
    );
  }
}
