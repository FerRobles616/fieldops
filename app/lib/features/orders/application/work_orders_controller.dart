import 'package:fieldops_app/core/database/fieldops_database.dart';
import 'package:fieldops_app/features/auth/application/auth_controller.dart';
import 'package:fieldops_app/features/orders/data/work_orders_api.dart';
import 'package:fieldops_app/features/orders/data/work_orders_local_store.dart';
import 'package:fieldops_app/features/orders/data/work_orders_repository.dart';
import 'package:fieldops_app/features/orders/data/work_orders_sync_service.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';
import 'package:fieldops_app/features/orders/domain/work_order_photo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final workOrdersRepositoryProvider = Provider<WorkOrdersRepository>((ref) {
  return ApiWorkOrdersRepository(
    api: WorkOrdersApi(ref.watch(apiClientProvider).dio),
  );
});

final databaseProvider = Provider<FieldOpsDatabase>((ref) {
  final database = FieldOpsDatabase.defaults();
  ref.onDispose(() {
    database.close();
  });
  return database;
});

final localStoreProvider = Provider<WorkOrdersLocalStore>((ref) {
  return WorkOrdersLocalStore(ref.watch(databaseProvider));
});

final syncServiceProvider = Provider<WorkOrdersSyncService>((ref) {
  return WorkOrdersSyncService(
    local: ref.watch(localStoreProvider),
    remote: ref.watch(workOrdersRepositoryProvider),
  );
});

final workOrdersProvider = StreamProvider<List<WorkOrder>>((ref) {
  return ref.watch(localStoreProvider).watchOrders();
});

final workOrderProvider = StreamProvider.family<WorkOrder?, String>((ref, id) {
  return ref.watch(localStoreProvider).watchOrder(id);
});

final pendingOpsCountProvider = StreamProvider<int>((ref) {
  return ref.watch(localStoreProvider).watchPendingCount();
});

final photosProvider = StreamProvider.family<List<WorkOrderPhoto>, String>((
  ref,
  workOrderId,
) {
  return ref.watch(localStoreProvider).watchPhotos(workOrderId);
});
