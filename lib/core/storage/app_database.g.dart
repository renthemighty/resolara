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
  static const VerificationMeta _patientLabelMeta = const VerificationMeta(
    'patientLabel',
  );
  @override
  late final GeneratedColumn<String> patientLabel = GeneratedColumn<String>(
    'patient_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    patientLabel,
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
    if (data.containsKey('patient_label')) {
      context.handle(
        _patientLabelMeta,
        patientLabel.isAcceptableOrUnknown(
          data['patient_label']!,
          _patientLabelMeta,
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
      patientLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}patient_label'],
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
  final String? patientLabel;
  const Visualization({
    required this.id,
    required this.jobId,
    required this.imagePath,
    required this.createdAt,
    required this.bodyRegions,
    required this.findingCount,
    this.retainUntil,
    this.patientLabel,
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
    if (!nullToAbsent || patientLabel != null) {
      map['patient_label'] = Variable<String>(patientLabel);
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
      patientLabel: patientLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(patientLabel),
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
      patientLabel: serializer.fromJson<String?>(json['patientLabel']),
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
      'patientLabel': serializer.toJson<String?>(patientLabel),
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
    Value<String?> patientLabel = const Value.absent(),
  }) => Visualization(
    id: id ?? this.id,
    jobId: jobId ?? this.jobId,
    imagePath: imagePath ?? this.imagePath,
    createdAt: createdAt ?? this.createdAt,
    bodyRegions: bodyRegions ?? this.bodyRegions,
    findingCount: findingCount ?? this.findingCount,
    retainUntil: retainUntil.present ? retainUntil.value : this.retainUntil,
    patientLabel: patientLabel.present ? patientLabel.value : this.patientLabel,
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
      patientLabel: data.patientLabel.present
          ? data.patientLabel.value
          : this.patientLabel,
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
          ..write('retainUntil: $retainUntil, ')
          ..write('patientLabel: $patientLabel')
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
    patientLabel,
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
          other.retainUntil == this.retainUntil &&
          other.patientLabel == this.patientLabel);
}

class VisualizationsCompanion extends UpdateCompanion<Visualization> {
  final Value<int> id;
  final Value<String> jobId;
  final Value<String> imagePath;
  final Value<int> createdAt;
  final Value<String> bodyRegions;
  final Value<int> findingCount;
  final Value<int?> retainUntil;
  final Value<String?> patientLabel;
  const VisualizationsCompanion({
    this.id = const Value.absent(),
    this.jobId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.bodyRegions = const Value.absent(),
    this.findingCount = const Value.absent(),
    this.retainUntil = const Value.absent(),
    this.patientLabel = const Value.absent(),
  });
  VisualizationsCompanion.insert({
    this.id = const Value.absent(),
    required String jobId,
    required String imagePath,
    required int createdAt,
    required String bodyRegions,
    required int findingCount,
    this.retainUntil = const Value.absent(),
    this.patientLabel = const Value.absent(),
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
    Expression<String>? patientLabel,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (jobId != null) 'job_id': jobId,
      if (imagePath != null) 'image_path': imagePath,
      if (createdAt != null) 'created_at': createdAt,
      if (bodyRegions != null) 'body_regions': bodyRegions,
      if (findingCount != null) 'finding_count': findingCount,
      if (retainUntil != null) 'retain_until': retainUntil,
      if (patientLabel != null) 'patient_label': patientLabel,
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
    Value<String?>? patientLabel,
  }) {
    return VisualizationsCompanion(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      bodyRegions: bodyRegions ?? this.bodyRegions,
      findingCount: findingCount ?? this.findingCount,
      retainUntil: retainUntil ?? this.retainUntil,
      patientLabel: patientLabel ?? this.patientLabel,
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
    if (patientLabel.present) {
      map['patient_label'] = Variable<String>(patientLabel.value);
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
          ..write('retainUntil: $retainUntil, ')
          ..write('patientLabel: $patientLabel')
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

class $PatientSavedResultsTable extends PatientSavedResults
    with TableInfo<$PatientSavedResultsTable, PatientSavedResult> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PatientSavedResultsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _shareCodeMeta = const VerificationMeta(
    'shareCode',
  );
  @override
  late final GeneratedColumn<String> shareCode = GeneratedColumn<String>(
    'share_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _patientNameMeta = const VerificationMeta(
    'patientName',
  );
  @override
  late final GeneratedColumn<String> patientName = GeneratedColumn<String>(
    'patient_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<int> savedAt = GeneratedColumn<int>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, shareCode, patientName, savedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'patient_saved_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<PatientSavedResult> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('share_code')) {
      context.handle(
        _shareCodeMeta,
        shareCode.isAcceptableOrUnknown(data['share_code']!, _shareCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_shareCodeMeta);
    }
    if (data.containsKey('patient_name')) {
      context.handle(
        _patientNameMeta,
        patientName.isAcceptableOrUnknown(
          data['patient_name']!,
          _patientNameMeta,
        ),
      );
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PatientSavedResult map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PatientSavedResult(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      shareCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}share_code'],
      )!,
      patientName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}patient_name'],
      ),
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}saved_at'],
      )!,
    );
  }

  @override
  $PatientSavedResultsTable createAlias(String alias) {
    return $PatientSavedResultsTable(attachedDatabase, alias);
  }
}

class PatientSavedResult extends DataClass
    implements Insertable<PatientSavedResult> {
  final int id;
  final String shareCode;
  final String? patientName;
  final int savedAt;
  const PatientSavedResult({
    required this.id,
    required this.shareCode,
    this.patientName,
    required this.savedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['share_code'] = Variable<String>(shareCode);
    if (!nullToAbsent || patientName != null) {
      map['patient_name'] = Variable<String>(patientName);
    }
    map['saved_at'] = Variable<int>(savedAt);
    return map;
  }

  PatientSavedResultsCompanion toCompanion(bool nullToAbsent) {
    return PatientSavedResultsCompanion(
      id: Value(id),
      shareCode: Value(shareCode),
      patientName: patientName == null && nullToAbsent
          ? const Value.absent()
          : Value(patientName),
      savedAt: Value(savedAt),
    );
  }

  factory PatientSavedResult.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PatientSavedResult(
      id: serializer.fromJson<int>(json['id']),
      shareCode: serializer.fromJson<String>(json['shareCode']),
      patientName: serializer.fromJson<String?>(json['patientName']),
      savedAt: serializer.fromJson<int>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'shareCode': serializer.toJson<String>(shareCode),
      'patientName': serializer.toJson<String?>(patientName),
      'savedAt': serializer.toJson<int>(savedAt),
    };
  }

  PatientSavedResult copyWith({
    int? id,
    String? shareCode,
    Value<String?> patientName = const Value.absent(),
    int? savedAt,
  }) => PatientSavedResult(
    id: id ?? this.id,
    shareCode: shareCode ?? this.shareCode,
    patientName: patientName.present ? patientName.value : this.patientName,
    savedAt: savedAt ?? this.savedAt,
  );
  PatientSavedResult copyWithCompanion(PatientSavedResultsCompanion data) {
    return PatientSavedResult(
      id: data.id.present ? data.id.value : this.id,
      shareCode: data.shareCode.present ? data.shareCode.value : this.shareCode,
      patientName: data.patientName.present
          ? data.patientName.value
          : this.patientName,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PatientSavedResult(')
          ..write('id: $id, ')
          ..write('shareCode: $shareCode, ')
          ..write('patientName: $patientName, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, shareCode, patientName, savedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PatientSavedResult &&
          other.id == this.id &&
          other.shareCode == this.shareCode &&
          other.patientName == this.patientName &&
          other.savedAt == this.savedAt);
}

class PatientSavedResultsCompanion extends UpdateCompanion<PatientSavedResult> {
  final Value<int> id;
  final Value<String> shareCode;
  final Value<String?> patientName;
  final Value<int> savedAt;
  const PatientSavedResultsCompanion({
    this.id = const Value.absent(),
    this.shareCode = const Value.absent(),
    this.patientName = const Value.absent(),
    this.savedAt = const Value.absent(),
  });
  PatientSavedResultsCompanion.insert({
    this.id = const Value.absent(),
    required String shareCode,
    this.patientName = const Value.absent(),
    required int savedAt,
  }) : shareCode = Value(shareCode),
       savedAt = Value(savedAt);
  static Insertable<PatientSavedResult> custom({
    Expression<int>? id,
    Expression<String>? shareCode,
    Expression<String>? patientName,
    Expression<int>? savedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shareCode != null) 'share_code': shareCode,
      if (patientName != null) 'patient_name': patientName,
      if (savedAt != null) 'saved_at': savedAt,
    });
  }

  PatientSavedResultsCompanion copyWith({
    Value<int>? id,
    Value<String>? shareCode,
    Value<String?>? patientName,
    Value<int>? savedAt,
  }) {
    return PatientSavedResultsCompanion(
      id: id ?? this.id,
      shareCode: shareCode ?? this.shareCode,
      patientName: patientName ?? this.patientName,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (shareCode.present) {
      map['share_code'] = Variable<String>(shareCode.value);
    }
    if (patientName.present) {
      map['patient_name'] = Variable<String>(patientName.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<int>(savedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PatientSavedResultsCompanion(')
          ..write('id: $id, ')
          ..write('shareCode: $shareCode, ')
          ..write('patientName: $patientName, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }
}

class $PatientRemindersTable extends PatientReminders
    with TableInfo<$PatientRemindersTable, PatientReminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PatientRemindersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _shareCodeMeta = const VerificationMeta(
    'shareCode',
  );
  @override
  late final GeneratedColumn<String> shareCode = GeneratedColumn<String>(
    'share_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemTypeMeta = const VerificationMeta(
    'itemType',
  );
  @override
  late final GeneratedColumn<String> itemType = GeneratedColumn<String>(
    'item_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemNameMeta = const VerificationMeta(
    'itemName',
  );
  @override
  late final GeneratedColumn<String> itemName = GeneratedColumn<String>(
    'item_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reminderHourMeta = const VerificationMeta(
    'reminderHour',
  );
  @override
  late final GeneratedColumn<int> reminderHour = GeneratedColumn<int>(
    'reminder_hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reminderMinuteMeta = const VerificationMeta(
    'reminderMinute',
  );
  @override
  late final GeneratedColumn<int> reminderMinute = GeneratedColumn<int>(
    'reminder_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    shareCode,
    itemId,
    itemType,
    itemName,
    reminderHour,
    reminderMinute,
    enabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'patient_reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<PatientReminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('share_code')) {
      context.handle(
        _shareCodeMeta,
        shareCode.isAcceptableOrUnknown(data['share_code']!, _shareCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_shareCodeMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('item_type')) {
      context.handle(
        _itemTypeMeta,
        itemType.isAcceptableOrUnknown(data['item_type']!, _itemTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_itemTypeMeta);
    }
    if (data.containsKey('item_name')) {
      context.handle(
        _itemNameMeta,
        itemName.isAcceptableOrUnknown(data['item_name']!, _itemNameMeta),
      );
    } else if (isInserting) {
      context.missing(_itemNameMeta);
    }
    if (data.containsKey('reminder_hour')) {
      context.handle(
        _reminderHourMeta,
        reminderHour.isAcceptableOrUnknown(
          data['reminder_hour']!,
          _reminderHourMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reminderHourMeta);
    }
    if (data.containsKey('reminder_minute')) {
      context.handle(
        _reminderMinuteMeta,
        reminderMinute.isAcceptableOrUnknown(
          data['reminder_minute']!,
          _reminderMinuteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reminderMinuteMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PatientReminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PatientReminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      shareCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}share_code'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      itemType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_type'],
      )!,
      itemName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_name'],
      )!,
      reminderHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_hour'],
      )!,
      reminderMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minute'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
    );
  }

  @override
  $PatientRemindersTable createAlias(String alias) {
    return $PatientRemindersTable(attachedDatabase, alias);
  }
}

class PatientReminder extends DataClass implements Insertable<PatientReminder> {
  final int id;
  final String shareCode;
  final String itemId;
  final String itemType;
  final String itemName;
  final int reminderHour;
  final int reminderMinute;
  final bool enabled;
  const PatientReminder({
    required this.id,
    required this.shareCode,
    required this.itemId,
    required this.itemType,
    required this.itemName,
    required this.reminderHour,
    required this.reminderMinute,
    required this.enabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['share_code'] = Variable<String>(shareCode);
    map['item_id'] = Variable<String>(itemId);
    map['item_type'] = Variable<String>(itemType);
    map['item_name'] = Variable<String>(itemName);
    map['reminder_hour'] = Variable<int>(reminderHour);
    map['reminder_minute'] = Variable<int>(reminderMinute);
    map['enabled'] = Variable<bool>(enabled);
    return map;
  }

  PatientRemindersCompanion toCompanion(bool nullToAbsent) {
    return PatientRemindersCompanion(
      id: Value(id),
      shareCode: Value(shareCode),
      itemId: Value(itemId),
      itemType: Value(itemType),
      itemName: Value(itemName),
      reminderHour: Value(reminderHour),
      reminderMinute: Value(reminderMinute),
      enabled: Value(enabled),
    );
  }

  factory PatientReminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PatientReminder(
      id: serializer.fromJson<int>(json['id']),
      shareCode: serializer.fromJson<String>(json['shareCode']),
      itemId: serializer.fromJson<String>(json['itemId']),
      itemType: serializer.fromJson<String>(json['itemType']),
      itemName: serializer.fromJson<String>(json['itemName']),
      reminderHour: serializer.fromJson<int>(json['reminderHour']),
      reminderMinute: serializer.fromJson<int>(json['reminderMinute']),
      enabled: serializer.fromJson<bool>(json['enabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'shareCode': serializer.toJson<String>(shareCode),
      'itemId': serializer.toJson<String>(itemId),
      'itemType': serializer.toJson<String>(itemType),
      'itemName': serializer.toJson<String>(itemName),
      'reminderHour': serializer.toJson<int>(reminderHour),
      'reminderMinute': serializer.toJson<int>(reminderMinute),
      'enabled': serializer.toJson<bool>(enabled),
    };
  }

  PatientReminder copyWith({
    int? id,
    String? shareCode,
    String? itemId,
    String? itemType,
    String? itemName,
    int? reminderHour,
    int? reminderMinute,
    bool? enabled,
  }) => PatientReminder(
    id: id ?? this.id,
    shareCode: shareCode ?? this.shareCode,
    itemId: itemId ?? this.itemId,
    itemType: itemType ?? this.itemType,
    itemName: itemName ?? this.itemName,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    enabled: enabled ?? this.enabled,
  );
  PatientReminder copyWithCompanion(PatientRemindersCompanion data) {
    return PatientReminder(
      id: data.id.present ? data.id.value : this.id,
      shareCode: data.shareCode.present ? data.shareCode.value : this.shareCode,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      itemName: data.itemName.present ? data.itemName.value : this.itemName,
      reminderHour: data.reminderHour.present
          ? data.reminderHour.value
          : this.reminderHour,
      reminderMinute: data.reminderMinute.present
          ? data.reminderMinute.value
          : this.reminderMinute,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PatientReminder(')
          ..write('id: $id, ')
          ..write('shareCode: $shareCode, ')
          ..write('itemId: $itemId, ')
          ..write('itemType: $itemType, ')
          ..write('itemName: $itemName, ')
          ..write('reminderHour: $reminderHour, ')
          ..write('reminderMinute: $reminderMinute, ')
          ..write('enabled: $enabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    shareCode,
    itemId,
    itemType,
    itemName,
    reminderHour,
    reminderMinute,
    enabled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PatientReminder &&
          other.id == this.id &&
          other.shareCode == this.shareCode &&
          other.itemId == this.itemId &&
          other.itemType == this.itemType &&
          other.itemName == this.itemName &&
          other.reminderHour == this.reminderHour &&
          other.reminderMinute == this.reminderMinute &&
          other.enabled == this.enabled);
}

class PatientRemindersCompanion extends UpdateCompanion<PatientReminder> {
  final Value<int> id;
  final Value<String> shareCode;
  final Value<String> itemId;
  final Value<String> itemType;
  final Value<String> itemName;
  final Value<int> reminderHour;
  final Value<int> reminderMinute;
  final Value<bool> enabled;
  const PatientRemindersCompanion({
    this.id = const Value.absent(),
    this.shareCode = const Value.absent(),
    this.itemId = const Value.absent(),
    this.itemType = const Value.absent(),
    this.itemName = const Value.absent(),
    this.reminderHour = const Value.absent(),
    this.reminderMinute = const Value.absent(),
    this.enabled = const Value.absent(),
  });
  PatientRemindersCompanion.insert({
    this.id = const Value.absent(),
    required String shareCode,
    required String itemId,
    required String itemType,
    required String itemName,
    required int reminderHour,
    required int reminderMinute,
    this.enabled = const Value.absent(),
  }) : shareCode = Value(shareCode),
       itemId = Value(itemId),
       itemType = Value(itemType),
       itemName = Value(itemName),
       reminderHour = Value(reminderHour),
       reminderMinute = Value(reminderMinute);
  static Insertable<PatientReminder> custom({
    Expression<int>? id,
    Expression<String>? shareCode,
    Expression<String>? itemId,
    Expression<String>? itemType,
    Expression<String>? itemName,
    Expression<int>? reminderHour,
    Expression<int>? reminderMinute,
    Expression<bool>? enabled,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shareCode != null) 'share_code': shareCode,
      if (itemId != null) 'item_id': itemId,
      if (itemType != null) 'item_type': itemType,
      if (itemName != null) 'item_name': itemName,
      if (reminderHour != null) 'reminder_hour': reminderHour,
      if (reminderMinute != null) 'reminder_minute': reminderMinute,
      if (enabled != null) 'enabled': enabled,
    });
  }

  PatientRemindersCompanion copyWith({
    Value<int>? id,
    Value<String>? shareCode,
    Value<String>? itemId,
    Value<String>? itemType,
    Value<String>? itemName,
    Value<int>? reminderHour,
    Value<int>? reminderMinute,
    Value<bool>? enabled,
  }) {
    return PatientRemindersCompanion(
      id: id ?? this.id,
      shareCode: shareCode ?? this.shareCode,
      itemId: itemId ?? this.itemId,
      itemType: itemType ?? this.itemType,
      itemName: itemName ?? this.itemName,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (shareCode.present) {
      map['share_code'] = Variable<String>(shareCode.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<String>(itemType.value);
    }
    if (itemName.present) {
      map['item_name'] = Variable<String>(itemName.value);
    }
    if (reminderHour.present) {
      map['reminder_hour'] = Variable<int>(reminderHour.value);
    }
    if (reminderMinute.present) {
      map['reminder_minute'] = Variable<int>(reminderMinute.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PatientRemindersCompanion(')
          ..write('id: $id, ')
          ..write('shareCode: $shareCode, ')
          ..write('itemId: $itemId, ')
          ..write('itemType: $itemType, ')
          ..write('itemName: $itemName, ')
          ..write('reminderHour: $reminderHour, ')
          ..write('reminderMinute: $reminderMinute, ')
          ..write('enabled: $enabled')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $VisualizationsTable visualizations = $VisualizationsTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $PatientSavedResultsTable patientSavedResults =
      $PatientSavedResultsTable(this);
  late final $PatientRemindersTable patientReminders = $PatientRemindersTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    visualizations,
    sessions,
    patientSavedResults,
    patientReminders,
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
      Value<String?> patientLabel,
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
      Value<String?> patientLabel,
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

  ColumnFilters<String> get patientLabel => $composableBuilder(
    column: $table.patientLabel,
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

  ColumnOrderings<String> get patientLabel => $composableBuilder(
    column: $table.patientLabel,
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

  GeneratedColumn<String> get patientLabel => $composableBuilder(
    column: $table.patientLabel,
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
                Value<String?> patientLabel = const Value.absent(),
              }) => VisualizationsCompanion(
                id: id,
                jobId: jobId,
                imagePath: imagePath,
                createdAt: createdAt,
                bodyRegions: bodyRegions,
                findingCount: findingCount,
                retainUntil: retainUntil,
                patientLabel: patientLabel,
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
                Value<String?> patientLabel = const Value.absent(),
              }) => VisualizationsCompanion.insert(
                id: id,
                jobId: jobId,
                imagePath: imagePath,
                createdAt: createdAt,
                bodyRegions: bodyRegions,
                findingCount: findingCount,
                retainUntil: retainUntil,
                patientLabel: patientLabel,
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
typedef $$PatientSavedResultsTableCreateCompanionBuilder =
    PatientSavedResultsCompanion Function({
      Value<int> id,
      required String shareCode,
      Value<String?> patientName,
      required int savedAt,
    });
typedef $$PatientSavedResultsTableUpdateCompanionBuilder =
    PatientSavedResultsCompanion Function({
      Value<int> id,
      Value<String> shareCode,
      Value<String?> patientName,
      Value<int> savedAt,
    });

class $$PatientSavedResultsTableFilterComposer
    extends Composer<_$AppDatabase, $PatientSavedResultsTable> {
  $$PatientSavedResultsTableFilterComposer({
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

  ColumnFilters<String> get shareCode => $composableBuilder(
    column: $table.shareCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get patientName => $composableBuilder(
    column: $table.patientName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PatientSavedResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $PatientSavedResultsTable> {
  $$PatientSavedResultsTableOrderingComposer({
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

  ColumnOrderings<String> get shareCode => $composableBuilder(
    column: $table.shareCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get patientName => $composableBuilder(
    column: $table.patientName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PatientSavedResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PatientSavedResultsTable> {
  $$PatientSavedResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shareCode =>
      $composableBuilder(column: $table.shareCode, builder: (column) => column);

  GeneratedColumn<String> get patientName => $composableBuilder(
    column: $table.patientName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);
}

class $$PatientSavedResultsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PatientSavedResultsTable,
          PatientSavedResult,
          $$PatientSavedResultsTableFilterComposer,
          $$PatientSavedResultsTableOrderingComposer,
          $$PatientSavedResultsTableAnnotationComposer,
          $$PatientSavedResultsTableCreateCompanionBuilder,
          $$PatientSavedResultsTableUpdateCompanionBuilder,
          (
            PatientSavedResult,
            BaseReferences<
              _$AppDatabase,
              $PatientSavedResultsTable,
              PatientSavedResult
            >,
          ),
          PatientSavedResult,
          PrefetchHooks Function()
        > {
  $$PatientSavedResultsTableTableManager(
    _$AppDatabase db,
    $PatientSavedResultsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PatientSavedResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PatientSavedResultsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PatientSavedResultsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> shareCode = const Value.absent(),
                Value<String?> patientName = const Value.absent(),
                Value<int> savedAt = const Value.absent(),
              }) => PatientSavedResultsCompanion(
                id: id,
                shareCode: shareCode,
                patientName: patientName,
                savedAt: savedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String shareCode,
                Value<String?> patientName = const Value.absent(),
                required int savedAt,
              }) => PatientSavedResultsCompanion.insert(
                id: id,
                shareCode: shareCode,
                patientName: patientName,
                savedAt: savedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PatientSavedResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PatientSavedResultsTable,
      PatientSavedResult,
      $$PatientSavedResultsTableFilterComposer,
      $$PatientSavedResultsTableOrderingComposer,
      $$PatientSavedResultsTableAnnotationComposer,
      $$PatientSavedResultsTableCreateCompanionBuilder,
      $$PatientSavedResultsTableUpdateCompanionBuilder,
      (
        PatientSavedResult,
        BaseReferences<
          _$AppDatabase,
          $PatientSavedResultsTable,
          PatientSavedResult
        >,
      ),
      PatientSavedResult,
      PrefetchHooks Function()
    >;
typedef $$PatientRemindersTableCreateCompanionBuilder =
    PatientRemindersCompanion Function({
      Value<int> id,
      required String shareCode,
      required String itemId,
      required String itemType,
      required String itemName,
      required int reminderHour,
      required int reminderMinute,
      Value<bool> enabled,
    });
typedef $$PatientRemindersTableUpdateCompanionBuilder =
    PatientRemindersCompanion Function({
      Value<int> id,
      Value<String> shareCode,
      Value<String> itemId,
      Value<String> itemType,
      Value<String> itemName,
      Value<int> reminderHour,
      Value<int> reminderMinute,
      Value<bool> enabled,
    });

class $$PatientRemindersTableFilterComposer
    extends Composer<_$AppDatabase, $PatientRemindersTable> {
  $$PatientRemindersTableFilterComposer({
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

  ColumnFilters<String> get shareCode => $composableBuilder(
    column: $table.shareCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemName => $composableBuilder(
    column: $table.itemName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderHour => $composableBuilder(
    column: $table.reminderHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinute => $composableBuilder(
    column: $table.reminderMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PatientRemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $PatientRemindersTable> {
  $$PatientRemindersTableOrderingComposer({
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

  ColumnOrderings<String> get shareCode => $composableBuilder(
    column: $table.shareCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemName => $composableBuilder(
    column: $table.itemName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderHour => $composableBuilder(
    column: $table.reminderHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinute => $composableBuilder(
    column: $table.reminderMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PatientRemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PatientRemindersTable> {
  $$PatientRemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shareCode =>
      $composableBuilder(column: $table.shareCode, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<String> get itemName =>
      $composableBuilder(column: $table.itemName, builder: (column) => column);

  GeneratedColumn<int> get reminderHour => $composableBuilder(
    column: $table.reminderHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderMinute => $composableBuilder(
    column: $table.reminderMinute,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);
}

class $$PatientRemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PatientRemindersTable,
          PatientReminder,
          $$PatientRemindersTableFilterComposer,
          $$PatientRemindersTableOrderingComposer,
          $$PatientRemindersTableAnnotationComposer,
          $$PatientRemindersTableCreateCompanionBuilder,
          $$PatientRemindersTableUpdateCompanionBuilder,
          (
            PatientReminder,
            BaseReferences<
              _$AppDatabase,
              $PatientRemindersTable,
              PatientReminder
            >,
          ),
          PatientReminder,
          PrefetchHooks Function()
        > {
  $$PatientRemindersTableTableManager(
    _$AppDatabase db,
    $PatientRemindersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PatientRemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PatientRemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PatientRemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> shareCode = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> itemType = const Value.absent(),
                Value<String> itemName = const Value.absent(),
                Value<int> reminderHour = const Value.absent(),
                Value<int> reminderMinute = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
              }) => PatientRemindersCompanion(
                id: id,
                shareCode: shareCode,
                itemId: itemId,
                itemType: itemType,
                itemName: itemName,
                reminderHour: reminderHour,
                reminderMinute: reminderMinute,
                enabled: enabled,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String shareCode,
                required String itemId,
                required String itemType,
                required String itemName,
                required int reminderHour,
                required int reminderMinute,
                Value<bool> enabled = const Value.absent(),
              }) => PatientRemindersCompanion.insert(
                id: id,
                shareCode: shareCode,
                itemId: itemId,
                itemType: itemType,
                itemName: itemName,
                reminderHour: reminderHour,
                reminderMinute: reminderMinute,
                enabled: enabled,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PatientRemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PatientRemindersTable,
      PatientReminder,
      $$PatientRemindersTableFilterComposer,
      $$PatientRemindersTableOrderingComposer,
      $$PatientRemindersTableAnnotationComposer,
      $$PatientRemindersTableCreateCompanionBuilder,
      $$PatientRemindersTableUpdateCompanionBuilder,
      (
        PatientReminder,
        BaseReferences<_$AppDatabase, $PatientRemindersTable, PatientReminder>,
      ),
      PatientReminder,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$VisualizationsTableTableManager get visualizations =>
      $$VisualizationsTableTableManager(_db, _db.visualizations);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$PatientSavedResultsTableTableManager get patientSavedResults =>
      $$PatientSavedResultsTableTableManager(_db, _db.patientSavedResults);
  $$PatientRemindersTableTableManager get patientReminders =>
      $$PatientRemindersTableTableManager(_db, _db.patientReminders);
}
