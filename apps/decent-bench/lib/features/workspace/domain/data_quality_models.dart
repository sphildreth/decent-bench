import 'dart:convert';
import 'dart:math' as math;

enum QualityTargetKind { database, table, queryResult }

enum QualityRunStatus { running, completed, failed, cancelled }

enum QualityRunMode { full, sampled }

enum QualitySeverity { info, warning, error }

enum ValidationRuleType {
  required,
  unique,
  allowedValues,
  regex,
  numericRange,
  dateRange,
  stringLength,
  crossColumn,
  referential,
  customSqlPredicate,
  exactDuplicateRows,
  nearDuplicateRows,
}

enum OutlierMethod { iqr }

enum NearDuplicateSimilarity { normalizedLevenshtein, tokenSortRatio }

enum QualityFreshnessStatus { fresh, stale, running, failed, noRun }

enum QualityReportFormat { markdown, html, json }

enum QualityMetricStatus { computed, notComputed }

class DataQualityValidationError {
  const DataQualityValidationError({
    required this.field,
    required this.message,
  });

  final String field;
  final String message;

  @override
  String toString() => '$field: $message';

  @override
  bool operator ==(Object other) =>
      other is DataQualityValidationError &&
      other.field == field &&
      other.message == message;

  @override
  int get hashCode => Object.hash(field, message);
}

class QualityProfileDocument {
  const QualityProfileDocument({
    required this.configVersion,
    required this.profileId,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.defaultMode,
    required this.sampleRowLimit,
    required this.includeImportReconciliation,
    required this.includeDuplicateChecks,
    required this.duplicateCandidateLimit,
    required this.rules,
  });

  static const int currentConfigVersion = 1;

  final int configVersion;
  final String profileId;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final QualityRunMode defaultMode;
  final int sampleRowLimit;
  final bool includeImportReconciliation;
  final bool includeDuplicateChecks;
  final int duplicateCandidateLimit;
  final List<ValidationRule> rules;

