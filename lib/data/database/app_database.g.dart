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
  static const VerificationMeta _inFlashcardMeta = const VerificationMeta(
    'inFlashcard',
  );
  @override
  late final GeneratedColumn<bool> inFlashcard = GeneratedColumn<bool>(
    'in_flashcard',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("in_flashcard" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    speaker,
    content,
    timestamp,
    correctedForm,
    inFlashcard,
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
    if (data.containsKey('in_flashcard')) {
      context.handle(
        _inFlashcardMeta,
        inFlashcard.isAcceptableOrUnknown(
          data['in_flashcard']!,
          _inFlashcardMeta,
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
      inFlashcard: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}in_flashcard'],
      )!,
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
  final bool inFlashcard;
  const Transcript({
    required this.id,
    required this.sessionId,
    required this.speaker,
    required this.content,
    required this.timestamp,
    this.correctedForm,
    required this.inFlashcard,
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
    map['in_flashcard'] = Variable<bool>(inFlashcard);
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
      inFlashcard: Value(inFlashcard),
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
      inFlashcard: serializer.fromJson<bool>(json['inFlashcard']),
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
      'inFlashcard': serializer.toJson<bool>(inFlashcard),
    };
  }

  Transcript copyWith({
    int? id,
    int? sessionId,
    String? speaker,
    String? content,
    DateTime? timestamp,
    Value<String?> correctedForm = const Value.absent(),
    bool? inFlashcard,
  }) => Transcript(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    speaker: speaker ?? this.speaker,
    content: content ?? this.content,
    timestamp: timestamp ?? this.timestamp,
    correctedForm: correctedForm.present
        ? correctedForm.value
        : this.correctedForm,
    inFlashcard: inFlashcard ?? this.inFlashcard,
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
      inFlashcard: data.inFlashcard.present
          ? data.inFlashcard.value
          : this.inFlashcard,
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
          ..write('correctedForm: $correctedForm, ')
          ..write('inFlashcard: $inFlashcard')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    speaker,
    content,
    timestamp,
    correctedForm,
    inFlashcard,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transcript &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.speaker == this.speaker &&
          other.content == this.content &&
          other.timestamp == this.timestamp &&
          other.correctedForm == this.correctedForm &&
          other.inFlashcard == this.inFlashcard);
}

class TranscriptsCompanion extends UpdateCompanion<Transcript> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<String> speaker;
  final Value<String> content;
  final Value<DateTime> timestamp;
  final Value<String?> correctedForm;
  final Value<bool> inFlashcard;
  const TranscriptsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.speaker = const Value.absent(),
    this.content = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.correctedForm = const Value.absent(),
    this.inFlashcard = const Value.absent(),
  });
  TranscriptsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required String speaker,
    required String content,
    required DateTime timestamp,
    this.correctedForm = const Value.absent(),
    this.inFlashcard = const Value.absent(),
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
    Expression<bool>? inFlashcard,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (speaker != null) 'speaker': speaker,
      if (content != null) 'content': content,
      if (timestamp != null) 'timestamp': timestamp,
      if (correctedForm != null) 'corrected_form': correctedForm,
      if (inFlashcard != null) 'in_flashcard': inFlashcard,
    });
  }

  TranscriptsCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionId,
    Value<String>? speaker,
    Value<String>? content,
    Value<DateTime>? timestamp,
    Value<String?>? correctedForm,
    Value<bool>? inFlashcard,
  }) {
    return TranscriptsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      speaker: speaker ?? this.speaker,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      correctedForm: correctedForm ?? this.correctedForm,
      inFlashcard: inFlashcard ?? this.inFlashcard,
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
    if (inFlashcard.present) {
      map['in_flashcard'] = Variable<bool>(inFlashcard.value);
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
          ..write('correctedForm: $correctedForm, ')
          ..write('inFlashcard: $inFlashcard')
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
  static const VerificationMeta _memoryBriefingMeta = const VerificationMeta(
    'memoryBriefing',
  );
  @override
  late final GeneratedColumn<String> memoryBriefing = GeneratedColumn<String>(
    'memory_briefing',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userFactsMeta = const VerificationMeta(
    'userFacts',
  );
  @override
  late final GeneratedColumn<String> userFacts = GeneratedColumn<String>(
    'user_facts',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _preparedTopicMeta = const VerificationMeta(
    'preparedTopic',
  );
  @override
  late final GeneratedColumn<String> preparedTopic = GeneratedColumn<String>(
    'prepared_topic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _preparedTopicAtMeta = const VerificationMeta(
    'preparedTopicAt',
  );
  @override
  late final GeneratedColumn<DateTime> preparedTopicAt =
      GeneratedColumn<DateTime>(
        'prepared_topic_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
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
    memoryBriefing,
    userFacts,
    preparedTopic,
    preparedTopicAt,
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
    if (data.containsKey('memory_briefing')) {
      context.handle(
        _memoryBriefingMeta,
        memoryBriefing.isAcceptableOrUnknown(
          data['memory_briefing']!,
          _memoryBriefingMeta,
        ),
      );
    }
    if (data.containsKey('user_facts')) {
      context.handle(
        _userFactsMeta,
        userFacts.isAcceptableOrUnknown(data['user_facts']!, _userFactsMeta),
      );
    }
    if (data.containsKey('prepared_topic')) {
      context.handle(
        _preparedTopicMeta,
        preparedTopic.isAcceptableOrUnknown(
          data['prepared_topic']!,
          _preparedTopicMeta,
        ),
      );
    }
    if (data.containsKey('prepared_topic_at')) {
      context.handle(
        _preparedTopicAtMeta,
        preparedTopicAt.isAcceptableOrUnknown(
          data['prepared_topic_at']!,
          _preparedTopicAtMeta,
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
      memoryBriefing: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memory_briefing'],
      ),
      userFacts: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_facts'],
      )!,
      preparedTopic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prepared_topic'],
      ),
      preparedTopicAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}prepared_topic_at'],
      ),
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
  final String? memoryBriefing;
  final String userFacts;
  final String? preparedTopic;
  final DateTime? preparedTopicAt;
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
    this.memoryBriefing,
    required this.userFacts,
    this.preparedTopic,
    this.preparedTopicAt,
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
    if (!nullToAbsent || memoryBriefing != null) {
      map['memory_briefing'] = Variable<String>(memoryBriefing);
    }
    map['user_facts'] = Variable<String>(userFacts);
    if (!nullToAbsent || preparedTopic != null) {
      map['prepared_topic'] = Variable<String>(preparedTopic);
    }
    if (!nullToAbsent || preparedTopicAt != null) {
      map['prepared_topic_at'] = Variable<DateTime>(preparedTopicAt);
    }
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
      memoryBriefing: memoryBriefing == null && nullToAbsent
          ? const Value.absent()
          : Value(memoryBriefing),
      userFacts: Value(userFacts),
      preparedTopic: preparedTopic == null && nullToAbsent
          ? const Value.absent()
          : Value(preparedTopic),
      preparedTopicAt: preparedTopicAt == null && nullToAbsent
          ? const Value.absent()
          : Value(preparedTopicAt),
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
      memoryBriefing: serializer.fromJson<String?>(json['memoryBriefing']),
      userFacts: serializer.fromJson<String>(json['userFacts']),
      preparedTopic: serializer.fromJson<String?>(json['preparedTopic']),
      preparedTopicAt: serializer.fromJson<DateTime?>(json['preparedTopicAt']),
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
      'memoryBriefing': serializer.toJson<String?>(memoryBriefing),
      'userFacts': serializer.toJson<String>(userFacts),
      'preparedTopic': serializer.toJson<String?>(preparedTopic),
      'preparedTopicAt': serializer.toJson<DateTime?>(preparedTopicAt),
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
    Value<String?> memoryBriefing = const Value.absent(),
    String? userFacts,
    Value<String?> preparedTopic = const Value.absent(),
    Value<DateTime?> preparedTopicAt = const Value.absent(),
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
    memoryBriefing: memoryBriefing.present
        ? memoryBriefing.value
        : this.memoryBriefing,
    userFacts: userFacts ?? this.userFacts,
    preparedTopic: preparedTopic.present
        ? preparedTopic.value
        : this.preparedTopic,
    preparedTopicAt: preparedTopicAt.present
        ? preparedTopicAt.value
        : this.preparedTopicAt,
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
      memoryBriefing: data.memoryBriefing.present
          ? data.memoryBriefing.value
          : this.memoryBriefing,
      userFacts: data.userFacts.present ? data.userFacts.value : this.userFacts,
      preparedTopic: data.preparedTopic.present
          ? data.preparedTopic.value
          : this.preparedTopic,
      preparedTopicAt: data.preparedTopicAt.present
          ? data.preparedTopicAt.value
          : this.preparedTopicAt,
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
          ..write('totalSessions: $totalSessions, ')
          ..write('memoryBriefing: $memoryBriefing, ')
          ..write('userFacts: $userFacts, ')
          ..write('preparedTopic: $preparedTopic, ')
          ..write('preparedTopicAt: $preparedTopicAt')
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
    memoryBriefing,
    userFacts,
    preparedTopic,
    preparedTopicAt,
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
          other.totalSessions == this.totalSessions &&
          other.memoryBriefing == this.memoryBriefing &&
          other.userFacts == this.userFacts &&
          other.preparedTopic == this.preparedTopic &&
          other.preparedTopicAt == this.preparedTopicAt);
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
  final Value<String?> memoryBriefing;
  final Value<String> userFacts;
  final Value<String?> preparedTopic;
  final Value<DateTime?> preparedTopicAt;
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
    this.memoryBriefing = const Value.absent(),
    this.userFacts = const Value.absent(),
    this.preparedTopic = const Value.absent(),
    this.preparedTopicAt = const Value.absent(),
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
    this.memoryBriefing = const Value.absent(),
    this.userFacts = const Value.absent(),
    this.preparedTopic = const Value.absent(),
    this.preparedTopicAt = const Value.absent(),
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
    Expression<String>? memoryBriefing,
    Expression<String>? userFacts,
    Expression<String>? preparedTopic,
    Expression<DateTime>? preparedTopicAt,
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
      if (memoryBriefing != null) 'memory_briefing': memoryBriefing,
      if (userFacts != null) 'user_facts': userFacts,
      if (preparedTopic != null) 'prepared_topic': preparedTopic,
      if (preparedTopicAt != null) 'prepared_topic_at': preparedTopicAt,
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
    Value<String?>? memoryBriefing,
    Value<String>? userFacts,
    Value<String?>? preparedTopic,
    Value<DateTime?>? preparedTopicAt,
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
      memoryBriefing: memoryBriefing ?? this.memoryBriefing,
      userFacts: userFacts ?? this.userFacts,
      preparedTopic: preparedTopic ?? this.preparedTopic,
      preparedTopicAt: preparedTopicAt ?? this.preparedTopicAt,
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
    if (memoryBriefing.present) {
      map['memory_briefing'] = Variable<String>(memoryBriefing.value);
    }
    if (userFacts.present) {
      map['user_facts'] = Variable<String>(userFacts.value);
    }
    if (preparedTopic.present) {
      map['prepared_topic'] = Variable<String>(preparedTopic.value);
    }
    if (preparedTopicAt.present) {
      map['prepared_topic_at'] = Variable<DateTime>(preparedTopicAt.value);
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
          ..write('totalSessions: $totalSessions, ')
          ..write('memoryBriefing: $memoryBriefing, ')
          ..write('userFacts: $userFacts, ')
          ..write('preparedTopic: $preparedTopic, ')
          ..write('preparedTopicAt: $preparedTopicAt')
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
  static const VerificationMeta _inFlashcardMeta = const VerificationMeta(
    'inFlashcard',
  );
  @override
  late final GeneratedColumn<bool> inFlashcard = GeneratedColumn<bool>(
    'in_flashcard',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("in_flashcard" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    inFlashcard,
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
    if (data.containsKey('in_flashcard')) {
      context.handle(
        _inFlashcardMeta,
        inFlashcard.isAcceptableOrUnknown(
          data['in_flashcard']!,
          _inFlashcardMeta,
        ),
      );
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
      inFlashcard: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}in_flashcard'],
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
  final bool inFlashcard;
  const ErrorLog({
    required this.id,
    required this.sessionId,
    required this.errorType,
    required this.userSaid,
    required this.correctForm,
    required this.explanation,
    required this.timestamp,
    required this.inFlashcard,
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
    map['in_flashcard'] = Variable<bool>(inFlashcard);
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
      inFlashcard: Value(inFlashcard),
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
      inFlashcard: serializer.fromJson<bool>(json['inFlashcard']),
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
      'inFlashcard': serializer.toJson<bool>(inFlashcard),
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
    bool? inFlashcard,
  }) => ErrorLog(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    errorType: errorType ?? this.errorType,
    userSaid: userSaid ?? this.userSaid,
    correctForm: correctForm ?? this.correctForm,
    explanation: explanation ?? this.explanation,
    timestamp: timestamp ?? this.timestamp,
    inFlashcard: inFlashcard ?? this.inFlashcard,
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
      inFlashcard: data.inFlashcard.present
          ? data.inFlashcard.value
          : this.inFlashcard,
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
          ..write('timestamp: $timestamp, ')
          ..write('inFlashcard: $inFlashcard')
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
    inFlashcard,
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
          other.timestamp == this.timestamp &&
          other.inFlashcard == this.inFlashcard);
}

class ErrorLogsCompanion extends UpdateCompanion<ErrorLog> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<String> errorType;
  final Value<String> userSaid;
  final Value<String> correctForm;
  final Value<String> explanation;
  final Value<DateTime> timestamp;
  final Value<bool> inFlashcard;
  const ErrorLogsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.errorType = const Value.absent(),
    this.userSaid = const Value.absent(),
    this.correctForm = const Value.absent(),
    this.explanation = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.inFlashcard = const Value.absent(),
  });
  ErrorLogsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required String errorType,
    required String userSaid,
    required String correctForm,
    required String explanation,
    required DateTime timestamp,
    this.inFlashcard = const Value.absent(),
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
    Expression<bool>? inFlashcard,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (errorType != null) 'error_type': errorType,
      if (userSaid != null) 'user_said': userSaid,
      if (correctForm != null) 'correct_form': correctForm,
      if (explanation != null) 'explanation': explanation,
      if (timestamp != null) 'timestamp': timestamp,
      if (inFlashcard != null) 'in_flashcard': inFlashcard,
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
    Value<bool>? inFlashcard,
  }) {
    return ErrorLogsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      errorType: errorType ?? this.errorType,
      userSaid: userSaid ?? this.userSaid,
      correctForm: correctForm ?? this.correctForm,
      explanation: explanation ?? this.explanation,
      timestamp: timestamp ?? this.timestamp,
      inFlashcard: inFlashcard ?? this.inFlashcard,
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
    if (inFlashcard.present) {
      map['in_flashcard'] = Variable<bool>(inFlashcard.value);
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
          ..write('timestamp: $timestamp, ')
          ..write('inFlashcard: $inFlashcard')
          ..write(')'))
        .toString();
  }
}

