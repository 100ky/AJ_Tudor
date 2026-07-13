// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fluencyScoreMeta = const VerificationMeta(
    'fluencyScore',
  );
  @override
  late final GeneratedColumn<double> fluencyScore = GeneratedColumn<double>(
    'fluency_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalUserUtterancesMeta =
      const VerificationMeta('totalUserUtterances');
  @override
  late final GeneratedColumn<int> totalUserUtterances = GeneratedColumn<int>(
    'total_user_utterances',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalErrorsMeta = const VerificationMeta(
    'totalErrors',
  );
  @override
  late final GeneratedColumn<int> totalErrors = GeneratedColumn<int>(
    'total_errors',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _topicSummaryMeta = const VerificationMeta(
    'topicSummary',
  );
  @override
  late final GeneratedColumn<String> topicSummary = GeneratedColumn<String>(
    'topic_summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    endedAt,
    fluencyScore,
    totalUserUtterances,
    totalErrors,
    topicSummary,
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
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('fluency_score')) {
      context.handle(
        _fluencyScoreMeta,
        fluencyScore.isAcceptableOrUnknown(
          data['fluency_score']!,
          _fluencyScoreMeta,
        ),
      );
    }
    if (data.containsKey('total_user_utterances')) {
      context.handle(
        _totalUserUtterancesMeta,
        totalUserUtterances.isAcceptableOrUnknown(
          data['total_user_utterances']!,
          _totalUserUtterancesMeta,
        ),
      );
    }
    if (data.containsKey('total_errors')) {
      context.handle(
        _totalErrorsMeta,
        totalErrors.isAcceptableOrUnknown(
          data['total_errors']!,
          _totalErrorsMeta,
        ),
      );
    }
    if (data.containsKey('topic_summary')) {
      context.handle(
        _topicSummaryMeta,
        topicSummary.isAcceptableOrUnknown(
          data['topic_summary']!,
          _topicSummaryMeta,
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
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      fluencyScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fluency_score'],
      ),
      totalUserUtterances: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_user_utterances'],
      )!,
      totalErrors: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_errors'],
      )!,
      topicSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic_summary'],
      ),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final int id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double? fluencyScore;
  final int totalUserUtterances;
  final int totalErrors;
  final String? topicSummary;
  const Session({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.fluencyScore,
    required this.totalUserUtterances,
    required this.totalErrors,
    this.topicSummary,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    if (!nullToAbsent || fluencyScore != null) {
      map['fluency_score'] = Variable<double>(fluencyScore);
    }
    map['total_user_utterances'] = Variable<int>(totalUserUtterances);
    map['total_errors'] = Variable<int>(totalErrors);
    if (!nullToAbsent || topicSummary != null) {
      map['topic_summary'] = Variable<String>(topicSummary);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      fluencyScore: fluencyScore == null && nullToAbsent
          ? const Value.absent()
          : Value(fluencyScore),
      totalUserUtterances: Value(totalUserUtterances),
      totalErrors: Value(totalErrors),
      topicSummary: topicSummary == null && nullToAbsent
          ? const Value.absent()
          : Value(topicSummary),
    );
  }

  factory Session.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<int>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      fluencyScore: serializer.fromJson<double?>(json['fluencyScore']),
      totalUserUtterances: serializer.fromJson<int>(
        json['totalUserUtterances'],
      ),
      totalErrors: serializer.fromJson<int>(json['totalErrors']),
      topicSummary: serializer.fromJson<String?>(json['topicSummary']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'fluencyScore': serializer.toJson<double?>(fluencyScore),
      'totalUserUtterances': serializer.toJson<int>(totalUserUtterances),
      'totalErrors': serializer.toJson<int>(totalErrors),
      'topicSummary': serializer.toJson<String?>(topicSummary),
    };
  }

  Session copyWith({
    int? id,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    Value<double?> fluencyScore = const Value.absent(),
    int? totalUserUtterances,
    int? totalErrors,
    Value<String?> topicSummary = const Value.absent(),
  }) => Session(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    fluencyScore: fluencyScore.present ? fluencyScore.value : this.fluencyScore,
    totalUserUtterances: totalUserUtterances ?? this.totalUserUtterances,
    totalErrors: totalErrors ?? this.totalErrors,
    topicSummary: topicSummary.present ? topicSummary.value : this.topicSummary,
  );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      fluencyScore: data.fluencyScore.present
          ? data.fluencyScore.value
          : this.fluencyScore,
      totalUserUtterances: data.totalUserUtterances.present
          ? data.totalUserUtterances.value
          : this.totalUserUtterances,
      totalErrors: data.totalErrors.present
          ? data.totalErrors.value
          : this.totalErrors,
      topicSummary: data.topicSummary.present
          ? data.topicSummary.value
          : this.topicSummary,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('fluencyScore: $fluencyScore, ')
          ..write('totalUserUtterances: $totalUserUtterances, ')
          ..write('totalErrors: $totalErrors, ')
          ..write('topicSummary: $topicSummary')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    endedAt,
    fluencyScore,
    totalUserUtterances,
    totalErrors,
    topicSummary,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.fluencyScore == this.fluencyScore &&
          other.totalUserUtterances == this.totalUserUtterances &&
          other.totalErrors == this.totalErrors &&
          other.topicSummary == this.topicSummary);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<int> id;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<double?> fluencyScore;
  final Value<int> totalUserUtterances;
  final Value<int> totalErrors;
  final Value<String?> topicSummary;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.fluencyScore = const Value.absent(),
    this.totalUserUtterances = const Value.absent(),
    this.totalErrors = const Value.absent(),
    this.topicSummary = const Value.absent(),
  });
  SessionsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.fluencyScore = const Value.absent(),
    this.totalUserUtterances = const Value.absent(),
    this.totalErrors = const Value.absent(),
    this.topicSummary = const Value.absent(),
  }) : startedAt = Value(startedAt);
  static Insertable<Session> custom({
    Expression<int>? id,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<double>? fluencyScore,
    Expression<int>? totalUserUtterances,
    Expression<int>? totalErrors,
    Expression<String>? topicSummary,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (fluencyScore != null) 'fluency_score': fluencyScore,
      if (totalUserUtterances != null)
        'total_user_utterances': totalUserUtterances,
      if (totalErrors != null) 'total_errors': totalErrors,
      if (topicSummary != null) 'topic_summary': topicSummary,
    });
  }

  SessionsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<double?>? fluencyScore,
    Value<int>? totalUserUtterances,
    Value<int>? totalErrors,
    Value<String?>? topicSummary,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      fluencyScore: fluencyScore ?? this.fluencyScore,
      totalUserUtterances: totalUserUtterances ?? this.totalUserUtterances,
      totalErrors: totalErrors ?? this.totalErrors,
      topicSummary: topicSummary ?? this.topicSummary,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (fluencyScore.present) {
      map['fluency_score'] = Variable<double>(fluencyScore.value);
    }
    if (totalUserUtterances.present) {
      map['total_user_utterances'] = Variable<int>(totalUserUtterances.value);
    }
    if (totalErrors.present) {
      map['total_errors'] = Variable<int>(totalErrors.value);
    }
    if (topicSummary.present) {
      map['topic_summary'] = Variable<String>(topicSummary.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('fluencyScore: $fluencyScore, ')
          ..write('totalUserUtterances: $totalUserUtterances, ')
          ..write('totalErrors: $totalErrors, ')
          ..write('topicSummary: $topicSummary')
          ..write(')'))
        .toString();
  }
}

