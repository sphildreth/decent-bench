import 'package:decent_bench/features/workspace/domain/sql_dump_import_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SqlDumpImportSession', () {
    test('initial creates session with idle defaults', () {
      final session = SqlDumpImportSession.initial();

      expect(session.step, SqlDumpImportWizardStep.source);
      expect(session.phase, SqlDumpImportJobPhase.idle);
      expect(session.tables, isEmpty);
      expect(session.warnings, isEmpty);
      expect(session.encoding, 'auto');
    });

    test('canAdvanceFromSource is false when no tables', () {
      final session = SqlDumpImportSession.initial(sourcePath: '/test.sql');

      expect(session.canAdvanceFromSource, isFalse);
    });

    test('canAdvanceFromSource is true when source and tables exist', () {
      final session = SqlDumpImportSession.initial(sourcePath: '/test.sql')
          .copyWith(
            tables: [
              SqlDumpImportTableDraft(
                sourceName: 'users',
                targetName: 'users',
                selected: true,
                rowCount: 5,
                columns: [],
                previewRows: [],
              ),
            ],
          );

      expect(session.canAdvanceFromSource, isTrue);
    });

    test('canAdvanceFromTarget requires non-empty target', () {
      final empty = SqlDumpImportSession.initial();
      expect(empty.canAdvanceFromTarget, isFalse);

      final withTarget = empty.copyWith(targetPath: '/out.ddb');
      expect(withTarget.canAdvanceFromTarget, isTrue);
    });

    test('canAdvanceFromPreview requires selected tables', () {
      final withSelected = SqlDumpImportSession.initial().copyWith(
        tables: [
          SqlDumpImportTableDraft(
            sourceName: 't',
            targetName: 't',
            selected: true,
            rowCount: 1,
            columns: [],
            previewRows: [],
          ),
        ],
      );
      expect(withSelected.canAdvanceFromPreview, isTrue);

      final withUnselected = SqlDumpImportSession.initial().copyWith(
        tables: [
          SqlDumpImportTableDraft(
            sourceName: 't',
            targetName: 't',
            selected: false,
            rowCount: 1,
            columns: [],
            previewRows: [],
          ),
        ],
      );
      expect(withUnselected.canAdvanceFromPreview, isFalse);
    });

    test('canAdvanceFromTransforms rejects duplicate target names', () {
      final duplicateTargets = SqlDumpImportSession.initial().copyWith(
        tables: [
          SqlDumpImportTableDraft(
            sourceName: 'a',
            targetName: 'same_name',
            selected: true,
            rowCount: 1,
            columns: [],
            previewRows: [],
          ),
          SqlDumpImportTableDraft(
            sourceName: 'b',
            targetName: 'same_name',
            selected: true,
            rowCount: 1,
            columns: [],
            previewRows: [],
          ),
        ],
      );
      expect(duplicateTargets.canAdvanceFromTransforms, isFalse);
    });

    test('focusedTableDraft returns focused or first table', () {
      final session = SqlDumpImportSession.initial().copyWith(
        tables: [
          SqlDumpImportTableDraft(
            sourceName: 'first',
            targetName: 'first',
            selected: true,
            rowCount: 1,
            columns: [],
            previewRows: [],
          ),
          SqlDumpImportTableDraft(
            sourceName: 'second',
            targetName: 'second',
            selected: true,
            rowCount: 1,
            columns: [],
            previewRows: [],
          ),
        ],
        focusedTable: 'second',
      );

      expect(session.focusedTableDraft!.sourceName, 'second');
    });

    test('copyWith preserves unset optional fields', () {
      final original = SqlDumpImportSession.initial().copyWith(
        error: 'some error',
        jobId: '123',
        progress: SqlDumpImportProgress(
          jobId: '123',
          currentTable: 't',
          completedTables: 0,
          totalTables: 1,
          currentTableRowsCopied: 5,
          currentTableRowCount: 10,
          totalRowsCopied: 5,
          message: 'progress',
        ),
      );

      final updated = original.copyWith(phase: SqlDumpImportJobPhase.running);

      expect(updated.error, 'some error');
      expect(updated.jobId, '123');
      expect(updated.progress, isNotNull);
      expect(updated.phase, SqlDumpImportJobPhase.running);
    });
  });

  group('SqlDumpImportColumnDraft', () {
    test('toMap/fromMap round-trip', () {
      final column = SqlDumpImportColumnDraft(
        sourceIndex: 0,
        sourceName: 'id',
        targetName: 'id',
        declaredType: 'INT',
        inferredTargetType: 'INTEGER',
        targetType: 'INTEGER',
        notNull: true,
        primaryKey: true,
        unique: false,
      );

      final map = column.toMap();
      final restored = SqlDumpImportColumnDraft.fromMap(map);

      expect(restored.sourceIndex, 0);
      expect(restored.sourceName, 'id');
      expect(restored.declaredType, 'INT');
      expect(restored.inferredTargetType, 'INTEGER');
      expect(restored.notNull, isTrue);
      expect(restored.primaryKey, isTrue);
    });
  });

  group('SqlDumpImportSummary', () {
    test('totalRowsCopied sums by table', () {
      final summary = SqlDumpImportSummary(
        jobId: 'j1',
        sourcePath: '/src',
        targetPath: '/tgt',
        importedTables: ['a', 'b'],
        rowsCopiedByTable: {'a': 10, 'b': 25},
        skippedStatementCount: 0,
        warnings: [],
        skippedStatements: [],
        statusMessage: 'done',
        rolledBack: false,
      );

      expect(summary.totalRowsCopied, 35);
      expect(summary.firstImportedTable, 'a');
    });

    test('firstImportedTable returns null when empty', () {
      final summary = SqlDumpImportSummary(
        jobId: 'j1',
        sourcePath: '/src',
        targetPath: '/tgt',
        importedTables: [],
        rowsCopiedByTable: {},
        skippedStatementCount: 0,
        warnings: [],
        skippedStatements: [],
        statusMessage: 'none',
        rolledBack: false,
      );

      expect(summary.firstImportedTable, isNull);
      expect(summary.totalRowsCopied, 0);
    });
  });

  group('SqlDumpImportUpdate', () {
    test('toMap/fromMap round-trip for progress update', () {
      final update = SqlDumpImportUpdate(
        kind: SqlDumpImportUpdateKind.progress,
        jobId: 'j1',
        progress: SqlDumpImportProgress(
          jobId: 'j1',
          currentTable: 'users',
          completedTables: 0,
          totalTables: 1,
          currentTableRowsCopied: 5,
          currentTableRowCount: 100,
          totalRowsCopied: 5,
          message: 'Importing...',
        ),
      );

      final map = update.toMap();
      final restored = SqlDumpImportUpdate.fromMap(map);

      expect(restored.kind, SqlDumpImportUpdateKind.progress);
      expect(restored.jobId, 'j1');
      expect(restored.progress, isNotNull);
      expect(restored.progress!.currentTable, 'users');
    });
  });

  group('sqlDumpEncodingLabel', () {
    test('returns human-readable labels', () {
      expect(sqlDumpEncodingLabel('auto'), 'Auto-detect');
      expect(sqlDumpEncodingLabel('utf8'), 'UTF-8');
      expect(sqlDumpEncodingLabel('latin1'), 'Latin-1');
      expect(sqlDumpEncodingLabel('other'), 'other');
    });
  });
}
