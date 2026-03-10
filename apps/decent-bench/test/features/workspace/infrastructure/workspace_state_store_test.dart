import 'dart:io';

import 'package:decent_bench/features/workspace/domain/workspace_state.dart';
import 'package:decent_bench/features/workspace/infrastructure/workspace_state_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'workspace state store round-trips tab drafts by database path',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'workspace-state-store-',
      );
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });

      final store = FileWorkspaceStateStore(rootOverride: root);
      const state = PersistedWorkspaceState(
        schemaVersion: PersistedWorkspaceState.currentSchemaVersion,
        activeTabId: 'query-tab-2',
        tabs: <WorkspaceTabDraft>[
          WorkspaceTabDraft(
            id: 'query-tab-1',
            title: 'Query 1',
            sql: 'SELECT 1;',
            parameterJson: '',
            exportPath: '/tmp/query-1.csv',
          ),
          WorkspaceTabDraft(
            id: 'query-tab-2',
            title: 'Query 2',
            sql: 'SELECT 2;',
            parameterJson: '[2]',
            exportPath: '/tmp/query-2.csv',
          ),
        ],
      );

      await store.save('/tmp/example.ddb', state);
      final restored = await store.load('/tmp/example.ddb');

      expect(restored?.activeTabId, 'query-tab-2');
      expect(restored?.tabs, hasLength(2));
      expect(restored?.tabs.last.sql, 'SELECT 2;');

      await store.clear('/tmp/example.ddb');
      expect(await store.load('/tmp/example.ddb'), isNull);
    },
  );
}
