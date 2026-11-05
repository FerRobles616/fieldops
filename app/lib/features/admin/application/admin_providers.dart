import 'package:fieldops_app/features/admin/data/admin_api.dart';
import 'package:fieldops_app/features/admin/data/admin_repository.dart';
import 'package:fieldops_app/features/auth/application/auth_controller.dart';
import 'package:fieldops_app/features/auth/domain/auth_models.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return ApiAdminRepository(api: AdminApi(ref.watch(apiClientProvider).dio));
});

final customersProvider = FutureProvider<List<Customer>>((ref) {
  return ref.watch(adminRepositoryProvider).listCustomers();
});

final techniciansProvider = FutureProvider<List<AuthUser>>((ref) {
  return ref.watch(adminRepositoryProvider).listTechnicians();
});