class $ScenariosTable extends Scenarios
    with TableInfo<$ScenariosTable, Scenario> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScenariosTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _externalIdMeta = const VerificationMeta(
    'externalId',
  );
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
    'external_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tutorInstructionMeta = const VerificationMeta(
    'tutorInstruction',
  );
  @override
  late final GeneratedColumn<String> tutorInstruction = GeneratedColumn<String>(
    'tutor_instruction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<String> difficulty = GeneratedColumn<String>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isUsedMeta = const VerificationMeta('isUsed');
  @override
  late final GeneratedColumn<bool> isUsed = GeneratedColumn<bool>(
    'is_used',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_used" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
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
  List<GeneratedColumn> get $columns => [
    id,
    externalId,
    title,
    description,
    tutorInstruction,
    difficulty,
    isUsed,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scenarios';
  @override
  VerificationContext validateIntegrity(
    Insertable<Scenario> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('external_id')) {
      context.handle(
        _externalIdMeta,
        externalId.isAcceptableOrUnknown(data['external_id']!, _externalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_externalIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('tutor_instruction')) {
      context.handle(
        _tutorInstructionMeta,
        tutorInstruction.isAcceptableOrUnknown(
          data['tutor_instruction']!,
          _tutorInstructionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tutorInstructionMeta);
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    } else if (isInserting) {
      context.missing(_difficultyMeta);
    }
    if (data.containsKey('is_used')) {
      context.handle(
        _isUsedMeta,
        isUsed.isAcceptableOrUnknown(data['is_used']!, _isUsedMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Scenario map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Scenario(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      externalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      tutorInstruction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tutor_instruction'],
      )!,
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}difficulty'],
      )!,
      isUsed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_used'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ScenariosTable createAlias(String alias) {
    return $ScenariosTable(attachedDatabase, alias);
  }
}

class Scenario extends DataClass implements Insertable<Scenario> {
  final int id;
  final String externalId;
  final String title;
  final String description;
  final String tutorInstruction;
  final String difficulty;
  final bool isUsed;
  final DateTime createdAt;
  const Scenario({
    required this.id,
    required this.externalId,
    required this.title,
    required this.description,
    required this.tutorInstruction,
    required this.difficulty,
    required this.isUsed,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['external_id'] = Variable<String>(externalId);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['tutor_instruction'] = Variable<String>(tutorInstruction);
    map['difficulty'] = Variable<String>(difficulty);
    map['is_used'] = Variable<bool>(isUsed);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ScenariosCompanion toCompanion(bool nullToAbsent) {
    return ScenariosCompanion(
      id: Value(id),
      externalId: Value(externalId),
      title: Value(title),
      description: Value(description),
      tutorInstruction: Value(tutorInstruction),
      difficulty: Value(difficulty),
      isUsed: Value(isUsed),
      createdAt: Value(createdAt),
    );
  }

  factory Scenario.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Scenario(
      id: serializer.fromJson<int>(json['id']),
      externalId: serializer.fromJson<String>(json['externalId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      tutorInstruction: serializer.fromJson<String>(json['tutorInstruction']),
      difficulty: serializer.fromJson<String>(json['difficulty']),
      isUsed: serializer.fromJson<bool>(json['isUsed']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'externalId': serializer.toJson<String>(externalId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'tutorInstruction': serializer.toJson<String>(tutorInstruction),
      'difficulty': serializer.toJson<String>(difficulty),
      'isUsed': serializer.toJson<bool>(isUsed),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Scenario copyWith({
    int? id,
    String? externalId,
    String? title,
    String? description,
    String? tutorInstruction,
    String? difficulty,
    bool? isUsed,
    DateTime? createdAt,
  }) => Scenario(
    id: id ?? this.id,
    externalId: externalId ?? this.externalId,
    title: title ?? this.title,
    description: description ?? this.description,
    tutorInstruction: tutorInstruction ?? this.tutorInstruction,
    difficulty: difficulty ?? this.difficulty,
    isUsed: isUsed ?? this.isUsed,
    createdAt: createdAt ?? this.createdAt,
  );
  Scenario copyWithCompanion(ScenariosCompanion data) {
    return Scenario(
      id: data.id.present ? data.id.value : this.id,
      externalId: data.externalId.present
          ? data.externalId.value
          : this.externalId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      tutorInstruction: data.tutorInstruction.present
          ? data.tutorInstruction.value
          : this.tutorInstruction,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      isUsed: data.isUsed.present ? data.isUsed.value : this.isUsed,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Scenario(')
          ..write('id: $id, ')
          ..write('externalId: $externalId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('tutorInstruction: $tutorInstruction, ')
          ..write('difficulty: $difficulty, ')
          ..write('isUsed: $isUsed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    externalId,
    title,
    description,
    tutorInstruction,
    difficulty,
    isUsed,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Scenario &&
          other.id == this.id &&
          other.externalId == this.externalId &&
          other.title == this.title &&
          other.description == this.description &&
          other.tutorInstruction == this.tutorInstruction &&
          other.difficulty == this.difficulty &&
          other.isUsed == this.isUsed &&
          other.createdAt == this.createdAt);
}

class ScenariosCompanion extends UpdateCompanion<Scenario> {
  final Value<int> id;
  final Value<String> externalId;
  final Value<String> title;
  final Value<String> description;
  final Value<String> tutorInstruction;
  final Value<String> difficulty;
  final Value<bool> isUsed;
  final Value<DateTime> createdAt;
  const ScenariosCompanion({
    this.id = const Value.absent(),
    this.externalId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.tutorInstruction = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.isUsed = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ScenariosCompanion.insert({
    this.id = const Value.absent(),
    required String externalId,
    required String title,
    required String description,
    required String tutorInstruction,
    required String difficulty,
    this.isUsed = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : externalId = Value(externalId),
       title = Value(title),
       description = Value(description),
       tutorInstruction = Value(tutorInstruction),
       difficulty = Value(difficulty);
  static Insertable<Scenario> custom({
    Expression<int>? id,
    Expression<String>? externalId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? tutorInstruction,
    Expression<String>? difficulty,
    Expression<bool>? isUsed,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (externalId != null) 'external_id': externalId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (tutorInstruction != null) 'tutor_instruction': tutorInstruction,
      if (difficulty != null) 'difficulty': difficulty,
      if (isUsed != null) 'is_used': isUsed,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ScenariosCompanion copyWith({
    Value<int>? id,
    Value<String>? externalId,
    Value<String>? title,
    Value<String>? description,
    Value<String>? tutorInstruction,
    Value<String>? difficulty,
    Value<bool>? isUsed,
    Value<DateTime>? createdAt,
  }) {
    return ScenariosCompanion(
      id: id ?? this.id,
      externalId: externalId ?? this.externalId,
      title: title ?? this.title,
      description: description ?? this.description,
      tutorInstruction: tutorInstruction ?? this.tutorInstruction,
      difficulty: difficulty ?? this.difficulty,
      isUsed: isUsed ?? this.isUsed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (tutorInstruction.present) {
      map['tutor_instruction'] = Variable<String>(tutorInstruction.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<String>(difficulty.value);
    }
    if (isUsed.present) {
      map['is_used'] = Variable<bool>(isUsed.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScenariosCompanion(')
          ..write('id: $id, ')
          ..write('externalId: $externalId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('tutorInstruction: $tutorInstruction, ')
          ..write('difficulty: $difficulty, ')
          ..write('isUsed: $isUsed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $FlashcardsTable extends Flashcards
    with TableInfo<$FlashcardsTable, Flashcard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FlashcardsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _errorLogIdMeta = const VerificationMeta(
    'errorLogId',
  );
  @override
  late final GeneratedColumn<int> errorLogId = GeneratedColumn<int>(
    'error_log_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES error_logs (id)',
    ),
  );
  static const VerificationMeta _frontTextMeta = const VerificationMeta(
    'frontText',
  );
  @override
  late final GeneratedColumn<String> frontText = GeneratedColumn<String>(
    'front_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _backTextMeta = const VerificationMeta(
    'backText',
  );
  @override
  late final GeneratedColumn<String> backText = GeneratedColumn<String>(
    'back_text',
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
  static const VerificationMeta _errorTypeMeta = const VerificationMeta(
    'errorType',
  );
  @override
  late final GeneratedColumn<String> errorType = GeneratedColumn<String>(
    'error_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('grammar'),
  );
  static const VerificationMeta _sourceSentenceMeta = const VerificationMeta(
    'sourceSentence',
  );
  @override
  late final GeneratedColumn<String> sourceSentence = GeneratedColumn<String>(
    'source_sentence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _intervalDaysMeta = const VerificationMeta(
    'intervalDays',
  );
  @override
  late final GeneratedColumn<int> intervalDays = GeneratedColumn<int>(
    'interval_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _repetitionCountMeta = const VerificationMeta(
    'repetitionCount',
  );
  @override
  late final GeneratedColumn<int> repetitionCount = GeneratedColumn<int>(
    'repetition_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _masteryScoreMeta = const VerificationMeta(
    'masteryScore',
  );
  @override
  late final GeneratedColumn<double> masteryScore = GeneratedColumn<double>(
    'mastery_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _nextReviewAtMeta = const VerificationMeta(
    'nextReviewAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextReviewAt = GeneratedColumn<DateTime>(
    'next_review_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    errorLogId,
    frontText,
    backText,
    explanation,
    errorType,
    sourceSentence,
    intervalDays,
    repetitionCount,
    masteryScore,
    nextReviewAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'flashcards';
  @override
  VerificationContext validateIntegrity(
    Insertable<Flashcard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('error_log_id')) {
      context.handle(
        _errorLogIdMeta,
        errorLogId.isAcceptableOrUnknown(
          data['error_log_id']!,
          _errorLogIdMeta,
        ),
      );
    }
    if (data.containsKey('front_text')) {
      context.handle(
        _frontTextMeta,
        frontText.isAcceptableOrUnknown(data['front_text']!, _frontTextMeta),
      );
    } else if (isInserting) {
      context.missing(_frontTextMeta);
    }
    if (data.containsKey('back_text')) {
      context.handle(
        _backTextMeta,
        backText.isAcceptableOrUnknown(data['back_text']!, _backTextMeta),
      );
    } else if (isInserting) {
      context.missing(_backTextMeta);
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
    if (data.containsKey('error_type')) {
      context.handle(
        _errorTypeMeta,
        errorType.isAcceptableOrUnknown(data['error_type']!, _errorTypeMeta),
      );
    }
    if (data.containsKey('source_sentence')) {
      context.handle(
        _sourceSentenceMeta,
        sourceSentence.isAcceptableOrUnknown(
          data['source_sentence']!,
          _sourceSentenceMeta,
        ),
      );
    }
    if (data.containsKey('interval_days')) {
      context.handle(
        _intervalDaysMeta,
        intervalDays.isAcceptableOrUnknown(
          data['interval_days']!,
          _intervalDaysMeta,
        ),
      );
    }
    if (data.containsKey('repetition_count')) {
      context.handle(
        _repetitionCountMeta,
        repetitionCount.isAcceptableOrUnknown(
          data['repetition_count']!,
          _repetitionCountMeta,
        ),
      );
    }
    if (data.containsKey('mastery_score')) {
      context.handle(
        _masteryScoreMeta,
        masteryScore.isAcceptableOrUnknown(
          data['mastery_score']!,
          _masteryScoreMeta,
        ),
      );
    }
    if (data.containsKey('next_review_at')) {
      context.handle(
        _nextReviewAtMeta,
        nextReviewAt.isAcceptableOrUnknown(
          data['next_review_at']!,
          _nextReviewAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextReviewAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Flashcard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Flashcard(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      errorLogId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}error_log_id'],
      ),
      frontText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}front_text'],
      )!,
      backText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}back_text'],
      )!,
      explanation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}explanation'],
      )!,
      errorType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_type'],
      )!,
      sourceSentence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_sentence'],
      ),
      intervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_days'],
      )!,
      repetitionCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repetition_count'],
      )!,
      masteryScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mastery_score'],
      )!,
      nextReviewAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_review_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FlashcardsTable createAlias(String alias) {
    return $FlashcardsTable(attachedDatabase, alias);
  }
}

class Flashcard extends DataClass implements Insertable<Flashcard> {
  /// Unikátní identifikátor kartičky.
  final int id;

  /// Volitelná reference na konkrétní záznam chyby v chybovém logu.
  final int? errorLogId;

  /// Text na přední straně kartičky (např. česká nápověda, věta k doplnění či otázka).
  final String frontText;

  /// Správné anglické znění na zadní straně kartičky.
  final String backText;

  /// České gramatické vysvětlení nebo kontext.
  final String explanation;

  /// Typ procvičovaného jevu ('grammar' | 'vocabulary' | 'pronunciation' | 'preposition' | 'tense').
  final String errorType;

  /// Původní věta ze sezení, ve které chyba vznikla.
  final String? sourceSentence;

  /// Aktuální interval pro opakování ve dnech (algoritmus SRS).
  final int intervalDays;

  /// Počet úspěšných po sobě jdoucích zopakování.
  final int repetitionCount;

  /// Úroveň zvládnutí kartičky (0.0 = nová, 1.0 = perfektně zvládnutá).
  final double masteryScore;

  /// Čas, kdy má být kartička znovu nabídnuta k procvičení.
  final DateTime nextReviewAt;

  /// Čas vytvoření kartičky.
  final DateTime createdAt;
  const Flashcard({
    required this.id,
    this.errorLogId,
    required this.frontText,
    required this.backText,
    required this.explanation,
    required this.errorType,
    this.sourceSentence,
    required this.intervalDays,
    required this.repetitionCount,
    required this.masteryScore,
    required this.nextReviewAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || errorLogId != null) {
      map['error_log_id'] = Variable<int>(errorLogId);
    }
    map['front_text'] = Variable<String>(frontText);
    map['back_text'] = Variable<String>(backText);
    map['explanation'] = Variable<String>(explanation);
    map['error_type'] = Variable<String>(errorType);
    if (!nullToAbsent || sourceSentence != null) {
      map['source_sentence'] = Variable<String>(sourceSentence);
    }
    map['interval_days'] = Variable<int>(intervalDays);
    map['repetition_count'] = Variable<int>(repetitionCount);
    map['mastery_score'] = Variable<double>(masteryScore);
    map['next_review_at'] = Variable<DateTime>(nextReviewAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FlashcardsCompanion toCompanion(bool nullToAbsent) {
    return FlashcardsCompanion(
      id: Value(id),
      errorLogId: errorLogId == null && nullToAbsent
          ? const Value.absent()
          : Value(errorLogId),
      frontText: Value(frontText),
      backText: Value(backText),
      explanation: Value(explanation),
      errorType: Value(errorType),
      sourceSentence: sourceSentence == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceSentence),
      intervalDays: Value(intervalDays),
      repetitionCount: Value(repetitionCount),
      masteryScore: Value(masteryScore),
      nextReviewAt: Value(nextReviewAt),
      createdAt: Value(createdAt),
    );
  }

  factory Flashcard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Flashcard(
      id: serializer.fromJson<int>(json['id']),
      errorLogId: serializer.fromJson<int?>(json['errorLogId']),
      frontText: serializer.fromJson<String>(json['frontText']),
      backText: serializer.fromJson<String>(json['backText']),
      explanation: serializer.fromJson<String>(json['explanation']),
      errorType: serializer.fromJson<String>(json['errorType']),
      sourceSentence: serializer.fromJson<String?>(json['sourceSentence']),
      intervalDays: serializer.fromJson<int>(json['intervalDays']),
      repetitionCount: serializer.fromJson<int>(json['repetitionCount']),
      masteryScore: serializer.fromJson<double>(json['masteryScore']),
      nextReviewAt: serializer.fromJson<DateTime>(json['nextReviewAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'errorLogId': serializer.toJson<int?>(errorLogId),
      'frontText': serializer.toJson<String>(frontText),
      'backText': serializer.toJson<String>(backText),
      'explanation': serializer.toJson<String>(explanation),
      'errorType': serializer.toJson<String>(errorType),
      'sourceSentence': serializer.toJson<String?>(sourceSentence),
      'intervalDays': serializer.toJson<int>(intervalDays),
      'repetitionCount': serializer.toJson<int>(repetitionCount),
      'masteryScore': serializer.toJson<double>(masteryScore),
      'nextReviewAt': serializer.toJson<DateTime>(nextReviewAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Flashcard copyWith({
    int? id,
    Value<int?> errorLogId = const Value.absent(),
    String? frontText,
    String? backText,
    String? explanation,
    String? errorType,
    Value<String?> sourceSentence = const Value.absent(),
    int? intervalDays,
    int? repetitionCount,
    double? masteryScore,
    DateTime? nextReviewAt,
    DateTime? createdAt,
  }) => Flashcard(
    id: id ?? this.id,
    errorLogId: errorLogId.present ? errorLogId.value : this.errorLogId,
    frontText: frontText ?? this.frontText,
    backText: backText ?? this.backText,
    explanation: explanation ?? this.explanation,
    errorType: errorType ?? this.errorType,
    sourceSentence: sourceSentence.present
        ? sourceSentence.value
        : this.sourceSentence,
    intervalDays: intervalDays ?? this.intervalDays,
    repetitionCount: repetitionCount ?? this.repetitionCount,
    masteryScore: masteryScore ?? this.masteryScore,
    nextReviewAt: nextReviewAt ?? this.nextReviewAt,
    createdAt: createdAt ?? this.createdAt,
  );
  Flashcard copyWithCompanion(FlashcardsCompanion data) {
    return Flashcard(
      id: data.id.present ? data.id.value : this.id,
      errorLogId: data.errorLogId.present
          ? data.errorLogId.value
          : this.errorLogId,
      frontText: data.frontText.present ? data.frontText.value : this.frontText,
      backText: data.backText.present ? data.backText.value : this.backText,
      explanation: data.explanation.present
          ? data.explanation.value
          : this.explanation,
      errorType: data.errorType.present ? data.errorType.value : this.errorType,
      sourceSentence: data.sourceSentence.present
          ? data.sourceSentence.value
          : this.sourceSentence,
      intervalDays: data.intervalDays.present
          ? data.intervalDays.value
          : this.intervalDays,
      repetitionCount: data.repetitionCount.present
          ? data.repetitionCount.value
          : this.repetitionCount,
      masteryScore: data.masteryScore.present
          ? data.masteryScore.value
          : this.masteryScore,
      nextReviewAt: data.nextReviewAt.present
          ? data.nextReviewAt.value
          : this.nextReviewAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Flashcard(')
          ..write('id: $id, ')
          ..write('errorLogId: $errorLogId, ')
          ..write('frontText: $frontText, ')
          ..write('backText: $backText, ')
          ..write('explanation: $explanation, ')
          ..write('errorType: $errorType, ')
          ..write('sourceSentence: $sourceSentence, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('repetitionCount: $repetitionCount, ')
          ..write('masteryScore: $masteryScore, ')
          ..write('nextReviewAt: $nextReviewAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    errorLogId,
    frontText,
    backText,
    explanation,
    errorType,
    sourceSentence,
    intervalDays,
    repetitionCount,
    masteryScore,
    nextReviewAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Flashcard &&
          other.id == this.id &&
          other.errorLogId == this.errorLogId &&
          other.frontText == this.frontText &&
          other.backText == this.backText &&
          other.explanation == this.explanation &&
          other.errorType == this.errorType &&
          other.sourceSentence == this.sourceSentence &&
          other.intervalDays == this.intervalDays &&
          other.repetitionCount == this.repetitionCount &&
          other.masteryScore == this.masteryScore &&
          other.nextReviewAt == this.nextReviewAt &&
          other.createdAt == this.createdAt);
}

class FlashcardsCompanion extends UpdateCompanion<Flashcard> {
  final Value<int> id;
  final Value<int?> errorLogId;
  final Value<String> frontText;
  final Value<String> backText;
  final Value<String> explanation;
  final Value<String> errorType;
  final Value<String?> sourceSentence;
  final Value<int> intervalDays;
  final Value<int> repetitionCount;
  final Value<double> masteryScore;
  final Value<DateTime> nextReviewAt;
  final Value<DateTime> createdAt;
  const FlashcardsCompanion({
    this.id = const Value.absent(),
    this.errorLogId = const Value.absent(),
    this.frontText = const Value.absent(),
    this.backText = const Value.absent(),
    this.explanation = const Value.absent(),
    this.errorType = const Value.absent(),
    this.sourceSentence = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.repetitionCount = const Value.absent(),
    this.masteryScore = const Value.absent(),
    this.nextReviewAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  FlashcardsCompanion.insert({
    this.id = const Value.absent(),
    this.errorLogId = const Value.absent(),
    required String frontText,
    required String backText,
    required String explanation,
    this.errorType = const Value.absent(),
    this.sourceSentence = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.repetitionCount = const Value.absent(),
    this.masteryScore = const Value.absent(),
    required DateTime nextReviewAt,
    required DateTime createdAt,
  }) : frontText = Value(frontText),
       backText = Value(backText),
       explanation = Value(explanation),
       nextReviewAt = Value(nextReviewAt),
       createdAt = Value(createdAt);
  static Insertable<Flashcard> custom({
    Expression<int>? id,
    Expression<int>? errorLogId,
    Expression<String>? frontText,
    Expression<String>? backText,
    Expression<String>? explanation,
    Expression<String>? errorType,
    Expression<String>? sourceSentence,
    Expression<int>? intervalDays,
    Expression<int>? repetitionCount,
    Expression<double>? masteryScore,
    Expression<DateTime>? nextReviewAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (errorLogId != null) 'error_log_id': errorLogId,
      if (frontText != null) 'front_text': frontText,
      if (backText != null) 'back_text': backText,
      if (explanation != null) 'explanation': explanation,
      if (errorType != null) 'error_type': errorType,
      if (sourceSentence != null) 'source_sentence': sourceSentence,
      if (intervalDays != null) 'interval_days': intervalDays,
      if (repetitionCount != null) 'repetition_count': repetitionCount,
      if (masteryScore != null) 'mastery_score': masteryScore,
      if (nextReviewAt != null) 'next_review_at': nextReviewAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  FlashcardsCompanion copyWith({
    Value<int>? id,
    Value<int?>? errorLogId,
    Value<String>? frontText,
    Value<String>? backText,
    Value<String>? explanation,
    Value<String>? errorType,
    Value<String?>? sourceSentence,
    Value<int>? intervalDays,
    Value<int>? repetitionCount,
    Value<double>? masteryScore,
    Value<DateTime>? nextReviewAt,
    Value<DateTime>? createdAt,
  }) {
    return FlashcardsCompanion(
      id: id ?? this.id,
      errorLogId: errorLogId ?? this.errorLogId,
      frontText: frontText ?? this.frontText,
      backText: backText ?? this.backText,
      explanation: explanation ?? this.explanation,
      errorType: errorType ?? this.errorType,
      sourceSentence: sourceSentence ?? this.sourceSentence,
      intervalDays: intervalDays ?? this.intervalDays,
      repetitionCount: repetitionCount ?? this.repetitionCount,
      masteryScore: masteryScore ?? this.masteryScore,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (errorLogId.present) {
      map['error_log_id'] = Variable<int>(errorLogId.value);
    }
    if (frontText.present) {
      map['front_text'] = Variable<String>(frontText.value);
    }
    if (backText.present) {
      map['back_text'] = Variable<String>(backText.value);
    }
    if (explanation.present) {
      map['explanation'] = Variable<String>(explanation.value);
    }
    if (errorType.present) {
      map['error_type'] = Variable<String>(errorType.value);
    }
    if (sourceSentence.present) {
      map['source_sentence'] = Variable<String>(sourceSentence.value);
    }
    if (intervalDays.present) {
      map['interval_days'] = Variable<int>(intervalDays.value);
    }
    if (repetitionCount.present) {
      map['repetition_count'] = Variable<int>(repetitionCount.value);
    }
    if (masteryScore.present) {
      map['mastery_score'] = Variable<double>(masteryScore.value);
    }
    if (nextReviewAt.present) {
      map['next_review_at'] = Variable<DateTime>(nextReviewAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FlashcardsCompanion(')
          ..write('id: $id, ')
          ..write('errorLogId: $errorLogId, ')
          ..write('frontText: $frontText, ')
          ..write('backText: $backText, ')
          ..write('explanation: $explanation, ')
          ..write('errorType: $errorType, ')
          ..write('sourceSentence: $sourceSentence, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('repetitionCount: $repetitionCount, ')
          ..write('masteryScore: $masteryScore, ')
          ..write('nextReviewAt: $nextReviewAt, ')
          ..write('createdAt: $createdAt')
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
  late final $ScenariosTable scenarios = $ScenariosTable(this);
  late final $FlashcardsTable flashcards = $FlashcardsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sessions,
    transcripts,
    userProfiles,
    errorLogs,
    scenarios,
    flashcards,
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
      Value<bool> inFlashcard,
    });
typedef $$TranscriptsTableUpdateCompanionBuilder =
    TranscriptsCompanion Function({
      Value<int> id,
      Value<int> sessionId,
      Value<String> speaker,
      Value<String> content,
      Value<DateTime> timestamp,
      Value<String?> correctedForm,
      Value<bool> inFlashcard,
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

  ColumnFilters<bool> get inFlashcard => $composableBuilder(
    column: $table.inFlashcard,
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

  ColumnOrderings<bool> get inFlashcard => $composableBuilder(
    column: $table.inFlashcard,
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

  GeneratedColumn<bool> get inFlashcard => $composableBuilder(
    column: $table.inFlashcard,
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
                Value<bool> inFlashcard = const Value.absent(),
              }) => TranscriptsCompanion(
                id: id,
                sessionId: sessionId,
                speaker: speaker,
                content: content,
                timestamp: timestamp,
                correctedForm: correctedForm,
                inFlashcard: inFlashcard,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionId,
                required String speaker,
                required String content,
                required DateTime timestamp,
                Value<String?> correctedForm = const Value.absent(),
                Value<bool> inFlashcard = const Value.absent(),
              }) => TranscriptsCompanion.insert(
                id: id,
                sessionId: sessionId,
                speaker: speaker,
                content: content,
                timestamp: timestamp,
                correctedForm: correctedForm,
                inFlashcard: inFlashcard,
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
      Value<String?> memoryBriefing,
      Value<String> userFacts,
      Value<String?> preparedTopic,
      Value<DateTime?> preparedTopicAt,
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
      Value<String?> memoryBriefing,
      Value<String> userFacts,
      Value<String?> preparedTopic,
      Value<DateTime?> preparedTopicAt,
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

  ColumnFilters<String> get memoryBriefing => $composableBuilder(
    column: $table.memoryBriefing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userFacts => $composableBuilder(
    column: $table.userFacts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preparedTopic => $composableBuilder(
    column: $table.preparedTopic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get preparedTopicAt => $composableBuilder(
    column: $table.preparedTopicAt,
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

  ColumnOrderings<String> get memoryBriefing => $composableBuilder(
    column: $table.memoryBriefing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userFacts => $composableBuilder(
    column: $table.userFacts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preparedTopic => $composableBuilder(
    column: $table.preparedTopic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get preparedTopicAt => $composableBuilder(
    column: $table.preparedTopicAt,
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

  GeneratedColumn<String> get memoryBriefing => $composableBuilder(
    column: $table.memoryBriefing,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userFacts =>
      $composableBuilder(column: $table.userFacts, builder: (column) => column);

  GeneratedColumn<String> get preparedTopic => $composableBuilder(
    column: $table.preparedTopic,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get preparedTopicAt => $composableBuilder(
    column: $table.preparedTopicAt,
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
                Value<String?> memoryBriefing = const Value.absent(),
                Value<String> userFacts = const Value.absent(),
                Value<String?> preparedTopic = const Value.absent(),
                Value<DateTime?> preparedTopicAt = const Value.absent(),
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
                memoryBriefing: memoryBriefing,
                userFacts: userFacts,
                preparedTopic: preparedTopic,
                preparedTopicAt: preparedTopicAt,
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
                Value<String?> memoryBriefing = const Value.absent(),
                Value<String> userFacts = const Value.absent(),
                Value<String?> preparedTopic = const Value.absent(),
                Value<DateTime?> preparedTopicAt = const Value.absent(),
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
                memoryBriefing: memoryBriefing,
                userFacts: userFacts,
                preparedTopic: preparedTopic,
                preparedTopicAt: preparedTopicAt,
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
      Value<bool> inFlashcard,
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
      Value<bool> inFlashcard,
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

  static MultiTypedResultKey<$FlashcardsTable, List<Flashcard>>
  _flashcardsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.flashcards,
    aliasName: 'error_logs__id__flashcards__error_log_id',
  );

  $$FlashcardsTableProcessedTableManager get flashcardsRefs {
    final manager = $$FlashcardsTableTableManager(
      $_db,
      $_db.flashcards,
    ).filter((f) => f.errorLogId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_flashcardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
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

  ColumnFilters<bool> get inFlashcard => $composableBuilder(
    column: $table.inFlashcard,
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

  Expression<bool> flashcardsRefs(
    Expression<bool> Function($$FlashcardsTableFilterComposer f) f,
  ) {
    final $$FlashcardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flashcards,
      getReferencedColumn: (t) => t.errorLogId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlashcardsTableFilterComposer(
            $db: $db,
            $table: $db.flashcards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
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

  ColumnOrderings<bool> get inFlashcard => $composableBuilder(
    column: $table.inFlashcard,
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

  GeneratedColumn<bool> get inFlashcard => $composableBuilder(
    column: $table.inFlashcard,
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

  Expression<T> flashcardsRefs<T extends Object>(
    Expression<T> Function($$FlashcardsTableAnnotationComposer a) f,
  ) {
    final $$FlashcardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.flashcards,
      getReferencedColumn: (t) => t.errorLogId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FlashcardsTableAnnotationComposer(
            $db: $db,
            $table: $db.flashcards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
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
          PrefetchHooks Function({bool sessionId, bool flashcardsRefs})
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
                Value<bool> inFlashcard = const Value.absent(),
              }) => ErrorLogsCompanion(
                id: id,
                sessionId: sessionId,
                errorType: errorType,
                userSaid: userSaid,
                correctForm: correctForm,
                explanation: explanation,
                timestamp: timestamp,
                inFlashcard: inFlashcard,
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
                Value<bool> inFlashcard = const Value.absent(),
              }) => ErrorLogsCompanion.insert(
                id: id,
                sessionId: sessionId,
                errorType: errorType,
                userSaid: userSaid,
                correctForm: correctForm,
                explanation: explanation,
                timestamp: timestamp,
                inFlashcard: inFlashcard,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ErrorLogsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false, flashcardsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (flashcardsRefs) db.flashcards],
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
                return [
                  if (flashcardsRefs)
                    await $_getPrefetchedData<
                      ErrorLog,
                      $ErrorLogsTable,
                      Flashcard
                    >(
                      currentTable: table,
                      referencedTable: $$ErrorLogsTableReferences
                          ._flashcardsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ErrorLogsTableReferences(
                            db,
                            table,
                            p0,
                          ).flashcardsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.errorLogId == item.id),
                      typedResults: items,
                    ),
                ];
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
      PrefetchHooks Function({bool sessionId, bool flashcardsRefs})
    >;
typedef $$ScenariosTableCreateCompanionBuilder =
    ScenariosCompanion Function({
      Value<int> id,
      required String externalId,
      required String title,
      required String description,
      required String tutorInstruction,
      required String difficulty,
      Value<bool> isUsed,
      Value<DateTime> createdAt,
    });
typedef $$ScenariosTableUpdateCompanionBuilder =
    ScenariosCompanion Function({
      Value<int> id,
      Value<String> externalId,
      Value<String> title,
      Value<String> description,
      Value<String> tutorInstruction,
      Value<String> difficulty,
      Value<bool> isUsed,
      Value<DateTime> createdAt,
    });

class $$ScenariosTableFilterComposer
    extends Composer<_$AppDatabase, $ScenariosTable> {
  $$ScenariosTableFilterComposer({
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

  ColumnFilters<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tutorInstruction => $composableBuilder(
    column: $table.tutorInstruction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isUsed => $composableBuilder(
    column: $table.isUsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScenariosTableOrderingComposer
    extends Composer<_$AppDatabase, $ScenariosTable> {
  $$ScenariosTableOrderingComposer({
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

  ColumnOrderings<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tutorInstruction => $composableBuilder(
    column: $table.tutorInstruction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isUsed => $composableBuilder(
    column: $table.isUsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScenariosTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScenariosTable> {
  $$ScenariosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tutorInstruction => $composableBuilder(
    column: $table.tutorInstruction,
    builder: (column) => column,
  );

  GeneratedColumn<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isUsed =>
      $composableBuilder(column: $table.isUsed, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ScenariosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScenariosTable,
          Scenario,
          $$ScenariosTableFilterComposer,
          $$ScenariosTableOrderingComposer,
          $$ScenariosTableAnnotationComposer,
          $$ScenariosTableCreateCompanionBuilder,
          $$ScenariosTableUpdateCompanionBuilder,
          (Scenario, BaseReferences<_$AppDatabase, $ScenariosTable, Scenario>),
          Scenario,
          PrefetchHooks Function()
        > {
  $$ScenariosTableTableManager(_$AppDatabase db, $ScenariosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScenariosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScenariosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScenariosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> externalId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> tutorInstruction = const Value.absent(),
                Value<String> difficulty = const Value.absent(),
                Value<bool> isUsed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ScenariosCompanion(
                id: id,
                externalId: externalId,
                title: title,
                description: description,
                tutorInstruction: tutorInstruction,
                difficulty: difficulty,
                isUsed: isUsed,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String externalId,
                required String title,
                required String description,
                required String tutorInstruction,
                required String difficulty,
                Value<bool> isUsed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ScenariosCompanion.insert(
                id: id,
                externalId: externalId,
                title: title,
                description: description,
                tutorInstruction: tutorInstruction,
                difficulty: difficulty,
                isUsed: isUsed,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScenariosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScenariosTable,
      Scenario,
      $$ScenariosTableFilterComposer,
      $$ScenariosTableOrderingComposer,
      $$ScenariosTableAnnotationComposer,
      $$ScenariosTableCreateCompanionBuilder,
      $$ScenariosTableUpdateCompanionBuilder,
      (Scenario, BaseReferences<_$AppDatabase, $ScenariosTable, Scenario>),
      Scenario,
      PrefetchHooks Function()
    >;
typedef $$FlashcardsTableCreateCompanionBuilder =
    FlashcardsCompanion Function({
      Value<int> id,
      Value<int?> errorLogId,
      required String frontText,
      required String backText,
      required String explanation,
      Value<String> errorType,
      Value<String?> sourceSentence,
      Value<int> intervalDays,
      Value<int> repetitionCount,
      Value<double> masteryScore,
      required DateTime nextReviewAt,
      required DateTime createdAt,
    });
typedef $$FlashcardsTableUpdateCompanionBuilder =
    FlashcardsCompanion Function({
      Value<int> id,
      Value<int?> errorLogId,
      Value<String> frontText,
      Value<String> backText,
      Value<String> explanation,
      Value<String> errorType,
      Value<String?> sourceSentence,
      Value<int> intervalDays,
      Value<int> repetitionCount,
      Value<double> masteryScore,
      Value<DateTime> nextReviewAt,
      Value<DateTime> createdAt,
    });

final class $$FlashcardsTableReferences
    extends BaseReferences<_$AppDatabase, $FlashcardsTable, Flashcard> {
  $$FlashcardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ErrorLogsTable _errorLogIdTable(_$AppDatabase db) =>
      db.errorLogs.createAlias('flashcards__error_log_id__error_logs__id');

  $$ErrorLogsTableProcessedTableManager? get errorLogId {
    final $_column = $_itemColumn<int>('error_log_id');
    if ($_column == null) return null;
    final manager = $$ErrorLogsTableTableManager(
      $_db,
      $_db.errorLogs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_errorLogIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FlashcardsTableFilterComposer
    extends Composer<_$AppDatabase, $FlashcardsTable> {
  $$FlashcardsTableFilterComposer({
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

  ColumnFilters<String> get frontText => $composableBuilder(
    column: $table.frontText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backText => $composableBuilder(
    column: $table.backText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorType => $composableBuilder(
    column: $table.errorType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceSentence => $composableBuilder(
    column: $table.sourceSentence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repetitionCount => $composableBuilder(
    column: $table.repetitionCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get masteryScore => $composableBuilder(
    column: $table.masteryScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ErrorLogsTableFilterComposer get errorLogId {
    final $$ErrorLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.errorLogId,
      referencedTable: $db.errorLogs,
      getReferencedColumn: (t) => t.id,
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
    return composer;
  }
}

class $$FlashcardsTableOrderingComposer
    extends Composer<_$AppDatabase, $FlashcardsTable> {
  $$FlashcardsTableOrderingComposer({
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

  ColumnOrderings<String> get frontText => $composableBuilder(
    column: $table.frontText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backText => $composableBuilder(
    column: $table.backText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorType => $composableBuilder(
    column: $table.errorType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceSentence => $composableBuilder(
    column: $table.sourceSentence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repetitionCount => $composableBuilder(
    column: $table.repetitionCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get masteryScore => $composableBuilder(
    column: $table.masteryScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ErrorLogsTableOrderingComposer get errorLogId {
    final $$ErrorLogsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.errorLogId,
      referencedTable: $db.errorLogs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ErrorLogsTableOrderingComposer(
            $db: $db,
            $table: $db.errorLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FlashcardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FlashcardsTable> {
  $$FlashcardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get frontText =>
      $composableBuilder(column: $table.frontText, builder: (column) => column);

  GeneratedColumn<String> get backText =>
      $composableBuilder(column: $table.backText, builder: (column) => column);

  GeneratedColumn<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorType =>
      $composableBuilder(column: $table.errorType, builder: (column) => column);

  GeneratedColumn<String> get sourceSentence => $composableBuilder(
    column: $table.sourceSentence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repetitionCount => $composableBuilder(
    column: $table.repetitionCount,
    builder: (column) => column,
  );

  GeneratedColumn<double> get masteryScore => $composableBuilder(
    column: $table.masteryScore,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ErrorLogsTableAnnotationComposer get errorLogId {
    final $$ErrorLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.errorLogId,
      referencedTable: $db.errorLogs,
      getReferencedColumn: (t) => t.id,
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
    return composer;
  }
}

class $$FlashcardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FlashcardsTable,
          Flashcard,
          $$FlashcardsTableFilterComposer,
          $$FlashcardsTableOrderingComposer,
          $$FlashcardsTableAnnotationComposer,
          $$FlashcardsTableCreateCompanionBuilder,
          $$FlashcardsTableUpdateCompanionBuilder,
          (Flashcard, $$FlashcardsTableReferences),
          Flashcard,
          PrefetchHooks Function({bool errorLogId})
        > {
  $$FlashcardsTableTableManager(_$AppDatabase db, $FlashcardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FlashcardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FlashcardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FlashcardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> errorLogId = const Value.absent(),
                Value<String> frontText = const Value.absent(),
                Value<String> backText = const Value.absent(),
                Value<String> explanation = const Value.absent(),
                Value<String> errorType = const Value.absent(),
                Value<String?> sourceSentence = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<int> repetitionCount = const Value.absent(),
                Value<double> masteryScore = const Value.absent(),
                Value<DateTime> nextReviewAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => FlashcardsCompanion(
                id: id,
                errorLogId: errorLogId,
                frontText: frontText,
                backText: backText,
                explanation: explanation,
                errorType: errorType,
                sourceSentence: sourceSentence,
                intervalDays: intervalDays,
                repetitionCount: repetitionCount,
                masteryScore: masteryScore,
                nextReviewAt: nextReviewAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> errorLogId = const Value.absent(),
                required String frontText,
                required String backText,
                required String explanation,
                Value<String> errorType = const Value.absent(),
                Value<String?> sourceSentence = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<int> repetitionCount = const Value.absent(),
                Value<double> masteryScore = const Value.absent(),
                required DateTime nextReviewAt,
                required DateTime createdAt,
              }) => FlashcardsCompanion.insert(
                id: id,
                errorLogId: errorLogId,
                frontText: frontText,
                backText: backText,
                explanation: explanation,
                errorType: errorType,
                sourceSentence: sourceSentence,
                intervalDays: intervalDays,
                repetitionCount: repetitionCount,
                masteryScore: masteryScore,
                nextReviewAt: nextReviewAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FlashcardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({errorLogId = false}) {
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
                    if (errorLogId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.errorLogId,
                                referencedTable: $$FlashcardsTableReferences
                                    ._errorLogIdTable(db),
                                referencedColumn: $$FlashcardsTableReferences
                                    ._errorLogIdTable(db)
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

typedef $$FlashcardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FlashcardsTable,
      Flashcard,
      $$FlashcardsTableFilterComposer,
      $$FlashcardsTableOrderingComposer,
      $$FlashcardsTableAnnotationComposer,
      $$FlashcardsTableCreateCompanionBuilder,
      $$FlashcardsTableUpdateCompanionBuilder,
      (Flashcard, $$FlashcardsTableReferences),
      Flashcard,
      PrefetchHooks Function({bool errorLogId})
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
  $$ScenariosTableTableManager get scenarios =>
      $$ScenariosTableTableManager(_db, _db.scenarios);
  $$FlashcardsTableTableManager get flashcards =>
      $$FlashcardsTableTableManager(_db, _db.flashcards);
}
