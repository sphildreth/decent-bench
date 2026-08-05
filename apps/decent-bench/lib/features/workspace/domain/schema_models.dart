enum SchemaObjectKind { table, view }

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
    this.autoIncrement = false,
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
  final bool autoIncrement;
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
      autoIncrement: map['autoIncrement'] as bool? ?? false,
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

class SchemaForeignKey {
  const SchemaForeignKey({
    this.name,
    required this.columns,
    required this.referencedTable,
    required this.referencedColumns,
    this.onDelete,
    this.onUpdate,
  });

  final String? name;
  final List<String> columns;
  final String referencedTable;
  final List<String> referencedColumns;
  final String? onDelete;
  final String? onUpdate;

  factory SchemaForeignKey.fromMap(Map<String, Object?> map) {
    return SchemaForeignKey(
      name: map['name'] as String?,
      columns: ((map['columns'] as List?) ?? const <Object?>[]).cast<String>(),
      referencedTable: map['referencedTable']! as String,
      referencedColumns:
          ((map['referencedColumns'] as List?) ?? const <Object?>[]).cast<String>(),
      onDelete: map['onDelete'] as String?,
      onUpdate: map['onUpdate'] as String?,
    );
  }

  String get summary {
    final label = name == null || name!.isEmpty
        ? 'FK'
        : 'FK $name';
    final local = columns.join(', ');
    final referenced = referencedColumns.join(', ');
    final actions = <String>[
      if (onDelete != null && onDelete!.isNotEmpty) 'ON DELETE $onDelete',
      if (onUpdate != null && onUpdate!.isNotEmpty) 'ON UPDATE $onUpdate',
    ].join(' ');
    return '$label ($local) REFERENCES $referencedTable($referenced)'
        '${actions.isEmpty ? '' : ' $actions'}';
  }
}

class SchemaObjectSummary {
  const SchemaObjectSummary({
    required this.name,
    required this.kind,
    required this.columns,
    this.temporary = false,
    this.checks = const <SchemaCheckConstraint>[],
    this.ddl,
    this.rowCount,
    this.primaryKeyColumns = const <String>[],
    this.foreignKeys = const <SchemaForeignKey>[],
    this.sqlText,
    this.viewDependencies = const <String>[],
  });

  final String name;
  final SchemaObjectKind kind;
  final bool temporary;
  final String? ddl;
  final int? rowCount;
  final List<String> primaryKeyColumns;
  final List<SchemaForeignKey> foreignKeys;
  final List<SchemaColumn> columns;
  final List<SchemaCheckConstraint> checks;
  final String? sqlText;
  final List<String> viewDependencies;

  bool get isTable => kind == SchemaObjectKind.table;
  bool get isView => kind == SchemaObjectKind.view;

  factory SchemaObjectSummary.fromMap(Map<String, Object?> map) {
    final kind = (map['kind'] as String) == 'view'
        ? SchemaObjectKind.view
        : SchemaObjectKind.table;
    return SchemaObjectSummary(
      name: map['name']! as String,
      kind: kind,
      temporary: map['temporary'] as bool? ?? false,
      ddl: map['ddl'] as String?,
      rowCount: (map['rowCount'] as num?)?.toInt(),
      primaryKeyColumns:
          ((map['primaryKeyColumns'] as List?) ?? const <Object?>[]).cast<String>(),
      foreignKeys: ((map['foreignKeys'] as List?) ?? const <Object?>[])
          .cast<Map<Object?, Object?>>()
          .map(
            (foreignKey) => SchemaForeignKey.fromMap(
              foreignKey.map((key, value) => MapEntry(key as String, value)),
            ),
          )
          .toList(),
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
      sqlText: map['sqlText'] as String?,
      viewDependencies:
          ((map['viewDependencies'] as List?) ?? const <Object?>[]).cast<String>(),
    );
  }

  List<String> get exposedConstraintSummaries {
    return <String>[
      for (final column in columns)
        for (final constraint in column.constraintSummaries)
          '${column.name}: $constraint',
      for (final check in checks) check.summary,
      for (final foreignKey in foreignKeys) foreignKey.summary,
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
    this.includeColumns = const <String>[],
    this.fresh = true,
  });

  final String name;
  final String table;
  final List<String> columns;
  final List<String> includeColumns;
  final bool unique;
  final bool fresh;
  final String kind;
  final bool temporary;
  final String? predicateSql;
  final String? ddl;

  factory IndexSummary.fromMap(Map<String, Object?> map) {
    return IndexSummary(
      name: map['name']! as String,
      table: map['table']! as String,
      columns: ((map['columns'] as List?) ?? const <Object?>[]).cast<String>(),
      includeColumns:
          ((map['includeColumns'] as List?) ?? const <Object?>[]).cast<String>(),
      unique: map['unique']! as bool,
      kind: map['kind']! as String,
      temporary: map['temporary'] as bool? ?? false,
      predicateSql: map['predicateSql'] as String?,
      ddl: map['ddl'] as String?,
      fresh: map['fresh'] as bool? ?? true,
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
  SchemaSnapshot({
    required this.objects,
    required this.indexes,
    this.triggers = const <TriggerSummary>[],
    required this.loadedAt,
  })  : _tables = objects
            .where((item) => item.kind == SchemaObjectKind.table)
            .toList(),
        _views = objects
            .where((item) => item.kind == SchemaObjectKind.view)
            .toList(),
        _indexesByTable = _groupByTable(indexes),
        _triggersByTarget = _groupByTarget(triggers);

  final List<SchemaObjectSummary> objects;
  final List<IndexSummary> indexes;
  final List<TriggerSummary> triggers;
  final DateTime loadedAt;

  final List<SchemaObjectSummary> _tables;
  final List<SchemaObjectSummary> _views;
  final Map<String, List<IndexSummary>> _indexesByTable;
  final Map<String, List<TriggerSummary>> _triggersByTarget;

  List<SchemaObjectSummary> get tables => _tables;
  List<SchemaObjectSummary> get views => _views;

  static Map<String, List<IndexSummary>> _groupByTable(
    List<IndexSummary> indexes,
  ) {
    final result = <String, List<IndexSummary>>{};
    for (final index in indexes) {
      result.putIfAbsent(index.table, () => []).add(index);
    }
    return result;
  }

  static Map<String, List<TriggerSummary>> _groupByTarget(
    List<TriggerSummary> triggers,
  ) {
    final result = <String, List<TriggerSummary>>{};
    for (final trigger in triggers) {
      result.putIfAbsent(trigger.targetName, () => []).add(trigger);
    }
    return result;
  }

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

  SchemaObjectSummary? objectNamed(String name) {
    for (final object in objects) {
      if (object.name == name) {
        return object;
      }
    }
    return null;
  }

  List<IndexSummary> indexesForObject(String objectName) {
    return _indexesByTable[objectName] ?? const <IndexSummary>[];
  }

  List<TriggerSummary> triggersForObject(String objectName) {
    return _triggersByTarget[objectName] ?? const <TriggerSummary>[];
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
