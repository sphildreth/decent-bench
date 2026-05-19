import 'package:decent_bench/features/workspace/domain/database_statistics.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('summarizes object counts branch state and maintenance hints', () {
    final stats = buildDatabaseStatistics(
      databasePath: '/tmp/app.ddb',
      databaseFileBytes: 4096,
      walFileBytes: 2048,
      shmFileBytes: 0,
      schema: SchemaSnapshot(
        objects: const <SchemaObjectSummary>[
          SchemaObjectSummary(
            name: 'tasks',
            kind: SchemaObjectKind.table,
            columns: <SchemaColumn>[],
          ),
          SchemaObjectSummary(
            name: 'active_tasks',
            kind: SchemaObjectKind.view,
            temporary: true,
            columns: <SchemaColumn>[],
          ),
        ],
        indexes: const <IndexSummary>[
          IndexSummary(
            name: 'idx_tasks_title',
            table: 'tasks',
            columns: <String>['title'],
            unique: false,
            kind: 'btree',
          ),
        ],
        triggers: const <TriggerSummary>[
          TriggerSummary(
            name: 'tasks_ai',
            targetName: 'tasks',
            targetKind: 'table',
            timing: 'after',
            events: <String>['insert'],
            eventsMask: 1,
            forEachRow: true,
            temporary: false,
            actionSql: 'SELECT 1',
            ddl: 'CREATE TRIGGER tasks_ai AFTER INSERT ON tasks SELECT 1;',
          ),
        ],
        loadedAt: DateTime.utc(2026, 5, 19),
      ),
      branchState: const WorkspaceBranchState(
        currentBranch: 'analysis',
        isNativeBranchApiAvailable: true,
        nativeBranchApiUnavailableReason: '',
        branches: <WorkspaceBranchInfo>[
          WorkspaceBranchInfo(name: 'main'),
          WorkspaceBranchInfo(name: 'analysis', isCurrent: true),
        ],
        snapshots: <WorkspaceSnapshotInfo>[
          WorkspaceSnapshotInfo(name: 'baseline', ref: 'snapshot:baseline'),
        ],
      ),
    );

    expect(stats.tableCount, 1);
    expect(stats.viewCount, 1);
    expect(stats.indexCount, 1);
    expect(stats.triggerCount, 1);
    expect(stats.temporaryObjectCount, 1);
    expect(stats.branchCount, 2);
    expect(stats.snapshotCount, 1);
    expect(stats.hasWalSidecar, isTrue);
    expect(
      stats.rowCountQueries['tasks'],
      'SELECT COUNT(*) AS row_count\nFROM "tasks";',
    );
    expect(stats.maintenanceHints.first, contains('WAL sidecar'));
    expect(stats.toClipboardText(), contains('Database file: 4.00 KB'));
  });

  test('quotes table identifiers for row count templates', () {
    final stats = buildDatabaseStatistics(
      schema: SchemaSnapshot(
        objects: const <SchemaObjectSummary>[
          SchemaObjectSummary(
            name: 'odd"name',
            kind: SchemaObjectKind.table,
            columns: <SchemaColumn>[],
          ),
        ],
        indexes: const <IndexSummary>[],
        loadedAt: DateTime.utc(2026, 5, 19),
      ),
      branchState: WorkspaceBranchState.unavailable('No API'),
    );

    expect(
      stats.rowCountQueries['odd"name'],
      'SELECT COUNT(*) AS row_count\nFROM "odd""name";',
    );
    expect(stats.maintenanceHints, contains('No API'));
  });
}
