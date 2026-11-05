import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'fieldops_database.g.dart';

class CachedWorkOrders extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get customerId => text()();
  TextColumn get customerName => text()();
  TextColumn get customerAddress => text().nullable()();
  TextColumn get customerPhone => text().nullable()();
  TextColumn get assignedToId => text().nullable()();
  TextColumn get assignedToName => text().nullable()();
  TextColumn get assignedToEmail => text().nullable()();
  TextColumn get assignedToRole => text().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text()();
  TextColumn get priority => text()();
  DateTimeColumn get scheduledAt => dateTime().nullable()();
  IntColumn get version => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class OutboxOperations extends Table {
  TextColumn get id => text()();
  TextColumn get workOrderId => text()();
  TextColumn get type => text()();
  TextColumn get payload => text()();
  IntColumn get baseVersion => integer()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get nextAttemptAt => dateTime()();
  TextColumn get state => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class CachedPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get workOrderId => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get caption => text().nullable()();
  TextColumn get contentType => text()();
  BlobColumn get bytes => blob()();
  TextColumn get state => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [CachedWorkOrders, OutboxOperations, SyncMetadata, CachedPhotos],
)
class FieldOpsDatabase extends _$FieldOpsDatabase {
  FieldOpsDatabase(super.e);

  FieldOpsDatabase.defaults()
    : super(
        driftDatabase(
          name: 'fieldops',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(cachedPhotos);
      }
    },
  );
}