class $TranscriptsTable extends Transcripts
    with TableInfo<$TranscriptsTable, Transcript> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranscriptsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  static const VerificationMeta _speakerMeta = const VerificationMeta(
    'speaker',
  );
  @override
  late final GeneratedColumn<String> speaker = GeneratedColumn<String>(
    'speaker',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctedFormMeta = const VerificationMeta(
    'correctedForm',
  );
  @override
  late final GeneratedColumn<String> correctedForm = GeneratedColumn<String>(
    'corrected_form',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    speaker,
    content,
    timestamp,
    correctedForm,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transcripts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transcript> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('speaker')) {
      context.handle(
        _speakerMeta,
        speaker.isAcceptableOrUnknown(data['speaker']!, _speakerMeta),
      );
    } else if (isInserting) {
      context.missing(_speakerMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('corrected_form')) {
      context.handle(
        _correctedFormMeta,
        correctedForm.isAcceptableOrUnknown(
          data['corrected_form']!,
          _correctedFormMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transcript map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transcript(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      speaker: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speaker'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      correctedForm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}corrected_form'],
      ),
    );
  }

  @override
  $TranscriptsTable createAlias(String alias) {
    return $TranscriptsTable(attachedDatabase, alias);
  }
}

class Transcript extends DataClass implements Insertable<Transcript> {
  final int id;
  final int sessionId;
  final String speaker;
  final String content;
  final DateTime timestamp;
  final String? correctedForm;
  const Transcript({
    required this.id,
    required this.sessionId,
    required this.speaker,
    required this.content,
    required this.timestamp,
    this.correctedForm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['speaker'] = Variable<String>(speaker);
    map['content'] = Variable<String>(content);
    map['timestamp'] = Variable<DateTime>(timestamp);
    if (!nullToAbsent || correctedForm != null) {
      map['corrected_form'] = Variable<String>(correctedForm);
    }
    return map;
  }

  TranscriptsCompanion toCompanion(bool nullToAbsent) {
    return TranscriptsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      speaker: Value(speaker),
      content: Value(content),
      timestamp: Value(timestamp),
      correctedForm: correctedForm == null && nullToAbsent
          ? const Value.absent()
          : Value(correctedForm),
    );
  }

  factory Transcript.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transcript(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      speaker: serializer.fromJson<String>(json['speaker']),
      content: serializer.fromJson<String>(json['content']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      correctedForm: serializer.fromJson<String?>(json['correctedForm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'speaker': serializer.toJson<String>(speaker),
      'content': serializer.toJson<String>(content),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'correctedForm': serializer.toJson<String?>(correctedForm),
    };
  }

  Transcript copyWith({
    int? id,
    int? sessionId,
    String? speaker,
    String? content,
    DateTime? timestamp,
    Value<String?> correctedForm = const Value.absent(),
  }) => Transcript(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    speaker: speaker ?? this.speaker,
    content: content ?? this.content,
    timestamp: timestamp ?? this.timestamp,
    correctedForm: correctedForm.present
        ? correctedForm.value
        : this.correctedForm,
  );
  Transcript copyWithCompanion(TranscriptsCompanion data) {
    return Transcript(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      speaker: data.speaker.present ? data.speaker.value : this.speaker,
      content: data.content.present ? data.content.value : this.content,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      correctedForm: data.correctedForm.present
          ? data.correctedForm.value
          : this.correctedForm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transcript(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('speaker: $speaker, ')
          ..write('content: $content, ')
          ..write('timestamp: $timestamp, ')
          ..write('correctedForm: $correctedForm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionId, speaker, content, timestamp, correctedForm);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transcript &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.speaker == this.speaker &&
          other.content == this.content &&
          other.timestamp == this.timestamp &&
          other.correctedForm == this.correctedForm);
}

class TranscriptsCompanion extends UpdateCompanion<Transcript> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<String> speaker;
  final Value<String> content;
  final Value<DateTime> timestamp;
  final Value<String?> correctedForm;
  const TranscriptsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.speaker = const Value.absent(),
    this.content = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.correctedForm = const Value.absent(),
  });
  TranscriptsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required String speaker,
    required String content,
    required DateTime timestamp,
    this.correctedForm = const Value.absent(),
  }) : sessionId = Value(sessionId),
       speaker = Value(speaker),
       content = Value(content),
       timestamp = Value(timestamp);
  static Insertable<Transcript> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<String>? speaker,
    Expression<String>? content,
    Expression<DateTime>? timestamp,
    Expression<String>? correctedForm,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (speaker != null) 'speaker': speaker,
      if (content != null) 'content': content,
      if (timestamp != null) 'timestamp': timestamp,
      if (correctedForm != null) 'corrected_form': correctedForm,
    });
  }

  TranscriptsCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionId,
    Value<String>? speaker,
    Value<String>? content,
    Value<DateTime>? timestamp,
    Value<String?>? correctedForm,
  }) {
    return TranscriptsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      speaker: speaker ?? this.speaker,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      correctedForm: correctedForm ?? this.correctedForm,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (speaker.present) {
      map['speaker'] = Variable<String>(speaker.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (correctedForm.present) {
      map['corrected_form'] = Variable<String>(correctedForm.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('speaker: $speaker, ')
          ..write('content: $content, ')
          ..write('timestamp: $timestamp, ')
          ..write('correctedForm: $correctedForm')
          ..write(')'))
        .toString();
  }
}

class $UserProfilesTable extends UserProfiles
    with TableInfo<$UserProfilesTable, UserProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Student'),
  );
  static const VerificationMeta _nativeLanguageMeta = const VerificationMeta(
    'nativeLanguage',
  );
  @override
  late final GeneratedColumn<String> nativeLanguage = GeneratedColumn<String>(
    'native_language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('cs'),
  );
  static const VerificationMeta _targetLevelMeta = const VerificationMeta(
    'targetLevel',
  );
  @override
  late final GeneratedColumn<String> targetLevel = GeneratedColumn<String>(
    'target_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('B1'),
  );
  static const VerificationMeta _recurringErrorsMeta = const VerificationMeta(
    'recurringErrors',
  );
  @override
  late final GeneratedColumn<String> recurringErrors = GeneratedColumn<String>(
    'recurring_errors',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _vocabularyMeta = const VerificationMeta(
    'vocabulary',
  );
  @override
  late final GeneratedColumn<String> vocabulary = GeneratedColumn<String>(
    'vocabulary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _topicPreferencesMeta = const VerificationMeta(
    'topicPreferences',
  );
  @override
  late final GeneratedColumn<String> topicPreferences = GeneratedColumn<String>(
    'topic_preferences',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _lastSessionAtMeta = const VerificationMeta(
    'lastSessionAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSessionAt =
      GeneratedColumn<DateTime>(
        'last_session_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _totalSessionsMeta = const VerificationMeta(
    'totalSessions',
  );
  @override
  late final GeneratedColumn<int> totalSessions = GeneratedColumn<int>(
    'total_sessions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    displayName,
    nativeLanguage,
    targetLevel,
    recurringErrors,
    vocabulary,
    topicPreferences,
    lastSessionAt,
    totalSessions,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('native_language')) {
      context.handle(
        _nativeLanguageMeta,
        nativeLanguage.isAcceptableOrUnknown(
          data['native_language']!,
          _nativeLanguageMeta,
        ),
      );
    }
    if (data.containsKey('target_level')) {
      context.handle(
        _targetLevelMeta,
        targetLevel.isAcceptableOrUnknown(
          data['target_level']!,
          _targetLevelMeta,
        ),
      );
    }
    if (data.containsKey('recurring_errors')) {
      context.handle(
        _recurringErrorsMeta,
        recurringErrors.isAcceptableOrUnknown(
          data['recurring_errors']!,
          _recurringErrorsMeta,
        ),
      );
    }
    if (data.containsKey('vocabulary')) {
      context.handle(
        _vocabularyMeta,
        vocabulary.isAcceptableOrUnknown(data['vocabulary']!, _vocabularyMeta),
      );
    }
    if (data.containsKey('topic_preferences')) {
      context.handle(
        _topicPreferencesMeta,
        topicPreferences.isAcceptableOrUnknown(
          data['topic_preferences']!,
          _topicPreferencesMeta,
        ),
      );
    }
    if (data.containsKey('last_session_at')) {
      context.handle(
        _lastSessionAtMeta,
        lastSessionAt.isAcceptableOrUnknown(
          data['last_session_at']!,
          _lastSessionAtMeta,
        ),
      );
    }
    if (data.containsKey('total_sessions')) {
      context.handle(
        _totalSessionsMeta,
        totalSessions.isAcceptableOrUnknown(
          data['total_sessions']!,
          _totalSessionsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      nativeLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}native_language'],
      )!,
      targetLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_level'],
      )!,
      recurringErrors: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurring_errors'],
      )!,
      vocabulary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vocabulary'],
      )!,
      topicPreferences: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic_preferences'],
      )!,
      lastSessionAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_session_at'],
      ),
      totalSessions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_sessions'],
      )!,
    );
  }

  @override
  $UserProfilesTable createAlias(String alias) {
    return $UserProfilesTable(attachedDatabase, alias);
  }
}

