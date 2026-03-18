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

class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vizJobIdMeta = const VerificationMeta(
    'vizJobId',
  );
  @override
  late final GeneratedColumn<String> vizJobId = GeneratedColumn<String>(
    'viz_job_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _findingsJsonMeta = const VerificationMeta(
    'findingsJson',
  );
  @override
  late final GeneratedColumn<String> findingsJson = GeneratedColumn<String>(
    'findings_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tokensInMeta = const VerificationMeta(
    'tokensIn',
  );
  @override
  late final GeneratedColumn<int> tokensIn = GeneratedColumn<int>(
    'tokens_in',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _tokensOutMeta = const VerificationMeta(
    'tokensOut',
  );
  @override
  late final GeneratedColumn<int> tokensOut = GeneratedColumn<int>(
    'tokens_out',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    vizJobId,
    status,
    findingsJson,
    bodyRegions,
    findingCount,
    startedAt,
    updatedAt,
    tokensIn,
    tokensOut,
    imageUrl,
    errorMessage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Session> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('viz_job_id')) {
      context.handle(
        _vizJobIdMeta,
        vizJobId.isAcceptableOrUnknown(data['viz_job_id']!, _vizJobIdMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('findings_json')) {
      context.handle(
        _findingsJsonMeta,
        findingsJson.isAcceptableOrUnknown(
          data['findings_json']!,
          _findingsJsonMeta,
        ),
      );
    }
    if (data.containsKey('body_regions')) {
      context.handle(
        _bodyRegionsMeta,
        bodyRegions.isAcceptableOrUnknown(
          data['body_regions']!,
          _bodyRegionsMeta,
        ),
      );
    }
    if (data.containsKey('finding_count')) {
      context.handle(
        _findingCountMeta,
        findingCount.isAcceptableOrUnknown(
          data['finding_count']!,
          _findingCountMeta,
        ),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('tokens_in')) {
      context.handle(
        _tokensInMeta,
        tokensIn.isAcceptableOrUnknown(data['tokens_in']!, _tokensInMeta),
      );
    }
    if (data.containsKey('tokens_out')) {
      context.handle(
        _tokensOutMeta,
        tokensOut.isAcceptableOrUnknown(data['tokens_out']!, _tokensOutMeta),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      vizJobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}viz_job_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      findingsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}findings_json'],
      ),
      bodyRegions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_regions'],
      )!,
      findingCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}finding_count'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      tokensIn: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tokens_in'],
      )!,
      tokensOut: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tokens_out'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final String id;
  final String? vizJobId;
  final String status;
  final String? findingsJson;
  final String bodyRegions;
  final int findingCount;
  final int startedAt;
  final int updatedAt;
  final int tokensIn;
  final int tokensOut;
  final String? imageUrl;
  final String? errorMessage;
  const Session({
    required this.id,
    this.vizJobId,
    required this.status,
    this.findingsJson,
    required this.bodyRegions,
    required this.findingCount,
    required this.startedAt,
    required this.updatedAt,
    required this.tokensIn,
    required this.tokensOut,
    this.imageUrl,
    this.errorMessage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || vizJobId != null) {
      map['viz_job_id'] = Variable<String>(vizJobId);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || findingsJson != null) {
      map['findings_json'] = Variable<String>(findingsJson);
    }
    map['body_regions'] = Variable<String>(bodyRegions);
    map['finding_count'] = Variable<int>(findingCount);
    map['started_at'] = Variable<int>(startedAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['tokens_in'] = Variable<int>(tokensIn);
    map['tokens_out'] = Variable<int>(tokensOut);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      vizJobId: vizJobId == null && nullToAbsent
          ? const Value.absent()
          : Value(vizJobId),
      status: Value(status),
      findingsJson: findingsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(findingsJson),
      bodyRegions: Value(bodyRegions),
      findingCount: Value(findingCount),
      startedAt: Value(startedAt),
      updatedAt: Value(updatedAt),
      tokensIn: Value(tokensIn),
      tokensOut: Value(tokensOut),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
    );
  }

  factory Session.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<String>(json['id']),
      vizJobId: serializer.fromJson<String?>(json['vizJobId']),
      status: serializer.fromJson<String>(json['status']),
      findingsJson: serializer.fromJson<String?>(json['findingsJson']),
      bodyRegions: serializer.fromJson<String>(json['bodyRegions']),
      findingCount: serializer.fromJson<int>(json['findingCount']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      tokensIn: serializer.fromJson<int>(json['tokensIn']),
      tokensOut: serializer.fromJson<int>(json['tokensOut']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'vizJobId': serializer.toJson<String?>(vizJobId),
      'status': serializer.toJson<String>(status),
      'findingsJson': serializer.toJson<String?>(findingsJson),
      'bodyRegions': serializer.toJson<String>(bodyRegions),
      'findingCount': serializer.toJson<int>(findingCount),
      'startedAt': serializer.toJson<int>(startedAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'tokensIn': serializer.toJson<int>(tokensIn),
      'tokensOut': serializer.toJson<int>(tokensOut),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'errorMessage': serializer.toJson<String?>(errorMessage),
    };
  }

  Session copyWith({
    String? id,
    Value<String?> vizJobId = const Value.absent(),
    String? status,
    Value<String?> findingsJson = const Value.absent(),
    String? bodyRegions,
    int? findingCount,
    int? startedAt,
    int? updatedAt,
    int? tokensIn,
    int? tokensOut,
    Value<String?> imageUrl = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
  }) => Session(
    id: id ?? this.id,
    vizJobId: vizJobId.present ? vizJobId.value : this.vizJobId,
    status: status ?? this.status,
    findingsJson: findingsJson.present ? findingsJson.value : this.findingsJson,
    bodyRegions: bodyRegions ?? this.bodyRegions,
    findingCount: findingCount ?? this.findingCount,
    startedAt: startedAt ?? this.startedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    tokensIn: tokensIn ?? this.tokensIn,
    tokensOut: tokensOut ?? this.tokensOut,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
  );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      vizJobId: data.vizJobId.present ? data.vizJobId.value : this.vizJobId,
      status: data.status.present ? data.status.value : this.status,
      findingsJson: data.findingsJson.present
          ? data.findingsJson.value
          : this.findingsJson,
      bodyRegions: data.bodyRegions.present
          ? data.bodyRegions.value
          : this.bodyRegions,
      findingCount: data.findingCount.present
          ? data.findingCount.value
          : this.findingCount,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      tokensIn: data.tokensIn.present ? data.tokensIn.value : this.tokensIn,
      tokensOut: data.tokensOut.present ? data.tokensOut.value : this.tokensOut,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('vizJobId: $vizJobId, ')
          ..write('status: $status, ')
          ..write('findingsJson: $findingsJson, ')
          ..write('bodyRegions: $bodyRegions, ')
          ..write('findingCount: $findingCount, ')
          ..write('startedAt: $startedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('tokensIn: $tokensIn, ')
          ..write('tokensOut: $tokensOut, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    vizJobId,
    status,
    findingsJson,
    bodyRegions,
    findingCount,
    startedAt,
    updatedAt,
    tokensIn,
    tokensOut,
    imageUrl,
    errorMessage,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.vizJobId == this.vizJobId &&
          other.status == this.status &&
          other.findingsJson == this.findingsJson &&
          other.bodyRegions == this.bodyRegions &&
          other.findingCount == this.findingCount &&
          other.startedAt == this.startedAt &&
          other.updatedAt == this.updatedAt &&
          other.tokensIn == this.tokensIn &&
          other.tokensOut == this.tokensOut &&
          other.imageUrl == this.imageUrl &&
          other.errorMessage == this.errorMessage);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<String> id;
  final Value<String?> vizJobId;
  final Value<String> status;
  final Value<String?> findingsJson;
  final Value<String> bodyRegions;
  final Value<int> findingCount;
  final Value<int> startedAt;
  final Value<int> updatedAt;
  final Value<int> tokensIn;
  final Value<int> tokensOut;
  final Value<String?> imageUrl;
  final Value<String?> errorMessage;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.vizJobId = const Value.absent(),
    this.status = const Value.absent(),
    this.findingsJson = const Value.absent(),
    this.bodyRegions = const Value.absent(),
    this.findingCount = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.tokensIn = const Value.absent(),
    this.tokensOut = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    this.vizJobId = const Value.absent(),
    required String status,
    this.findingsJson = const Value.absent(),
    this.bodyRegions = const Value.absent(),
    this.findingCount = const Value.absent(),
    required int startedAt,
    required int updatedAt,
    this.tokensIn = const Value.absent(),
    this.tokensOut = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       status = Value(status),
       startedAt = Value(startedAt),
       updatedAt = Value(updatedAt);
  static Insertable<Session> custom({
    Expression<String>? id,
    Expression<String>? vizJobId,
    Expression<String>? status,
    Expression<String>? findingsJson,
    Expression<String>? bodyRegions,
    Expression<int>? findingCount,
    Expression<int>? startedAt,
    Expression<int>? updatedAt,
    Expression<int>? tokensIn,
    Expression<int>? tokensOut,
    Expression<String>? imageUrl,
    Expression<String>? errorMessage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vizJobId != null) 'viz_job_id': vizJobId,
      if (status != null) 'status': status,
      if (findingsJson != null) 'findings_json': findingsJson,
      if (bodyRegions != null) 'body_regions': bodyRegions,
      if (findingCount != null) 'finding_count': findingCount,
      if (startedAt != null) 'started_at': startedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (tokensIn != null) 'tokens_in': tokensIn,
      if (tokensOut != null) 'tokens_out': tokensOut,
      if (imageUrl != null) 'image_url': imageUrl,
      if (errorMessage != null) 'error_message': errorMessage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? vizJobId,
    Value<String>? status,
    Value<String?>? findingsJson,
    Value<String>? bodyRegions,
    Value<int>? findingCount,
    Value<int>? startedAt,
    Value<int>? updatedAt,
    Value<int>? tokensIn,
    Value<int>? tokensOut,
    Value<String?>? imageUrl,
    Value<String?>? errorMessage,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      vizJobId: vizJobId ?? this.vizJobId,
      status: status ?? this.status,
      findingsJson: findingsJson ?? this.findingsJson,
      bodyRegions: bodyRegions ?? this.bodyRegions,
      findingCount: findingCount ?? this.findingCount,
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tokensIn: tokensIn ?? this.tokensIn,
      tokensOut: tokensOut ?? this.tokensOut,
      imageUrl: imageUrl ?? this.imageUrl,
      errorMessage: errorMessage ?? this.errorMessage,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (vizJobId.present) {
      map['viz_job_id'] = Variable<String>(vizJobId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (findingsJson.present) {
      map['findings_json'] = Variable<String>(findingsJson.value);
    }
    if (bodyRegions.present) {
      map['body_regions'] = Variable<String>(bodyRegions.value);
    }
    if (findingCount.present) {
      map['finding_count'] = Variable<int>(findingCount.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (tokensIn.present) {
      map['tokens_in'] = Variable<int>(tokensIn.value);
    }
    if (tokensOut.present) {
      map['tokens_out'] = Variable<int>(tokensOut.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('vizJobId: $vizJobId, ')
          ..write('status: $status, ')
          ..write('findingsJson: $findingsJson, ')
          ..write('bodyRegions: $bodyRegions, ')
          ..write('findingCount: $findingCount, ')
          ..write('startedAt: $startedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('tokensIn: $tokensIn, ')
          ..write('tokensOut: $tokensOut, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $VisualizationsTable visualizations = $VisualizationsTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    visualizations,
    sessions,
  ];
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
typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      required String id,
      Value<String?> vizJobId,
      required String status,
      Value<String?> findingsJson,
      Value<String> bodyRegions,
      Value<int> findingCount,
      required int startedAt,
      required int updatedAt,
      Value<int> tokensIn,
      Value<int> tokensOut,
      Value<String?> imageUrl,
      Value<String?> errorMessage,
      Value<int> rowid,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<String> id,
      Value<String?> vizJobId,
      Value<String> status,
      Value<String?> findingsJson,
      Value<String> bodyRegions,
      Value<int> findingCount,
      Value<int> startedAt,
      Value<int> updatedAt,
      Value<int> tokensIn,
      Value<int> tokensOut,
      Value<String?> imageUrl,
      Value<String?> errorMessage,
      Value<int> rowid,
    });

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vizJobId => $composableBuilder(
    column: $table.vizJobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get findingsJson => $composableBuilder(
    column: $table.findingsJson,
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

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tokensIn => $composableBuilder(
    column: $table.tokensIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tokensOut => $composableBuilder(
    column: $table.tokensOut,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vizJobId => $composableBuilder(
    column: $table.vizJobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get findingsJson => $composableBuilder(
    column: $table.findingsJson,
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

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tokensIn => $composableBuilder(
    column: $table.tokensIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tokensOut => $composableBuilder(
    column: $table.tokensOut,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get vizJobId =>
      $composableBuilder(column: $table.vizJobId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get findingsJson => $composableBuilder(
    column: $table.findingsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bodyRegions => $composableBuilder(
    column: $table.bodyRegions,
    builder: (column) => column,
  );

  GeneratedColumn<int> get findingCount => $composableBuilder(
    column: $table.findingCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get tokensIn =>
      $composableBuilder(column: $table.tokensIn, builder: (column) => column);

  GeneratedColumn<int> get tokensOut =>
      $composableBuilder(column: $table.tokensOut, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          Session,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (Session, BaseReferences<_$AppDatabase, $SessionsTable, Session>),
          Session,
          PrefetchHooks Function()
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> vizJobId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> findingsJson = const Value.absent(),
                Value<String> bodyRegions = const Value.absent(),
                Value<int> findingCount = const Value.absent(),
                Value<int> startedAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> tokensIn = const Value.absent(),
                Value<int> tokensOut = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                vizJobId: vizJobId,
                status: status,
                findingsJson: findingsJson,
                bodyRegions: bodyRegions,
                findingCount: findingCount,
                startedAt: startedAt,
                updatedAt: updatedAt,
                tokensIn: tokensIn,
                tokensOut: tokensOut,
                imageUrl: imageUrl,
                errorMessage: errorMessage,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> vizJobId = const Value.absent(),
                required String status,
                Value<String?> findingsJson = const Value.absent(),
                Value<String> bodyRegions = const Value.absent(),
                Value<int> findingCount = const Value.absent(),
                required int startedAt,
                required int updatedAt,
                Value<int> tokensIn = const Value.absent(),
                Value<int> tokensOut = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                vizJobId: vizJobId,
                status: status,
                findingsJson: findingsJson,
                bodyRegions: bodyRegions,
                findingCount: findingCount,
                startedAt: startedAt,
                updatedAt: updatedAt,
                tokensIn: tokensIn,
                tokensOut: tokensOut,
                imageUrl: imageUrl,
                errorMessage: errorMessage,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      Session,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (Session, BaseReferences<_$AppDatabase, $SessionsTable, Session>),
      Session,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$VisualizationsTableTableManager get visualizations =>
      $$VisualizationsTableTableManager(_db, _db.visualizations);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
}