  factory QualityProfileDocument.empty({required String name, DateTime? now}) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return QualityProfileDocument(
      configVersion: currentConfigVersion,
      profileId: generateQualityUuid(),
      name: name,
      description: '',
      createdAt: timestamp,
      updatedAt: timestamp,
      defaultMode: QualityRunMode.full,
      sampleRowLimit: 10000,
      includeImportReconciliation: true,
      includeDuplicateChecks: true,
      duplicateCandidateLimit: 50000,
      rules: const <ValidationRule>[],
    );
  }

  QualityProfileDocument copyWith({
    int? configVersion,
    String? profileId,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    QualityRunMode? defaultMode,
    int? sampleRowLimit,
    bool? includeImportReconciliation,
    bool? includeDuplicateChecks,
    int? duplicateCandidateLimit,
    List<ValidationRule>? rules,
  }) {
    return QualityProfileDocument(
      configVersion: configVersion ?? this.configVersion,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      defaultMode: defaultMode ?? this.defaultMode,
      sampleRowLimit: sampleRowLimit ?? this.sampleRowLimit,
      includeImportReconciliation:
          includeImportReconciliation ?? this.includeImportReconciliation,
      includeDuplicateChecks:
          includeDuplicateChecks ?? this.includeDuplicateChecks,
      duplicateCandidateLimit:
          duplicateCandidateLimit ?? this.duplicateCandidateLimit,
      rules: rules ?? this.rules,
    );
  }

  List<DataQualityValidationError> validate() {
    final errors = <DataQualityValidationError>[];
    if (configVersion != currentConfigVersion) {
      errors.add(
        DataQualityValidationError(
          field: 'config_version',
          message: 'Unsupported config version $configVersion.',
        ),
      );
    }
    if (profileId.trim().isEmpty) {
      errors.add(
        const DataQualityValidationError(
          field: 'profile_id',
          message: 'Profile id is required.',
        ),
      );
    }
    if (name.trim().isEmpty) {
      errors.add(
        const DataQualityValidationError(
          field: 'name',
          message: 'Profile name is required.',
        ),
      );
    }
    if (sampleRowLimit < 1) {
      errors.add(
        const DataQualityValidationError(
          field: 'sample_row_limit',
          message: 'Sample row limit must be positive.',
        ),
      );
    }
    if (duplicateCandidateLimit < 1) {
      errors.add(
        const DataQualityValidationError(
          field: 'duplicate_candidate_limit',
          message: 'Duplicate candidate limit must be positive.',
        ),
      );
    }
    final ruleIds = <String>{};
    for (var index = 0; index < rules.length; index++) {
      final rule = rules[index];
      if (!ruleIds.add(rule.id)) {
        errors.add(
          DataQualityValidationError(
            field: 'rules[$index].id',
            message: 'Duplicate rule id ${rule.id}.',
          ),
        );
      }
      for (final error in rule.validate()) {
        errors.add(
          DataQualityValidationError(
            field: 'rules[$index].${error.field}',
            message: error.message,
          ),
        );
      }
    }
    return errors;
  }

  String toToml() {
    final buffer = StringBuffer()
      ..writeln('config_version = $configVersion')
      ..writeln('profile_id = ${jsonEncode(profileId)}')
      ..writeln('name = ${jsonEncode(name)}')
      ..writeln('description = ${jsonEncode(description)}')
      ..writeln(
        'created_at = ${jsonEncode(createdAt.toUtc().toIso8601String())}',
      )
      ..writeln(
        'updated_at = ${jsonEncode(updatedAt.toUtc().toIso8601String())}',
      )
      ..writeln('default_mode = ${jsonEncode(defaultMode.wireName)}')
      ..writeln('sample_row_limit = $sampleRowLimit')
      ..writeln('include_import_reconciliation = $includeImportReconciliation')
      ..writeln('include_duplicate_checks = $includeDuplicateChecks')
      ..writeln('duplicate_candidate_limit = $duplicateCandidateLimit')
      ..writeln();
    for (final rule in rules) {
      buffer
        ..writeln('[[rules]]')
        ..writeln('id = ${jsonEncode(rule.id)}')
        ..writeln('name = ${jsonEncode(rule.name)}')
        ..writeln('description = ${jsonEncode(rule.description)}')
        ..writeln('enabled = ${rule.enabled}')
        ..writeln('severity = ${jsonEncode(rule.severity.wireName)}')
        ..writeln('target_table = ${jsonEncode(rule.targetTable)}')
        ..writeln(
          'target_column = ${rule.targetColumn == null ? 'null' : jsonEncode(rule.targetColumn)}',
        )
        ..writeln('rule_type = ${jsonEncode(rule.ruleType.wireName)}');
      if (rule.params.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('[rules.params]');
        for (final entry in rule.params.entries) {
          buffer.writeln('${entry.key} = ${_tomlValue(entry.value)}');
        }
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  factory QualityProfileDocument.fromToml(String source) {
    final root = <String, Object?>{};
    final rules = <ValidationRule>[];
    Map<String, Object?>? currentRule;
    var section = 'root';

    for (final rawLine in const LineSplitter().convert(source)) {
      final line = _stripTomlComment(rawLine).trim();
      if (line.isEmpty) {
        continue;
      }
      if (line == '[[rules]]') {
        currentRule = <String, Object?>{'params': <String, Object?>{}};
        rules.add(ValidationRule.fromTomlMap(currentRule));
        section = 'rule';
        continue;
      }
      if (line == '[rules.params]') {
        if (currentRule == null) {
          throw const FormatException(
            '[rules.params] requires a current rule.',
          );
        }
        section = 'params';
        continue;
      }
      final separator = line.indexOf('=');
      if (separator < 0) {
        throw FormatException('Invalid quality profile TOML line: $line');
      }
      final key = line.substring(0, separator).trim();
      final value = _parseTomlValue(line.substring(separator + 1).trim());
      if (section == 'root') {
        root[key] = value;
      } else if (section == 'rule') {
        currentRule![key] = value;
        rules[rules.length - 1] = ValidationRule.fromTomlMap(currentRule);
      } else {
        final params = currentRule!['params']! as Map<String, Object?>;
        params[key] = value;
        rules[rules.length - 1] = ValidationRule.fromTomlMap(currentRule);
      }
    }

    return QualityProfileDocument(
      configVersion: _asInt(root['config_version']) ?? currentConfigVersion,
      profileId: root['profile_id'] as String? ?? '',
      name: root['name'] as String? ?? '',
      description: root['description'] as String? ?? '',
      createdAt: _asDateTime(root['created_at']),
      updatedAt: _asDateTime(root['updated_at']),
      defaultMode: _parseQualityRunMode(root['default_mode']),
      sampleRowLimit: _asInt(root['sample_row_limit']) ?? 10000,
      includeImportReconciliation:
          root['include_import_reconciliation'] as bool? ?? true,
      includeDuplicateChecks: root['include_duplicate_checks'] as bool? ?? true,
      duplicateCandidateLimit:
          _asInt(root['duplicate_candidate_limit']) ?? 50000,
      rules: rules,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'config_version': configVersion,
      'profile_id': profileId,
      'name': name,
      'description': description,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'default_mode': defaultMode.wireName,
      'sample_row_limit': sampleRowLimit,
      'include_import_reconciliation': includeImportReconciliation,
      'include_duplicate_checks': includeDuplicateChecks,
      'duplicate_candidate_limit': duplicateCandidateLimit,
      'rules': <Map<String, Object?>>[for (final rule in rules) rule.toJson()],
    };
  }

  @override
  bool operator ==(Object other) =>
      other is QualityProfileDocument &&
      other.configVersion == configVersion &&
      other.profileId == profileId &&
      other.name == name &&
      other.description == description &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.defaultMode == defaultMode &&
      other.sampleRowLimit == sampleRowLimit &&
      other.includeImportReconciliation == includeImportReconciliation &&
      other.includeDuplicateChecks == includeDuplicateChecks &&
      other.duplicateCandidateLimit == duplicateCandidateLimit &&
      _listEquals(other.rules, rules);

  @override
  int get hashCode => Object.hash(
    configVersion,
    profileId,
    name,
    description,
    createdAt,
    updatedAt,
    defaultMode,
    sampleRowLimit,
    includeImportReconciliation,
    includeDuplicateChecks,
    duplicateCandidateLimit,
    Object.hashAll(rules),
  );
}

class ValidationRule {
  const ValidationRule({
    required this.id,
    required this.name,
    required this.description,
    required this.enabled,
    required this.severity,
    required this.targetTable,
    required this.targetColumn,
    required this.ruleType,
    required this.params,
  });

  final String id;
  final String name;
  final String description;
  final bool enabled;
  final QualitySeverity severity;
  final String targetTable;
  final String? targetColumn;
  final ValidationRuleType ruleType;
  final Map<String, Object?> params;

  ValidationRule copyWith({
    String? id,
    String? name,
    String? description,
    bool? enabled,
    QualitySeverity? severity,
    String? targetTable,
    Object? targetColumn = _unset,
    ValidationRuleType? ruleType,
    Map<String, Object?>? params,
  }) {
    return ValidationRule(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      severity: severity ?? this.severity,
      targetTable: targetTable ?? this.targetTable,
      targetColumn: targetColumn == _unset
          ? this.targetColumn
          : targetColumn as String?,
      ruleType: ruleType ?? this.ruleType,
      params: params ?? this.params,
    );
  }

  factory ValidationRule.fromTomlMap(Map<String, Object?> map) {
    return ValidationRule(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      enabled: map['enabled'] as bool? ?? true,
      severity: _parseQualitySeverity(map['severity']),
      targetTable: map['target_table'] as String? ?? '',
      targetColumn: map['target_column'] as String?,
      ruleType: _parseValidationRuleType(map['rule_type']),
      params: Map<String, Object?>.from(
        map['params'] as Map<String, Object?>? ?? const <String, Object?>{},
      ),
    );
  }

  factory ValidationRule.fromJson(Map<String, Object?> map) {
    return ValidationRule(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      enabled: map['enabled'] as bool? ?? true,
      severity: _parseQualitySeverity(map['severity']),
      targetTable: map['target_table'] as String? ?? '',
      targetColumn: map['target_column'] as String?,
      ruleType: _parseValidationRuleType(map['rule_type']),
      params: Map<String, Object?>.from(
        map['params'] as Map? ?? const <String, Object?>{},
      ),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'description': description,
      'enabled': enabled,
      'severity': severity.wireName,
      'target_table': targetTable,
      'target_column': targetColumn,
      'rule_type': ruleType.wireName,
      'params': params,
    };
  }

  List<DataQualityValidationError> validate() {
    final errors = <DataQualityValidationError>[];
    if (id.trim().isEmpty) {
      errors.add(
        const DataQualityValidationError(
          field: 'id',
          message: 'Rule id is required.',
        ),
      );
    }
    if (name.trim().isEmpty) {
      errors.add(
        const DataQualityValidationError(
          field: 'name',
          message: 'Rule name is required.',
        ),
      );
    }
    if (targetTable.trim().isEmpty) {
      errors.add(
        const DataQualityValidationError(
          field: 'target_table',
          message: 'Target table is required.',
        ),
      );
    }
    errors.addAll(validateValidationRuleParams(this));
    return errors;
  }

  @override
  bool operator ==(Object other) =>
      other is ValidationRule &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.enabled == enabled &&
      other.severity == severity &&
      other.targetTable == targetTable &&
      other.targetColumn == targetColumn &&
      other.ruleType == ruleType &&
      _mapEquals(other.params, params);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    enabled,
    severity,
    targetTable,
    targetColumn,
    ruleType,
    Object.hashAll(
      params.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );
}

class QualityRunRequest {
  const QualityRunRequest({
    required this.targetKind,
    required this.targetDatabasePath,
    required this.targetTable,
    required this.targetQueryId,
    required this.targetQuerySql,
    required this.profileId,
    required this.profilePath,
    required this.mode,
    required this.sampleRowLimit,
    required this.includeProfiling,
    required this.includeValidation,
    required this.includeImportReconciliation,
    required this.includeDuplicateChecks,
    required this.requestedAt,
  });

  final QualityTargetKind targetKind;
  final String targetDatabasePath;
  final String? targetTable;
  final String? targetQueryId;
  final String? targetQuerySql;
  final String? profileId;
  final String? profilePath;
  final QualityRunMode mode;
  final int sampleRowLimit;
  final bool includeProfiling;
  final bool includeValidation;
  final bool includeImportReconciliation;
  final bool includeDuplicateChecks;
  final DateTime requestedAt;

  QualityRunRequest copyWith({
    QualityTargetKind? targetKind,
    String? targetDatabasePath,
    Object? targetTable = _unset,
    Object? targetQueryId = _unset,
    Object? targetQuerySql = _unset,
    Object? profileId = _unset,
    Object? profilePath = _unset,
    QualityRunMode? mode,
    int? sampleRowLimit,
    bool? includeProfiling,
    bool? includeValidation,
    bool? includeImportReconciliation,
    bool? includeDuplicateChecks,
    DateTime? requestedAt,
  }) {
    return QualityRunRequest(
      targetKind: targetKind ?? this.targetKind,
      targetDatabasePath: targetDatabasePath ?? this.targetDatabasePath,
      targetTable: targetTable == _unset
          ? this.targetTable
          : targetTable as String?,
      targetQueryId: targetQueryId == _unset
          ? this.targetQueryId
          : targetQueryId as String?,
      targetQuerySql: targetQuerySql == _unset
          ? this.targetQuerySql
          : targetQuerySql as String?,
      profileId: profileId == _unset ? this.profileId : profileId as String?,
      profilePath: profilePath == _unset
          ? this.profilePath
          : profilePath as String?,
      mode: mode ?? this.mode,
      sampleRowLimit: sampleRowLimit ?? this.sampleRowLimit,
      includeProfiling: includeProfiling ?? this.includeProfiling,
      includeValidation: includeValidation ?? this.includeValidation,
      includeImportReconciliation:
          includeImportReconciliation ?? this.includeImportReconciliation,
      includeDuplicateChecks:
          includeDuplicateChecks ?? this.includeDuplicateChecks,
      requestedAt: requestedAt ?? this.requestedAt,
    );
  }

  List<DataQualityValidationError> validate() {
    final errors = <DataQualityValidationError>[];
    if (targetDatabasePath.trim().isEmpty) {
      errors.add(
        const DataQualityValidationError(
          field: 'target_database_path',
          message: 'Database path is required.',
        ),
      );
    }
    if (sampleRowLimit < 1) {
      errors.add(
        const DataQualityValidationError(
          field: 'sample_row_limit',
          message: 'Sample row limit must be positive.',
        ),
      );
    }
    if (targetKind == QualityTargetKind.database &&
        (targetTable != null ||
            targetQueryId != null ||
            targetQuerySql != null)) {
      errors.add(
        const DataQualityValidationError(
          field: 'target_kind',
          message: 'Database target must not set table or query fields.',
        ),
      );
    }
    if (targetKind == QualityTargetKind.table &&
        (targetTable == null || targetTable!.trim().isEmpty)) {
      errors.add(
        const DataQualityValidationError(
          field: 'target_table',
          message: 'Table target requires a target table.',
        ),
      );
    }
    if (targetKind == QualityTargetKind.queryResult &&
        ((targetQueryId == null || targetQueryId!.trim().isEmpty) &&
            (targetQuerySql == null || targetQuerySql!.trim().isEmpty))) {
      errors.add(
        const DataQualityValidationError(
          field: 'target_query',
          message: 'Query result target requires a query id or SQL.',
        ),
      );
    }
    if (!includeProfiling &&
        !includeValidation &&
        !includeImportReconciliation &&
        !includeDuplicateChecks) {
      errors.add(
        const DataQualityValidationError(
          field: 'includes',
          message: 'At least one quality run section must be enabled.',
        ),
      );
    }
    return errors;
  }
}

class QualityRunResult {
  const QualityRunResult({
    required this.runId,
    required this.profileId,
    required this.targetKind,
    required this.targetLabel,
    required this.databasePath,
    required this.startedAt,
    required this.completedAt,
    required this.status,
    required this.mode,
    required this.sampleRowLimit,
    required this.schemaFingerprint,
    required this.schemaFingerprintAlgorithm,
    required this.dataFingerprints,
    required this.profileSummaries,
    required this.validationIssues,
    required this.importReconciliation,
    required this.duplicateSummaries,
    required this.errorMessage,
    required this.warningMessages,
    required this.detailStorePath,
  });

  final String runId;
  final String? profileId;
  final QualityTargetKind targetKind;
  final String targetLabel;
  final String databasePath;
  final DateTime startedAt;
  final DateTime? completedAt;
  final QualityRunStatus status;
  final QualityRunMode mode;
  final int? sampleRowLimit;
  final String schemaFingerprint;
  final String schemaFingerprintAlgorithm;
  final List<QualityDataFingerprint> dataFingerprints;
  final List<TableQualitySummary> profileSummaries;
  final List<ValidationIssueSummary> validationIssues;
  final ImportReconciliationSummary? importReconciliation;
  final List<DuplicateSummary> duplicateSummaries;
  final String? errorMessage;
  final List<String> warningMessages;
  final String? detailStorePath;

  int get errorIssueCount => validationIssues
      .where((issue) => issue.severity == QualitySeverity.error)
      .length;
  int get warningIssueCount => validationIssues
      .where((issue) => issue.severity == QualitySeverity.warning)
      .length;
  int get infoIssueCount => validationIssues
      .where((issue) => issue.severity == QualitySeverity.info)
      .length;
  int get totalFailureCount =>
      validationIssues.fold<int>(0, (sum, issue) => sum + issue.failureCount);

  QualityRunResult redactedForReport({bool includeSampleValues = false}) {
    if (includeSampleValues) {
      return this;
    }
    return QualityRunResult(
      runId: runId,
      profileId: profileId,
      targetKind: targetKind,
      targetLabel: targetLabel,
      databasePath: databasePath,
      startedAt: startedAt,
      completedAt: completedAt,
      status: status,
      mode: mode,
      sampleRowLimit: sampleRowLimit,
      schemaFingerprint: schemaFingerprint,
      schemaFingerprintAlgorithm: schemaFingerprintAlgorithm,
      dataFingerprints: dataFingerprints,
      profileSummaries: profileSummaries,
      validationIssues: <ValidationIssueSummary>[
        for (final issue in validationIssues) issue.redactedForReport(),
      ],
      importReconciliation: importReconciliation,
      duplicateSummaries: duplicateSummaries,
      errorMessage: errorMessage,
      warningMessages: warningMessages,
      detailStorePath: detailStorePath,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'run_id': runId,
      'profile_id': profileId,
      'target_kind': targetKind.wireName,
      'target_label': targetLabel,
      'database_path': databasePath,
      'started_at': startedAt.toUtc().toIso8601String(),
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'status': status.wireName,
      'mode': mode.wireName,
      'sample_row_limit': sampleRowLimit,
      'schema_fingerprint': schemaFingerprint,
      'schema_fingerprint_algorithm': schemaFingerprintAlgorithm,
      'data_fingerprints': <Map<String, Object?>>[
        for (final item in dataFingerprints) item.toJson(),
      ],
      'profile_summaries': <Map<String, Object?>>[
        for (final item in profileSummaries) item.toJson(),
      ],
      'validation_issues': <Map<String, Object?>>[
        for (final item in validationIssues) item.toJson(),
      ],
      'import_reconciliation': importReconciliation?.toJson(),
      'duplicate_summaries': <Map<String, Object?>>[
        for (final item in duplicateSummaries) item.toJson(),
      ],
      'error_message': errorMessage,
      'warning_messages': warningMessages,
      'detail_store_path': detailStorePath,
    };
  }

  factory QualityRunResult.fromJson(Map<String, Object?> map) {
    return QualityRunResult(
      runId: map['run_id'] as String? ?? '',
      profileId: map['profile_id'] as String?,
      targetKind: _parseQualityTargetKind(map['target_kind']),
      targetLabel: map['target_label'] as String? ?? '',
      databasePath: map['database_path'] as String? ?? '',
      startedAt: _asDateTime(map['started_at']),
      completedAt: map['completed_at'] == null
          ? null
          : _asDateTime(map['completed_at']),
      status: _parseQualityRunStatus(map['status']),
      mode: _parseQualityRunMode(map['mode']),
      sampleRowLimit: _asInt(map['sample_row_limit']),
      schemaFingerprint: map['schema_fingerprint'] as String? ?? '',
      schemaFingerprintAlgorithm:
          map['schema_fingerprint_algorithm'] as String? ?? '',
      dataFingerprints: _asMapList(
        map['data_fingerprints'],
      ).map(QualityDataFingerprint.fromJson).toList(),
      profileSummaries: _asMapList(
        map['profile_summaries'],
      ).map(TableQualitySummary.fromJson).toList(),
      validationIssues: _asMapList(
        map['validation_issues'],
      ).map(ValidationIssueSummary.fromJson).toList(),
      importReconciliation: map['import_reconciliation'] is Map
          ? ImportReconciliationSummary.fromJson(
              Map<String, Object?>.from(map['import_reconciliation']! as Map),
            )
          : null,
      duplicateSummaries: _asMapList(
        map['duplicate_summaries'],
      ).map(DuplicateSummary.fromJson).toList(),
      errorMessage: map['error_message'] as String?,
      warningMessages: _asStringList(map['warning_messages']),
      detailStorePath: map['detail_store_path'] as String?,
    );
  }
}

class QualityDataFingerprint {
  const QualityDataFingerprint({
    required this.tableName,
    required this.rowCount,
    required this.contentFingerprint,
    required this.contentFingerprintAlgorithm,
    required this.computedAt,
  });

  final String tableName;
  final int rowCount;
  final String contentFingerprint;
  final String contentFingerprintAlgorithm;
  final DateTime computedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'table_name': tableName,
    'row_count': rowCount,
    'content_fingerprint': contentFingerprint,
    'content_fingerprint_algorithm': contentFingerprintAlgorithm,
    'computed_at': computedAt.toUtc().toIso8601String(),
  };

  factory QualityDataFingerprint.fromJson(Map<String, Object?> map) {
    return QualityDataFingerprint(
      tableName: map['table_name'] as String? ?? '',
      rowCount: _asInt(map['row_count']) ?? 0,
      contentFingerprint: map['content_fingerprint'] as String? ?? '',
      contentFingerprintAlgorithm:
          map['content_fingerprint_algorithm'] as String? ?? '',
      computedAt: _asDateTime(map['computed_at']),
    );
  }
}

class TableQualitySummary {
  const TableQualitySummary({
    required this.tableName,
    required this.rowCount,
    required this.profileMode,
    required this.sampleRowCount,
    required this.columnSummaries,
    required this.tableWarnings,
  });

  final String tableName;
  final int rowCount;
  final QualityRunMode profileMode;
  final int? sampleRowCount;
  final List<ColumnQualitySummary> columnSummaries;
  final List<String> tableWarnings;

  Map<String, Object?> toJson() => <String, Object?>{
    'table_name': tableName,
    'row_count': rowCount,
    'profile_mode': profileMode.wireName,
    'sample_row_count': sampleRowCount,
    'column_summaries': <Map<String, Object?>>[
      for (final item in columnSummaries) item.toJson(),
    ],
    'table_warnings': tableWarnings,
  };

  factory TableQualitySummary.fromJson(Map<String, Object?> map) {
    return TableQualitySummary(
      tableName: map['table_name'] as String? ?? '',
      rowCount: _asInt(map['row_count']) ?? 0,
      profileMode: _parseQualityRunMode(map['profile_mode']),
      sampleRowCount: _asInt(map['sample_row_count']),
      columnSummaries: _asMapList(
        map['column_summaries'],
      ).map(ColumnQualitySummary.fromJson).toList(),
      tableWarnings: _asStringList(map['table_warnings']),
    );
  }
}

class ColumnQualitySummary {
  const ColumnQualitySummary({
    required this.columnName,
    required this.typeName,
    required this.nativeTypeFamily,
    required this.rowCount,
    required this.sampleRowCount,
    required this.nullCount,
    required this.nullPercent,
    required this.emptyStringCount,
    required this.emptyStringPercent,
    required this.nonNullCount,
    required this.distinctCount,
    required this.distinctPercent,
    required this.minValueDisplay,
    required this.maxValueDisplay,
    required this.meanValueDisplay,
    required this.medianValueDisplay,
    required this.stddevValueDisplay,
    required this.minLength,
    required this.maxLength,
    required this.topValues,
    required this.histogramBuckets,
    required this.malformedTemporalCount,
    required this.potentialKey,
    required this.outlierSummary,
    required this.warnings,
    this.distinctStatus = QualityMetricStatus.computed,
  });

  final String columnName;
  final String typeName;
  final String? nativeTypeFamily;
  final int rowCount;
  final int? sampleRowCount;
  final int nullCount;
  final double nullPercent;
  final int emptyStringCount;
  final double emptyStringPercent;
  final int nonNullCount;
  final int distinctCount;
  final double distinctPercent;
  final String? minValueDisplay;
  final String? maxValueDisplay;
  final String? meanValueDisplay;
  final String? medianValueDisplay;
  final String? stddevValueDisplay;
  final int? minLength;
  final int? maxLength;
  final List<QualityValueFrequency> topValues;
  final List<QualityHistogramBucket> histogramBuckets;
  final int malformedTemporalCount;
  final bool potentialKey;
  final OutlierSummary? outlierSummary;
  final List<String> warnings;
  final QualityMetricStatus distinctStatus;

  Map<String, Object?> toJson() => <String, Object?>{
    'column_name': columnName,
    'type_name': typeName,
    'native_type_family': nativeTypeFamily,
    'row_count': rowCount,
    'sample_row_count': sampleRowCount,
    'null_count': nullCount,
    'null_percent': nullPercent,
    'empty_string_count': emptyStringCount,
    'empty_string_percent': emptyStringPercent,
    'non_null_count': nonNullCount,
    'distinct_count': distinctCount,
    'distinct_percent': distinctPercent,
    'min_value_display': minValueDisplay,
    'max_value_display': maxValueDisplay,
    'mean_value_display': meanValueDisplay,
    'median_value_display': medianValueDisplay,
    'stddev_value_display': stddevValueDisplay,
    'min_length': minLength,
    'max_length': maxLength,
    'top_values': <Map<String, Object?>>[
      for (final item in topValues) item.toJson(),
    ],
    'histogram_buckets': <Map<String, Object?>>[
      for (final item in histogramBuckets) item.toJson(),
    ],
    'malformed_temporal_count': malformedTemporalCount,
    'potential_key': potentialKey,
    'outlier_summary': outlierSummary?.toJson(),
    'warnings': warnings,
    'distinct_status': distinctStatus.wireName,
  };

  factory ColumnQualitySummary.fromJson(Map<String, Object?> map) {
    return ColumnQualitySummary(
      columnName: map['column_name'] as String? ?? '',
      typeName: map['type_name'] as String? ?? '',
      nativeTypeFamily: map['native_type_family'] as String?,
      rowCount: _asInt(map['row_count']) ?? 0,
      sampleRowCount: _asInt(map['sample_row_count']),
      nullCount: _asInt(map['null_count']) ?? 0,
      nullPercent: _asDouble(map['null_percent']),
      emptyStringCount: _asInt(map['empty_string_count']) ?? 0,
      emptyStringPercent: _asDouble(map['empty_string_percent']),
      nonNullCount: _asInt(map['non_null_count']) ?? 0,
      distinctCount: _asInt(map['distinct_count']) ?? 0,
      distinctPercent: _asDouble(map['distinct_percent']),
      minValueDisplay: map['min_value_display'] as String?,
      maxValueDisplay: map['max_value_display'] as String?,
      meanValueDisplay: map['mean_value_display'] as String?,
      medianValueDisplay: map['median_value_display'] as String?,
      stddevValueDisplay: map['stddev_value_display'] as String?,
      minLength: _asInt(map['min_length']),
      maxLength: _asInt(map['max_length']),
      topValues: _asMapList(
        map['top_values'],
      ).map(QualityValueFrequency.fromJson).toList(),
      histogramBuckets: _asMapList(
        map['histogram_buckets'],
      ).map(QualityHistogramBucket.fromJson).toList(),
      malformedTemporalCount: _asInt(map['malformed_temporal_count']) ?? 0,
      potentialKey: map['potential_key'] as bool? ?? false,
      outlierSummary: map['outlier_summary'] is Map
          ? OutlierSummary.fromJson(
              Map<String, Object?>.from(map['outlier_summary']! as Map),
            )
          : null,
      warnings: _asStringList(map['warnings']),
      distinctStatus: _parseQualityMetricStatus(map['distinct_status']),
    );
  }
}

class QualityValueFrequency {
  const QualityValueFrequency({
    required this.valueDisplay,
    required this.count,
    required this.percent,
  });

  final String valueDisplay;
  final int count;
  final double percent;

  Map<String, Object?> toJson() => <String, Object?>{
    'value_display': valueDisplay,
    'count': count,
    'percent': percent,
  };

  factory QualityValueFrequency.fromJson(Map<String, Object?> map) {
    return QualityValueFrequency(
      valueDisplay: map['value_display'] as String? ?? '',
      count: _asInt(map['count']) ?? 0,
      percent: _asDouble(map['percent']),
    );
  }
}

class QualityHistogramBucket {
  const QualityHistogramBucket({
    required this.label,
    required this.lowerBoundDisplay,
    required this.upperBoundDisplay,
    required this.count,
    required this.percent,
  });

  final String label;
  final String? lowerBoundDisplay;
  final String? upperBoundDisplay;
  final int count;
  final double percent;

  Map<String, Object?> toJson() => <String, Object?>{
    'label': label,
    'lower_bound_display': lowerBoundDisplay,
    'upper_bound_display': upperBoundDisplay,
    'count': count,
    'percent': percent,
  };

  factory QualityHistogramBucket.fromJson(Map<String, Object?> map) {
    return QualityHistogramBucket(
      label: map['label'] as String? ?? '',
      lowerBoundDisplay: map['lower_bound_display'] as String?,
      upperBoundDisplay: map['upper_bound_display'] as String?,
      count: _asInt(map['count']) ?? 0,
      percent: _asDouble(map['percent']),
    );
  }
}

class OutlierSummary {
  const OutlierSummary({
    required this.method,
    required this.lowerFenceDisplay,
    required this.upperFenceDisplay,
    required this.outlierCount,
    required this.outlierPercent,
  });

  final OutlierMethod method;
  final String lowerFenceDisplay;
  final String upperFenceDisplay;
  final int outlierCount;
  final double outlierPercent;

  Map<String, Object?> toJson() => <String, Object?>{
    'method': method.wireName,
    'lower_fence_display': lowerFenceDisplay,
    'upper_fence_display': upperFenceDisplay,
    'outlier_count': outlierCount,
    'outlier_percent': outlierPercent,
  };

  factory OutlierSummary.fromJson(Map<String, Object?> map) {
    return OutlierSummary(
      method: _parseOutlierMethod(map['method']),
      lowerFenceDisplay: map['lower_fence_display'] as String? ?? '',
      upperFenceDisplay: map['upper_fence_display'] as String? ?? '',
      outlierCount: _asInt(map['outlier_count']) ?? 0,
      outlierPercent: _asDouble(map['outlier_percent']),
    );
  }
}

class ImportReconciliationSummary {
  const ImportReconciliationSummary({
    required this.importJobId,
    required this.sourcePathDisplay,
    required this.sourceFormat,
    required this.sourceFingerprint,
    required this.startedAt,
    required this.completedAt,
    required this.tableMappings,
    required this.warningCount,
    required this.warningsByTable,
    required this.warningsByCode,
  });

  final String? importJobId;
  final String sourcePathDisplay;
  final String sourceFormat;
  final String? sourceFingerprint;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<ImportTableReconciliation> tableMappings;
  final int warningCount;
  final Map<String, int> warningsByTable;
  final Map<String, int> warningsByCode;

  Map<String, Object?> toJson() => <String, Object?>{
    'import_job_id': importJobId,
    'source_path_display': sourcePathDisplay,
    'source_format': sourceFormat,
    'source_fingerprint': sourceFingerprint,
    'started_at': startedAt?.toUtc().toIso8601String(),
    'completed_at': completedAt?.toUtc().toIso8601String(),
    'table_mappings': <Map<String, Object?>>[
      for (final mapping in tableMappings) mapping.toJson(),
    ],
    'warning_count': warningCount,
    'warnings_by_table': warningsByTable,
    'warnings_by_code': warningsByCode,
  };

  factory ImportReconciliationSummary.fromJson(Map<String, Object?> map) {
    return ImportReconciliationSummary(
      importJobId: map['import_job_id'] as String?,
      sourcePathDisplay: map['source_path_display'] as String? ?? '',
      sourceFormat: map['source_format'] as String? ?? '',
      sourceFingerprint: map['source_fingerprint'] as String?,
      startedAt: map['started_at'] == null
          ? null
          : _asDateTime(map['started_at']),
      completedAt: map['completed_at'] == null
          ? null
          : _asDateTime(map['completed_at']),
      tableMappings: _asMapList(
        map['table_mappings'],
      ).map(ImportTableReconciliation.fromJson).toList(),
      warningCount: _asInt(map['warning_count']) ?? 0,
      warningsByTable: _asIntMap(map['warnings_by_table']),
      warningsByCode: _asIntMap(map['warnings_by_code']),
    );
  }
}

class ImportTableReconciliation {
  const ImportTableReconciliation({
    required this.sourceName,
    required this.targetTable,
    required this.sourceRowCount,
    required this.importedRowCount,
    required this.skippedRowCount,
    required this.rejectedRowCount,
    required this.transformedRowCount,
    required this.typeCoercionFailureCount,
    required this.warningCount,
  });

  final String sourceName;
  final String targetTable;
  final int? sourceRowCount;
  final int importedRowCount;
  final int skippedRowCount;
  final int rejectedRowCount;
  final int transformedRowCount;
  final int typeCoercionFailureCount;
  final int warningCount;

  Map<String, Object?> toJson() => <String, Object?>{
    'source_name': sourceName,
    'target_table': targetTable,
    'source_row_count': sourceRowCount,
    'imported_row_count': importedRowCount,
    'skipped_row_count': skippedRowCount,
    'rejected_row_count': rejectedRowCount,
    'transformed_row_count': transformedRowCount,
    'type_coercion_failure_count': typeCoercionFailureCount,
    'warning_count': warningCount,
  };

  factory ImportTableReconciliation.fromJson(Map<String, Object?> map) {
    return ImportTableReconciliation(
      sourceName: map['source_name'] as String? ?? '',
      targetTable: map['target_table'] as String? ?? '',
      sourceRowCount: _asInt(map['source_row_count']),
      importedRowCount: _asInt(map['imported_row_count']) ?? 0,
      skippedRowCount: _asInt(map['skipped_row_count']) ?? 0,
      rejectedRowCount: _asInt(map['rejected_row_count']) ?? 0,
      transformedRowCount: _asInt(map['transformed_row_count']) ?? 0,
      typeCoercionFailureCount: _asInt(map['type_coercion_failure_count']) ?? 0,
      warningCount: _asInt(map['warning_count']) ?? 0,
    );
  }
}

class ValidationIssueSummary {
  const ValidationIssueSummary({
    required this.issueId,
    required this.ruleId,
    required this.ruleName,
    required this.ruleType,
    required this.severity,
    required this.targetTable,
    required this.targetColumn,
    required this.issueCode,
    required this.message,
    required this.failureCount,
    required this.sampleViolationRows,
    required this.detailsAvailable,
    required this.detailQuerySql,
    required this.detailStorePath,
  });

  final String issueId;
  final String ruleId;
  final String ruleName;
  final String ruleType;
  final QualitySeverity severity;
  final String targetTable;
  final String? targetColumn;
  final String issueCode;
  final String message;
  final int failureCount;
  final List<ViolationRowReference> sampleViolationRows;
  final bool detailsAvailable;
  final String? detailQuerySql;
  final String? detailStorePath;

  ValidationIssueSummary redactedForReport() {
    return ValidationIssueSummary(
      issueId: issueId,
      ruleId: ruleId,
      ruleName: ruleName,
      ruleType: ruleType,
      severity: severity,
      targetTable: targetTable,
      targetColumn: targetColumn,
      issueCode: issueCode,
      message: message,
      failureCount: failureCount,
      sampleViolationRows: <ViolationRowReference>[
        for (final row in sampleViolationRows) row.redactedForReport(),
      ],
      detailsAvailable: detailsAvailable,
      detailQuerySql: detailQuerySql,
      detailStorePath: detailStorePath,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'issue_id': issueId,
    'rule_id': ruleId,
    'rule_name': ruleName,
    'rule_type': ruleType,
    'severity': severity.wireName,
    'target_table': targetTable,
    'target_column': targetColumn,
    'issue_code': issueCode,
    'message': message,
    'failure_count': failureCount,
    'sample_violation_rows': <Map<String, Object?>>[
      for (final row in sampleViolationRows) row.toJson(),
    ],
    'details_available': detailsAvailable,
    'detail_query_sql': detailQuerySql,
    'detail_store_path': detailStorePath,
  };

  factory ValidationIssueSummary.fromJson(Map<String, Object?> map) {
    return ValidationIssueSummary(
      issueId: map['issue_id'] as String? ?? '',
      ruleId: map['rule_id'] as String? ?? '',
      ruleName: map['rule_name'] as String? ?? '',
      ruleType: map['rule_type'] as String? ?? '',
      severity: _parseQualitySeverity(map['severity']),
      targetTable: map['target_table'] as String? ?? '',
      targetColumn: map['target_column'] as String?,
      issueCode: map['issue_code'] as String? ?? '',
      message: map['message'] as String? ?? '',
      failureCount: _asInt(map['failure_count']) ?? 0,
      sampleViolationRows: _asMapList(
        map['sample_violation_rows'],
      ).map(ViolationRowReference.fromJson).toList(),
      detailsAvailable: map['details_available'] as bool? ?? false,
      detailQuerySql: map['detail_query_sql'] as String?,
      detailStorePath: map['detail_store_path'] as String?,
    );
  }
}

class ViolationRowReference {
  const ViolationRowReference({
    required this.rowIdentity,
    required this.rowNumber,
    required this.valueDisplay,
    required this.message,
  });

  final Map<String, String> rowIdentity;
  final int? rowNumber;
  final String? valueDisplay;
  final String message;

  ViolationRowReference redactedForReport() {
    return ViolationRowReference(
      rowIdentity: rowIdentity,
      rowNumber: rowNumber,
      valueDisplay: null,
      message: message,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'row_identity': rowIdentity,
    'row_number': rowNumber,
    'value_display': valueDisplay,
    'message': message,
  };

  factory ViolationRowReference.fromJson(Map<String, Object?> map) {
    return ViolationRowReference(
      rowIdentity: Map<String, String>.from(
        map['row_identity'] as Map? ?? const <String, String>{},
      ),
      rowNumber: _asInt(map['row_number']),
      valueDisplay: map['value_display'] as String?,
      message: map['message'] as String? ?? '',
    );
  }
}

class DuplicateSummary {
  const DuplicateSummary({
    required this.summaryId,
    required this.ruleId,
    required this.targetTable,
    required this.columns,
    required this.duplicateType,
    required this.groupCount,
    required this.rowCount,
    required this.candidateLimit,
    required this.detailsAvailable,
    required this.detailStorePath,
  });

  final String summaryId;
  final String? ruleId;
  final String targetTable;
  final List<String> columns;
  final String duplicateType;
  final int groupCount;
  final int rowCount;
  final int? candidateLimit;
  final bool detailsAvailable;
  final String? detailStorePath;

  Map<String, Object?> toJson() => <String, Object?>{
    'summary_id': summaryId,
    'rule_id': ruleId,
    'target_table': targetTable,
    'columns': columns,
    'duplicate_type': duplicateType,
    'group_count': groupCount,
    'row_count': rowCount,
    'candidate_limit': candidateLimit,
    'details_available': detailsAvailable,
    'detail_store_path': detailStorePath,
  };

  factory DuplicateSummary.fromJson(Map<String, Object?> map) {
    return DuplicateSummary(
      summaryId: map['summary_id'] as String? ?? '',
      ruleId: map['rule_id'] as String?,
      targetTable: map['target_table'] as String? ?? '',
      columns: _asStringList(map['columns']),
      duplicateType: map['duplicate_type'] as String? ?? '',
      groupCount: _asInt(map['group_count']) ?? 0,
      rowCount: _asInt(map['row_count']) ?? 0,
      candidateLimit: _asInt(map['candidate_limit']),
      detailsAvailable: map['details_available'] as bool? ?? false,
      detailStorePath: map['detail_store_path'] as String?,
    );
  }
}

List<DataQualityValidationError> validateValidationRuleParams(
  ValidationRule rule,
) {
  final params = rule.params;
  final errors = <DataQualityValidationError>[];
  void unknownExcept(Set<String> allowed) {
    for (final key in params.keys) {
      if (!allowed.contains(key)) {
        errors.add(
          DataQualityValidationError(
            field: 'params.$key',
            message: 'Parameter is not supported by ${rule.ruleType.wireName}.',
          ),
        );
      }
    }
  }

  void requireColumn() {
    if (rule.targetColumn == null || rule.targetColumn!.trim().isEmpty) {
      errors.add(
        DataQualityValidationError(
          field: 'target_column',
          message: '${rule.ruleType.wireName} requires a target column.',
        ),
      );
    }
  }

  switch (rule.ruleType) {
    case ValidationRuleType.required:
      requireColumn();
      unknownExcept(<String>{'trim_strings', 'treat_empty_string_as_null'});
      _expectBool(errors, params, 'trim_strings');
      _expectBool(errors, params, 'treat_empty_string_as_null');
    case ValidationRuleType.unique:
      unknownExcept(<String>{'columns', 'ignore_nulls', 'trim_strings'});
      final columns = _optionalStringList(params['columns']);
      if ((columns == null || columns.isEmpty) &&
          (rule.targetColumn == null || rule.targetColumn!.trim().isEmpty)) {
        errors.add(
          const DataQualityValidationError(
            field: 'params.columns',
            message: 'Unique requires columns or a target column.',
          ),
        );
      }
      _expectBool(errors, params, 'ignore_nulls');
      _expectBool(errors, params, 'trim_strings');
    case ValidationRuleType.allowedValues:
      requireColumn();
      unknownExcept(<String>{
        'values',
        'case_sensitive',
        'trim_strings',
        'allow_null',
      });
      final values = _optionalStringList(params['values']);
      if (values == null || values.isEmpty) {
        errors.add(
          const DataQualityValidationError(
            field: 'params.values',
            message: 'Allowed values requires a non-empty values list.',
          ),
        );
      }
      _expectBool(errors, params, 'case_sensitive');
      _expectBool(errors, params, 'trim_strings');
      _expectBool(errors, params, 'allow_null');
    case ValidationRuleType.regex:
      requireColumn();
      unknownExcept(<String>{'pattern', 'case_sensitive', 'allow_null'});
      if ((params['pattern'] as String? ?? '').trim().isEmpty) {
        errors.add(
          const DataQualityValidationError(
            field: 'params.pattern',
            message: 'Regex requires a pattern.',
          ),
        );
      }
      _expectBool(errors, params, 'case_sensitive');
      _expectBool(errors, params, 'allow_null');
    case ValidationRuleType.numericRange:
      requireColumn();
      unknownExcept(<String>{
        'min',
        'max',
        'inclusive_min',
        'inclusive_max',
        'allow_null',
      });
      if (params['min'] == null && params['max'] == null) {
        errors.add(
          const DataQualityValidationError(
            field: 'params.min',
            message: 'Numeric range requires min or max.',
          ),
        );
      }
      _expectNumber(errors, params, 'min');
      _expectNumber(errors, params, 'max');
      _expectBool(errors, params, 'inclusive_min');
      _expectBool(errors, params, 'inclusive_max');
      _expectBool(errors, params, 'allow_null');
    case ValidationRuleType.dateRange:
      requireColumn();
      unknownExcept(<String>{
        'min',
        'max',
        'inclusive_min',
        'inclusive_max',
        'allow_null',
      });
      if (params['min'] == null && params['max'] == null) {
        errors.add(
          const DataQualityValidationError(
            field: 'params.min',
            message: 'Date range requires min or max.',
          ),
        );
      }
      _expectIsoDate(errors, params, 'min');
      _expectIsoDate(errors, params, 'max');
      _expectBool(errors, params, 'inclusive_min');
      _expectBool(errors, params, 'inclusive_max');
      _expectBool(errors, params, 'allow_null');
    case ValidationRuleType.stringLength:
      requireColumn();
      unknownExcept(<String>{
        'min_length',
        'max_length',
        'trim_strings',
        'allow_null',
      });
      if (params['min_length'] == null && params['max_length'] == null) {
        errors.add(
          const DataQualityValidationError(
            field: 'params.min_length',
            message: 'String length requires min_length or max_length.',
          ),
        );
      }
      _expectInt(errors, params, 'min_length');
      _expectInt(errors, params, 'max_length');
      _expectBool(errors, params, 'trim_strings');
      _expectBool(errors, params, 'allow_null');
    case ValidationRuleType.crossColumn:
      unknownExcept(<String>{'sql_expression', 'referenced_columns'});
      _validateSafePredicate(
        errors,
        params['sql_expression'] as String? ?? '',
        'params.sql_expression',
      );
      final columns = _optionalStringList(params['referenced_columns']);
      if (columns == null || columns.isEmpty) {
        errors.add(
          const DataQualityValidationError(
            field: 'params.referenced_columns',
            message: 'Cross-column rule requires referenced columns.',
          ),
        );
      }
    case ValidationRuleType.referential:
      unknownExcept(<String>{
        'source_columns',
        'reference_table',
        'reference_columns',
        'ignore_nulls',
      });
      final source = _optionalStringList(params['source_columns']);
      final reference = _optionalStringList(params['reference_columns']);
      if (source == null || source.isEmpty) {
        errors.add(
          const DataQualityValidationError(
            field: 'params.source_columns',
            message: 'Referential rule requires source columns.',
          ),
        );
      }
      if ((params['reference_table'] as String? ?? '').trim().isEmpty) {
        errors.add(
          const DataQualityValidationError(
            field: 'params.reference_table',
            message: 'Referential rule requires a reference table.',
          ),
        );
      }
      if (reference == null || reference.isEmpty) {
        errors.add(
          const DataQualityValidationError(
            field: 'params.reference_columns',
            message: 'Referential rule requires reference columns.',
          ),
        );
      }
      if (source != null &&
          reference != null &&
          source.length != reference.length) {
        errors.add(
          const DataQualityValidationError(
            field: 'params.reference_columns',
            message: 'Source and reference column counts must match.',
          ),
        );
      }
      _expectBool(errors, params, 'ignore_nulls');
    case ValidationRuleType.customSqlPredicate:
      unknownExcept(<String>{'predicate_sql', 'referenced_columns'});
      _validateSafePredicate(
        errors,
        params['predicate_sql'] as String? ?? '',
        'params.predicate_sql',
      );
      final columns = _optionalStringList(params['referenced_columns']);
      if (columns == null || columns.isEmpty) {
        errors.add(
          const DataQualityValidationError(
            field: 'params.referenced_columns',
            message: 'Custom SQL predicate requires referenced columns.',
          ),
        );
      }
    case ValidationRuleType.exactDuplicateRows:
      unknownExcept(<String>{'columns', 'ignore_nulls', 'trim_strings'});
      final columns = _optionalStringList(params['columns']);
      if (columns == null || columns.isEmpty) {
        errors.add(
          const DataQualityValidationError(
            field: 'params.columns',
            message: 'Exact duplicate check requires columns.',
          ),
        );
      }
      _expectBool(errors, params, 'ignore_nulls');
      _expectBool(errors, params, 'trim_strings');
    case ValidationRuleType.nearDuplicateRows:
      unknownExcept(<String>{
        'columns',
        'similarity',
        'threshold',
        'candidate_limit',
        'blocking_columns',
        'trim_strings',
        'case_sensitive',
      });
      final columns = _optionalStringList(params['columns']);
      if (columns == null || columns.isEmpty) {
        errors.add(
          const DataQualityValidationError(
            field: 'params.columns',
            message: 'Near duplicate check requires columns.',
          ),
        );
      }
      final threshold = _asDouble(params['threshold']);
      if (threshold < 0 || threshold > 1) {
        errors.add(
          const DataQualityValidationError(
            field: 'params.threshold',
            message: 'Near duplicate threshold must be between 0.0 and 1.0.',
          ),
        );
      }
      if ((_asInt(params['candidate_limit']) ?? 0) < 1) {
        errors.add(
          const DataQualityValidationError(
            field: 'params.candidate_limit',
            message: 'Near duplicate candidate limit must be positive.',
          ),
        );
      }
      if (params['similarity'] != null) {
        _parseNearDuplicateSimilarity(params['similarity']);
      }
      _optionalStringList(params['blocking_columns']);
      _expectBool(errors, params, 'trim_strings');
      _expectBool(errors, params, 'case_sensitive');
  }
  return errors;
}

String generateQualityUuid() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
  final value = bytes.map(hex).join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-${value.substring(16, 20)}-'
      '${value.substring(20)}';
}

String normalizeImportWarningCode(String warning) {
  final normalized = warning.toLowerCase();
  if (normalized.contains('coerc') || normalized.contains('type')) {
    return 'type_coercion_failed';
  }
  if (normalized.contains('skipped') && normalized.contains('malformed')) {
    return 'malformed_row_skipped';
  }
  if (normalized.contains('truncated') ||
      normalized.contains('padded') ||
      normalized.contains('normalized')) {
    return 'malformed_row_normalized';
  }
  if (normalized.contains('unsupported')) {
    return 'unsupported_source_feature';
  }
  return 'import_warning_unknown';
}

const Object _unset = Object();

extension QualityTargetKindWire on QualityTargetKind {
  String get wireName =>
      this == QualityTargetKind.queryResult ? 'query_result' : name;
}

extension QualityRunStatusWire on QualityRunStatus {
  String get wireName => name;
}

extension QualityRunModeWire on QualityRunMode {
  String get wireName => name;
}

extension QualitySeverityWire on QualitySeverity {
  String get wireName => name;
}

extension ValidationRuleTypeWire on ValidationRuleType {
  String get wireName {
    return switch (this) {
      ValidationRuleType.allowedValues => 'allowed_values',
      ValidationRuleType.numericRange => 'numeric_range',
      ValidationRuleType.dateRange => 'date_range',
      ValidationRuleType.stringLength => 'string_length',
      ValidationRuleType.crossColumn => 'cross_column',
      ValidationRuleType.customSqlPredicate => 'custom_sql_predicate',
      ValidationRuleType.exactDuplicateRows => 'exact_duplicate_rows',
      ValidationRuleType.nearDuplicateRows => 'near_duplicate_rows',
      _ => name,
    };
  }
}

extension OutlierMethodWire on OutlierMethod {
  String get wireName => name;
}

extension NearDuplicateSimilarityWire on NearDuplicateSimilarity {
  String get wireName {
    return switch (this) {
      NearDuplicateSimilarity.normalizedLevenshtein => 'normalized_levenshtein',
      NearDuplicateSimilarity.tokenSortRatio => 'token_sort_ratio',
    };
  }
}

extension QualityReportFormatWire on QualityReportFormat {
  String get wireName => name == 'json' ? 'json' : name;
  String get extension {
    return switch (this) {
      QualityReportFormat.markdown => '.md',
      QualityReportFormat.html => '.html',
      QualityReportFormat.json => '.json',
    };
  }
}

extension QualityMetricStatusWire on QualityMetricStatus {
  String get wireName {
    return switch (this) {
      QualityMetricStatus.computed => 'computed',
      QualityMetricStatus.notComputed => 'not_computed',
    };
  }
}

QualityTargetKind _parseQualityTargetKind(Object? value) {
  return switch ((value as String? ?? 'database').trim()) {
    'table' => QualityTargetKind.table,
    'query_result' => QualityTargetKind.queryResult,
    _ => QualityTargetKind.database,
  };
}

QualityRunStatus _parseQualityRunStatus(Object? value) {
  return QualityRunStatus.values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => QualityRunStatus.completed,
  );
}

QualityRunMode _parseQualityRunMode(Object? value) {
  return QualityRunMode.values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => QualityRunMode.full,
  );
}