class UserProfile extends DataClass implements Insertable<UserProfile> {
  final int id;
  final String displayName;
  final String nativeLanguage;
  final String targetLevel;
  final String recurringErrors;
  final String vocabulary;
  final String topicPreferences;
  final DateTime? lastSessionAt;
  final int totalSessions;
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.nativeLanguage,
    required this.targetLevel,
    required this.recurringErrors,
    required this.vocabulary,
    required this.topicPreferences,
    this.lastSessionAt,
    required this.totalSessions,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['display_name'] = Variable<String>(displayName);
    map['native_language'] = Variable<String>(nativeLanguage);
    map['target_level'] = Variable<String>(targetLevel);
    map['recurring_errors'] = Variable<String>(recurringErrors);
    map['vocabulary'] = Variable<String>(vocabulary);
    map['topic_preferences'] = Variable<String>(topicPreferences);
    if (!nullToAbsent || lastSessionAt != null) {
      map['last_session_at'] = Variable<DateTime>(lastSessionAt);
    }
    map['total_sessions'] = Variable<int>(totalSessions);
    return map;
  }

  UserProfilesCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesCompanion(
      id: Value(id),
      displayName: Value(displayName),
      nativeLanguage: Value(nativeLanguage),
      targetLevel: Value(targetLevel),
      recurringErrors: Value(recurringErrors),
      vocabulary: Value(vocabulary),
      topicPreferences: Value(topicPreferences),
      lastSessionAt: lastSessionAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSessionAt),
      totalSessions: Value(totalSessions),
    );
  }

  factory UserProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfile(
      id: serializer.fromJson<int>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      nativeLanguage: serializer.fromJson<String>(json['nativeLanguage']),
      targetLevel: serializer.fromJson<String>(json['targetLevel']),
      recurringErrors: serializer.fromJson<String>(json['recurringErrors']),
      vocabulary: serializer.fromJson<String>(json['vocabulary']),
      topicPreferences: serializer.fromJson<String>(json['topicPreferences']),
      lastSessionAt: serializer.fromJson<DateTime?>(json['lastSessionAt']),
      totalSessions: serializer.fromJson<int>(json['totalSessions']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'displayName': serializer.toJson<String>(displayName),
      'nativeLanguage': serializer.toJson<String>(nativeLanguage),
      'targetLevel': serializer.toJson<String>(targetLevel),
      'recurringErrors': serializer.toJson<String>(recurringErrors),
      'vocabulary': serializer.toJson<String>(vocabulary),
      'topicPreferences': serializer.toJson<String>(topicPreferences),
      'lastSessionAt': serializer.toJson<DateTime?>(lastSessionAt),
      'totalSessions': serializer.toJson<int>(totalSessions),
    };
  }

  UserProfile copyWith({
    int? id,
    String? displayName,
    String? nativeLanguage,
    String? targetLevel,
    String? recurringErrors,
    String? vocabulary,
    String? topicPreferences,
    Value<DateTime?> lastSessionAt = const Value.absent(),
    int? totalSessions,
  }) => UserProfile(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    nativeLanguage: nativeLanguage ?? this.nativeLanguage,
    targetLevel: targetLevel ?? this.targetLevel,
    recurringErrors: recurringErrors ?? this.recurringErrors,
    vocabulary: vocabulary ?? this.vocabulary,
    topicPreferences: topicPreferences ?? this.topicPreferences,
    lastSessionAt: lastSessionAt.present
        ? lastSessionAt.value
        : this.lastSessionAt,
    totalSessions: totalSessions ?? this.totalSessions,
  );
  UserProfile copyWithCompanion(UserProfilesCompanion data) {
    return UserProfile(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      nativeLanguage: data.nativeLanguage.present
          ? data.nativeLanguage.value
          : this.nativeLanguage,
      targetLevel: data.targetLevel.present
          ? data.targetLevel.value
          : this.targetLevel,
      recurringErrors: data.recurringErrors.present
          ? data.recurringErrors.value
          : this.recurringErrors,
      vocabulary: data.vocabulary.present
          ? data.vocabulary.value
          : this.vocabulary,
      topicPreferences: data.topicPreferences.present
          ? data.topicPreferences.value
          : this.topicPreferences,
      lastSessionAt: data.lastSessionAt.present
          ? data.lastSessionAt.value
          : this.lastSessionAt,
      totalSessions: data.totalSessions.present
          ? data.totalSessions.value
          : this.totalSessions,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfile(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('nativeLanguage: $nativeLanguage, ')
          ..write('targetLevel: $targetLevel, ')
          ..write('recurringErrors: $recurringErrors, ')
          ..write('vocabulary: $vocabulary, ')
          ..write('topicPreferences: $topicPreferences, ')
          ..write('lastSessionAt: $lastSessionAt, ')
          ..write('totalSessions: $totalSessions')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    nativeLanguage,
    targetLevel,
    recurringErrors,
    vocabulary,
    topicPreferences,
    lastSessionAt,
    totalSessions,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfile &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.nativeLanguage == this.nativeLanguage &&
          other.targetLevel == this.targetLevel &&
          other.recurringErrors == this.recurringErrors &&
          other.vocabulary == this.vocabulary &&
          other.topicPreferences == this.topicPreferences &&
          other.lastSessionAt == this.lastSessionAt &&
          other.totalSessions == this.totalSessions);
}

class UserProfilesCompanion extends UpdateCompanion<UserProfile> {
  final Value<int> id;
  final Value<String> displayName;
  final Value<String> nativeLanguage;
  final Value<String> targetLevel;
  final Value<String> recurringErrors;
  final Value<String> vocabulary;
  final Value<String> topicPreferences;
  final Value<DateTime?> lastSessionAt;
  final Value<int> totalSessions;
  const UserProfilesCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.nativeLanguage = const Value.absent(),
    this.targetLevel = const Value.absent(),
    this.recurringErrors = const Value.absent(),
    this.vocabulary = const Value.absent(),
    this.topicPreferences = const Value.absent(),
    this.lastSessionAt = const Value.absent(),
    this.totalSessions = const Value.absent(),
  });
  UserProfilesCompanion.insert({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.nativeLanguage = const Value.absent(),
    this.targetLevel = const Value.absent(),
    this.recurringErrors = const Value.absent(),
    this.vocabulary = const Value.absent(),
    this.topicPreferences = const Value.absent(),
    this.lastSessionAt = const Value.absent(),
    this.totalSessions = const Value.absent(),
  });
  static Insertable<UserProfile> custom({
    Expression<int>? id,
    Expression<String>? displayName,
    Expression<String>? nativeLanguage,
    Expression<String>? targetLevel,
    Expression<String>? recurringErrors,
    Expression<String>? vocabulary,
    Expression<String>? topicPreferences,
    Expression<DateTime>? lastSessionAt,
    Expression<int>? totalSessions,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (nativeLanguage != null) 'native_language': nativeLanguage,
      if (targetLevel != null) 'target_level': targetLevel,
      if (recurringErrors != null) 'recurring_errors': recurringErrors,
      if (vocabulary != null) 'vocabulary': vocabulary,
      if (topicPreferences != null) 'topic_preferences': topicPreferences,
      if (lastSessionAt != null) 'last_session_at': lastSessionAt,
      if (totalSessions != null) 'total_sessions': totalSessions,
    });
  }

  UserProfilesCompanion copyWith({
    Value<int>? id,
    Value<String>? displayName,
    Value<String>? nativeLanguage,
    Value<String>? targetLevel,
    Value<String>? recurringErrors,
    Value<String>? vocabulary,
    Value<String>? topicPreferences,
    Value<DateTime?>? lastSessionAt,
    Value<int>? totalSessions,
  }) {
    return UserProfilesCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      targetLevel: targetLevel ?? this.targetLevel,
      recurringErrors: recurringErrors ?? this.recurringErrors,
      vocabulary: vocabulary ?? this.vocabulary,
      topicPreferences: topicPreferences ?? this.topicPreferences,
      lastSessionAt: lastSessionAt ?? this.lastSessionAt,
      totalSessions: totalSessions ?? this.totalSessions,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (nativeLanguage.present) {
      map['native_language'] = Variable<String>(nativeLanguage.value);
    }
    if (targetLevel.present) {
      map['target_level'] = Variable<String>(targetLevel.value);
    }
    if (recurringErrors.present) {
      map['recurring_errors'] = Variable<String>(recurringErrors.value);
    }
    if (vocabulary.present) {
      map['vocabulary'] = Variable<String>(vocabulary.value);
    }
    if (topicPreferences.present) {
      map['topic_preferences'] = Variable<String>(topicPreferences.value);
    }
    if (lastSessionAt.present) {
      map['last_session_at'] = Variable<DateTime>(lastSessionAt.value);
    }
    if (totalSessions.present) {
      map['total_sessions'] = Variable<int>(totalSessions.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('nativeLanguage: $nativeLanguage, ')
          ..write('targetLevel: $targetLevel, ')
          ..write('recurringErrors: $recurringErrors, ')
          ..write('vocabulary: $vocabulary, ')
          ..write('topicPreferences: $topicPreferences, ')
          ..write('lastSessionAt: $lastSessionAt, ')
          ..write('totalSessions: $totalSessions')
          ..write(')'))
        .toString();
  }
}

