import 'dart:convert';
import 'dart:typed_data';

import 'sql_error_location.dart';

enum QueryPhase {
  idle,
  opening,
  running,
  fetching,
  cancelling,
  completed,
  cancelled,
  failed,
}

enum QueryErrorStage { validation, opening, paging, cancellation, export }

enum QueryMessageLevel { info, warning, error }

enum QueryHistoryOutcome { completed, failed, cancelled }

enum SchemaObjectKind { table, view }

enum NativeTypeFamily {
  numeric,
  boolean,
  text,
  binary,
  uuid,
  enumValue,
  temporal,
  network,
  macAddress,
  spatial,
  unknown,
}

class NativeTypeDescriptor {
  const NativeTypeDescriptor({
    required this.typeName,
    required this.baseTypeName,
    required this.family,
    this.valueKind,
    this.spatial,
    this.enumLabels = const <String>[],
  });

  final String typeName;
  final String baseTypeName;
  final NativeTypeFamily family;
  final String? valueKind;
  final ToolingSpatialTypeInfo? spatial;
  final List<String> enumLabels;

  bool get isNativeV25Type {
    return switch (family) {
      NativeTypeFamily.enumValue ||
      NativeTypeFamily.temporal ||
      NativeTypeFamily.network ||
      NativeTypeFamily.macAddress ||
      NativeTypeFamily.spatial => true,
      _ => false,
    };
  }

  bool get isSpatial => family == NativeTypeFamily.spatial;

  String get familyLabel {
    return switch (family) {
      NativeTypeFamily.numeric => 'Numeric',
      NativeTypeFamily.boolean => 'Boolean',
      NativeTypeFamily.text => 'Text',
      NativeTypeFamily.binary => 'Binary',
      NativeTypeFamily.uuid => 'UUID',
      NativeTypeFamily.enumValue => 'Enum',
      NativeTypeFamily.temporal => 'Temporal',
      NativeTypeFamily.network => 'Network',
      NativeTypeFamily.macAddress => 'MAC address',
      NativeTypeFamily.spatial => 'Spatial',
      NativeTypeFamily.unknown => 'Unknown',
    };
  }

  String get summaryLabel {
    final base = baseTypeName.isEmpty ? 'UNKNOWN' : baseTypeName;
    final parts = <String>['$base $familyLabel'];
    if (valueKind != null && valueKind!.trim().isNotEmpty) {
      parts.add('value kind ${valueKind!.trim()}');
    }
    final spatialInfo = spatial;
    if (spatialInfo != null) {
      parts.add(spatialInfo.summaryLabel);
    }
    if (enumLabels.isNotEmpty) {
      parts.add('labels ${enumLabels.join(", ")}');
    }
    return parts.join(' | ');
  }

  String? enumLabelForId(int labelId) {
    final index = labelId - 1;
    if (index < 0 || index >= enumLabels.length) {
      return null;
    }
    return enumLabels[index];
  }
}

class NativeEnumCellValue {
  const NativeEnumCellValue({required this.typeId, required this.labelId});

  final int typeId;
  final int labelId;

  String displayString({NativeTypeDescriptor? descriptor}) {
    final label = descriptor?.enumLabelForId(labelId);
    final identity = 'type $typeId, label $labelId';
    return label == null ? 'ENUM($identity)' : '$label ($identity)';
  }
}

class NativeIntervalCellValue {
  const NativeIntervalCellValue({
    required this.months,
    required this.days,
    required this.microseconds,
  });

  final int months;
  final int days;
  final int microseconds;

  String displayString() {
    final parts = <String>[
      if (months != 0) '${months}mo',
      if (days != 0) '${days}d',
      if (microseconds != 0) _formatTimeMicros(microseconds),
    ];
    return parts.isEmpty ? '0us' : parts.join(' ');
  }
}

NativeTypeDescriptor describeNativeType({
  String? typeName,
  String? valueKind,
  ToolingSpatialTypeInfo? spatial,
}) {
  final rawType = typeName?.trim() ?? '';
  final baseType = _baseTypeName(rawType);
  final family = _nativeTypeFamily(baseType, valueKind: valueKind);
  return NativeTypeDescriptor(
    typeName: rawType,
    baseTypeName: baseType,
    family: family,
    valueKind: valueKind,
    spatial: spatial,
    enumLabels: family == NativeTypeFamily.enumValue
        ? _parseEnumLabels(rawType)
        : const <String>[],
  );
}

class BridgeFailure implements Exception {
  final String message;
  final String? code;

  const BridgeFailure(this.message, {this.code});

  @override
  String toString() => code == null ? message : '$code: $message';
}

class QueryErrorDetails {
  const QueryErrorDetails({
    required this.stage,
    required this.message,
    this.code,
    this.location,
  });

  final QueryErrorStage stage;
  final String message;
  final String? code;
  final QueryErrorLocation? location;

  factory QueryErrorDetails.fromError(
    Object error, {
    required QueryErrorStage stage,
    String? executedSql,
    String? bufferText,
    int bufferStartOffset = 0,
  }) {
    if (error is QueryErrorDetails) {
      if (error.location != null ||
          executedSql == null ||
          bufferText == null ||
          executedSql.trim().isEmpty) {
        return error;
      }
      return QueryErrorDetails(
        stage: error.stage,
        message: error.message,
        code: error.code,
        location: resolveQueryErrorLocation(
          message: error.message,
          executedSql: executedSql,
          bufferText: bufferText,
          bufferStartOffset: bufferStartOffset,
        ),
      );
    }
    final message = error is BridgeFailure ? error.message : error.toString();
    final code = error is BridgeFailure ? error.code : null;
    final location =
        executedSql != null &&
            bufferText != null &&
            executedSql.trim().isNotEmpty
        ? resolveQueryErrorLocation(
            message: message,
            executedSql: executedSql,
            bufferText: bufferText,
            bufferStartOffset: bufferStartOffset,
          )
        : null;
    if (error is BridgeFailure) {
      return QueryErrorDetails(
        stage: stage,
        message: message,
        code: code,
        location: location,
      );
    }
    return QueryErrorDetails(
      stage: stage,
      message: message,
      code: code,
      location: location,
    );
  }

  String get stageLabel {
    switch (stage) {
      case QueryErrorStage.validation:
        return 'Validation';
      case QueryErrorStage.opening:
        return 'Open';
      case QueryErrorStage.paging:
        return 'Paging';
      case QueryErrorStage.cancellation:
        return 'Cancellation';
      case QueryErrorStage.export:
        return 'Export';
    }
  }

  String toClipboardText({String? sql}) {
    final buffer = StringBuffer()
      ..writeln('Stage: $stageLabel')
      ..writeln('Message: $message');
    if (code != null) {
      buffer.writeln('Code: $code');
    }
    if (location != null) {
      buffer.writeln('Location: ${location!.shortLabel}');
    }
    if (sql != null && sql.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('SQL:')
        ..writeln(sql.trim());
    }
    return buffer.toString().trimRight();
  }
}

