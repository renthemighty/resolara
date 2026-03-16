// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $VisualizationsTable extends Visualizations
    with TableInfo<$VisualizationsTable, Visualization> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VisualizationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _jobIdMeta = const VerificationMeta('jobId');
  @override
  late final GeneratedColumn<String> jobId = GeneratedColumn<String>(
    'job_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyRegionsMeta = const VerificationMeta(
    'bodyRegions',
  );
  @override
  late final GeneratedColumn<String> bodyRegions = GeneratedColumn<String>(
    'body_regions',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _findingCountMeta = const VerificationMeta(
    'findingCount',
  );
  @override
  late final GeneratedColumn<int> findingCount = GeneratedColumn<int>(
    'finding_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retainUntilMeta = const VerificationMeta(
    'retainUntil',
  );
  @override
  late final GeneratedColumn<int> retainUntil = GeneratedColumn<int>(
    'retain_until',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    jobId,
    imagePath,
    createdAt,
    bodyRegions,
    findingCount,
    retainUntil,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'visualizations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Visualization> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('job_id')) {
      context.handle(
        _jobIdMeta,
        jobId.isAcceptableOrUnknown(data['job_id']!, _jobIdMeta),
      );
    } else if (isInserting) {
      context.missing(_jobIdMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('body_regions')) {
      context.handle(
        _bodyRegionsMeta,
        bodyRegions.isAcceptableOrUnknown(
          data['body_regions']!,
          _bodyRegionsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bodyRegionsMeta);
    }
    if (data.containsKey('finding_count')) {
      context.handle(
        _findingCountMeta,
        findingCount.isAcceptableOrUnknown(
          data['finding_count']!,
          _findingCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_findingCountMeta);
    }
    if (data.containsKey('retain_until')) {
      context.handle(
        _retainUntilMeta,
        retainUntil.isAcceptableOrUnknown(
          data['retain_until']!,
          _retainUntilMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Visualization map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Visualization(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      jobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_id'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      bodyRegions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_regions'],
      )!,
      findingCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}finding_count'],
      )!,
      retainUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retain_until'],
      ),
    );
  }

  @override
  $VisualizationsTable createAlias(String alias) {
    return $VisualizationsTable(attachedDatabase, alias);
  }
}