class $ErrorLogsTable extends ErrorLogs
    with TableInfo<$ErrorLogsTable, ErrorLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ErrorLogsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  static const VerificationMeta _errorTypeMeta = const VerificationMeta(
    'errorType',
  );
  @override
  late final GeneratedColumn<String> errorType = GeneratedColumn<String>(
    'error_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userSaidMeta = const VerificationMeta(
    'userSaid',
  );
  @override
  late final GeneratedColumn<String> userSaid = GeneratedColumn<String>(
    'user_said',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctFormMeta = const VerificationMeta(
    'correctForm',
  );
  @override
  late final GeneratedColumn<String> correctForm = GeneratedColumn<String>(
    'correct_form',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _explanationMeta = const VerificationMeta(
    'explanation',
  );
  @override
  late final GeneratedColumn<String> explanation = GeneratedColumn<String>(
    'explanation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    errorType,
    userSaid,
    correctForm,
    explanation,
    timestamp,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'error_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ErrorLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('error_type')) {
      context.handle(
        _errorTypeMeta,
        errorType.isAcceptableOrUnknown(data['error_type']!, _errorTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_errorTypeMeta);
    }
    if (data.containsKey('user_said')) {
      context.handle(
        _userSaidMeta,
        userSaid.isAcceptableOrUnknown(data['user_said']!, _userSaidMeta),
      );
    } else if (isInserting) {
      context.missing(_userSaidMeta);
    }
    if (data.containsKey('correct_form')) {
      context.handle(
        _correctFormMeta,
        correctForm.isAcceptableOrUnknown(
          data['correct_form']!,
          _correctFormMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_correctFormMeta);
    }
    if (data.containsKey('explanation')) {
      context.handle(
        _explanationMeta,
        explanation.isAcceptableOrUnknown(
          data['explanation']!,
          _explanationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_explanationMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ErrorLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ErrorLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      errorType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_type'],
      )!,
      userSaid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_said'],
      )!,
      correctForm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}correct_form'],
      )!,
      explanation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}explanation'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
    );
  }

  @override
  $ErrorLogsTable createAlias(String alias) {
    return $ErrorLogsTable(attachedDatabase, alias);
  }
}

