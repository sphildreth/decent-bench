import 'package:decent_bench/features/workspace/domain/schema_relationship_export.dart';
import 'package:decent_bench/features/workspace/domain/schema_relationship_graph.dart';
import 'package:decent_bench/features/workspace/domain/schema_relationship_layout.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test(
    'export title includes database label, table count, and relationship count',
    () {
      expect(
        schemaRelationshipExportTitle(
          databaseLabel: 'sample.decentdb',
          tableCount: 2,
          relationshipCount: 1,
        ),
        'sample.decentdb - ERD - 2 tables, 1 relationship',
      );
    },
  );

  test('2x and 3x export requests calculate expected output dimensions', () {
    const bounds = SchemaRelationshipRect(
      left: 0,
      top: 0,
      width: 320,
      height: 180,
    );
    const planner = SchemaRelationshipExportPlanner();

    final twoX = planner.plan(logicalBounds: bounds, requestedScale: 2);
    final threeX = planner.plan(logicalBounds: bounds, requestedScale: 3);

    expect(twoX.outputWidth, 640);
    expect(twoX.outputHeight, 360);
    expect(threeX.outputWidth, 960);
    expect(threeX.outputHeight, 540);
  });

  test(
    'oversized export requests are downscaled or rejected before allocation',
    () {
      const planner = SchemaRelationshipExportPlanner();
      const large = SchemaRelationshipRect(
        left: 0,
        top: 0,
        width: 5000,
        height: 3000,
      );
      const tooLarge = SchemaRelationshipRect(
        left: 0,
        top: 0,
        width: 10000,
        height: 9000,
      );

      final downscaled = planner.plan(logicalBounds: large, requestedScale: 3);
      final rejected = planner.plan(logicalBounds: tooLarge, requestedScale: 1);

      expect(downscaled.rejected, isFalse);
      expect(downscaled.downscaled, isTrue);
      expect(downscaled.outputWidth, lessThanOrEqualTo(8192));
      expect(rejected.rejected, isTrue);
    },
  );

  test('PNG export produces non-empty bytes', () async {
    final source = graph(<SchemaObjectSummary>[
      table('users', columns: <SchemaColumn>[column('id', primaryKey: true)]),
      table(
        'invoices',
        columns: <SchemaColumn>[
          column('id', primaryKey: true),
          column('user_id', refTable: 'users', refColumn: 'id'),
        ],
      ),
    ]);
    final layout = SchemaRelationshipLayout.compute(source);

    final rendered = await const SchemaRelationshipExportRenderer().render(
      graph: source,
      layout: layout,
      options: const SchemaRelationshipExportOptions(requestedScale: 1),
      title: schemaRelationshipExportTitle(
        databaseLabel: 'sample.decentdb',
        tableCount: source.nodes.length,
        relationshipCount: source.edges.length,
      ),
    );

    expect(rendered.bytes, isNotEmpty);
    expect(rendered.bytes.take(8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
  });

  test('JPG export produces non-empty bytes on a solid background', () async {
    final source = graph(<SchemaObjectSummary>[
      table('users', columns: <SchemaColumn>[column('id', primaryKey: true)]),
    ]);
    final layout = SchemaRelationshipLayout.compute(source);

    final rendered = await const SchemaRelationshipExportRenderer().render(
      graph: source,
      layout: layout,
      options: const SchemaRelationshipExportOptions(
        format: SchemaRelationshipImageFormat.jpeg,
        requestedScale: 1,
      ),
      title: schemaRelationshipExportTitle(
        databaseLabel: 'sample.decentdb',
        tableCount: source.nodes.length,
        relationshipCount: source.edges.length,
      ),
    );

    expect(rendered.bytes, isNotEmpty);
    expect(rendered.bytes[0], 0xff);
    expect(rendered.bytes[1], 0xd8);
  });

  test(
    'full diagram export includes offscreen nodes compared with viewport',
    () {
      final source = graph(<SchemaObjectSummary>[
        table('users', columns: <SchemaColumn>[column('id')]),
        table(
          'invoices',
          columns: <SchemaColumn>[
            column('id'),
            column('user_id', refTable: 'users', refColumn: 'id'),
          ],
        ),
        table('isolated', columns: <SchemaColumn>[column('id')]),
      ]);
      final layout = SchemaRelationshipLayout.compute(source);
      const planner = SchemaRelationshipExportPlanner();
      final full = planner.plan(
        logicalBounds: layout.canvasBounds,
        requestedScale: 1,
      );
      final viewport = planner.plan(
        logicalBounds: const SchemaRelationshipRect(
          left: 0,
          top: 0,
          width: 120,
          height: 90,
        ),
        requestedScale: 1,
      );

      expect(full.outputWidth, greaterThan(viewport.outputWidth));
      expect(full.outputHeight, greaterThan(viewport.outputHeight));
    },
  );

  test('viewport export honors viewport bounds', () {
    const planner = SchemaRelationshipExportPlanner();
    final plan = planner.plan(
      logicalBounds: const SchemaRelationshipRect(
        left: 120,
        top: 80,
        width: 300,
        height: 200,
      ),
      requestedScale: 2,
    );

    expect(plan.outputWidth, 600);
    expect(plan.outputHeight, 400);
  });

  test(
    'missing reference placeholders are included in rendered images',
    () async {
      final source = graph(<SchemaObjectSummary>[
        table(
          'invoices',
          columns: <SchemaColumn>[
            column('id'),
            column('user_id', refTable: 'users', refColumn: 'id'),
          ],
        ),
      ]);
      final layout = SchemaRelationshipLayout.compute(source);

      expect(source.nodes.any((node) => node.isPlaceholder), isTrue);
      final rendered = await const SchemaRelationshipExportRenderer().render(
        graph: source,
        layout: layout,
        options: const SchemaRelationshipExportOptions(requestedScale: 1),
        title: schemaRelationshipExportTitle(
          databaseLabel: 'sample.decentdb',
          tableCount: source.nodes.length,
          relationshipCount: source.edges.length,
        ),
      );

      expect(rendered.bytes, isNotEmpty);
    },
  );
}
