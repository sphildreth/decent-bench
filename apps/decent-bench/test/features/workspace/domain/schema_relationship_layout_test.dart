import 'package:decent_bench/features/workspace/domain/schema_relationship_graph.dart';
import 'package:decent_bench/features/workspace/domain/schema_relationship_layout.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SchemaColumn column(
    String name, {
    bool primaryKey = false,
    String? refTable,
    String? refColumn,
  }) {
    return SchemaColumn(
      name: name,
      type: 'INTEGER',
      notNull: primaryKey,
      unique: primaryKey,
      primaryKey: primaryKey,
      refTable: refTable,
      refColumn: refColumn,
      refOnDelete: null,
      refOnUpdate: null,
    );
  }

  SchemaObjectSummary table(
    String name, {
    List<SchemaColumn> columns = const <SchemaColumn>[],
  }) {
    return SchemaObjectSummary(
      name: name,
      kind: SchemaObjectKind.table,
      columns: columns,
    );
  }

  SchemaRelationshipGraph graph(List<SchemaObjectSummary> tables) {
    return SchemaRelationshipGraph.fromSnapshot(
      SchemaSnapshot(
        objects: tables,
        indexes: const <IndexSummary>[],
        loadedAt: DateTime(2026, 5, 19),
      ),
    );
  }

  String layoutSignature(SchemaRelationshipLayout layout) {
    final nodes = layout.nodes
        .map(
          (node) =>
              '${node.tableName}:${node.bounds.left},${node.bounds.top},${node.bounds.width},${node.bounds.height}',
        )
        .join('|');
    final edges = layout.edges
        .map(
          (edge) =>
              '${edge.edgeId}:${edge.points.map((p) => '${p.x},${p.y}').join(';')}',
        )
        .join('|');
    return '$nodes#$edges#${layout.canvasBounds.width},${layout.canvasBounds.height}';
  }

  test('layout is deterministic for the same graph', () {
    final source = graph(<SchemaObjectSummary>[
      table(
        'orders',
        columns: <SchemaColumn>[
          column('id', primaryKey: true),
          column('customer_id', refTable: 'customers', refColumn: 'id'),
        ],
      ),
      table('customers', columns: <SchemaColumn>[column('id')]),
      table('audit_log', columns: <SchemaColumn>[column('id')]),
    ]);

    final first = SchemaRelationshipLayout.compute(source);
    final second = SchemaRelationshipLayout.compute(source);

    expect(layoutSignature(first), layoutSignature(second));
  });

  test('parent child ranking is stable', () {
    final source = graph(<SchemaObjectSummary>[
      table(
        'orders',
        columns: <SchemaColumn>[
          column('id'),
          column('customer_id', refTable: 'customers', refColumn: 'id'),
        ],
      ),
      table('customers', columns: <SchemaColumn>[column('id')]),
    ]);

    final layout = SchemaRelationshipLayout.compute(source);
    final parent = layout.nodeLayoutForTable('customers')!;
    final child = layout.nodeLayoutForTable('orders')!;

    expect(parent.bounds.left, lessThan(child.bounds.left));
  });

  test('isolated tables are packed consistently', () {
    final source = graph(<SchemaObjectSummary>[
      table('zeta'),
      table('alpha'),
      table('middle'),
    ]);

    final layout = SchemaRelationshipLayout.compute(source);

    expect(layout.nodes.map((node) => node.tableName), <String>[
      'alpha',
      'middle',
      'zeta',
    ]);
    expect(layout.edges, isEmpty);
  });

  test('cycle components do not crash layout', () {
    final source = graph(<SchemaObjectSummary>[
      table(
        'a',
        columns: <SchemaColumn>[
          column('id'),
          column('b_id', refTable: 'b', refColumn: 'id'),
        ],
      ),
      table(
        'b',
        columns: <SchemaColumn>[
          column('id'),
          column('a_id', refTable: 'a', refColumn: 'id'),
        ],
      ),
    ]);

    final layout = SchemaRelationshipLayout.compute(source);

    expect(layout.nodes, hasLength(2));
    expect(layout.edges, hasLength(2));
  });

  test('self foreign key routes are present', () {
    final source = graph(<SchemaObjectSummary>[
      table(
        'categories',
        columns: <SchemaColumn>[
          column('id'),
          column('parent_id', refTable: 'categories', refColumn: 'id'),
        ],
      ),
    ]);

    final layout = SchemaRelationshipLayout.compute(source);

    expect(layout.edges.single.isSelfReference, isTrue);
    expect(layout.edges.single.points.length, greaterThan(2));
  });

  test('missing reference placeholder nodes receive bounds', () {
    final source = graph(<SchemaObjectSummary>[
      table(
        'orders',
        columns: <SchemaColumn>[
          column('id'),
          column('customer_id', refTable: 'customers', refColumn: 'id'),
        ],
      ),
    ]);

    final layout = SchemaRelationshipLayout.compute(source);

    expect(layout.nodeLayoutForTable('customers'), isNotNull);
    expect(
      layout.nodeLayoutForTable('customers')!.bounds.width,
      greaterThan(0),
    );
    expect(layout.edges.single.hasMissingParent, isTrue);
  });

  test('selected table neighborhood keeps directly connected neighbors', () {
    final source = graph(<SchemaObjectSummary>[
      table(
        'orders',
        columns: <SchemaColumn>[
          column('id'),
          column('customer_id', refTable: 'customers', refColumn: 'id'),
        ],
      ),
      table('customers'),
      table('audit_log'),
    ]);

    final layout = SchemaRelationshipLayout.compute(
      source,
      options: const SchemaRelationshipLayoutOptions(
        mode: SchemaRelationshipLayoutMode.selectedTableNeighborhood,
        selectedTableName: 'orders',
      ),
    );

    expect(layout.visibleTableNames, <String>{'customers', 'orders'});
  });

  test('canvas bounds include all nodes and routed edges', () {
    final source = graph(<SchemaObjectSummary>[
      table(
        'categories',
        columns: <SchemaColumn>[
          column('id'),
          column('parent_id', refTable: 'categories', refColumn: 'id'),
        ],
      ),
    ]);

    final layout = SchemaRelationshipLayout.compute(source);

    for (final node in layout.nodes) {
      expect(
        layout.canvasBounds.right,
        greaterThanOrEqualTo(node.bounds.right),
      );
      expect(
        layout.canvasBounds.bottom,
        greaterThanOrEqualTo(node.bounds.bottom),
      );
    }
    for (final edge in layout.edges) {
      for (final point in edge.points) {
        expect(layout.canvasBounds.right, greaterThanOrEqualTo(point.x));
        expect(layout.canvasBounds.bottom, greaterThanOrEqualTo(point.y));
      }
    }
  });
}