QualitySeverity _parseQualitySeverity(Object? value) {
  return QualitySeverity.values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => QualitySeverity.warning,
  );
}

ValidationRuleType _parseValidationRuleType(Object? value) {
  return ValidationRuleType.values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => ValidationRuleType.required,
  );
}

OutlierMethod _parseOutlierMethod(Object? value) {
  return OutlierMethod.values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => OutlierMethod.iqr,
  );
}

NearDuplicateSimilarity _parseNearDuplicateSimilarity(Object? value) {
  return NearDuplicateSimilarity.values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => NearDuplicateSimilarity.normalizedLevenshtein,
  );
}

QualityMetricStatus _parseQualityMetricStatus(Object? value) {
  return QualityMetricStatus.values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => QualityMetricStatus.computed,
  );
}

Object? _parseTomlValue(String rawValue) {
  final value = rawValue.trim();
  if (value == 'true') {
    return true;
  }
  if (value == 'false') {
    return false;
  }
  if (value == 'null') {
    return null;
  }
  if (value.startsWith('"') || value.startsWith('[')) {
    return jsonDecode(value);
  }
  return int.tryParse(value) ?? double.tryParse(value) ?? value;
}

String _tomlValue(Object? value) {
  if (value == null) {
    return 'null';
  }
  if (value is bool || value is num) {
    return '$value';
  }
  return jsonEncode(value);
}

