// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checkout_database.dart';

// ignore_for_file: type=lint
class $CheckoutSessionRecordsTable extends CheckoutSessionRecords
    with TableInfo<$CheckoutSessionRecordsTable, CheckoutSessionRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CheckoutSessionRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [userId, payload];
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
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta, userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta, payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  CheckoutSessionRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CheckoutSessionRecord(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
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

class CheckoutSessionRecord extends DataClass implements Insertable<CheckoutSessionRecord> {
  final String userId;
  final String payload;
  const CheckoutSessionRecord({required this.userId, required this.payload});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  CheckoutSessionRecordsCompanion toCompanion(bool nullToAbsent) {
    return CheckoutSessionRecordsCompanion(userId: Value(userId), payload: Value(payload));
  }

  factory CheckoutSessionRecord.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CheckoutSessionRecord(
      userId: serializer.fromJson<String>(json['userId']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'payload': serializer.toJson<String>(payload),
    };
  }

  CheckoutSessionRecord copyWith({String? userId, String? payload}) =>
      CheckoutSessionRecord(userId: userId ?? this.userId, payload: payload ?? this.payload);
  CheckoutSessionRecord copyWithCompanion(CheckoutSessionRecordsCompanion data) {
    return CheckoutSessionRecord(
      userId: data.userId.present ? data.userId.value : this.userId,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CheckoutSessionRecord(')
          ..write('userId: $userId, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CheckoutSessionRecord &&
          other.userId == this.userId &&
          other.payload == this.payload);
}

class CheckoutSessionRecordsCompanion extends UpdateCompanion<CheckoutSessionRecord> {
  final Value<String> userId;
  final Value<String> payload;
  final Value<int> rowid;
  const CheckoutSessionRecordsCompanion({
    this.userId = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CheckoutSessionRecordsCompanion.insert({
    required String userId,
    required String payload,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       payload = Value(payload);
  static Insertable<CheckoutSessionRecord> custom({
    Expression<String>? userId,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CheckoutSessionRecordsCompanion copyWith({
    Value<String>? userId,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return CheckoutSessionRecordsCompanion(
      userId: userId ?? this.userId,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CheckoutSessionRecordsCompanion(')
          ..write('userId: $userId, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxEventsTable extends OutboxEvents with TableInfo<$OutboxEventsTable, OutboxEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta('idempotencyKey');
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationTypeMeta = const VerificationMeta('operationType');
  @override
  late final GeneratedColumn<String> operationType = GeneratedColumn<String>(
    'operation_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [userId, idempotencyKey, operationType, payload, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta, userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(data['idempotency_key']!, _idempotencyKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('operation_type')) {
      context.handle(
        _operationTypeMeta,
        operationType.isAcceptableOrUnknown(data['operation_type']!, _operationTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_operationTypeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta, payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {idempotencyKey};
  @override
  OutboxEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEvent(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      operationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_type'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OutboxEventsTable createAlias(String alias) {
    return $OutboxEventsTable(attachedDatabase, alias);
  }
}

class OutboxEvent extends DataClass implements Insertable<OutboxEvent> {
  final String userId;
  final String idempotencyKey;
  final String operationType;
  final String payload;
  final DateTime createdAt;
  const OutboxEvent({
    required this.userId,
    required this.idempotencyKey,
    required this.operationType,
    required this.payload,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['operation_type'] = Variable<String>(operationType);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OutboxEventsCompanion toCompanion(bool nullToAbsent) {
    return OutboxEventsCompanion(
      userId: Value(userId),
      idempotencyKey: Value(idempotencyKey),
      operationType: Value(operationType),
      payload: Value(payload),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxEvent.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEvent(
      userId: serializer.fromJson<String>(json['userId']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      operationType: serializer.fromJson<String>(json['operationType']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'operationType': serializer.toJson<String>(operationType),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxEvent copyWith({
    String? userId,
    String? idempotencyKey,
    String? operationType,
    String? payload,
    DateTime? createdAt,
  }) => OutboxEvent(
    userId: userId ?? this.userId,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    operationType: operationType ?? this.operationType,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
  );
  OutboxEvent copyWithCompanion(OutboxEventsCompanion data) {
    return OutboxEvent(
      userId: data.userId.present ? data.userId.value : this.userId,
      idempotencyKey: data.idempotencyKey.present ? data.idempotencyKey.value : this.idempotencyKey,
      operationType: data.operationType.present ? data.operationType.value : this.operationType,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEvent(')
          ..write('userId: $userId, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('operationType: $operationType, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, idempotencyKey, operationType, payload, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEvent &&
          other.userId == this.userId &&
          other.idempotencyKey == this.idempotencyKey &&
          other.operationType == this.operationType &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt);
}

class OutboxEventsCompanion extends UpdateCompanion<OutboxEvent> {
  final Value<String> userId;
  final Value<String> idempotencyKey;
  final Value<String> operationType;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const OutboxEventsCompanion({
    this.userId = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.operationType = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxEventsCompanion.insert({
    required String userId,
    required String idempotencyKey,
    required String operationType,
    required String payload,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       idempotencyKey = Value(idempotencyKey),
       operationType = Value(operationType),
       payload = Value(payload);
  static Insertable<OutboxEvent> custom({
    Expression<String>? userId,
    Expression<String>? idempotencyKey,
    Expression<String>? operationType,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (operationType != null) 'operation_type': operationType,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxEventsCompanion copyWith({
    Value<String>? userId,
    Value<String>? idempotencyKey,
    Value<String>? operationType,
    Value<String>? payload,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return OutboxEventsCompanion(
      userId: userId ?? this.userId,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      operationType: operationType ?? this.operationType,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEventsCompanion(')
          ..write('userId: $userId, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('operationType: $operationType, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CheckoutDatabase extends GeneratedDatabase {
  _$CheckoutDatabase(QueryExecutor e) : super(e);
  $CheckoutDatabaseManager get managers => $CheckoutDatabaseManager(this);
  late final $CheckoutSessionRecordsTable checkoutSessionRecords = $CheckoutSessionRecordsTable(
    this,
  );
  late final $OutboxEventsTable outboxEvents = $OutboxEventsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [checkoutSessionRecords, outboxEvents];
}

typedef $$CheckoutSessionRecordsTableCreateCompanionBuilder =
    CheckoutSessionRecordsCompanion Function({
      required String userId,
      required String payload,
      Value<int> rowid,
    });
typedef $$CheckoutSessionRecordsTableUpdateCompanionBuilder =
    CheckoutSessionRecordsCompanion Function({
      Value<String> userId,
      Value<String> payload,
      Value<int> rowid,
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
  ColumnFilters<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => ColumnFilters(column));
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
  ColumnOrderings<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => ColumnOrderings(column));
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
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

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
            BaseReferences<_$CheckoutDatabase, $CheckoutSessionRecordsTable, CheckoutSessionRecord>,
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
              $$CheckoutSessionRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CheckoutSessionRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CheckoutSessionRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => CheckoutSessionRecordsCompanion(userId: userId, payload: payload, rowid: rowid),
          createCompanionCallback:
              ({
                required String userId,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => CheckoutSessionRecordsCompanion.insert(
                userId: userId,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CheckoutSessionRecordsTable, CheckoutSessionRecord>(table),
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
        BaseReferences<_$CheckoutDatabase, $CheckoutSessionRecordsTable, CheckoutSessionRecord>,
      ),
      CheckoutSessionRecord,
      PrefetchHooks Function()
    >;
typedef $$OutboxEventsTableCreateCompanionBuilder = OutboxEventsCompanion Function({
  required String userId,
  required String idempotencyKey,
  required String operationType,
  required String payload,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$OutboxEventsTableUpdateCompanionBuilder = OutboxEventsCompanion Function({
  Value<String> userId,
  Value<String> idempotencyKey,
  Value<String> operationType,
  Value<String> payload,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$OutboxEventsTableFilterComposer extends Composer<_$CheckoutDatabase, $OutboxEventsTable> {
  $$OutboxEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get idempotencyKey =>
      $composableBuilder(column: $table.idempotencyKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operationType =>
      $composableBuilder(column: $table.operationType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$OutboxEventsTableOrderingComposer extends Composer<_$CheckoutDatabase, $OutboxEventsTable> {
  $$OutboxEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$OutboxEventsTableAnnotationComposer
    extends Composer<_$CheckoutDatabase, $OutboxEventsTable> {
  $$OutboxEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey =>
      $composableBuilder(column: $table.idempotencyKey, builder: (column) => column);

  GeneratedColumn<String> get operationType =>
      $composableBuilder(column: $table.operationType, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxEventsTableTableManager
    extends
        RootTableManager<
          _$CheckoutDatabase,
          $OutboxEventsTable,
          OutboxEvent,
          $$OutboxEventsTableFilterComposer,
          $$OutboxEventsTableOrderingComposer,
          $$OutboxEventsTableAnnotationComposer,
          $$OutboxEventsTableCreateCompanionBuilder,
          $$OutboxEventsTableUpdateCompanionBuilder,
          (OutboxEvent, BaseReferences<_$CheckoutDatabase, $OutboxEventsTable, OutboxEvent>),
          OutboxEvent,
          PrefetchHooks Function()
        > {
  $$OutboxEventsTableTableManager(_$CheckoutDatabase db, $OutboxEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$OutboxEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$OutboxEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<String> operationType = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxEventsCompanion(
                userId: userId,
                idempotencyKey: idempotencyKey,
                operationType: operationType,
                payload: payload,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String idempotencyKey,
                required String operationType,
                required String payload,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxEventsCompanion.insert(
                userId: userId,
                idempotencyKey: idempotencyKey,
                operationType: operationType,
                payload: payload,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxEventsTable, OutboxEvent>(table),
                  BaseReferences<_$CheckoutDatabase, $OutboxEventsTable, OutboxEvent>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$CheckoutDatabase,
      $OutboxEventsTable,
      OutboxEvent,
      $$OutboxEventsTableFilterComposer,
      $$OutboxEventsTableOrderingComposer,
      $$OutboxEventsTableAnnotationComposer,
      $$OutboxEventsTableCreateCompanionBuilder,
      $$OutboxEventsTableUpdateCompanionBuilder,
      (OutboxEvent, BaseReferences<_$CheckoutDatabase, $OutboxEventsTable, OutboxEvent>),
      OutboxEvent,
      PrefetchHooks Function()
    >;

class $CheckoutDatabaseManager {
  final _$CheckoutDatabase _db;
  $CheckoutDatabaseManager(this._db);
  $$CheckoutSessionRecordsTableTableManager get checkoutSessionRecords =>
      $$CheckoutSessionRecordsTableTableManager(_db, _db.checkoutSessionRecords);
  $$OutboxEventsTableTableManager get outboxEvents =>
      $$OutboxEventsTableTableManager(_db, _db.outboxEvents);
}
