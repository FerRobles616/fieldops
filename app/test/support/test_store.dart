import 'package:drift/native.dart';
import 'package:fieldops_app/core/database/fieldops_database.dart';
import 'package:fieldops_app/features/orders/data/work_orders_local_store.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';

class TestStore {
  TestStore._(this.database, this.store);

  final FieldOpsDatabase database;
  final WorkOrdersLocalStore store;

  static Future<TestStore> create({List<WorkOrder> orders = const []}) async {
    final database = FieldOpsDatabase(NativeDatabase.memory());
    final store = WorkOrdersLocalStore(database);

    if (orders.isNotEmpty) {
      await store.applyRemoteChanges(orders, full: true);
    }

    return TestStore._(database, store);
  }

  Future<void> close() => database.close();
}
