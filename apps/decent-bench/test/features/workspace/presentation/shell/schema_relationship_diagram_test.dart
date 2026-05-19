import 'package:decent_bench/app/theme.dart';
import 'package:decent_bench/app/theme_system/theme_presets.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:decent_bench/features/workspace/presentation/shell/schema_relationship_diagram.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SchemaColumn column(
    String name, {
    bool primaryKey = false,
    String type = 'INTEGER',
    String? refTable,
    String? refColumn,
  }) {
    return SchemaColumn(
      name: name,
      type: type,
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

  SchemaSnapshot schema(List<SchemaObjectSummary> objects) {
    return SchemaSnapshot(
      objects: objects,
      indexes: const <IndexSummary>[],
      loadedAt: DateTime(2026, 5, 19),
    );
  }

  Future<List<String>> pumpDiagram(
    WidgetTester tester, {
    required SchemaSnapshot schema,
    String? selectedTableName,
    Size size = const Size(720, 520),
  }) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDecentBenchTheme(buildEmergencyTheme()),
        home: Scaffold(
          body: SizedBox(
            width: size.width,
            height: size.height,
            child: SchemaRelationshipDiagram(
              schema: schema,
              databaseLabel: 'sample.decentdb',
              selectedTableName: selectedTableName,
              onSelectTable: (_) {},
              onOpenTable: (tableName) async {
                opened.add(tableName);
              },
              isLoading: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return opened;
  }

  testWidgets('empty graph renders an empty ERD state', (tester) async {
    await pumpDiagram(tester, schema: SchemaSnapshot.empty());

    expect(find.text('No tables'), findsOneWidget);
  });

  testWidgets('no relationship state still shows table nodes', (tester) async {
    await pumpDiagram(
      tester,
      schema: schema(<SchemaObjectSummary>[
        table('users', columns: <SchemaColumn>[column('id')]),
        table('products', columns: <SchemaColumn>[column('id')]),
      ]),
    );

    expect(
      find.text('No foreign-key relationships are exposed for this schema.'),
      findsOneWidget,
    );
    expect(find.text('users'), findsOneWidget);
    expect(find.text('products'), findsOneWidget);
  });

  testWidgets('missing parent placeholder appears', (tester) async {
    await pumpDiagram(
      tester,
      schema: schema(<SchemaObjectSummary>[
        table(
          'invoices',
          columns: <SchemaColumn>[
            column('id'),
            column('user_id', refTable: 'users', refColumn: 'id'),
          ],
        ),
      ]),
    );

    expect(find.text('invoices'), findsOneWidget);
    expect(find.text('users'), findsOneWidget);
  });

  testWidgets('search is case-insensitive', (tester) async {
    await pumpDiagram(
      tester,
      schema: schema(<SchemaObjectSummary>[
        table('Customers', columns: <SchemaColumn>[column('id')]),
        table('products', columns: <SchemaColumn>[column('id')]),
      ]),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('erd.search')),
      'cust',
    );
    await tester.pump();

    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('products'), findsNothing);
  });

  testWidgets('search keeps connected neighbor context visible', (
    tester,
  ) async {
    await pumpDiagram(
      tester,
      schema: schema(<SchemaObjectSummary>[
        table('users', columns: <SchemaColumn>[column('id')]),
        table(
          'invoices',
          columns: <SchemaColumn>[
            column('id'),
            column('user_id', refTable: 'users', refColumn: 'id'),
          ],
        ),
        table('products', columns: <SchemaColumn>[column('id')]),
      ]),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('erd.search')),
      'invoice',
    );
    await tester.pump();

    expect(find.text('invoices'), findsOneWidget);
    expect(find.text('users'), findsOneWidget);
    expect(find.text('products'), findsNothing);
  });

  testWidgets('hide isolated tables removes isolated nodes', (tester) async {
    await pumpDiagram(
      tester,
      schema: schema(<SchemaObjectSummary>[
        table('users', columns: <SchemaColumn>[column('id')]),
        table(
          'invoices',
          columns: <SchemaColumn>[
            column('id'),
            column('user_id', refTable: 'users', refColumn: 'id'),
          ],
        ),
        table('audit_log', columns: <SchemaColumn>[column('id')]),
      ]),
    );

    await tester.tap(find.text('Isolated'));
    await tester.pump();

    expect(find.text('audit_log'), findsNothing);
    expect(find.text('invoices'), findsOneWidget);
  });

  testWidgets('selected table neighborhood mode keeps adjacent nodes', (
    tester,
  ) async {
    await pumpDiagram(
      tester,
      selectedTableName: 'invoices',
      schema: schema(<SchemaObjectSummary>[
        table('users', columns: <SchemaColumn>[column('id')]),
        table(
          'invoices',
          columns: <SchemaColumn>[
            column('id'),
            column('user_id', refTable: 'users', refColumn: 'id'),
          ],
        ),
        table('audit_log', columns: <SchemaColumn>[column('id')]),
      ]),
    );

    await tester.tap(find.text('Neighbors'));
    await tester.pump();

    expect(find.text('invoices'), findsOneWidget);
    expect(find.text('users'), findsOneWidget);
    expect(find.text('audit_log'), findsNothing);
  });

  testWidgets('responsive density changes visible column count', (
    tester,
  ) async {
    final source = schema(<SchemaObjectSummary>[
      table(
        'invoices',
        columns: <SchemaColumn>[
          column('id', primaryKey: true),
          column('user_id', refTable: 'users', refColumn: 'id'),
          column('amount', type: 'DECIMAL'),
        ],
      ),
      table('users', columns: <SchemaColumn>[column('id')]),
    ]);

    await pumpDiagram(tester, schema: source, size: const Size(720, 520));
    expect(find.textContaining('amount'), findsOneWidget);

    await pumpDiagram(tester, schema: source, size: const Size(300, 520));
    expect(find.textContaining('amount'), findsNothing);
  });

  testWidgets('table nodes are focusable and Enter opens table preview', (
    tester,
  ) async {
    final opened = await pumpDiagram(
      tester,
      schema: schema(<SchemaObjectSummary>[
        table('invoices', columns: <SchemaColumn>[column('id')]),
      ]),
    );

    await tester.tap(find.byKey(const ValueKey<String>('erd.node.invoices')));
    await tester.pump(const Duration(milliseconds: 350));
    expect(FocusManager.instance.primaryFocus, isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(opened, <String>['invoices']);
  });
}
