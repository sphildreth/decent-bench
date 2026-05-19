import 'workspace_models.dart';

class SchemaRelationshipGraphOptions {
  const SchemaRelationshipGraphOptions();
}

class SchemaRelationshipGraph {
  const SchemaRelationshipGraph._({
    required this.nodes,
    required this.edges,
    required this.warnings,
  });

  final List<SchemaRelationshipNode> nodes;
  final List<SchemaRelationshipEdge> edges;
  final List<String> warnings;

  SchemaRelationshipNode? nodeByTable(String tableName) {
    for (final node in nodes) {
      if (node.tableName == tableName) {
        return node;
      }
    }
    return null;
  }

  Set<String> directlyConnectedTables(String tableName) {
    final connected = <String>{};
    for (final edge in edges) {
      if (edge.childTable == tableName) {
        connected.add(edge.parentTable);
      }
      if (edge.parentTable == tableName) {
        connected.add(edge.childTable);
      }
    }
    return connected;
  }

  factory SchemaRelationshipGraph.fromSnapshot(
    SchemaSnapshot snapshot, {
    SchemaRelationshipGraphOptions options =
        const SchemaRelationshipGraphOptions(),
  }) {
    final realTables = snapshot.tables.toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    final realNodes = <String, SchemaRelationshipNode>{
      for (final table in realTables)
        table.name: SchemaRelationshipNode(
          id: 'table:${table.name}',
          tableName: table.name,
          isPlaceholder: false,
          isTemporary: table.temporary,
          columns: List<SchemaColumn>.unmodifiable(table.columns),
        ),
    };

    final placeholderNodes = <String, SchemaRelationshipNode>{};
    final edgeGroups = <String, _SchemaRelationshipEdgeGroup>{};

    for (final table in realTables) {
      for (final column in table.columns) {
        final referencedTable = _normalizedName(column.refTable);
        final referencedColumn = _normalizedName(column.refColumn);
        if (referencedTable == null || referencedColumn == null) {
          continue;
        }

        final deleteAction = _normalizedAction(column.refOnDelete);
        final updateAction = _normalizedAction(column.refOnUpdate);
        // Synthetic grouping keeps same table-pair FK columns together until
        // upstream constraint identity is available in the schema snapshot.
        final groupKey = _edgeGroupKey(
          childTable: table.name,
          parentTable: referencedTable,
          deleteAction: deleteAction,
          updateAction: updateAction,
        );
        final group = edgeGroups.putIfAbsent(
          groupKey,
          () => _SchemaRelationshipEdgeGroup(
            childTable: table.name,
            parentTable: referencedTable,
            deleteAction: deleteAction,
            updateAction: updateAction,
          ),
        );

        group.addPair(
          SchemaRelationshipColumnPair(
            childColumn: column.name,
            parentColumn: referencedColumn,
            refOnDelete: deleteAction,
            refOnUpdate: updateAction,
          ),
        );

        if (!realNodes.containsKey(referencedTable)) {
          placeholderNodes.putIfAbsent(
            referencedTable,
            () => SchemaRelationshipNode(
              id: 'table:$referencedTable',
              tableName: referencedTable,
              isPlaceholder: true,
              isTemporary: false,
              columns: const <SchemaColumn>[],
            ),
          );
        }
      }
    }

    final nodes =
        <SchemaRelationshipNode>[
          ...realNodes.values,
          ...placeholderNodes.values,
        ]..sort((left, right) {
          final nameComparison = left.tableName.compareTo(right.tableName);
          if (nameComparison != 0) {
            return nameComparison;
          }
          if (left.isPlaceholder == right.isPlaceholder) {
            return 0;
          }
          return left.isPlaceholder ? 1 : -1;
        });

    final edges = edgeGroups.values.toList()..sort(_compareEdgeGroups);

    final warnings = <String>[
      for (final missingTable in placeholderNodes.keys.toList()..sort())
        'Referenced table "$missingTable" is missing from SchemaSnapshot.tables.',
    ];

    final relationshipEdges = <SchemaRelationshipEdge>[
      for (final group in edges) group.toEdge(realNodes.containsKey),
    ];
    final incidentTables = <String>{
      for (final edge in relationshipEdges) ...<String>[
        edge.childTable,
        edge.parentTable,
      ],
    };
    final annotatedNodes = <SchemaRelationshipNode>[
      for (final node in nodes)
        node.copyWith(isIsolated: !incidentTables.contains(node.tableName)),
    ];

    return SchemaRelationshipGraph._(
      nodes: List<SchemaRelationshipNode>.unmodifiable(annotatedNodes),
      edges: List<SchemaRelationshipEdge>.unmodifiable(relationshipEdges),
      warnings: List<String>.unmodifiable(warnings),
    );
  }
}

class SchemaRelationshipNode {
  const SchemaRelationshipNode({
    required this.id,
    required this.tableName,
    required this.isPlaceholder,
    required this.isTemporary,
    required this.columns,
    this.isIsolated = false,
  });

  final String id;
  final String tableName;
  final bool isPlaceholder;
  final bool isTemporary;
  final List<SchemaColumn> columns;
  final bool isIsolated;

  List<String> get primaryKeyColumns {
    return <String>[
      for (final column in columns)
        if (column.primaryKey) column.name,
    ];
  }

  List<String> get foreignKeyColumns {
    return <String>[
      for (final column in columns)
        if (column.hasForeignKey) column.name,
    ];
  }

