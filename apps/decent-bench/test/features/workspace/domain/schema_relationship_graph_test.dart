import 'package:decent_bench/features/workspace/domain/schema_relationship_graph.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SchemaColumn column(
    String name, {
    String? refTable,
    String? refColumn,
    String? refOnDelete,
    String? refOnUpdate,
  }) {
    return SchemaColumn(
      name: name,
      type: 'INTEGER',
      notNull: false,
      unique: false,
      primaryKey: false,
      refTable: refTable,
      refColumn: refColumn,
      refOnDelete: refOnDelete,
      refOnUpdate: refOnUpdate,
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

  SchemaObjectSummary view(
    String name, {
    List<SchemaColumn> columns = const <SchemaColumn>[],
  }) {
    return SchemaObjectSummary(
      name: name,
      kind: SchemaObjectKind.view,
      columns: columns,
    );
  }

  SchemaSnapshot snapshot(
    List<SchemaObjectSummary> objects, {
    DateTime? loadedAt,
  }) {
    return SchemaSnapshot(
      objects: objects,
      indexes: const <IndexSummary>[],
      loadedAt: loadedAt ?? DateTime(2026, 5, 19),
    );
  }

  String graphSignature(SchemaRelationshipGraph graph) {
    final nodePart = graph.nodes
        .map(
          (node) =>
              '${node.tableName}:${node.isPlaceholder}:${node.columns.length}',
        )
        .join('|');
    final edgePart = graph.edges
        .map(
          (edge) =>
              '${edge.constraintId}:${edge.childTable}->${edge.parentTable}:'
              '${edge.isSelfReference}:${edge.isMissingReference}:'
              '${edge.columnPairs.map((pair) => '${pair.childColumn}>${pair.parentColumn}:${pair.refOnDelete ?? ""}:${pair.refOnUpdate ?? ""}').join(",")}',
        )
        .join('|');
    final warningPart = graph.warnings.join('|');
    return '$nodePart#$edgePart#$warningPart';
  }

  test('empty schema returns an empty graph', () {
    final graph = SchemaRelationshipGraph.fromSnapshot(SchemaSnapshot.empty());

    expect(graph.nodes, isEmpty);
    expect(graph.edges, isEmpty);
    expect(graph.warnings, isEmpty);
  });

  test('tables with no foreign keys return isolated nodes and no edges', () {
    final graph = SchemaRelationshipGraph.fromSnapshot(
      snapshot(<SchemaObjectSummary>[
        table(
          'projects',
          columns: <SchemaColumn>[column('id'), column('name')],
        ),
        table('users', columns: <SchemaColumn>[column('id'), column('email')]),
      ]),
    );

    expect(graph.nodes.map((node) => node.tableName), <String>[
      'projects',
      'users',
    ]);
    expect(graph.nodes.every((node) => node.isPlaceholder), isFalse);
    expect(graph.edges, isEmpty);
    expect(graph.warnings, isEmpty);
  });

  test('views are excluded from the graph', () {
    final graph = SchemaRelationshipGraph.fromSnapshot(
      snapshot(<SchemaObjectSummary>[
        table('users', columns: <SchemaColumn>[column('id'), column('email')]),
        view(
          'active_users',
          columns: <SchemaColumn>[column('id'), column('email')],
        ),
      ]),
    );

    expect(graph.nodes.map((node) => node.tableName), <String>['users']);
    expect(graph.edges, isEmpty);
    expect(graph.warnings, isEmpty);
  });

  test('single-column foreign key creates one edge', () {
    final graph = SchemaRelationshipGraph.fromSnapshot(
      snapshot(<SchemaObjectSummary>[
        table(
          'posts',
          columns: <SchemaColumn>[
            column('id'),
            column('author_id', refTable: 'users', refColumn: 'id'),
          ],
        ),
        table('users', columns: <SchemaColumn>[column('id'), column('name')]),
      ]),
    );

    expect(graph.nodes.map((node) => node.tableName), <String>[
      'posts',
      'users',
    ]);
    expect(graph.edges, hasLength(1));
    final edge = graph.edges.single;
    expect(edge.childTable, 'posts');
    expect(edge.parentTable, 'users');
    expect(edge.constraintId, startsWith('synthetic:posts->users:'));
    expect(edge.constraintName, isNull);
    expect(edge.isSelfReference, isFalse);
    expect(edge.isMissingReference, isFalse);
    expect(edge.columnPairs, hasLength(1));
    expect(edge.columnPairs.single.childColumn, 'author_id');
    expect(edge.columnPairs.single.parentColumn, 'id');
  });

  test(
    'multiple foreign keys between different table pairs create distinct edges',
    () {
      final graph = SchemaRelationshipGraph.fromSnapshot(
        snapshot(<SchemaObjectSummary>[
          table(
            'comments',
            columns: <SchemaColumn>[
              column('id'),
              column('post_id', refTable: 'posts', refColumn: 'id'),
            ],
          ),
          table(
            'posts',
            columns: <SchemaColumn>[
              column('id'),
              column('author_id', refTable: 'users', refColumn: 'id'),
            ],
          ),
          table('users', columns: <SchemaColumn>[column('id'), column('name')]),
        ]),
      );

      expect(graph.edges, hasLength(2));
      expect(
        graph.edges.map((edge) => '${edge.childTable}->${edge.parentTable}'),
        <String>['comments->posts', 'posts->users'],
      );
    },
  );

  test('same child parent and actions merge into one deterministic edge', () {
    final graph = SchemaRelationshipGraph.fromSnapshot(
      snapshot(<SchemaObjectSummary>[
        table(
          'line_items',
          columns: <SchemaColumn>[
            column('id'),
            column(
              'order_id',
              refTable: 'orders',
              refColumn: 'id',
              refOnDelete: 'CASCADE',
              refOnUpdate: 'RESTRICT',
            ),
            column(
              'order_number',
              refTable: 'orders',
              refColumn: 'order_number',
              refOnDelete: 'CASCADE',
              refOnUpdate: 'RESTRICT',
            ),
          ],
        ),
        table(
          'orders',
          columns: <SchemaColumn>[column('id'), column('order_number')],
        ),
      ]),
    );

    expect(graph.edges, hasLength(1));
    final edge = graph.edges.single;
    expect(edge.constraintName, isNull);
    expect(edge.columnPairs, hasLength(2));
    expect(edge.columnPairs.map((pair) => pair.childColumn), <String>[
      'order_id',
      'order_number',
    ]);
    expect(
      edge.columnPairs.every((pair) => pair.refOnDelete == 'CASCADE'),
      isTrue,
    );
    expect(
      edge.columnPairs.every((pair) => pair.refOnUpdate == 'RESTRICT'),
      isTrue,
    );
  });

  test('same child parent with different actions creates separate edges', () {
    final graph = SchemaRelationshipGraph.fromSnapshot(
      snapshot(<SchemaObjectSummary>[
        table(
          'line_items',
          columns: <SchemaColumn>[
            column('id'),
            column(
              'primary_order_id',
              refTable: 'orders',
              refColumn: 'id',
              refOnDelete: 'CASCADE',
              refOnUpdate: 'CASCADE',
            ),
            column(
              'backup_order_id',
              refTable: 'orders',
              refColumn: 'id',
              refOnDelete: 'RESTRICT',
              refOnUpdate: 'RESTRICT',
            ),
          ],
        ),
        table('orders', columns: <SchemaColumn>[column('id')]),
      ]),
    );

    expect(graph.edges, hasLength(2));
    expect(
      graph.edges.map((edge) => edge.columnPairs.single.childColumn),
      <String>['primary_order_id', 'backup_order_id'],
    );
    expect(graph.edges[0].columnPairs.single.refOnDelete, 'CASCADE');
    expect(graph.edges[1].columnPairs.single.refOnDelete, 'RESTRICT');
  });

  test('self foreign key is marked as a self reference', () {
    final graph = SchemaRelationshipGraph.fromSnapshot(
      snapshot(<SchemaObjectSummary>[
        table(
          'categories',
          columns: <SchemaColumn>[
            column('id'),
            column('parent_id', refTable: 'categories', refColumn: 'id'),
          ],
        ),
      ]),
    );

    expect(graph.edges, hasLength(1));
    expect(graph.edges.single.isSelfReference, isTrue);
    expect(graph.edges.single.isMissingReference, isFalse);
  });

  test(
    'missing parent table creates a placeholder node and marks the edge missing',
    () {
      final graph = SchemaRelationshipGraph.fromSnapshot(
        snapshot(<SchemaObjectSummary>[
          table(
            'posts',
            columns: <SchemaColumn>[
              column('id'),
              column('author_id', refTable: 'users', refColumn: 'id'),
            ],
          ),
        ]),
      );

      expect(
        graph.nodes.map((node) => '${node.tableName}:${node.isPlaceholder}'),
        <String>['posts:false', 'users:true'],
      );
      expect(
        graph.nodes.singleWhere((node) => node.tableName == 'users').columns,
        isEmpty,
      );
      expect(graph.edges.single.isMissingReference, isTrue);
      expect(graph.warnings, <String>[
        'Referenced table "users" is missing from SchemaSnapshot.tables.',
      ]);
    },
  );

  test('cyclic foreign keys remain representable without recursion errors', () {
    final graph = SchemaRelationshipGraph.fromSnapshot(
      snapshot(<SchemaObjectSummary>[
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
      ]),
    );

    expect(graph.nodes.map((node) => node.tableName), <String>['a', 'b']);
    expect(graph.edges, hasLength(2));
    expect(
      graph.edges.map((edge) => '${edge.childTable}->${edge.parentTable}'),
      <String>['a->b', 'b->a'],
    );
  });

  test('output ordering is stable across repeated graph builds', () {
    final source = snapshot(<SchemaObjectSummary>[
      table(
        'orders',
        columns: <SchemaColumn>[
          column('id'),
          column(
            'customer_id',
            refTable: 'customers',
            refColumn: 'id',
            refOnDelete: 'CASCADE',
            refOnUpdate: 'CASCADE',
          ),
        ],
      ),
      table(
        'line_items',
        columns: <SchemaColumn>[
          column('id'),
          column(
            'order_id',
            refTable: 'orders',
            refColumn: 'id',
            refOnDelete: 'CASCADE',
            refOnUpdate: 'CASCADE',
          ),
          column('missing_parent_id', refTable: 'zeta', refColumn: 'id'),
          column(
            'another_missing_parent_id',
            refTable: 'alpha',
            refColumn: 'id',
          ),
        ],
      ),
      table('customers', columns: <SchemaColumn>[column('id')]),
      view('order_view', columns: <SchemaColumn>[column('id')]),
    ]);

    final first = SchemaRelationshipGraph.fromSnapshot(source);
    final second = SchemaRelationshipGraph.fromSnapshot(source);

    expect(graphSignature(first), graphSignature(second));
    expect(first.warnings, <String>[
      'Referenced table "alpha" is missing from SchemaSnapshot.tables.',
      'Referenced table "zeta" is missing from SchemaSnapshot.tables.',
    ]);
  });
}
