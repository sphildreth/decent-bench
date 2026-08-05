import 'package:decent_bench/features/workspace/domain/explain_plan_visualization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses query_plan rows into scannable plan nodes', () {
    final visualization = buildExplainPlanVisualization(const <
      Map<String, Object?>
    >[
      <String, Object?>{
        'query_plan': 'SCAN tasks USING COVERING INDEX idx_tasks_title',
      },
      <String, Object?>{
        'query_plan':
            '  SEARCH projects USING INDEX idx_projects_name rows=12 actual rows=3',
      },
    ], 'query_plan');

    expect(visualization.rawText, contains('SCAN tasks'));
    expect(visualization.nodes, hasLength(2));
    expect(visualization.nodes.first.operation, 'SCAN');
    expect(visualization.nodes.first.tableName, 'tasks');
    expect(visualization.nodes.first.indexName, 'idx_tasks_title');
    expect(visualization.nodes.last.operation, 'SEARCH');
    expect(visualization.nodes.last.depth, 1);
    expect(visualization.nodes.last.tableName, 'projects');
    expect(visualization.nodes.last.indexName, 'idx_projects_name');
    expect(visualization.nodes.last.estimatedRows, 12);
    expect(visualization.nodes.last.actualRows, 3);
  });

  test('splits multiline raw explain text', () {
    final visualization = buildExplainPlanVisualization(
      const <Map<String, Object?>>[
        <String, Object?>{
          'query_plan': 'SCAN tasks\n  FILTER title IS NOT NULL',
        },
      ],
      'query_plan',
    );

    expect(visualization.nodes, hasLength(2));
    expect(visualization.nodes.last.operation, 'FILTER');
    expect(visualization.rawText, 'SCAN tasks\n  FILTER title IS NOT NULL');
  });

  test('recognizes multi-word operators added in v2.15-v2.17', () {
    final visualization = buildExplainPlanVisualization(
      const <Map<String, Object?>>[
        <String, Object?>{
          'query_plan':
              'HASH JOIN orders ON orders.id = line_items.order_id rows=1234 cost=18.5\n'
                  '  INDEXED JOIN line_items USING INDEX idx_line_items_order_id rows=8 cost=2.0\n'
                  '  STREAMING AGGREGATE rows=8 cost=2.5\n'
                  '  VIEW SCAN recent_orders rows=200 cost=4.1\n'
                  '  EXPANDED VIEW recent_orders_expanded rows=200 cost=4.5',
        },
      ],
      'query_plan',
    );

    final ops = visualization.nodes.map((n) => n.operation).toList();
    expect(ops, <String>[
      'HASH JOIN',
      'INDEXED JOIN',
      'STREAMING AGGREGATE',
      'VIEW SCAN',
      'EXPANDED VIEW',
    ]);
    expect(visualization.nodes.first.estimatedRows, 1234);
    expect(visualization.nodes.first.estimatedCost, closeTo(18.5, 0.001));
    expect(visualization.nodes[1].indexName, 'idx_line_items_order_id');
    expect(visualization.nodes[3].tableName, 'recent_orders');
  });

  test('parser tolerates unknown operator kinds by returning the raw token',
      () {
    final visualization = buildExplainPlanVisualization(
      const <Map<String, Object?>>[
        <String, Object?>{
          'query_plan': 'FUTURE_OPERATOR some_table rows=42',
        },
      ],
      'query_plan',
    );
    expect(visualization.nodes.single.operation, 'FUTURE_OPERATOR');
    expect(visualization.nodes.single.estimatedRows, 42);
  });
}