  SchemaRelationshipNode copyWith({bool? isIsolated}) {
    return SchemaRelationshipNode(
      id: id,
      tableName: tableName,
      isPlaceholder: isPlaceholder,
      isTemporary: isTemporary,
      columns: columns,
      isIsolated: isIsolated ?? this.isIsolated,
    );
  }
}

class SchemaRelationshipEdge {
  const SchemaRelationshipEdge({
    required this.id,
    required this.constraintId,
    required this.constraintName,
    required this.childTable,
    required this.parentTable,
    required this.onDelete,
    required this.onUpdate,
    required this.isSelfReference,
    required this.isMissingReference,
    required this.columnPairs,
  });

  final String id;
  final String constraintId;
  final String? constraintName;
  final String childTable;
  final String parentTable;
  final String? onDelete;
  final String? onUpdate;
  final bool isSelfReference;
  final bool isMissingReference;
  final List<SchemaRelationshipColumnPair> columnPairs;

  bool get hasMissingParent => isMissingReference;
}

class SchemaRelationshipColumnPair {
  const SchemaRelationshipColumnPair({
    required this.childColumn,
    required this.parentColumn,
    String? refOnDelete,
    String? refOnUpdate,
    String? onDelete,
    String? onUpdate,
  }) : onDelete = onDelete ?? refOnDelete,
       onUpdate = onUpdate ?? refOnUpdate;

  final String childColumn;
  final String parentColumn;
  final String? onDelete;
  final String? onUpdate;

  String? get refOnDelete => onDelete;
  String? get refOnUpdate => onUpdate;
}

class _SchemaRelationshipEdgeGroup {
  _SchemaRelationshipEdgeGroup({
    required this.childTable,
    required this.parentTable,
    required this.deleteAction,
    required this.updateAction,
  });

  final String childTable;
  final String parentTable;
  final String? deleteAction;
  final String? updateAction;
  final Map<String, SchemaRelationshipColumnPair> _pairsBySignature =
      <String, SchemaRelationshipColumnPair>{};

  void addPair(SchemaRelationshipColumnPair pair) {
    _pairsBySignature.putIfAbsent(
      _pairSignature(
        childColumn: pair.childColumn,
        parentColumn: pair.parentColumn,
        deleteAction: pair.refOnDelete,
        updateAction: pair.refOnUpdate,
      ),
      () => pair,
    );
  }

  List<SchemaRelationshipColumnPair> get pairs {
    final pairs = _pairsBySignature.values.toList();
    pairs.sort((left, right) {
      final childComparison = left.childColumn.compareTo(right.childColumn);
      if (childComparison != 0) {
        return childComparison;
      }
      final parentComparison = left.parentColumn.compareTo(right.parentColumn);
      if (parentComparison != 0) {
        return parentComparison;
      }
      final deleteComparison = (left.refOnDelete ?? '').compareTo(
        right.refOnDelete ?? '',
      );
      if (deleteComparison != 0) {
        return deleteComparison;
      }
      return (left.refOnUpdate ?? '').compareTo(right.refOnUpdate ?? '');
    });
    return pairs;
  }

  SchemaRelationshipEdge toEdge(bool Function(String tableName) hasRealTable) {
    final id = _edgeConstraintId(
      childTable: childTable,
      parentTable: parentTable,
      deleteAction: deleteAction,
      updateAction: updateAction,
    );
    return SchemaRelationshipEdge(
      id: id,
      constraintId: id,
      constraintName: null,
      childTable: childTable,
      parentTable: parentTable,
      onDelete: _sharedAction(pairs.map((pair) => pair.onDelete)),
      onUpdate: _sharedAction(pairs.map((pair) => pair.onUpdate)),
      isSelfReference: childTable == parentTable,
      isMissingReference: !hasRealTable(parentTable),
      columnPairs: List<SchemaRelationshipColumnPair>.unmodifiable(pairs),
    );
  }
}

int _compareEdgeGroups(
  _SchemaRelationshipEdgeGroup left,
  _SchemaRelationshipEdgeGroup right,
) {
  final childComparison = left.childTable.compareTo(right.childTable);
  if (childComparison != 0) {
    return childComparison;
  }
  final parentComparison = left.parentTable.compareTo(right.parentTable);
  if (parentComparison != 0) {
    return parentComparison;
  }
  final deleteComparison = (left.deleteAction ?? '').compareTo(
    right.deleteAction ?? '',
  );
  if (deleteComparison != 0) {
    return deleteComparison;
  }
  return (left.updateAction ?? '').compareTo(right.updateAction ?? '');
}

String _edgeGroupKey({
  required String childTable,
  required String parentTable,
  required String? deleteAction,
  required String? updateAction,
}) {
  return <String>[
    childTable,
    parentTable,
    deleteAction ?? '',
    updateAction ?? '',
  ].join('\u0000');
}

String _edgeConstraintId({
  required String childTable,
  required String parentTable,
  required String? deleteAction,
  required String? updateAction,
}) {
  return 'synthetic:$childTable->$parentTable:${deleteAction ?? ''}:${updateAction ?? ''}';
}

String _pairSignature({
  required String childColumn,
  required String parentColumn,
  required String? deleteAction,
  required String? updateAction,
}) {
  return <String>[
    childColumn,
    parentColumn,
    deleteAction ?? '',
    updateAction ?? '',
  ].join('\u0000');
}

String? _normalizedName(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String? _normalizedAction(String? value) {
  return _normalizedName(value);
}

String? _sharedAction(Iterable<String?> actions) {
  String? shared;
  var initialized = false;
  for (final action in actions) {
    if (!initialized) {
      shared = action;
      initialized = true;
      continue;
    }
    if (shared != action) {
      return null;
    }
  }
  return shared;
}