class Visualization extends DataClass implements Insertable<Visualization> {
  final int id;
  final String jobId;
  final String imagePath;
  final int createdAt;
  final String bodyRegions;
  final int findingCount;
  final int? retainUntil;
  const Visualization({
    required this.id,
    required this.jobId,
    required this.imagePath,
    required this.createdAt,
    required this.bodyRegions,
    required this.findingCount,
    this.retainUntil,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['job_id'] = Variable<String>(jobId);
    map['image_path'] = Variable<String>(imagePath);
    map['created_at'] = Variable<int>(createdAt);
    map['body_regions'] = Variable<String>(bodyRegions);
    map['finding_count'] = Variable<int>(findingCount);
    if (!nullToAbsent || retainUntil != null) {
      map['retain_until'] = Variable<int>(retainUntil);
    }
    return map;
  }

  VisualizationsCompanion toCompanion(bool nullToAbsent) {
    return VisualizationsCompanion(
      id: Value(id),
      jobId: Value(jobId),
      imagePath: Value(imagePath),
      createdAt: Value(createdAt),
      bodyRegions: Value(bodyRegions),
      findingCount: Value(findingCount),
      retainUntil: retainUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(retainUntil),
    );
  }

  factory Visualization.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Visualization(
      id: serializer.fromJson<int>(json['id']),
      jobId: serializer.fromJson<String>(json['jobId']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      bodyRegions: serializer.fromJson<String>(json['bodyRegions']),
      findingCount: serializer.fromJson<int>(json['findingCount']),
      retainUntil: serializer.fromJson<int?>(json['retainUntil']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'jobId': serializer.toJson<String>(jobId),
      'imagePath': serializer.toJson<String>(imagePath),
      'createdAt': serializer.toJson<int>(createdAt),
      'bodyRegions': serializer.toJson<String>(bodyRegions),
      'findingCount': serializer.toJson<int>(findingCount),
      'retainUntil': serializer.toJson<int?>(retainUntil),
    };
  }

  Visualization copyWith({
    int? id,
    String? jobId,
    String? imagePath,
    int? createdAt,
    String? bodyRegions,
    int? findingCount,
    Value<int?> retainUntil = const Value.absent(),
  }) => Visualization(
    id: id ?? this.id,
    jobId: jobId ?? this.jobId,
    imagePath: imagePath ?? this.imagePath,
    createdAt: createdAt ?? this.createdAt,
    bodyRegions: bodyRegions ?? this.bodyRegions,
    findingCount: findingCount ?? this.findingCount,
    retainUntil: retainUntil.present ? retainUntil.value : this.retainUntil,
  );
  Visualization copyWithCompanion(VisualizationsCompanion data) {
    return Visualization(
      id: data.id.present ? data.id.value : this.id,
      jobId: data.jobId.present ? data.jobId.value : this.jobId,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      bodyRegions: data.bodyRegions.present
          ? data.bodyRegions.value
          : this.bodyRegions,
      findingCount: data.findingCount.present
          ? data.findingCount.value
          : this.findingCount,
      retainUntil: data.retainUntil.present
          ? data.retainUntil.value
          : this.retainUntil,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Visualization(')
          ..write('id: $id, ')
          ..write('jobId: $jobId, ')
          ..write('imagePath: $imagePath, ')
          ..write('createdAt: $createdAt, ')
          ..write('bodyRegions: $bodyRegions, ')
          ..write('findingCount: $findingCount, ')
          ..write('retainUntil: $retainUntil')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    jobId,
    imagePath,
    createdAt,
    bodyRegions,
    findingCount,
    retainUntil,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Visualization &&
          other.id == this.id &&
          other.jobId == this.jobId &&
          other.imagePath == this.imagePath &&
          other.createdAt == this.createdAt &&
          other.bodyRegions == this.bodyRegions &&
          other.findingCount == this.findingCount &&
          other.retainUntil == this.retainUntil);
}

class VisualizationsCompanion extends UpdateCompanion<Visualization> {
  final Value<int> id;
  final Value<String> jobId;
  final Value<String> imagePath;
  final Value<int> createdAt;
  final Value<String> bodyRegions;
  final Value<int> findingCount;
  final Value<int?> retainUntil;
  const VisualizationsCompanion({
    this.id = const Value.absent(),
    this.jobId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.bodyRegions = const Value.absent(),
    this.findingCount = const Value.absent(),
    this.retainUntil = const Value.absent(),
  });
  VisualizationsCompanion.insert({
    this.id = const Value.absent(),
    required String jobId,
    required String imagePath,
    required int createdAt,
    required String bodyRegions,
    required int findingCount,
    this.retainUntil = const Value.absent(),
  }) : jobId = Value(jobId),
       imagePath = Value(imagePath),
       createdAt = Value(createdAt),
       bodyRegions = Value(bodyRegions),
       findingCount = Value(findingCount);
  static Insertable<Visualization> custom({
    Expression<int>? id,
    Expression<String>? jobId,
    Expression<String>? imagePath,
    Expression<int>? createdAt,
    Expression<String>? bodyRegions,
    Expression<int>? findingCount,
    Expression<int>? retainUntil,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (jobId != null) 'job_id': jobId,
      if (imagePath != null) 'image_path': imagePath,
      if (createdAt != null) 'created_at': createdAt,
      if (bodyRegions != null) 'body_regions': bodyRegions,
      if (findingCount != null) 'finding_count': findingCount,
      if (retainUntil != null) 'retain_until': retainUntil,
    });
  }

  VisualizationsCompanion copyWith({
    Value<int>? id,
    Value<String>? jobId,
    Value<String>? imagePath,
    Value<int>? createdAt,
    Value<String>? bodyRegions,
    Value<int>? findingCount,
    Value<int?>? retainUntil,
  }) {
    return VisualizationsCompanion(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      bodyRegions: bodyRegions ?? this.bodyRegions,
      findingCount: findingCount ?? this.findingCount,
      retainUntil: retainUntil ?? this.retainUntil,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (jobId.present) {
      map['job_id'] = Variable<String>(jobId.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (bodyRegions.present) {
      map['body_regions'] = Variable<String>(bodyRegions.value);
    }
    if (findingCount.present) {
      map['finding_count'] = Variable<int>(findingCount.value);
    }
    if (retainUntil.present) {
      map['retain_until'] = Variable<int>(retainUntil.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VisualizationsCompanion(')
          ..write('id: $id, ')
          ..write('jobId: $jobId, ')
          ..write('imagePath: $imagePath, ')
          ..write('createdAt: $createdAt, ')
          ..write('bodyRegions: $bodyRegions, ')
          ..write('findingCount: $findingCount, ')
          ..write('retainUntil: $retainUntil')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $VisualizationsTable visualizations = $VisualizationsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [visualizations];
}

typedef $$VisualizationsTableCreateCompanionBuilder =
    VisualizationsCompanion Function({
      Value<int> id,
      required String jobId,
      required String imagePath,
      required int createdAt,
      required String bodyRegions,
      required int findingCount,
      Value<int?> retainUntil,
    });
typedef $$VisualizationsTableUpdateCompanionBuilder =
    VisualizationsCompanion Function({
      Value<int> id,
      Value<String> jobId,
      Value<String> imagePath,
      Value<int> createdAt,
      Value<String> bodyRegions,
      Value<int> findingCount,
      Value<int?> retainUntil,
    });

class $$VisualizationsTableFilterComposer
    extends Composer<_$AppDatabase, $VisualizationsTable> {
  $$VisualizationsTableFilterComposer({
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

  ColumnFilters<String> get jobId => $composableBuilder(
    column: $table.jobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyRegions => $composableBuilder(
    column: $table.bodyRegions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get findingCount => $composableBuilder(
    column: $table.findingCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retainUntil => $composableBuilder(
    column: $table.retainUntil,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VisualizationsTableOrderingComposer
    extends Composer<_$AppDatabase, $VisualizationsTable> {
  $$VisualizationsTableOrderingComposer({
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

  ColumnOrderings<String> get jobId => $composableBuilder(
    column: $table.jobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyRegions => $composableBuilder(
    column: $table.bodyRegions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get findingCount => $composableBuilder(
    column: $table.findingCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retainUntil => $composableBuilder(
    column: $table.retainUntil,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VisualizationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VisualizationsTable> {
  $$VisualizationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get jobId =>
      $composableBuilder(column: $table.jobId, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get bodyRegions => $composableBuilder(
    column: $table.bodyRegions,
    builder: (column) => column,
  );

  GeneratedColumn<int> get findingCount => $composableBuilder(
    column: $table.findingCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retainUntil => $composableBuilder(
    column: $table.retainUntil,
    builder: (column) => column,
  );
}

class $$VisualizationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VisualizationsTable,
          Visualization,
          $$VisualizationsTableFilterComposer,
          $$VisualizationsTableOrderingComposer,
          $$VisualizationsTableAnnotationComposer,
          $$VisualizationsTableCreateCompanionBuilder,
          $$VisualizationsTableUpdateCompanionBuilder,
          (
            Visualization,
            BaseReferences<_$AppDatabase, $VisualizationsTable, Visualization>,
          ),
          Visualization,
          PrefetchHooks Function()
        > {
  $$VisualizationsTableTableManager(
    _$AppDatabase db,
    $VisualizationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VisualizationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VisualizationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VisualizationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> jobId = const Value.absent(),
                Value<String> imagePath = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> bodyRegions = const Value.absent(),
                Value<int> findingCount = const Value.absent(),
                Value<int?> retainUntil = const Value.absent(),
              }) => VisualizationsCompanion(
                id: id,
                jobId: jobId,
                imagePath: imagePath,
                createdAt: createdAt,
                bodyRegions: bodyRegions,
                findingCount: findingCount,
                retainUntil: retainUntil,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String jobId,
                required String imagePath,
                required int createdAt,
                required String bodyRegions,
                required int findingCount,
                Value<int?> retainUntil = const Value.absent(),
              }) => VisualizationsCompanion.insert(
                id: id,
                jobId: jobId,
                imagePath: imagePath,
                createdAt: createdAt,
                bodyRegions: bodyRegions,
                findingCount: findingCount,
                retainUntil: retainUntil,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VisualizationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VisualizationsTable,
      Visualization,
      $$VisualizationsTableFilterComposer,
      $$VisualizationsTableOrderingComposer,
      $$VisualizationsTableAnnotationComposer,
      $$VisualizationsTableCreateCompanionBuilder,
      $$VisualizationsTableUpdateCompanionBuilder,
      (
        Visualization,
        BaseReferences<_$AppDatabase, $VisualizationsTable, Visualization>,
      ),
      Visualization,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$VisualizationsTableTableManager get visualizations =>
      $$VisualizationsTableTableManager(_db, _db.visualizations);
}