class ErrorLog extends DataClass implements Insertable<ErrorLog> {
  final int id;
  final int sessionId;
  final String errorType;
  final String userSaid;
  final String correctForm;
  final String explanation;
  final DateTime timestamp;
  const ErrorLog({
    required this.id,
    required this.sessionId,
    required this.errorType,
    required this.userSaid,
    required this.correctForm,
    required this.explanation,
    required this.timestamp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['error_type'] = Variable<String>(errorType);
    map['user_said'] = Variable<String>(userSaid);
    map['correct_form'] = Variable<String>(correctForm);
    map['explanation'] = Variable<String>(explanation);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  ErrorLogsCompanion toCompanion(bool nullToAbsent) {
    return ErrorLogsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      errorType: Value(errorType),
      userSaid: Value(userSaid),
      correctForm: Value(correctForm),
      explanation: Value(explanation),
      timestamp: Value(timestamp),
    );
  }

  factory ErrorLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ErrorLog(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      errorType: serializer.fromJson<String>(json['errorType']),
      userSaid: serializer.fromJson<String>(json['userSaid']),
      correctForm: serializer.fromJson<String>(json['correctForm']),
      explanation: serializer.fromJson<String>(json['explanation']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'errorType': serializer.toJson<String>(errorType),
      'userSaid': serializer.toJson<String>(userSaid),
      'correctForm': serializer.toJson<String>(correctForm),
      'explanation': serializer.toJson<String>(explanation),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  ErrorLog copyWith({
    int? id,
    int? sessionId,
    String? errorType,
    String? userSaid,
    String? correctForm,
    String? explanation,
    DateTime? timestamp,
  }) => ErrorLog(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    errorType: errorType ?? this.errorType,
    userSaid: userSaid ?? this.userSaid,
    correctForm: correctForm ?? this.correctForm,
    explanation: explanation ?? this.explanation,
    timestamp: timestamp ?? this.timestamp,
  );
  ErrorLog copyWithCompanion(ErrorLogsCompanion data) {
    return ErrorLog(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      errorType: data.errorType.present ? data.errorType.value : this.errorType,
      userSaid: data.userSaid.present ? data.userSaid.value : this.userSaid,
      correctForm: data.correctForm.present
          ? data.correctForm.value
          : this.correctForm,
      explanation: data.explanation.present
          ? data.explanation.value
          : this.explanation,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ErrorLog(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('errorType: $errorType, ')
          ..write('userSaid: $userSaid, ')
          ..write('correctForm: $correctForm, ')
          ..write('explanation: $explanation, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    errorType,
    userSaid,
    correctForm,
    explanation,
    timestamp,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ErrorLog &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.errorType == this.errorType &&
          other.userSaid == this.userSaid &&
          other.correctForm == this.correctForm &&
          other.explanation == this.explanation &&
          other.timestamp == this.timestamp);
}

class ErrorLogsCompanion extends UpdateCompanion<ErrorLog> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<String> errorType;
  final Value<String> userSaid;
  final Value<String> correctForm;
  final Value<String> explanation;
  final Value<DateTime> timestamp;
  const ErrorLogsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.errorType = const Value.absent(),
    this.userSaid = const Value.absent(),
    this.correctForm = const Value.absent(),
    this.explanation = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  ErrorLogsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required String errorType,
    required String userSaid,
    required String correctForm,
    required String explanation,
    required DateTime timestamp,
  }) : sessionId = Value(sessionId),
       errorType = Value(errorType),
       userSaid = Value(userSaid),
       correctForm = Value(correctForm),
       explanation = Value(explanation),
       timestamp = Value(timestamp);
  static Insertable<ErrorLog> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<String>? errorType,
    Expression<String>? userSaid,
    Expression<String>? correctForm,
    Expression<String>? explanation,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (errorType != null) 'error_type': errorType,
      if (userSaid != null) 'user_said': userSaid,
      if (correctForm != null) 'correct_form': correctForm,
      if (explanation != null) 'explanation': explanation,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  ErrorLogsCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionId,
    Value<String>? errorType,
    Value<String>? userSaid,
    Value<String>? correctForm,
    Value<String>? explanation,
    Value<DateTime>? timestamp,
  }) {
    return ErrorLogsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      errorType: errorType ?? this.errorType,
      userSaid: userSaid ?? this.userSaid,
      correctForm: correctForm ?? this.correctForm,
      explanation: explanation ?? this.explanation,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (errorType.present) {
      map['error_type'] = Variable<String>(errorType.value);
    }
    if (userSaid.present) {
      map['user_said'] = Variable<String>(userSaid.value);
    }
    if (correctForm.present) {
      map['correct_form'] = Variable<String>(correctForm.value);
    }
    if (explanation.present) {
      map['explanation'] = Variable<String>(explanation.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ErrorLogsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('errorType: $errorType, ')
          ..write('userSaid: $userSaid, ')
          ..write('correctForm: $correctForm, ')
          ..write('explanation: $explanation, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $TranscriptsTable transcripts = $TranscriptsTable(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  late final $ErrorLogsTable errorLogs = $ErrorLogsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sessions,
    transcripts,
    userProfiles,
    errorLogs,
  ];
}

typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      Value<int> id,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<double?> fluencyScore,
      Value<int> totalUserUtterances,
      Value<int> totalErrors,
      Value<String?> topicSummary,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<int> id,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<double?> fluencyScore,
      Value<int> totalUserUtterances,
      Value<int> totalErrors,
      Value<String?> topicSummary,
    });

final class $$SessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTable, Session> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TranscriptsTable, List<Transcript>>
  _transcriptsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transcripts,
    aliasName: 'sessions__id__transcripts__session_id',
  );