String _stripTomlComment(String rawLine) {
  var inString = false;
  var escaped = false;
  for (var i = 0; i < rawLine.length; i++) {
    final char = rawLine[i];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char == '\\') {
      escaped = true;
      continue;
    }
    if (char == '"') {
      inString = !inString;
      continue;
    }
    if (char == '#' && !inString) {
      return rawLine.substring(0, i);
    }
  }
  return rawLine;
}

DateTime _asDateTime(Object? value) {
  return DateTime.tryParse(value as String? ?? '')?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

double _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}

List<Map<String, Object?>> _asMapList(Object? value) {
  return ((value as List?) ?? const <Object?>[])
      .whereType<Map>()
      .map((map) => Map<String, Object?>.from(map))
      .toList();
}

List<String> _asStringList(Object? value) {
  return ((value as List?) ?? const <Object?>[])
      .map((item) => '$item')
      .toList();
}

Map<String, int> _asIntMap(Object? value) {
  final map = value as Map? ?? const <String, Object?>{};
  return <String, int>{
    for (final entry in map.entries) '${entry.key}': _asInt(entry.value) ?? 0,
  };
}

List<String>? _optionalStringList(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is List) {
    return value
        .map((item) => '$item')
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }
  return null;
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}

bool _mapEquals(Map<String, Object?> left, Map<String, Object?> right) {
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

void _expectBool(
  List<DataQualityValidationError> errors,
  Map<String, Object?> params,
  String key,
) {
  if (params.containsKey(key) && params[key] is! bool) {
    errors.add(
      DataQualityValidationError(
        field: 'params.$key',
        message: '$key must be a bool.',
      ),
    );
  }
}

void _expectNumber(
  List<DataQualityValidationError> errors,
  Map<String, Object?> params,
  String key,
) {
  if (params.containsKey(key) && params[key] != null && params[key] is! num) {
    errors.add(
      DataQualityValidationError(
        field: 'params.$key',
        message: '$key must be a number.',
      ),
    );
  }
}

void _expectInt(
  List<DataQualityValidationError> errors,
  Map<String, Object?> params,
  String key,
) {
  if (params.containsKey(key) && params[key] != null && params[key] is! int) {
    errors.add(
      DataQualityValidationError(
        field: 'params.$key',
        message: '$key must be an integer.',
      ),
    );
  }
}

void _expectIsoDate(
  List<DataQualityValidationError> errors,
  Map<String, Object?> params,
  String key,
) {
  final value = params[key];
  if (value == null) {
    return;
  }
  if (value is! String || DateTime.tryParse(value) == null) {
    errors.add(
      DataQualityValidationError(
        field: 'params.$key',
        message: '$key must be an ISO-8601 date/time string.',
      ),
    );
  }
}

void _validateSafePredicate(
  List<DataQualityValidationError> errors,
  String value,
  String field,
) {
  if (value.trim().isEmpty) {
    errors.add(
      DataQualityValidationError(
        field: field,
        message: 'SQL predicate is required.',
      ),
    );
    return;
  }
  final upper = value.toUpperCase();
  if (value.contains(';') ||
      RegExp(
        r'\b(CREATE|ALTER|DROP|INSERT|UPDATE|DELETE|MERGE|REPLACE|ATTACH|DETACH|VACUUM|PRAGMA)\b',
      ).hasMatch(upper)) {
    errors.add(
      DataQualityValidationError(
        field: field,
        message: 'SQL predicate contains unsafe SQL.',
      ),
    );
  }
}
