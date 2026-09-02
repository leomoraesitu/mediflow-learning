// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checkout_database.dart';

// ignore_for_file: type=lint
class $CheckoutSessionRecordsTable extends CheckoutSessionRecords
    with TableInfo<$CheckoutSessionRecordsTable, CheckoutSessionRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CheckoutSessionRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'checkout_session_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<CheckoutSessionRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CheckoutSessionRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CheckoutSessionRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $CheckoutSessionRecordsTable createAlias(String alias) {
    return $CheckoutSessionRecordsTable(attachedDatabase, alias);
  }
}

class CheckoutSessionRecord extends DataClass
    implements Insertable<CheckoutSessionRecord> {
  final int id;
  final String payload;
  const CheckoutSessionRecord({required this.id, required this.payload});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  CheckoutSessionRecordsCompanion toCompanion(bool nullToAbsent) {
    return CheckoutSessionRecordsCompanion(
      id: Value(id),
      payload: Value(payload),
    );
  }

  factory CheckoutSessionRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CheckoutSessionRecord(
      id: serializer.fromJson<int>(json['id']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'payload': serializer.toJson<String>(payload),
    };
  }

  CheckoutSessionRecord copyWith({int? id, String? payload}) =>
      CheckoutSessionRecord(
        id: id ?? this.id,
        payload: payload ?? this.payload,
      );
  CheckoutSessionRecord copyWithCompanion(
    CheckoutSessionRecordsCompanion data,
  ) {
    return CheckoutSessionRecord(
      id: data.id.present ? data.id.value : this.id,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CheckoutSessionRecord(')
          ..write('id: $id, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CheckoutSessionRecord &&
          other.id == this.id &&
          other.payload == this.payload);
}

class CheckoutSessionRecordsCompanion
    extends UpdateCompanion<CheckoutSessionRecord> {
  final Value<int> id;
  final Value<String> payload;
  const CheckoutSessionRecordsCompanion({
    this.id = const Value.absent(),
    this.payload = const Value.absent(),
  });
  CheckoutSessionRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String payload,
  }) : payload = Value(payload);
  static Insertable<CheckoutSessionRecord> custom({
    Expression<int>? id,
    Expression<String>? payload,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (payload != null) 'payload': payload,
    });
  }

  CheckoutSessionRecordsCompanion copyWith({
    Value<int>? id,
    Value<String>? payload,
  }) {
    return CheckoutSessionRecordsCompanion(
      id: id ?? this.id,
      payload: payload ?? this.payload,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CheckoutSessionRecordsCompanion(')
          ..write('id: $id, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }
}

abstract class _$CheckoutDatabase extends GeneratedDatabase {
  _$CheckoutDatabase(QueryExecutor e) : super(e);
  $CheckoutDatabaseManager get managers => $CheckoutDatabaseManager(this);
  late final $CheckoutSessionRecordsTable checkoutSessionRecords =
      $CheckoutSessionRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [checkoutSessionRecords];
}

typedef $$CheckoutSessionRecordsTableCreateCompanionBuilder =
    CheckoutSessionRecordsCompanion Function({
      Value<int> id,
      required String payload,
    });
typedef $$CheckoutSessionRecordsTableUpdateCompanionBuilder =
    CheckoutSessionRecordsCompanion Function({
      Value<int> id,
      Value<String> payload,
    });

class $$CheckoutSessionRecordsTableFilterComposer
    extends Composer<_$CheckoutDatabase, $CheckoutSessionRecordsTable> {
  $$CheckoutSessionRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CheckoutSessionRecordsTableOrderingComposer
    extends Composer<_$CheckoutDatabase, $CheckoutSessionRecordsTable> {
  $$CheckoutSessionRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CheckoutSessionRecordsTableAnnotationComposer
    extends Composer<_$CheckoutDatabase, $CheckoutSessionRecordsTable> {
  $$CheckoutSessionRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$CheckoutSessionRecordsTableTableManager
    extends
        RootTableManager<
          _$CheckoutDatabase,
          $CheckoutSessionRecordsTable,
          CheckoutSessionRecord,
          $$CheckoutSessionRecordsTableFilterComposer,
          $$CheckoutSessionRecordsTableOrderingComposer,
          $$CheckoutSessionRecordsTableAnnotationComposer,
          $$CheckoutSessionRecordsTableCreateCompanionBuilder,
          $$CheckoutSessionRecordsTableUpdateCompanionBuilder,
          (
            CheckoutSessionRecord,
            BaseReferences<
              _$CheckoutDatabase,
              $CheckoutSessionRecordsTable,
              CheckoutSessionRecord
            >,
          ),
          CheckoutSessionRecord,
          PrefetchHooks Function()
        > {
  $$CheckoutSessionRecordsTableTableManager(
    _$CheckoutDatabase db,
    $CheckoutSessionRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CheckoutSessionRecordsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CheckoutSessionRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CheckoutSessionRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> payload = const Value.absent(),
          }) => CheckoutSessionRecordsCompanion(id: id, payload: payload),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String payload,
              }) => CheckoutSessionRecordsCompanion.insert(
                id: id,
                payload: payload,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $CheckoutSessionRecordsTable,
                    CheckoutSessionRecord
                  >(table),
                  BaseReferences<
                    _$CheckoutDatabase,
                    $CheckoutSessionRecordsTable,
                    CheckoutSessionRecord
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CheckoutSessionRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$CheckoutDatabase,
      $CheckoutSessionRecordsTable,
      CheckoutSessionRecord,
      $$CheckoutSessionRecordsTableFilterComposer,
      $$CheckoutSessionRecordsTableOrderingComposer,
      $$CheckoutSessionRecordsTableAnnotationComposer,
      $$CheckoutSessionRecordsTableCreateCompanionBuilder,
      $$CheckoutSessionRecordsTableUpdateCompanionBuilder,
      (
        CheckoutSessionRecord,
        BaseReferences<
          _$CheckoutDatabase,
          $CheckoutSessionRecordsTable,
          CheckoutSessionRecord
        >,
      ),
      CheckoutSessionRecord,
      PrefetchHooks Function()
    >;

class $CheckoutDatabaseManager {
  final _$CheckoutDatabase _db;
  $CheckoutDatabaseManager(this._db);
  $$CheckoutSessionRecordsTableTableManager get checkoutSessionRecords =>
      $$CheckoutSessionRecordsTableTableManager(
        _db,
        _db.checkoutSessionRecords,
      );
}
