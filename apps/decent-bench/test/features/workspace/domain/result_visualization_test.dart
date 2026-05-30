import 'package:decent_bench/features/workspace/domain/result_visualization.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('infers categorical x columns and numeric y columns', () {
    final columns = inferVisualizationColumns(
      columns: const <String>['region', 'total', 'count'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{'region': 'North', 'total': 12.5, 'count': 3},
        <String, Object?>{'region': 'South', 'total': 7.5, 'count': 2},
      ],
    );

    expect(columns.xColumns, contains('region'));
    expect(columns.yColumns, <String>['total', 'count']);
  });

  test('builds bounded chart points from loaded rows', () {
    final model = buildResultVisualizationModel(
      chartType: ResultChartType.line,
      xColumn: 'region',
      yColumn: 'total',
      maxRows: 2,
      rows: const <Map<String, Object?>>[
        <String, Object?>{'region': 'North', 'total': 12.5},
        <String, Object?>{'region': 'South', 'total': '7.5'},
        <String, Object?>{'region': 'West', 'total': 1},
      ],
    );

    expect(model.chartType, ResultChartType.line);
    expect(model.points, hasLength(2));
    expect(model.points.first.xLabel, 'North');
    expect(model.points.last.y, 7.5);
    expect(model.loadedRows, 3);
    expect(model.truncated, isTrue);
  });

  test('uses result contracts to identify numeric series', () {
    final tab = QueryTabState.initial(id: 'tab', title: 'Query').copyWith(
      queryContract: const QueryContract(
        contractVersion: 1,
        sql: 'SELECT total FROM sales',
        statementKind: 'query',
        readOnly: true,
        schemaCookie: 1,
        tempSchemaCookie: 0,
        schemaFingerprint: 'fingerprint',
        parameters: <QueryParameterContract>[],
        resultColumns: <QueryResultColumnContract>[
          QueryResultColumnContract(
            ordinal: 0,
            name: 'label',
            typeName: 'TEXT',
            nullable: false,
            source: 'expression',
            diagnostics: <String>[],
          ),
          QueryResultColumnContract(
            ordinal: 1,
            name: 'total',
            typeName: 'DECIMAL',
            nullable: false,
            source: 'expression',
            diagnostics: <String>[],
          ),
        ],
        diagnostics: <String>[],
      ),
    );

    final columns = inferVisualizationColumns(
      columns: const <String>['label', 'total'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{'label': 'A', 'total': '12.25'},
      ],
      tab: tab,
    );

    expect(columns.yColumns, <String>['total']);
  });
}