class DatabaseSession {
  const DatabaseSession({required this.path, required this.engineVersion});

  final String path;
  final String engineVersion;

  factory DatabaseSession.fromMap(Map<String, Object?> map) {
    return DatabaseSession(
      path: map['path']! as String,
      engineVersion: map['engineVersion']! as String,
    );
  }
}

class BranchWorkflowUnavailable implements Exception {
  const BranchWorkflowUnavailable([this.message]);

  final String? message;

  @override
  String toString() => message ?? 'Branch workflow is unavailable.';
}

class WorkspaceBranchInfo {
  const WorkspaceBranchInfo({
    required this.name,
    this.isCurrent = false,
    this.parentRef,
    this.createdAt,
  });

  final String name;
  final bool isCurrent;
  final String? parentRef;
  final DateTime? createdAt;

  factory WorkspaceBranchInfo.fromMap(Map<String, Object?> map) {
    return WorkspaceBranchInfo(
      name: map['name']! as String,
      isCurrent: map['isCurrent'] as bool? ?? false,
      parentRef: map['parentRef'] as String?,
      createdAt: map['createdAt'] is String
          ? DateTime.tryParse(map['createdAt'] as String)
          : null,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'isCurrent': isCurrent,
      if (parentRef != null) 'parentRef': parentRef,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}

class WorkspaceSnapshotInfo {
  const WorkspaceSnapshotInfo({
    required this.name,
    required this.ref,
    this.branch,
    this.createdAt,
  });

  final String name;
  final String ref;
  final String? branch;
  final DateTime? createdAt;

  factory WorkspaceSnapshotInfo.fromMap(Map<String, Object?> map) {
    return WorkspaceSnapshotInfo(
      name: map['name']! as String,
      ref: map['ref']! as String,
      branch: map['branch'] as String?,
      createdAt: map['createdAt'] is String
          ? DateTime.tryParse(map['createdAt'] as String)
          : null,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'ref': ref,
      if (branch != null) 'branch': branch,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}

class WorkspaceBranchDiffRow {
  const WorkspaceBranchDiffRow({
    required this.tableName,
    required this.operation,
    this.primaryKey,
    this.before,
    this.after,
  });

  final String tableName;
  final String operation;
  final String? primaryKey;
  final Map<String, Object?>? before;
  final Map<String, Object?>? after;

  factory WorkspaceBranchDiffRow.fromMap(Map<String, Object?> map) {
    return WorkspaceBranchDiffRow(
      tableName: map['tableName']! as String,
      operation: map['operation']! as String,
      primaryKey: map['primaryKey'] as String?,
      before: _asStringMap(map['before']),
      after: _asStringMap(map['after']),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'tableName': tableName,
      'operation': operation,
      if (primaryKey != null) 'primaryKey': primaryKey,
      if (before != null) 'before': before,
      if (after != null) 'after': after,
    };
  }
}

class WorkspaceBranchDiff {
  const WorkspaceBranchDiff({
    required this.leftRef,
    required this.rightRef,
    required this.rows,
    required this.addedRows,
    required this.modifiedRows,
    required this.removedRows,
  });

  final String leftRef;
  final String rightRef;
  final List<WorkspaceBranchDiffRow> rows;
  final int addedRows;
  final int modifiedRows;
  final int removedRows;

  int get totalChanges => addedRows + modifiedRows + removedRows;

  factory WorkspaceBranchDiff.fromMap(Map<String, Object?> map) {
    return WorkspaceBranchDiff(
      leftRef: map['leftRef']! as String,
      rightRef: map['rightRef']! as String,
      rows: _asMapList(
        map['rows'],
      ).map(WorkspaceBranchDiffRow.fromMap).toList(growable: false),
      addedRows: map['addedRows'] as int? ?? 0,
      modifiedRows: map['modifiedRows'] as int? ?? 0,
      removedRows: map['removedRows'] as int? ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'leftRef': leftRef,
      'rightRef': rightRef,
      'rows': <Map<String, Object?>>[for (final row in rows) row.toJson()],
      'addedRows': addedRows,
      'modifiedRows': modifiedRows,
      'removedRows': removedRows,
    };
  }

  static const WorkspaceBranchDiff empty = WorkspaceBranchDiff(
    leftRef: '',
    rightRef: '',
    rows: <WorkspaceBranchDiffRow>[],
    addedRows: 0,
    modifiedRows: 0,
    removedRows: 0,
  );
}

class WorkspaceBranchState {
  const WorkspaceBranchState({
    required this.currentBranch,
    required this.isNativeBranchApiAvailable,
    required this.nativeBranchApiUnavailableReason,
    required this.branches,
    required this.snapshots,
  });

  final String currentBranch;
  final bool isNativeBranchApiAvailable;
  final String nativeBranchApiUnavailableReason;
  final List<WorkspaceBranchInfo> branches;
  final List<WorkspaceSnapshotInfo> snapshots;

  factory WorkspaceBranchState.unavailable(String reason) {
    return WorkspaceBranchState(
      currentBranch: 'main',
      isNativeBranchApiAvailable: false,
      nativeBranchApiUnavailableReason: reason,
      branches: const <WorkspaceBranchInfo>[],
      snapshots: const <WorkspaceSnapshotInfo>[],
    );
  }

  factory WorkspaceBranchState.fromMap(Map<String, Object?> map) {
    return WorkspaceBranchState(
      currentBranch: map['currentBranch']! as String,
      isNativeBranchApiAvailable:
          map['isNativeBranchApiAvailable'] as bool? ?? false,
      nativeBranchApiUnavailableReason:
          map['nativeBranchApiUnavailableReason'] as String? ??
          'Native branch APIs are unavailable.',
      branches: _asMapList(
        map['branches'],
      ).map(WorkspaceBranchInfo.fromMap).toList(growable: false),
      snapshots: _asMapList(
        map['snapshots'],
      ).map(WorkspaceSnapshotInfo.fromMap).toList(growable: false),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'currentBranch': currentBranch,
      'isNativeBranchApiAvailable': isNativeBranchApiAvailable,
      'nativeBranchApiUnavailableReason': nativeBranchApiUnavailableReason,
      'branches': <Map<String, Object?>>[
        for (final branch in branches) branch.toJson(),
      ],
      'snapshots': <Map<String, Object?>>[
        for (final snapshot in snapshots) snapshot.toJson(),
      ],
    };
  }

  String get branchLabel {
    if (!isNativeBranchApiAvailable) {
      return 'Branch workflow unavailable';
    }
    return 'Branch: $currentBranch, ${branches.length} branches, ${snapshots.length} snapshots';
  }
}

class TableEditabilityState {
  const TableEditabilityState({
    required this.isEditable,
    required this.reason,
    this.tableName,
    this.primaryKeyColumn,
    this.primaryKeyResultColumn,
    this.editableColumns = const <String, String>{},
    this.insertableColumns = const <String, String>{},
    this.readOnlyColumns = const <String>{},
  });

  final bool isEditable;
  final String reason;
  final String? tableName;
  final String? primaryKeyColumn;
  final String? primaryKeyResultColumn;
  final Map<String, String> editableColumns;
  final Map<String, String> insertableColumns;
  final Set<String> readOnlyColumns;

  bool get canDeleteRows =>
      isEditable && tableName != null && primaryKeyResultColumn != null;

  bool get canInsertRows => isEditable && insertableColumns.isNotEmpty;

  bool canEditColumn(String columnName) =>
      editableColumns.containsKey(columnName);

  String get statusLabel {
    if (isEditable) {
      return 'Editable table: $tableName';
    }
    return 'Read-only results: $reason';
  }

  static const TableEditabilityState noResults = TableEditabilityState(
    isEditable: false,
    reason: 'Run a single-table SELECT before editing rows.',
  );
}

class TableEditCommitResult {
  const TableEditCommitResult({
    required this.success,
    required this.message,
    this.rowsAffected,
  });

  final bool success;
  final String message;
  final int? rowsAffected;
}

class SchemaColumn {
  const SchemaColumn({
    required this.name,
    required this.type,
    required this.notNull,
    required this.unique,
    required this.primaryKey,
    this.defaultExpr,
    this.generatedExpr,
    this.generatedStored = false,
    required this.refTable,
    required this.refColumn,
    required this.refOnDelete,
    required this.refOnUpdate,
  });

  final String name;
  final String type;
  final bool notNull;
  final bool unique;
  final bool primaryKey;
  final String? defaultExpr;
  final String? generatedExpr;
  final bool generatedStored;
  final String? refTable;
  final String? refColumn;
  final String? refOnDelete;
  final String? refOnUpdate;

  factory SchemaColumn.fromMap(Map<String, Object?> map) {
    return SchemaColumn(
      name: map['name']! as String,
      type: map['type']! as String,
      notNull: map['notNull']! as bool,
      unique: map['unique']! as bool,
      primaryKey: map['primaryKey']! as bool,
      defaultExpr: map['defaultExpr'] as String?,
      generatedExpr: map['generatedExpr'] as String?,
      generatedStored: map['generatedStored'] as bool? ?? false,
      refTable: map['refTable'] as String?,
      refColumn: map['refColumn'] as String?,
      refOnDelete: map['refOnDelete'] as String?,
      refOnUpdate: map['refOnUpdate'] as String?,
    );
  }

  bool get hasForeignKey => refTable != null && refColumn != null;
  bool get hasDefault => defaultExpr != null && defaultExpr!.trim().isNotEmpty;
  bool get isGenerated =>
      generatedExpr != null && generatedExpr!.trim().isNotEmpty;

  List<String> get constraintSummaries {
    return <String>[
      if (primaryKey) 'PRIMARY KEY',
      if (unique) 'UNIQUE',
      if (notNull) 'NOT NULL',
      if (hasDefault) 'DEFAULT $defaultExpr',
      if (isGenerated)
        generatedStored
            ? 'GENERATED ALWAYS AS ($generatedExpr) STORED'
            : 'GENERATED AS ($generatedExpr)',
      if (hasForeignKey)
        'REFERENCES $refTable($refColumn)'
            '${refOnDelete != null ? ' ON DELETE $refOnDelete' : ''}'
            '${refOnUpdate != null ? ' ON UPDATE $refOnUpdate' : ''}',
    ];
  }

  String get descriptor {
    final flags = constraintSummaries;
    return flags.isEmpty ? type : '$type | ${flags.join(" | ")}';
  }
}

class SchemaCheckConstraint {
  const SchemaCheckConstraint({required this.name, required this.exprSql});

  final String name;
  final String exprSql;

  factory SchemaCheckConstraint.fromMap(Map<String, Object?> map) {
    return SchemaCheckConstraint(
      name: map['name'] as String? ?? '',
      exprSql: map['exprSql']! as String,
    );
  }

  String get summary =>
      name.isEmpty ? 'CHECK ($exprSql)' : 'CHECK $name ($exprSql)';
}

class SchemaObjectSummary {
  const SchemaObjectSummary({
    required this.name,
    required this.kind,
    required this.columns,
    this.temporary = false,
    this.checks = const <SchemaCheckConstraint>[],
    this.ddl,
  });

  final String name;
  final SchemaObjectKind kind;
  final bool temporary;
  final String? ddl;
  final List<SchemaColumn> columns;
  final List<SchemaCheckConstraint> checks;

  factory SchemaObjectSummary.fromMap(Map<String, Object?> map) {
    return SchemaObjectSummary(
      name: map['name']! as String,
      kind: (map['kind'] as String) == 'view'
          ? SchemaObjectKind.view
          : SchemaObjectKind.table,
      temporary: map['temporary'] as bool? ?? false,
      ddl: map['ddl'] as String?,
      columns: ((map['columns'] as List?) ?? const <Object?>[])
          .cast<Map<Object?, Object?>>()
          .map(
            (column) => SchemaColumn.fromMap(
              column.map((key, value) => MapEntry(key as String, value)),
            ),
          )
          .toList(),
      checks: ((map['checks'] as List?) ?? const <Object?>[])
          .cast<Map<Object?, Object?>>()
          .map(
            (check) => SchemaCheckConstraint.fromMap(
              check.map((key, value) => MapEntry(key as String, value)),
            ),
          )
          .toList(),
    );
  }

  List<String> get exposedConstraintSummaries {
    return <String>[
      for (final column in columns)
        for (final constraint in column.constraintSummaries)
          '${column.name}: $constraint',
      for (final check in checks) check.summary,
    ];
  }
}

class IndexSummary {
  const IndexSummary({
    required this.name,
    required this.table,
    required this.columns,
    required this.unique,
    required this.kind,
    this.temporary = false,
    this.predicateSql,
    this.ddl,
  });

  final String name;
  final String table;
  final List<String> columns;
  final bool unique;
  final String kind;
  final bool temporary;
  final String? predicateSql;
  final String? ddl;

  factory IndexSummary.fromMap(Map<String, Object?> map) {
    return IndexSummary(
      name: map['name']! as String,
      table: map['table']! as String,
      columns: ((map['columns'] as List?) ?? const <Object?>[]).cast<String>(),
      unique: map['unique']! as bool,
      kind: map['kind']! as String,
      temporary: map['temporary'] as bool? ?? false,
      predicateSql: map['predicateSql'] as String?,
      ddl: map['ddl'] as String?,
    );
  }
}

class TriggerSummary {
  const TriggerSummary({
    required this.name,
    required this.targetName,
    required this.targetKind,
    required this.timing,
    required this.events,
    required this.eventsMask,
    required this.forEachRow,
    required this.temporary,
    required this.actionSql,
    required this.ddl,
  });

  final String name;
  final String targetName;
  final String targetKind;
  final String timing;
  final List<String> events;
  final int eventsMask;
  final bool forEachRow;
  final bool temporary;
  final String actionSql;
  final String ddl;

  factory TriggerSummary.fromMap(Map<String, Object?> map) {
    return TriggerSummary(
      name: map['name']! as String,
      targetName: map['targetName']! as String,
      targetKind: map['targetKind']! as String,
      timing: map['timing']! as String,
      events: ((map['events'] as List?) ?? const <Object?>[]).cast<String>(),
      eventsMask: map['eventsMask'] as int? ?? 0,
      forEachRow: map['forEachRow'] as bool? ?? true,
      temporary: map['temporary'] as bool? ?? false,
      actionSql: map['actionSql']! as String,
      ddl: map['ddl']! as String,
    );
  }
}

class SchemaSnapshot {
  const SchemaSnapshot({
    required this.objects,
    required this.indexes,
    this.triggers = const <TriggerSummary>[],
    required this.loadedAt,
  });

  final List<SchemaObjectSummary> objects;
  final List<IndexSummary> indexes;
  final List<TriggerSummary> triggers;
  final DateTime loadedAt;

  factory SchemaSnapshot.empty() {
    return SchemaSnapshot(
      objects: const <SchemaObjectSummary>[],
      indexes: const <IndexSummary>[],
      triggers: const <TriggerSummary>[],
      loadedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory SchemaSnapshot.fromMap(Map<String, Object?> map) {
    return SchemaSnapshot(
      objects: ((map['objects'] as List?) ?? const <Object?>[])
          .cast<Map<Object?, Object?>>()
          .map(
            (item) => SchemaObjectSummary.fromMap(
              item.map((key, value) => MapEntry(key as String, value)),
            ),
          )
          .toList(),
      indexes: ((map['indexes'] as List?) ?? const <Object?>[])
          .cast<Map<Object?, Object?>>()
          .map(
            (item) => IndexSummary.fromMap(
              item.map((key, value) => MapEntry(key as String, value)),
            ),
          )
          .toList(),
      triggers: ((map['triggers'] as List?) ?? const <Object?>[])
          .cast<Map<Object?, Object?>>()
          .map(
            (item) => TriggerSummary.fromMap(
              item.map((key, value) => MapEntry(key as String, value)),
            ),
          )
          .toList(),
      loadedAt: DateTime.parse(map['loadedAt']! as String),
    );
  }

  List<SchemaObjectSummary> get tables =>
      objects.where((item) => item.kind == SchemaObjectKind.table).toList();

  List<SchemaObjectSummary> get views =>
      objects.where((item) => item.kind == SchemaObjectKind.view).toList();

  SchemaObjectSummary? objectNamed(String name) {
    for (final object in objects) {
      if (object.name == name) {
        return object;
      }
    }
    return null;
  }

  List<IndexSummary> indexesForObject(String objectName) {
    return indexes.where((index) => index.table == objectName).toList();
  }

  List<TriggerSummary> triggersForObject(String objectName) {
    return triggers
        .where((trigger) => trigger.targetName == objectName)
        .toList();
  }

  TriggerSummary? triggerNamed(String targetName, String triggerName) {
    for (final trigger in triggers) {
      if (trigger.targetName == targetName && trigger.name == triggerName) {
        return trigger;
      }
    }
    return null;
  }
}

class ToolingCapabilities {
  const ToolingCapabilities({
    required this.queryContractVersion,
    required this.queryDescribe,
    required this.deterministicJson,
  });

  final int queryContractVersion;
  final bool queryDescribe;
  final bool deterministicJson;

  factory ToolingCapabilities.fromMap(Map<String, Object?> map) {
    return ToolingCapabilities(
      queryContractVersion: _asInt(map['query_contract_version']) ?? 0,
      queryDescribe: map['query_describe'] as bool? ?? false,
      deterministicJson: map['deterministic_json'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'query_contract_version': queryContractVersion,
      'query_describe': queryDescribe,
      'deterministic_json': deterministicJson,
    };
  }
}

class ToolingSpatialTypeInfo {
  const ToolingSpatialTypeInfo({
    required this.subtype,
    required this.dimensions,
    required this.srid,
  });

  final String subtype;
  final String dimensions;
  final int srid;

  String get summaryLabel {
    final parts = <String>[
      if (subtype.trim().isNotEmpty) subtype.trim(),
      if (dimensions.trim().isNotEmpty) dimensions.trim(),
      if (srid != 0) 'SRID $srid',
    ];
    return parts.isEmpty ? 'spatial metadata unavailable' : parts.join(' ');
  }

  factory ToolingSpatialTypeInfo.fromMap(Map<String, Object?> map) {
    return ToolingSpatialTypeInfo(
      subtype: map['subtype'] as String? ?? '',
      dimensions: map['dimensions'] as String? ?? '',
      srid: _asInt(map['srid']) ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'subtype': subtype,
      'dimensions': dimensions,
      'srid': srid,
    };
  }
}

class ToolingTypeInfo {
  const ToolingTypeInfo({
    required this.typeName,
    required this.valueKind,
    required this.cValueTag,
    this.spatial,
  });

  final String typeName;
  final String valueKind;
  final int cValueTag;
  final ToolingSpatialTypeInfo? spatial;

  NativeTypeDescriptor get nativeTypeDescriptor => describeNativeType(
    typeName: typeName,
    valueKind: valueKind,
    spatial: spatial,
  );

  factory ToolingTypeInfo.fromMap(Map<String, Object?> map) {
    final spatialMap = _asStringMap(map['spatial']);
    return ToolingTypeInfo(
      typeName: map['type_name'] as String? ?? '',
      valueKind: map['value_kind'] as String? ?? '',
      cValueTag: _asInt(map['c_value_tag']) ?? 0,
      spatial: spatialMap == null
          ? null
          : ToolingSpatialTypeInfo.fromMap(spatialMap),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'type_name': typeName,
      'value_kind': valueKind,
      'c_value_tag': cValueTag,
      'spatial': spatial?.toJson(),
    };
  }
}

class ToolingColumnTypeMetadata {
  const ToolingColumnTypeMetadata({
    required this.tableName,
    required this.columnName,
    required this.columnType,
    required this.typeInfo,
  });

  final String tableName;
  final String columnName;
  final String columnType;
  final ToolingTypeInfo typeInfo;

  NativeTypeDescriptor get nativeTypeDescriptor {
    final type = columnType.trim().isNotEmpty ? columnType : typeInfo.typeName;
    return describeNativeType(
      typeName: type,
      valueKind: typeInfo.valueKind,
      spatial: typeInfo.spatial,
    );
  }

  factory ToolingColumnTypeMetadata.fromMap(Map<String, Object?> map) {
    return ToolingColumnTypeMetadata(
      tableName: map['table_name'] as String? ?? '',
      columnName: map['column_name'] as String? ?? '',
      columnType: map['column_type'] as String? ?? '',
      typeInfo: ToolingTypeInfo.fromMap(
        _asStringMap(map['type_info']) ?? const <String, Object?>{},
      ),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'table_name': tableName,
      'column_name': columnName,
      'column_type': columnType,
      'type_info': typeInfo.toJson(),
    };
  }
}

class ToolingMetadata {
  const ToolingMetadata({
    required this.metadataVersion,
    required this.engineVersion,
    required this.databaseFormatVersion,
    required this.schemaCookie,
    required this.tempSchemaCookie,
    required this.schemaFingerprint,
    required this.schemaFingerprintAlgorithm,
    required this.columnTypeMetadata,
    required this.capabilities,
  });

  final int metadataVersion;
  final String engineVersion;
  final int databaseFormatVersion;
  final int schemaCookie;
  final int tempSchemaCookie;
  final String schemaFingerprint;
  final String schemaFingerprintAlgorithm;
  final List<ToolingColumnTypeMetadata> columnTypeMetadata;
  final ToolingCapabilities capabilities;

  factory ToolingMetadata.fromMap(Map<String, Object?> map) {
    final columns =
        _asMapList(
          map['column_type_metadata'],
        ).map(ToolingColumnTypeMetadata.fromMap).toList()..sort((left, right) {
          final byTable = left.tableName.compareTo(right.tableName);
          return byTable != 0
              ? byTable
              : left.columnName.compareTo(right.columnName);
        });
    return ToolingMetadata(
      metadataVersion: _asInt(map['metadata_version']) ?? 0,
      engineVersion: map['engine_version'] as String? ?? '',
      databaseFormatVersion: _asInt(map['database_format_version']) ?? 0,
      schemaCookie: _asInt(map['schema_cookie']) ?? 0,
      tempSchemaCookie: _asInt(map['temp_schema_cookie']) ?? 0,
      schemaFingerprint: map['schema_fingerprint'] as String? ?? '',
      schemaFingerprintAlgorithm:
          map['schema_fingerprint_algorithm'] as String? ?? '',
      columnTypeMetadata: columns,
      capabilities: ToolingCapabilities.fromMap(
        _asStringMap(map['capabilities']) ?? const <String, Object?>{},
      ),
    );
  }

  ToolingColumnTypeMetadata? columnTypeFor({
    required String tableName,
    required String columnName,
  }) {
    for (final column in columnTypeMetadata) {
      if (column.tableName == tableName && column.columnName == columnName) {
        return column;
      }
    }
    return null;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'metadata_version': metadataVersion,
      'engine_version': engineVersion,
      'database_format_version': databaseFormatVersion,
      'schema_cookie': schemaCookie,
      'temp_schema_cookie': tempSchemaCookie,
      'schema_fingerprint': schemaFingerprint,
      'schema_fingerprint_algorithm': schemaFingerprintAlgorithm,
      'column_type_metadata': <Map<String, Object?>>[
        for (final column in columnTypeMetadata) column.toJson(),
      ],
      'capabilities': capabilities.toJson(),
    };
  }
}

class QueryParameterContract {
  const QueryParameterContract({
    required this.position,
    required this.name,
    this.typeName,
    this.nullable,
    required this.source,
    this.sourceTable,
    this.sourceColumn,
    required this.diagnostics,
  });

  final int position;
  final String name;
  final String? typeName;
  final bool? nullable;
  final String source;
  final String? sourceTable;
  final String? sourceColumn;
  final List<String> diagnostics;

  factory QueryParameterContract.fromMap(Map<String, Object?> map) {
    return QueryParameterContract(
      position: _asInt(map['position']) ?? 0,
      name: map['name'] as String? ?? '',
      typeName: map['type_name'] as String?,
      nullable: map['nullable'] as bool?,
      source: map['source'] as String? ?? 'unknown',
      sourceTable: map['source_table'] as String?,
      sourceColumn: map['source_column'] as String?,
      diagnostics: _asStringList(map['diagnostics']),
    );
  }

  String get displayType =>
      typeName?.trim().isNotEmpty == true ? typeName!.trim() : 'UNKNOWN';

  NativeTypeDescriptor get nativeTypeDescriptor =>
      describeNativeType(typeName: typeName);

  String get sourceLabel {
    if (sourceTable != null && sourceColumn != null) {
      return '$sourceTable.$sourceColumn';
    }
    if (sourceColumn != null) {
      return sourceColumn!;
    }
    return source;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'position': position,
      'name': name,
      'type_name': typeName,
      'nullable': nullable,
      'source': source,
      'source_table': sourceTable,
      'source_column': sourceColumn,
      'diagnostics': diagnostics,
    };
  }
}

class QueryResultColumnContract {
  const QueryResultColumnContract({
    required this.ordinal,
    required this.name,
    this.typeName,
    this.nullable,
    required this.source,
    this.sourceTable,
    this.sourceColumn,
    this.expressionSql,
    required this.diagnostics,
  });

  final int ordinal;
  final String name;
  final String? typeName;
  final bool? nullable;
  final String source;
  final String? sourceTable;
  final String? sourceColumn;
  final String? expressionSql;
  final List<String> diagnostics;

  factory QueryResultColumnContract.fromMap(Map<String, Object?> map) {
    return QueryResultColumnContract(
      ordinal: _asInt(map['ordinal']) ?? 0,
      name: map['name'] as String? ?? '',
      typeName: map['type_name'] as String?,
      nullable: map['nullable'] as bool?,
      source: map['source'] as String? ?? 'unknown',
      sourceTable: map['source_table'] as String?,
      sourceColumn: map['source_column'] as String?,
      expressionSql: map['expression_sql'] as String?,
      diagnostics: _asStringList(map['diagnostics']),
    );
  }

  String get displayType =>
      typeName?.trim().isNotEmpty == true ? typeName!.trim() : 'UNKNOWN';

  NativeTypeDescriptor get nativeTypeDescriptor =>
      describeNativeType(typeName: typeName);

  String get nullabilityLabel {
    return switch (nullable) {
      true => 'nullable',
      false => 'not null',
      null => 'nullability unknown',
    };
  }

  String get sourceLabel {
    if (sourceTable != null && sourceColumn != null) {
      return '$sourceTable.$sourceColumn';
    }
    if (sourceColumn != null) {
      return sourceColumn!;
    }
    return source;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'ordinal': ordinal,
      'name': name,
      'type_name': typeName,
      'nullable': nullable,
      'source': source,
      'source_table': sourceTable,
      'source_column': sourceColumn,
      'expression_sql': expressionSql,
      'diagnostics': diagnostics,
    };
  }
}

class QueryContract {
  const QueryContract({
    required this.contractVersion,
    required this.sql,
    required this.statementKind,
    required this.readOnly,
    required this.schemaCookie,
    required this.tempSchemaCookie,
    required this.schemaFingerprint,
    required this.parameters,
    required this.resultColumns,
    required this.diagnostics,
  });

  final int contractVersion;
  final String sql;
  final String statementKind;
  final bool readOnly;
  final int schemaCookie;
  final int tempSchemaCookie;
  final String schemaFingerprint;
  final List<QueryParameterContract> parameters;
  final List<QueryResultColumnContract> resultColumns;
  final List<String> diagnostics;

  factory QueryContract.fromMap(Map<String, Object?> map) {
    final parameters =
        _asMapList(
            map['parameters'],
          ).map(QueryParameterContract.fromMap).toList()
          ..sort((left, right) => left.position.compareTo(right.position));
    final resultColumns =
        _asMapList(
            map['result_columns'],
          ).map(QueryResultColumnContract.fromMap).toList()
          ..sort((left, right) => left.ordinal.compareTo(right.ordinal));
    return QueryContract(
      contractVersion: _asInt(map['contract_version']) ?? 0,
      sql: map['sql'] as String? ?? '',
      statementKind: map['statement_kind'] as String? ?? 'unknown',
      readOnly: map['read_only'] as bool? ?? false,
      schemaCookie: _asInt(map['schema_cookie']) ?? 0,
      tempSchemaCookie: _asInt(map['temp_schema_cookie']) ?? 0,
      schemaFingerprint: map['schema_fingerprint'] as String? ?? '',
      parameters: parameters,
      resultColumns: resultColumns,
      diagnostics: _asStringList(map['diagnostics']),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'contract_version': contractVersion,
      'sql': sql,
      'statement_kind': statementKind,
      'read_only': readOnly,
      'schema_cookie': schemaCookie,
      'temp_schema_cookie': tempSchemaCookie,
      'schema_fingerprint': schemaFingerprint,
      'parameters': <Map<String, Object?>>[
        for (final parameter in parameters) parameter.toJson(),
      ],
      'result_columns': <Map<String, Object?>>[
        for (final column in resultColumns) column.toJson(),
      ],
      'diagnostics': diagnostics,
    };
  }
}

class QueryResultPage {
  const QueryResultPage({
    required this.cursorId,
    required this.columns,
    required this.rows,
    required this.done,
    required this.rowsAffected,
    required this.elapsed,
  });

  final String? cursorId;
  final List<String> columns;
  final List<Map<String, Object?>> rows;
  final bool done;
  final int? rowsAffected;
  final Duration elapsed;

  factory QueryResultPage.fromMap(Map<String, Object?> map) {
    return QueryResultPage(
      cursorId: map['cursorId'] as String?,
      columns: ((map['columns'] as List?) ?? const <Object?>[]).cast<String>(),
      rows: ((map['rows'] as List?) ?? const <Object?>[])
          .cast<Map<Object?, Object?>>()
          .map(
            (row) => row.map(
              (key, value) => MapEntry(key as String, _decodeCell(value)),
            ),
          )
          .toList(),
      done: map['done']! as bool,
      rowsAffected: map['rowsAffected'] as int?,
      elapsed: Duration(microseconds: map['elapsedMicros']! as int),
    );
  }

  static Object? _decodeCell(Object? value) {
    if (value is Map && value['kind'] == 'decimal') {
      final unscaled = value['unscaled'] as int;
      final scale = value['scale'] as int;
      return formatDecimalValue(unscaled, scale);
    }
    if (value is Map && value['kind'] == 'native_enum') {
      return NativeEnumCellValue(
        typeId: _asInt(value['typeId']) ?? 0,
        labelId: _asInt(value['labelId']) ?? 0,
      );
    }
    if (value is Map && value['kind'] == 'native_interval') {
      return NativeIntervalCellValue(
        months: _asInt(value['months']) ?? 0,
        days: _asInt(value['days']) ?? 0,
        microseconds: _asInt(value['microseconds']) ?? 0,
      );
    }
    if (value is Map && value['kind'] == 'duration') {
      return Duration(microseconds: _asInt(value['microseconds']) ?? 0);
    }
    if (value is Map && value['kind'] == 'blob') {
      return base64Decode(value['base64']! as String);
    }
    if (value is Map && value['kind'] == 'datetime') {
      return DateTime.parse(value['iso8601']! as String);
    }
    return value;
  }
}

class CsvExportResult {
  const CsvExportResult({required this.rowCount, required this.path});

  final int rowCount;
  final String path;

  factory CsvExportResult.fromMap(Map<String, Object?> map) {
    return CsvExportResult(
      rowCount: map['rowCount']! as int,
      path: map['path']! as String,
    );
  }
}

class JsonExportResult {
  const JsonExportResult({required this.rowCount, required this.path});

  final int rowCount;
  final String path;

  factory JsonExportResult.fromMap(Map<String, Object?> map) {
    return JsonExportResult(
      rowCount: map['rowCount']! as int,
      path: map['path']! as String,
    );
  }
}

class ExcelExportResult {
  const ExcelExportResult({required this.rowCount, required this.path});

  final int rowCount;
  final String path;

  factory ExcelExportResult.fromMap(Map<String, Object?> map) {
    return ExcelExportResult(
      rowCount: map['rowCount']! as int,
      path: map['path']! as String,
    );
  }
}

class QueryMessageEntry {
  const QueryMessageEntry({
    required this.level,
    required this.message,
    required this.timestamp,
  });

  final QueryMessageLevel level;
  final String message;
  final DateTime timestamp;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'level': level.name,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory QueryMessageEntry.fromJson(Map<String, Object?> map) {
    return QueryMessageEntry(
      level: switch (map['level'] as String? ?? 'info') {
        'warning' => QueryMessageLevel.warning,
        'error' => QueryMessageLevel.error,
        _ => QueryMessageLevel.info,
      },
      message: map['message'] as String? ?? '',
      timestamp: DateTime.parse(
        map['timestamp'] as String? ??
            DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
      ),
    );
  }
}

class QueryHistoryEntry {
  const QueryHistoryEntry({
    required this.sql,
    required this.parameterJson,
    required this.ranAt,
    required this.outcome,
    required this.elapsed,
    required this.rowsLoaded,
    required this.rowsAffected,
    this.errorMessage,
  });

  final String sql;
  final String parameterJson;
  final DateTime ranAt;
  final QueryHistoryOutcome outcome;
  final Duration elapsed;
  final int? rowsLoaded;
  final int? rowsAffected;
  final String? errorMessage;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'sql': sql,
      'parameterJson': parameterJson,
      'ranAt': ranAt.toIso8601String(),
      'outcome': outcome.name,
      'elapsedMs': elapsed.inMilliseconds,
      'rowsLoaded': rowsLoaded,
      'rowsAffected': rowsAffected,
      'errorMessage': errorMessage,
    };
  }

  factory QueryHistoryEntry.fromJson(Map<String, Object?> map) {
    return QueryHistoryEntry(
      sql: map['sql']! as String,
      parameterJson: map['parameterJson'] as String? ?? '',
      ranAt: DateTime.parse(map['ranAt']! as String),
      outcome: switch (map['outcome'] as String? ?? 'completed') {
        'failed' => QueryHistoryOutcome.failed,
        'cancelled' => QueryHistoryOutcome.cancelled,
        _ => QueryHistoryOutcome.completed,
      },
      elapsed: Duration(milliseconds: map['elapsedMs'] as int? ?? 0),
      rowsLoaded: map['rowsLoaded'] as int?,
      rowsAffected: map['rowsAffected'] as int?,
      errorMessage: map['errorMessage'] as String?,
    );
  }
}

class QueryExecutionPlanState {
  const QueryExecutionPlanState({
    required this.columns,
    required this.rows,
    required this.isLoading,
    this.errorMessage,
  });

  const QueryExecutionPlanState.idle()
    : columns = const <String>[],
      rows = const <Map<String, Object?>>[],
      isLoading = false,
      errorMessage = null;

  const QueryExecutionPlanState.loading()
    : columns = const <String>[],
      rows = const <Map<String, Object?>>[],
      isLoading = true,
      errorMessage = null;

  final List<String> columns;
  final List<Map<String, Object?>> rows;
  final bool isLoading;
  final String? errorMessage;

  bool get hasData => columns.isNotEmpty || rows.isNotEmpty;

  QueryExecutionPlanState copyWith({
    List<String>? columns,
    List<Map<String, Object?>>? rows,
    bool? isLoading,
    Object? errorMessage = QueryTabState._unset,
  }) {
    return QueryExecutionPlanState(
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == QueryTabState._unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class QueryTabState {
  const QueryTabState({
    required this.id,
    required this.title,
    required this.sql,
    required this.parameterJson,
    required this.exportPath,
    required this.phase,
    required this.resultColumns,
    required this.resultRows,
    required this.cursorId,
    required this.error,
    required this.statusMessage,
    required this.lastSql,
    required this.lastParameterJson,
    required this.lastParams,
    required this.lastRunStartedAt,
    required this.rowsAffected,
    required this.elapsed,
    required this.hasMoreRows,
    required this.isExporting,
    required this.isResultPartial,
    required this.executionGeneration,
    required this.executionPlan,
    required this.queryContract,
    required this.messageHistory,
    required this.queryHistory,
  });

  static const Object _unset = Object();

  final String id;
  final String title;
  final String sql;
  final String parameterJson;
  final String exportPath;
  final QueryPhase phase;
  final List<String> resultColumns;
  final List<Map<String, Object?>> resultRows;
  final String? cursorId;
  final QueryErrorDetails? error;
  final String? statusMessage;
  final String? lastSql;
  final String? lastParameterJson;
  final List<Object?> lastParams;
  final DateTime? lastRunStartedAt;
  final int? rowsAffected;
  final Duration? elapsed;
  final bool hasMoreRows;
  final bool isExporting;
  final bool isResultPartial;
  final int executionGeneration;
  final QueryExecutionPlanState executionPlan;
  final QueryContract? queryContract;
  final List<QueryMessageEntry> messageHistory;
  final List<QueryHistoryEntry> queryHistory;

  factory QueryTabState.initial({
    required String id,
    required String title,
    String sql = 'SELECT 1 AS ready;',
    String parameterJson = '',
    String exportPath = '',
  }) {
    return QueryTabState(
      id: id,
      title: title,
      sql: sql,
      parameterJson: parameterJson,
      exportPath: exportPath,
      phase: QueryPhase.idle,
      resultColumns: const <String>[],
      resultRows: const <Map<String, Object?>>[],
      cursorId: null,
      error: null,
      statusMessage: null,
      lastSql: null,
      lastParameterJson: null,
      lastParams: const <Object?>[],
      lastRunStartedAt: null,
      rowsAffected: null,
      elapsed: null,
      hasMoreRows: false,
      isExporting: false,
      isResultPartial: false,
      executionGeneration: 0,
      executionPlan: const QueryExecutionPlanState.idle(),
      queryContract: null,
      messageHistory: const <QueryMessageEntry>[],
      queryHistory: const <QueryHistoryEntry>[],
    );
  }

  bool get canCancel =>
      phase == QueryPhase.opening ||
      phase == QueryPhase.running ||
      phase == QueryPhase.fetching ||
      phase == QueryPhase.cancelling;

  bool get canExport =>
      lastSql != null && resultColumns.isNotEmpty && !isExporting;

  bool get hasResultData => resultColumns.isNotEmpty || rowsAffected != null;

  List<QueryParameterContract> get parameterContracts =>
      queryContract?.parameters ?? const <QueryParameterContract>[];

  List<QueryResultColumnContract> get resultColumnContracts =>
      queryContract?.resultColumns ?? const <QueryResultColumnContract>[];

  QueryResultColumnContract? resultContractForColumn(String columnName) {
    for (final column in resultColumnContracts) {
      if (column.name == columnName) {
        return column;
      }
    }
    final ordinal = resultColumns.indexOf(columnName);
    if (ordinal < 0) {
      return null;
    }
    for (final column in resultColumnContracts) {
      if (column.ordinal == ordinal) {
        return column;
      }
    }
    return null;
  }

  QueryTabState copyWith({
    String? id,
    String? title,
    String? sql,
    String? parameterJson,
    String? exportPath,
    QueryPhase? phase,
    List<String>? resultColumns,
    List<Map<String, Object?>>? resultRows,
    Object? cursorId = _unset,
    Object? error = _unset,
    Object? statusMessage = _unset,
    Object? lastSql = _unset,
    Object? lastParameterJson = _unset,
    List<Object?>? lastParams,
    Object? lastRunStartedAt = _unset,
    Object? rowsAffected = _unset,
    Object? elapsed = _unset,
    bool? hasMoreRows,
    bool? isExporting,
    bool? isResultPartial,
    int? executionGeneration,
    QueryExecutionPlanState? executionPlan,
    Object? queryContract = _unset,
    List<QueryMessageEntry>? messageHistory,
    List<QueryHistoryEntry>? queryHistory,
  }) {
    return QueryTabState(
      id: id ?? this.id,
      title: title ?? this.title,
      sql: sql ?? this.sql,
      parameterJson: parameterJson ?? this.parameterJson,
      exportPath: exportPath ?? this.exportPath,
      phase: phase ?? this.phase,
      resultColumns: resultColumns ?? this.resultColumns,
      resultRows: resultRows ?? this.resultRows,
      cursorId: cursorId == _unset ? this.cursorId : cursorId as String?,
      error: error == _unset ? this.error : error as QueryErrorDetails?,
      statusMessage: statusMessage == _unset
          ? this.statusMessage
          : statusMessage as String?,
      lastSql: lastSql == _unset ? this.lastSql : lastSql as String?,
      lastParameterJson: lastParameterJson == _unset
          ? this.lastParameterJson
          : lastParameterJson as String?,
      lastParams: lastParams ?? this.lastParams,
      lastRunStartedAt: lastRunStartedAt == _unset
          ? this.lastRunStartedAt
          : lastRunStartedAt as DateTime?,
      rowsAffected: rowsAffected == _unset
          ? this.rowsAffected
          : rowsAffected as int?,
      elapsed: elapsed == _unset ? this.elapsed : elapsed as Duration?,
      hasMoreRows: hasMoreRows ?? this.hasMoreRows,
      isExporting: isExporting ?? this.isExporting,
      isResultPartial: isResultPartial ?? this.isResultPartial,
      executionGeneration: executionGeneration ?? this.executionGeneration,
      executionPlan: executionPlan ?? this.executionPlan,
      queryContract: queryContract == _unset
          ? this.queryContract
          : queryContract as QueryContract?,
      messageHistory: messageHistory ?? this.messageHistory,
      queryHistory: queryHistory ?? this.queryHistory,
    );
  }
}

String formatCellValue(Object? value) {
  return formatTypedCellValue(value);
}

String formatTypedCellValue(Object? value, {String? typeName}) {
  if (value == null) {
    return 'NULL';
  }
  final descriptor = describeNativeType(typeName: typeName);
  if (value is NativeEnumCellValue) {
    return value.displayString(descriptor: descriptor);
  }
  if (value is NativeIntervalCellValue) {
    return value.displayString();
  }
  if (value is Duration) {
    return descriptor.baseTypeName == 'TIME'
        ? _formatTimeMicros(value.inMicroseconds)
        : '${value.inMicroseconds}us';
  }
  if (value is DateTime) {
    if (descriptor.baseTypeName == 'DATE') {
      final utc = value.toUtc();
      return '${utc.year.toString().padLeft(4, "0")}-'
          '${utc.month.toString().padLeft(2, "0")}-'
          '${utc.day.toString().padLeft(2, "0")}';
    }
    return value.toIso8601String();
  }
  if (value is Uint8List) {
    if (descriptor.isSpatial) {
      final type = descriptor.baseTypeName.isEmpty
          ? 'SPATIAL'
          : descriptor.baseTypeName;
      return '$type EWKB (${value.length} bytes)';
    }
    if (descriptor.baseTypeName == 'UUID' && value.length == 16) {
      return _formatUuidBytes(value);
    }
    return base64Encode(value);
  }
  return '$value';
}

String formatSpatialWkbBase64(Object? value) {
  return value is Uint8List ? base64Encode(value) : formatCellValue(value);
}

String formatDecimalValue(int unscaled, int scale) {
  if (scale == 0) {
    return '$unscaled';
  }

  final negative = unscaled < 0;
  final digits = unscaled.abs().toString().padLeft(scale + 1, '0');
  final split = digits.length - scale;
  final whole = digits.substring(0, split);
  final fraction = digits.substring(split);
  return '${negative ? "-" : ""}$whole.$fraction';
}

String _baseTypeName(String typeName) {
  final trimmed = typeName.trim().toUpperCase();
  if (trimmed.isEmpty) {
    return '';
  }
  final match = RegExp(r'^[A-Z][A-Z0-9_]*').firstMatch(trimmed);
  return match?.group(0) ?? trimmed;
}

NativeTypeFamily _nativeTypeFamily(String baseType, {String? valueKind}) {
  final kind = valueKind?.trim().toLowerCase() ?? '';
  if (kind.contains('geometry') || kind.contains('geography')) {
    return NativeTypeFamily.spatial;
  }
  return switch (baseType) {
    'INT' ||
    'INTEGER' ||
    'INT64' ||
    'BIGINT' ||
    'FLOAT' ||
    'FLOAT64' ||
    'DOUBLE' ||
    'REAL' ||
    'DECIMAL' => NativeTypeFamily.numeric,
    'BOOL' || 'BOOLEAN' => NativeTypeFamily.boolean,
    'TEXT' || 'VARCHAR' || 'CHAR' || 'STRING' => NativeTypeFamily.text,
    'BLOB' || 'BYTES' => NativeTypeFamily.binary,
    'UUID' => NativeTypeFamily.uuid,
    'ENUM' => NativeTypeFamily.enumValue,
    'DATE' ||
    'TIME' ||
    'TIMESTAMP' ||
    'TIMESTAMPTZ' ||
    'INTERVAL' => NativeTypeFamily.temporal,
    'IPADDR' || 'INET' || 'CIDR' => NativeTypeFamily.network,
    'MACADDR' || 'MACADDR8' => NativeTypeFamily.macAddress,
    'GEOMETRY' || 'GEOGRAPHY' => NativeTypeFamily.spatial,
    _ => NativeTypeFamily.unknown,
  };
}

List<String> _parseEnumLabels(String typeName) {
  final open = typeName.indexOf('(');
  final close = typeName.lastIndexOf(')');
  if (open < 0 || close <= open) {
    return const <String>[];
  }
  final labels = <String>[];
  final text = typeName.substring(open + 1, close);
  var index = 0;
  while (index < text.length) {
    while (index < text.length &&
        (text[index].trim().isEmpty || text[index] == ',')) {
      index++;
    }
    if (index >= text.length || text[index] != "'") {
      break;
    }
    index++;
    final label = StringBuffer();
    while (index < text.length) {
      final char = text[index];
      if (char == "'") {
        if (index + 1 < text.length && text[index + 1] == "'") {
          label.write("'");
          index += 2;
          continue;
        }
        index++;
        break;
      }
      label.write(char);
      index++;
    }
    labels.add(label.toString());
    while (index < text.length && text[index] != ',') {
      index++;
    }
  }
  return labels;
}

String _formatTimeMicros(int microseconds) {
  final negative = microseconds < 0;
  final absolute = microseconds.abs();
  final hours = absolute ~/ Duration.microsecondsPerHour;
  final minutes =
      (absolute % Duration.microsecondsPerHour) ~/
      Duration.microsecondsPerMinute;
  final seconds =
      (absolute % Duration.microsecondsPerMinute) ~/
      Duration.microsecondsPerSecond;
  final micros = absolute % Duration.microsecondsPerSecond;
  final base =
      '${hours.toString().padLeft(2, "0")}:'
      '${minutes.toString().padLeft(2, "0")}:'
      '${seconds.toString().padLeft(2, "0")}';
  final suffix = micros == 0 ? '' : '.${micros.toString().padLeft(6, "0")}';
  return '${negative ? "-" : ""}$base$suffix';
}

String _formatUuidBytes(Uint8List bytes) {
  final hex = <String>[
    for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
  ].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

Map<String, Object?>? _asStringMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map<Object?, Object?>) {
    return value.map((key, value) => MapEntry(key as String, value));
  }
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries) '${entry.key}': entry.value,
    };
  }
  return null;
}

List<Map<String, Object?>> _asMapList(Object? value) {
  if (value is! List) {
    return const <Map<String, Object?>>[];
  }
  final maps = <Map<String, Object?>>[];
  for (final item in value) {
    final map = _asStringMap(item);
    if (map != null) {
      maps.add(map);
    }
  }
  return maps;
}

List<String> _asStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return <String>[
    for (final item in value)
      if (item != null) '$item',
  ];
}
