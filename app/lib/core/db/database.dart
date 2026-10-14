import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class CachedLists extends Table {
  TextColumn get accountId => text()();
  TextColumn get label => text()();
  TextColumn get json => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {accountId, label};
}

class CachedThreads extends Table {
  TextColumn get accountId => text()();
  TextColumn get id => text()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {accountId, id};
}

class Drafts extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get json => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Mail waiting to be sent: the request body and how its attempts went. A row stays until the server has it.
class OutboxItems extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get json => text()();
  IntColumn get createdAt => integer()();
  IntColumn get sendAfter => integer()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get error => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [CachedLists, CachedThreads, Drafts, OutboxItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'bridgewood_mail'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(outboxItems);
    },
  );

  Future<String?> list(String accountId, String label) async =>
      (await (select(cachedLists)..where((t) => t.accountId.equals(accountId) & t.label.equals(label))).getSingleOrNull())?.json;

  Future<void> putList(String accountId, String label, String json) => into(cachedLists).insertOnConflictUpdate(
    CachedListsCompanion.insert(accountId: accountId, label: label, json: json, updatedAt: DateTime.now().millisecondsSinceEpoch),
  );

  Future<String?> thread(String accountId, String id) async =>
      (await (select(cachedThreads)..where((t) => t.accountId.equals(accountId) & t.id.equals(id))).getSingleOrNull())?.json;

  Future<void> putThread(String accountId, String id, String json) =>
      into(cachedThreads).insertOnConflictUpdate(CachedThreadsCompanion.insert(accountId: accountId, id: id, json: json));

  Future<List<Draft>> draftsFor(String accountId) =>
      (select(drafts)
            ..where((t) => t.accountId.equals(accountId))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

  Future<void> putDraft(String id, String accountId, String json) => into(drafts).insertOnConflictUpdate(
    DraftsCompanion.insert(id: id, accountId: accountId, json: json, updatedAt: DateTime.now().millisecondsSinceEpoch),
  );

  Future<void> deleteDraft(String id) => (delete(drafts)..where((t) => t.id.equals(id))).go();

  Future<List<OutboxItem>> outbox() => (select(outboxItems)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();

  Future<void> putOutbox(OutboxItemsCompanion item) => into(outboxItems).insertOnConflictUpdate(item);

  Future<void> deleteOutbox(String id) => (delete(outboxItems)..where((t) => t.id.equals(id))).go();

  Future<void> forgetAccount(String accountId) => transaction(() async {
    await (delete(cachedLists)..where((t) => t.accountId.equals(accountId))).go();
    await (delete(cachedThreads)..where((t) => t.accountId.equals(accountId))).go();
    await (delete(drafts)..where((t) => t.accountId.equals(accountId))).go();
    await (delete(outboxItems)..where((t) => t.accountId.equals(accountId))).go();
  });
}
