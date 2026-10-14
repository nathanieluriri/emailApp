// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CachedListsTable extends CachedLists with TableInfo<$CachedListsTable, CachedList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [accountId, label, json, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_lists';
  @override
  VerificationContext validateIntegrity(Insertable<CachedList> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta, accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(_labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('json')) {
      context.handle(_jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta, updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, label};
  @override
  CachedList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedList(
      accountId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      label: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}label'])!,
      json: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}json'])!,
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CachedListsTable createAlias(String alias) {
    return $CachedListsTable(attachedDatabase, alias);
  }
}

class CachedList extends DataClass implements Insertable<CachedList> {
  final String accountId;
  final String label;
  final String json;
  final int updatedAt;
  const CachedList({required this.accountId, required this.label, required this.json, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['label'] = Variable<String>(label);
    map['json'] = Variable<String>(json);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  CachedListsCompanion toCompanion(bool nullToAbsent) {
    return CachedListsCompanion(accountId: Value(accountId), label: Value(label), json: Value(json), updatedAt: Value(updatedAt));
  }

  factory CachedList.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedList(
      accountId: serializer.fromJson<String>(json['accountId']),
      label: serializer.fromJson<String>(json['label']),
      json: serializer.fromJson<String>(json['json']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'label': serializer.toJson<String>(label),
      'json': serializer.toJson<String>(json),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  CachedList copyWith({String? accountId, String? label, String? json, int? updatedAt}) => CachedList(
    accountId: accountId ?? this.accountId,
    label: label ?? this.label,
    json: json ?? this.json,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CachedList copyWithCompanion(CachedListsCompanion data) {
    return CachedList(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      label: data.label.present ? data.label.value : this.label,
      json: data.json.present ? data.json.value : this.json,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedList(')
          ..write('accountId: $accountId, ')
          ..write('label: $label, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, label, json, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedList &&
          other.accountId == this.accountId &&
          other.label == this.label &&
          other.json == this.json &&
          other.updatedAt == this.updatedAt);
}

class CachedListsCompanion extends UpdateCompanion<CachedList> {
  final Value<String> accountId;
  final Value<String> label;
  final Value<String> json;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const CachedListsCompanion({
    this.accountId = const Value.absent(),
    this.label = const Value.absent(),
    this.json = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedListsCompanion.insert({
    required String accountId,
    required String label,
    required String json,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       label = Value(label),
       json = Value(json),
       updatedAt = Value(updatedAt);
  static Insertable<CachedList> custom({
    Expression<String>? accountId,
    Expression<String>? label,
    Expression<String>? json,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (label != null) 'label': label,
      if (json != null) 'json': json,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedListsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? label,
    Value<String>? json,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return CachedListsCompanion(
      accountId: accountId ?? this.accountId,
      label: label ?? this.label,
      json: json ?? this.json,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedListsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('label: $label, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedThreadsTable extends CachedThreads with TableInfo<$CachedThreadsTable, CachedThread> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedThreadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [accountId, id, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_threads';
  @override
  VerificationContext validateIntegrity(Insertable<CachedThread> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta, accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('json')) {
      context.handle(_jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, id};
  @override
  CachedThread map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedThread(
      accountId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      json: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}json'])!,
    );
  }

  @override
  $CachedThreadsTable createAlias(String alias) {
    return $CachedThreadsTable(attachedDatabase, alias);
  }
}

class CachedThread extends DataClass implements Insertable<CachedThread> {
  final String accountId;
  final String id;
  final String json;
  const CachedThread({required this.accountId, required this.id, required this.json});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['id'] = Variable<String>(id);
    map['json'] = Variable<String>(json);
    return map;
  }

  CachedThreadsCompanion toCompanion(bool nullToAbsent) {
    return CachedThreadsCompanion(accountId: Value(accountId), id: Value(id), json: Value(json));
  }

  factory CachedThread.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedThread(
      accountId: serializer.fromJson<String>(json['accountId']),
      id: serializer.fromJson<String>(json['id']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'id': serializer.toJson<String>(id),
      'json': serializer.toJson<String>(json),
    };
  }

  CachedThread copyWith({String? accountId, String? id, String? json}) =>
      CachedThread(accountId: accountId ?? this.accountId, id: id ?? this.id, json: json ?? this.json);
  CachedThread copyWithCompanion(CachedThreadsCompanion data) {
    return CachedThread(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      id: data.id.present ? data.id.value : this.id,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedThread(')
          ..write('accountId: $accountId, ')
          ..write('id: $id, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, id, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedThread && other.accountId == this.accountId && other.id == this.id && other.json == this.json);
}

class CachedThreadsCompanion extends UpdateCompanion<CachedThread> {
  final Value<String> accountId;
  final Value<String> id;
  final Value<String> json;
  final Value<int> rowid;
  const CachedThreadsCompanion({
    this.accountId = const Value.absent(),
    this.id = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedThreadsCompanion.insert({required String accountId, required String id, required String json, this.rowid = const Value.absent()})
    : accountId = Value(accountId),
      id = Value(id),
      json = Value(json);
  static Insertable<CachedThread> custom({
    Expression<String>? accountId,
    Expression<String>? id,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (id != null) 'id': id,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedThreadsCompanion copyWith({Value<String>? accountId, Value<String>? id, Value<String>? json, Value<int>? rowid}) {
    return CachedThreadsCompanion(
      accountId: accountId ?? this.accountId,
      id: id ?? this.id,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedThreadsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DraftsTable extends Drafts with TableInfo<$DraftsTable, Draft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, accountId, json, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drafts';
  @override
  VerificationContext validateIntegrity(Insertable<Draft> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta, accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('json')) {
      context.handle(_jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta, updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Draft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Draft(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      accountId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      json: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}json'])!,
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $DraftsTable createAlias(String alias) {
    return $DraftsTable(attachedDatabase, alias);
  }
}

class Draft extends DataClass implements Insertable<Draft> {
  final String id;
  final String accountId;
  final String json;
  final int updatedAt;
  const Draft({required this.id, required this.accountId, required this.json, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['json'] = Variable<String>(json);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  DraftsCompanion toCompanion(bool nullToAbsent) {
    return DraftsCompanion(id: Value(id), accountId: Value(accountId), json: Value(json), updatedAt: Value(updatedAt));
  }

  factory Draft.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Draft(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      json: serializer.fromJson<String>(json['json']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'json': serializer.toJson<String>(json),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Draft copyWith({String? id, String? accountId, String? json, int? updatedAt}) =>
      Draft(id: id ?? this.id, accountId: accountId ?? this.accountId, json: json ?? this.json, updatedAt: updatedAt ?? this.updatedAt);
  Draft copyWithCompanion(DraftsCompanion data) {
    return Draft(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      json: data.json.present ? data.json.value : this.json,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Draft(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, accountId, json, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Draft &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.json == this.json &&
          other.updatedAt == this.updatedAt);
}

class DraftsCompanion extends UpdateCompanion<Draft> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> json;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const DraftsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.json = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DraftsCompanion.insert({
    required String id,
    required String accountId,
    required String json,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       json = Value(json),
       updatedAt = Value(updatedAt);
  static Insertable<Draft> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? json,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (json != null) 'json': json,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DraftsCompanion copyWith({Value<String>? id, Value<String>? accountId, Value<String>? json, Value<int>? updatedAt, Value<int>? rowid}) {
    return DraftsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      json: json ?? this.json,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedListsTable cachedLists = $CachedListsTable(this);
  late final $CachedThreadsTable cachedThreads = $CachedThreadsTable(this);
  late final $DraftsTable drafts = $DraftsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cachedLists, cachedThreads, drafts];
}

typedef $$CachedListsTableCreateCompanionBuilder = CachedListsCompanion Function({
  required String accountId,
  required String label,
  required String json,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$CachedListsTableUpdateCompanionBuilder = CachedListsCompanion Function({
  Value<String> accountId,
  Value<String> label,
  Value<String> json,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$CachedListsTableFilterComposer extends Composer<_$AppDatabase, $CachedListsTable> {
  $$CachedListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label => $composableBuilder(column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(column: $table.json, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedListsTableOrderingComposer extends Composer<_$AppDatabase, $CachedListsTable> {
  $$CachedListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(column: $table.json, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedListsTableAnnotationComposer extends Composer<_$AppDatabase, $CachedListsTable> {
  $$CachedListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId => $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get label => $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get json => $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<int> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CachedListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedListsTable,
          CachedList,
          $$CachedListsTableFilterComposer,
          $$CachedListsTableOrderingComposer,
          $$CachedListsTableAnnotationComposer,
          $$CachedListsTableCreateCompanionBuilder,
          $$CachedListsTableUpdateCompanionBuilder,
          (CachedList, BaseReferences<_$AppDatabase, $CachedListsTable, CachedList>),
          CachedList,
          PrefetchHooks Function()
        > {
  $$CachedListsTableTableManager(_$AppDatabase db, $CachedListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CachedListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CachedListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CachedListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> accountId = const Value.absent(),
            Value<String> label = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => CachedListsCompanion(accountId: accountId, label: label, json: json, updatedAt: updatedAt, rowid: rowid),
          createCompanionCallback: ({
            required String accountId,
            required String label,
            required String json,
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) => CachedListsCompanion.insert(accountId: accountId, label: label, json: json, updatedAt: updatedAt, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedListsTable, CachedList>(table),
                  BaseReferences<_$AppDatabase, $CachedListsTable, CachedList>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedListsTable,
      CachedList,
      $$CachedListsTableFilterComposer,
      $$CachedListsTableOrderingComposer,
      $$CachedListsTableAnnotationComposer,
      $$CachedListsTableCreateCompanionBuilder,
      $$CachedListsTableUpdateCompanionBuilder,
      (CachedList, BaseReferences<_$AppDatabase, $CachedListsTable, CachedList>),
      CachedList,
      PrefetchHooks Function()
    >;
typedef $$CachedThreadsTableCreateCompanionBuilder = CachedThreadsCompanion Function({
  required String accountId,
  required String id,
  required String json,
  Value<int> rowid,
});
typedef $$CachedThreadsTableUpdateCompanionBuilder = CachedThreadsCompanion Function({
  Value<String> accountId,
  Value<String> id,
  Value<String> json,
  Value<int> rowid,
});

class $$CachedThreadsTableFilterComposer extends Composer<_$AppDatabase, $CachedThreadsTable> {
  $$CachedThreadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(column: $table.json, builder: (column) => ColumnFilters(column));
}

class $$CachedThreadsTableOrderingComposer extends Composer<_$AppDatabase, $CachedThreadsTable> {
  $$CachedThreadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(column: $table.json, builder: (column) => ColumnOrderings(column));
}

class $$CachedThreadsTableAnnotationComposer extends Composer<_$AppDatabase, $CachedThreadsTable> {
  $$CachedThreadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId => $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get json => $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$CachedThreadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedThreadsTable,
          CachedThread,
          $$CachedThreadsTableFilterComposer,
          $$CachedThreadsTableOrderingComposer,
          $$CachedThreadsTableAnnotationComposer,
          $$CachedThreadsTableCreateCompanionBuilder,
          $$CachedThreadsTableUpdateCompanionBuilder,
          (CachedThread, BaseReferences<_$AppDatabase, $CachedThreadsTable, CachedThread>),
          CachedThread,
          PrefetchHooks Function()
        > {
  $$CachedThreadsTableTableManager(_$AppDatabase db, $CachedThreadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CachedThreadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CachedThreadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CachedThreadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> accountId = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => CachedThreadsCompanion(accountId: accountId, id: id, json: json, rowid: rowid),
          createCompanionCallback: ({
            required String accountId,
            required String id,
            required String json,
            Value<int> rowid = const Value.absent(),
          }) => CachedThreadsCompanion.insert(accountId: accountId, id: id, json: json, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedThreadsTable, CachedThread>(table),
                  BaseReferences<_$AppDatabase, $CachedThreadsTable, CachedThread>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedThreadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedThreadsTable,
      CachedThread,
      $$CachedThreadsTableFilterComposer,
      $$CachedThreadsTableOrderingComposer,
      $$CachedThreadsTableAnnotationComposer,
      $$CachedThreadsTableCreateCompanionBuilder,
      $$CachedThreadsTableUpdateCompanionBuilder,
      (CachedThread, BaseReferences<_$AppDatabase, $CachedThreadsTable, CachedThread>),
      CachedThread,
      PrefetchHooks Function()
    >;
typedef $$DraftsTableCreateCompanionBuilder = DraftsCompanion Function({
  required String id,
  required String accountId,
  required String json,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$DraftsTableUpdateCompanionBuilder = DraftsCompanion Function({
  Value<String> id,
  Value<String> accountId,
  Value<String> json,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$DraftsTableFilterComposer extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(column: $table.json, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$DraftsTableOrderingComposer extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(column: $table.json, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$DraftsTableAnnotationComposer extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountId => $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get json => $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<int> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DraftsTable,
          Draft,
          $$DraftsTableFilterComposer,
          $$DraftsTableOrderingComposer,
          $$DraftsTableAnnotationComposer,
          $$DraftsTableCreateCompanionBuilder,
          $$DraftsTableUpdateCompanionBuilder,
          (Draft, BaseReferences<_$AppDatabase, $DraftsTable, Draft>),
          Draft,
          PrefetchHooks Function()
        > {
  $$DraftsTableTableManager(_$AppDatabase db, $DraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$DraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$DraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$DraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => DraftsCompanion(id: id, accountId: accountId, json: json, updatedAt: updatedAt, rowid: rowid),
          createCompanionCallback: ({
            required String id,
            required String accountId,
            required String json,
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) => DraftsCompanion.insert(id: id, accountId: accountId, json: json, updatedAt: updatedAt, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable<$DraftsTable, Draft>(table), BaseReferences<_$AppDatabase, $DraftsTable, Draft>(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DraftsTable,
      Draft,
      $$DraftsTableFilterComposer,
      $$DraftsTableOrderingComposer,
      $$DraftsTableAnnotationComposer,
      $$DraftsTableCreateCompanionBuilder,
      $$DraftsTableUpdateCompanionBuilder,
      (Draft, BaseReferences<_$AppDatabase, $DraftsTable, Draft>),
      Draft,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedListsTableTableManager get cachedLists => $$CachedListsTableTableManager(_db, _db.cachedLists);
  $$CachedThreadsTableTableManager get cachedThreads => $$CachedThreadsTableTableManager(_db, _db.cachedThreads);
  $$DraftsTableTableManager get drafts => $$DraftsTableTableManager(_db, _db.drafts);
}
