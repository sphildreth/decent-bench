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
}
