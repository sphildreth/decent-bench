import 'dart:io';

import 'package:decent_bench/features/workspace/application/data_quality_controller.dart';
import 'package:decent_bench/features/workspace/domain/data_quality_models.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:decent_bench/features/workspace/infrastructure/data_quality_repository.dart';
import 'package:decent_bench/features/workspace/infrastructure/data_quality_runner.dart';
import 'package:decent_bench/features/workspace/presentation/quality/violation_browser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';

void main() {
  late Directory tempDir;
  late _PagedViolationGateway gateway;
  late DataQualityController controller;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('violation_browser_test_');
    gateway = _PagedViolationGateway();
    controller = DataQualityController(
      runner: DataQualityRunner(gateway: gateway),
      repository: DataQualityRepository(rootOverride: tempDir),
    );
    await controller.attachWorkspace(
      databasePath: '/tmp/workspace.ddb',
      schema: gateway.snapshot,
    );
  });

  tearDown(() async {
    controller.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets(
    'pages diagnostic SQL violations without exposing sample values',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 700,
              height: 520,
              child: ViolationBrowser(
                controller: controller,
                issue: _issue(detailStorePath: null),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('Required title'), findsOneWidget);
      expect(find.textContaining('2 failures'), findsOneWidget);
      expect(find.text('Copy diagnostic SQL'), findsOneWidget);
      expect(find.text('Copy issue summary'), findsOneWidget);
      expect(
        find.text('Values hidden by report privacy setting'),
        findsOneWidget,
      );
      expect(find.textContaining('rowid=1'), findsOneWidget);
      expect(find.text('Required value is missing.'), findsOneWidget);

      await tester.tap(find.byTooltip('Next page'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('No violation rows on this page.'), findsOneWidget);

      await tester.tap(find.byTooltip('Previous page'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('Page 1'), findsOneWidget);
      expect(find.textContaining('rowid=1'), findsOneWidget);
    },
  );
}

ValidationIssueSummary _issue({required String? detailStorePath}) {
  return ValidationIssueSummary(
    issueId: 'issue-1',
    ruleId: 'rule-1',
    ruleName: 'Required title',
    ruleType: ValidationRuleType.required.wireName,
    severity: QualitySeverity.error,
    targetTable: 'tasks',
    targetColumn: 'title',
    issueCode: 'required_value_missing',
    message: 'Required value is missing.',
    failureCount: 2,
    sampleViolationRows: const <ViolationRowReference>[
      ViolationRowReference(
        rowIdentity: <String, String>{'rowid': '1'},
        rowNumber: 1,
        valueDisplay: null,
        message: 'Required value is missing.',
      ),
    ],
    detailsAvailable: true,
    detailQuerySql: detailStorePath == null
        ? 'SELECT rowid AS row_number, title AS value_display FROM tasks'
        : null,
    detailStorePath: detailStorePath,
  );
}

class _PagedViolationGateway extends FakeWorkspaceGateway {
  @override
  Future<QueryResultPage> runQuery({
    required String sql,
    required List<Object?> params,
    required int pageSize,
  }) async {
    lastRunQuerySql = sql;
    lastRunQueryParams = <Object?>[...params];
    if (sql.contains('OFFSET 50')) {
      return _page(rows: const <Map<String, Object?>>[]);
    }
    return _page(
      rows: const <Map<String, Object?>>[
        <String, Object?>{
          'row_number': 1,
          'value_display': 'hidden by browser privacy',
        },
      ],
    );
  }

  QueryResultPage _page({required List<Map<String, Object?>> rows}) {
    return QueryResultPage(
      cursorId: null,
      columns: const <String>['row_number', 'value_display'],
      rows: rows,
      done: true,
      rowsAffected: null,
      elapsed: const Duration(milliseconds: 1),
    );
  }
}
