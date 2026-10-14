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

@DriftDatabase(tables: [CachedLists, CachedThreads, Drafts])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'bridgewood_mail'));

  @override
  int get schemaVersion => 1;

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

  Future<void> forgetAccount(String accountId) => transaction(() async {
    await (delete(cachedLists)..where((t) => t.accountId.equals(accountId))).go();
    await (delete(cachedThreads)..where((t) => t.accountId.equals(accountId))).go();
    await (delete(drafts)..where((t) => t.accountId.equals(accountId))).go();
  });
}
