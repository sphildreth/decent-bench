import 'dart:io';

import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:decent_bench/features/workspace/domain/workspace_state.dart';
import 'package:decent_bench/features/workspace/infrastructure/workspace_state_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workspace state store round-trips tab drafts by database path', () async {
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
      schemaFingerprint:
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      schemaFingerprintAlgorithm: 'sha256:decentdb-tooling-schema-v1',
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
          queryContract: QueryContract(
            contractVersion: 1,
            sql: 'SELECT 2;',
            statementKind: 'query',
            readOnly: true,
            schemaCookie: 1,
            tempSchemaCookie: 0,
            schemaFingerprint:
                '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            parameters: <QueryParameterContract>[],
            resultColumns: <QueryResultColumnContract>[
              QueryResultColumnContract(
                ordinal: 0,
                name: '2',
                typeName: 'INT64',
                nullable: false,
                source: 'expression',
                diagnostics: <String>[],
              ),
            ],
            diagnostics: <String>[],
          ),
        ),
      ],
    );

    await store.save('/tmp/example.ddb', state);
    final restored = await store.load('/tmp/example.ddb');

    expect(restored?.activeTabId, 'query-tab-2');
    expect(restored?.schemaFingerprint, state.schemaFingerprint);
    expect(restored?.tabs, hasLength(2));
    expect(restored?.tabs.last.sql, 'SELECT 2;');
    expect(
      restored?.tabs.last.queryContract?.resultColumns.single.typeName,
      'INT64',
    );

    await store.clear('/tmp/example.ddb');
    expect(await store.load('/tmp/example.ddb'), isNull);
  });
}