  $$TranscriptsTableProcessedTableManager get transcriptsRefs {
    final manager = $$TranscriptsTableTableManager(
      $_db,
      $_db.transcripts,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_transcriptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ErrorLogsTable, List<ErrorLog>>
  _errorLogsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.errorLogs,
    aliasName: 'sessions__id__error_logs__session_id',
  );

  $$ErrorLogsTableProcessedTableManager get errorLogsRefs {
    final manager = $$ErrorLogsTableTableManager(
      $_db,
      $_db.errorLogs,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_errorLogsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
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

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fluencyScore => $composableBuilder(
    column: $table.fluencyScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalUserUtterances => $composableBuilder(
    column: $table.totalUserUtterances,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalErrors => $composableBuilder(
    column: $table.totalErrors,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topicSummary => $composableBuilder(
    column: $table.topicSummary,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> transcriptsRefs(
    Expression<bool> Function($$TranscriptsTableFilterComposer f) f,
  ) {
    final $$TranscriptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transcripts,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptsTableFilterComposer(
            $db: $db,
            $table: $db.transcripts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> errorLogsRefs(
    Expression<bool> Function($$ErrorLogsTableFilterComposer f) f,
  ) {
    final $$ErrorLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.errorLogs,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ErrorLogsTableFilterComposer(
            $db: $db,
            $table: $db.errorLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
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
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fluencyScore => $composableBuilder(
    column: $table.fluencyScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalUserUtterances => $composableBuilder(
    column: $table.totalUserUtterances,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalErrors => $composableBuilder(
    column: $table.totalErrors,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topicSummary => $composableBuilder(
    column: $table.topicSummary,
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
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<double> get fluencyScore => $composableBuilder(
    column: $table.fluencyScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalUserUtterances => $composableBuilder(
    column: $table.totalUserUtterances,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalErrors => $composableBuilder(
    column: $table.totalErrors,
    builder: (column) => column,
  );

  GeneratedColumn<String> get topicSummary => $composableBuilder(
    column: $table.topicSummary,
    builder: (column) => column,
  );

  Expression<T> transcriptsRefs<T extends Object>(
    Expression<T> Function($$TranscriptsTableAnnotationComposer a) f,
  ) {
    final $$TranscriptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transcripts,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptsTableAnnotationComposer(
            $db: $db,
            $table: $db.transcripts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> errorLogsRefs<T extends Object>(
    Expression<T> Function($$ErrorLogsTableAnnotationComposer a) f,
  ) {
    final $$ErrorLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.errorLogs,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ErrorLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.errorLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
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
          (Session, $$SessionsTableReferences),
          Session,
          PrefetchHooks Function({bool transcriptsRefs, bool errorLogsRefs})
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
                Value<int> id = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<double?> fluencyScore = const Value.absent(),
                Value<int> totalUserUtterances = const Value.absent(),
                Value<int> totalErrors = const Value.absent(),
                Value<String?> topicSummary = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                fluencyScore: fluencyScore,
                totalUserUtterances: totalUserUtterances,
                totalErrors: totalErrors,
                topicSummary: topicSummary,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<double?> fluencyScore = const Value.absent(),
                Value<int> totalUserUtterances = const Value.absent(),
                Value<int> totalErrors = const Value.absent(),
                Value<String?> topicSummary = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                fluencyScore: fluencyScore,
                totalUserUtterances: totalUserUtterances,
                totalErrors: totalErrors,
                topicSummary: topicSummary,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({transcriptsRefs = false, errorLogsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transcriptsRefs) db.transcripts,
                    if (errorLogsRefs) db.errorLogs,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transcriptsRefs)
                        await $_getPrefetchedData<
                          Session,
                          $SessionsTable,
                          Transcript
                        >(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences
                              ._transcriptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).transcriptsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (errorLogsRefs)
                        await $_getPrefetchedData<
                          Session,
                          $SessionsTable,
                          ErrorLog
                        >(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences
                              ._errorLogsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).errorLogsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
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
      (Session, $$SessionsTableReferences),
      Session,
      PrefetchHooks Function({bool transcriptsRefs, bool errorLogsRefs})
    >;
typedef $$TranscriptsTableCreateCompanionBuilder =
    TranscriptsCompanion Function({
      Value<int> id,
      required int sessionId,
      required String speaker,
      required String content,
      required DateTime timestamp,
      Value<String?> correctedForm,
    });
typedef $$TranscriptsTableUpdateCompanionBuilder =
    TranscriptsCompanion Function({
      Value<int> id,
      Value<int> sessionId,
      Value<String> speaker,
      Value<String> content,
      Value<DateTime> timestamp,
      Value<String?> correctedForm,
    });

final class $$TranscriptsTableReferences
    extends BaseReferences<_$AppDatabase, $TranscriptsTable, Transcript> {
  $$TranscriptsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias('transcripts__session_id__sessions__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TranscriptsTableFilterComposer
    extends Composer<_$AppDatabase, $TranscriptsTable> {
  $$TranscriptsTableFilterComposer({
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

  ColumnFilters<String> get speaker => $composableBuilder(
    column: $table.speaker,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get correctedForm => $composableBuilder(
    column: $table.correctedForm,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptsTableOrderingComposer
    extends Composer<_$AppDatabase, $TranscriptsTable> {
  $$TranscriptsTableOrderingComposer({
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

  ColumnOrderings<String> get speaker => $composableBuilder(
    column: $table.speaker,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get correctedForm => $composableBuilder(
    column: $table.correctedForm,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TranscriptsTable> {
  $$TranscriptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get speaker =>
      $composableBuilder(column: $table.speaker, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get correctedForm => $composableBuilder(
    column: $table.correctedForm,
    builder: (column) => column,
  );

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TranscriptsTable,
          Transcript,
          $$TranscriptsTableFilterComposer,
          $$TranscriptsTableOrderingComposer,
          $$TranscriptsTableAnnotationComposer,
          $$TranscriptsTableCreateCompanionBuilder,
          $$TranscriptsTableUpdateCompanionBuilder,
          (Transcript, $$TranscriptsTableReferences),
          Transcript,
          PrefetchHooks Function({bool sessionId})
        > {
  $$TranscriptsTableTableManager(_$AppDatabase db, $TranscriptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranscriptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranscriptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranscriptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<String> speaker = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String?> correctedForm = const Value.absent(),
              }) => TranscriptsCompanion(
                id: id,
                sessionId: sessionId,
                speaker: speaker,
                content: content,
                timestamp: timestamp,
                correctedForm: correctedForm,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionId,
                required String speaker,
                required String content,
                required DateTime timestamp,
                Value<String?> correctedForm = const Value.absent(),
              }) => TranscriptsCompanion.insert(
                id: id,
                sessionId: sessionId,
                speaker: speaker,
                content: content,
                timestamp: timestamp,
                correctedForm: correctedForm,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TranscriptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$TranscriptsTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$TranscriptsTableReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TranscriptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TranscriptsTable,
      Transcript,
      $$TranscriptsTableFilterComposer,
      $$TranscriptsTableOrderingComposer,
      $$TranscriptsTableAnnotationComposer,
      $$TranscriptsTableCreateCompanionBuilder,
      $$TranscriptsTableUpdateCompanionBuilder,
      (Transcript, $$TranscriptsTableReferences),
      Transcript,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$UserProfilesTableCreateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<int> id,
      Value<String> displayName,
      Value<String> nativeLanguage,
      Value<String> targetLevel,
      Value<String> recurringErrors,
      Value<String> vocabulary,
      Value<String> topicPreferences,
      Value<DateTime?> lastSessionAt,
      Value<int> totalSessions,
    });
typedef $$UserProfilesTableUpdateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<int> id,
      Value<String> displayName,
      Value<String> nativeLanguage,
      Value<String> targetLevel,
      Value<String> recurringErrors,
      Value<String> vocabulary,
      Value<String> topicPreferences,
      Value<DateTime?> lastSessionAt,
      Value<int> totalSessions,
    });

class $$UserProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableFilterComposer({
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

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nativeLanguage => $composableBuilder(
    column: $table.nativeLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetLevel => $composableBuilder(
    column: $table.targetLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurringErrors => $composableBuilder(
    column: $table.recurringErrors,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vocabulary => $composableBuilder(
    column: $table.vocabulary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topicPreferences => $composableBuilder(
    column: $table.topicPreferences,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSessionAt => $composableBuilder(
    column: $table.lastSessionAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalSessions => $composableBuilder(
    column: $table.totalSessions,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableOrderingComposer({
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

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nativeLanguage => $composableBuilder(
    column: $table.nativeLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetLevel => $composableBuilder(
    column: $table.targetLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurringErrors => $composableBuilder(
    column: $table.recurringErrors,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vocabulary => $composableBuilder(
    column: $table.vocabulary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topicPreferences => $composableBuilder(
    column: $table.topicPreferences,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSessionAt => $composableBuilder(
    column: $table.lastSessionAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalSessions => $composableBuilder(
    column: $table.totalSessions,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nativeLanguage => $composableBuilder(
    column: $table.nativeLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetLevel => $composableBuilder(
    column: $table.targetLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurringErrors => $composableBuilder(
    column: $table.recurringErrors,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vocabulary => $composableBuilder(
    column: $table.vocabulary,
    builder: (column) => column,
  );

  GeneratedColumn<String> get topicPreferences => $composableBuilder(
    column: $table.topicPreferences,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSessionAt => $composableBuilder(
    column: $table.lastSessionAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalSessions => $composableBuilder(
    column: $table.totalSessions,
    builder: (column) => column,
  );
}

class $$UserProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfilesTable,
          UserProfile,
          $$UserProfilesTableFilterComposer,
          $$UserProfilesTableOrderingComposer,
          $$UserProfilesTableAnnotationComposer,
          $$UserProfilesTableCreateCompanionBuilder,
          $$UserProfilesTableUpdateCompanionBuilder,
          (
            UserProfile,
            BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfile>,
          ),
          UserProfile,
          PrefetchHooks Function()
        > {
  $$UserProfilesTableTableManager(_$AppDatabase db, $UserProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> nativeLanguage = const Value.absent(),
                Value<String> targetLevel = const Value.absent(),
                Value<String> recurringErrors = const Value.absent(),
                Value<String> vocabulary = const Value.absent(),
                Value<String> topicPreferences = const Value.absent(),
                Value<DateTime?> lastSessionAt = const Value.absent(),
                Value<int> totalSessions = const Value.absent(),
              }) => UserProfilesCompanion(
                id: id,
                displayName: displayName,
                nativeLanguage: nativeLanguage,
                targetLevel: targetLevel,
                recurringErrors: recurringErrors,
                vocabulary: vocabulary,
                topicPreferences: topicPreferences,
                lastSessionAt: lastSessionAt,
                totalSessions: totalSessions,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> nativeLanguage = const Value.absent(),
                Value<String> targetLevel = const Value.absent(),
                Value<String> recurringErrors = const Value.absent(),
                Value<String> vocabulary = const Value.absent(),
                Value<String> topicPreferences = const Value.absent(),
                Value<DateTime?> lastSessionAt = const Value.absent(),
                Value<int> totalSessions = const Value.absent(),
              }) => UserProfilesCompanion.insert(
                id: id,
                displayName: displayName,
                nativeLanguage: nativeLanguage,
                targetLevel: targetLevel,
                recurringErrors: recurringErrors,
                vocabulary: vocabulary,
                topicPreferences: topicPreferences,
                lastSessionAt: lastSessionAt,
                totalSessions: totalSessions,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfilesTable,
      UserProfile,
      $$UserProfilesTableFilterComposer,
      $$UserProfilesTableOrderingComposer,
      $$UserProfilesTableAnnotationComposer,
      $$UserProfilesTableCreateCompanionBuilder,
      $$UserProfilesTableUpdateCompanionBuilder,
      (
        UserProfile,
        BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfile>,
      ),
      UserProfile,
      PrefetchHooks Function()
    >;
typedef $$ErrorLogsTableCreateCompanionBuilder =
    ErrorLogsCompanion Function({
      Value<int> id,
      required int sessionId,
      required String errorType,
      required String userSaid,
      required String correctForm,
      required String explanation,
      required DateTime timestamp,
    });
typedef $$ErrorLogsTableUpdateCompanionBuilder =
    ErrorLogsCompanion Function({
      Value<int> id,
      Value<int> sessionId,
      Value<String> errorType,
      Value<String> userSaid,
      Value<String> correctForm,
      Value<String> explanation,
      Value<DateTime> timestamp,
    });

final class $$ErrorLogsTableReferences
    extends BaseReferences<_$AppDatabase, $ErrorLogsTable, ErrorLog> {
  $$ErrorLogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias('error_logs__session_id__sessions__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ErrorLogsTableFilterComposer
    extends Composer<_$AppDatabase, $ErrorLogsTable> {
  $$ErrorLogsTableFilterComposer({
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

  ColumnFilters<String> get errorType => $composableBuilder(
    column: $table.errorType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userSaid => $composableBuilder(
    column: $table.userSaid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get correctForm => $composableBuilder(
    column: $table.correctForm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ErrorLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $ErrorLogsTable> {
  $$ErrorLogsTableOrderingComposer({
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

  ColumnOrderings<String> get errorType => $composableBuilder(
    column: $table.errorType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userSaid => $composableBuilder(
    column: $table.userSaid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get correctForm => $composableBuilder(
    column: $table.correctForm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ErrorLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ErrorLogsTable> {
  $$ErrorLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get errorType =>
      $composableBuilder(column: $table.errorType, builder: (column) => column);

  GeneratedColumn<String> get userSaid =>
      $composableBuilder(column: $table.userSaid, builder: (column) => column);

  GeneratedColumn<String> get correctForm => $composableBuilder(
    column: $table.correctForm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ErrorLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ErrorLogsTable,
          ErrorLog,
          $$ErrorLogsTableFilterComposer,
          $$ErrorLogsTableOrderingComposer,
          $$ErrorLogsTableAnnotationComposer,
          $$ErrorLogsTableCreateCompanionBuilder,
          $$ErrorLogsTableUpdateCompanionBuilder,
          (ErrorLog, $$ErrorLogsTableReferences),
          ErrorLog,
          PrefetchHooks Function({bool sessionId})
        > {
  $$ErrorLogsTableTableManager(_$AppDatabase db, $ErrorLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ErrorLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ErrorLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ErrorLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<String> errorType = const Value.absent(),
                Value<String> userSaid = const Value.absent(),
                Value<String> correctForm = const Value.absent(),
                Value<String> explanation = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
              }) => ErrorLogsCompanion(
                id: id,
                sessionId: sessionId,
                errorType: errorType,
                userSaid: userSaid,
                correctForm: correctForm,
                explanation: explanation,
                timestamp: timestamp,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionId,
                required String errorType,
                required String userSaid,
                required String correctForm,
                required String explanation,
                required DateTime timestamp,
              }) => ErrorLogsCompanion.insert(
                id: id,
                sessionId: sessionId,
                errorType: errorType,
                userSaid: userSaid,
                correctForm: correctForm,
                explanation: explanation,
                timestamp: timestamp,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ErrorLogsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$ErrorLogsTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$ErrorLogsTableReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ErrorLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ErrorLogsTable,
      ErrorLog,
      $$ErrorLogsTableFilterComposer,
      $$ErrorLogsTableOrderingComposer,
      $$ErrorLogsTableAnnotationComposer,
      $$ErrorLogsTableCreateCompanionBuilder,
      $$ErrorLogsTableUpdateCompanionBuilder,
      (ErrorLog, $$ErrorLogsTableReferences),
      ErrorLog,
      PrefetchHooks Function({bool sessionId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$TranscriptsTableTableManager get transcripts =>
      $$TranscriptsTableTableManager(_db, _db.transcripts);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
  $$ErrorLogsTableTableManager get errorLogs =>
      $$ErrorLogsTableTableManager(_db, _db.errorLogs);
}
