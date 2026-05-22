import 'package:decent_bench/features/workspace/domain/saved_query_models.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saved query library round-trips TOML with query contracts', () {
    final library = SavedQueryLibrary(
      queries: <SavedQuery>[
        SavedQuery(
          id: 'query-1',
          name: 'Tasks',
          sql: 'SELECT id, title FROM tasks WHERE id = \$1',
          parameterJson: '[1]',
          description: 'Task lookup',
          folder: 'ops',
          tags: const <String>['tasks', 'lookup'],
          createdAt: DateTime.utc(2026, 5, 19, 12),
          updatedAt: DateTime.utc(2026, 5, 19, 13),
          schemaFingerprint: 'abc',
          schemaFingerprintAlgorithm: 'sha256:test',
          queryContract: const QueryContract(
            contractVersion: 1,
            sql: 'SELECT id, title FROM tasks WHERE id = \$1',
            statementKind: 'query',
            readOnly: true,
            schemaCookie: 1,
            tempSchemaCookie: 0,
            schemaFingerprint: 'abc',
            parameters: <QueryParameterContract>[
              QueryParameterContract(
                position: 1,
                name: r'$1',
                typeName: 'INT64',
                nullable: false,
                source: 'catalog_column',
                sourceTable: 'tasks',
                sourceColumn: 'id',
                diagnostics: <String>[],
              ),
            ],
            resultColumns: <QueryResultColumnContract>[
              QueryResultColumnContract(
                ordinal: 0,
                name: 'title',
                typeName: 'TEXT',
                nullable: false,
                source: 'catalog_column',
                sourceTable: 'tasks',
                sourceColumn: 'title',
                diagnostics: <String>[],
              ),
            ],
            diagnostics: <String>[],
          ),
        ),
      ],
    );

    final parsed = SavedQueryLibrary.fromToml(library.toToml());

    expect(parsed.queries, hasLength(1));
    expect(parsed.queries.single.name, 'Tasks');
    expect(parsed.queries.single.parameterJson, '[1]');
    expect(parsed.queries.single.queryContract?.parameters.single.name, r'$1');
    expect(
      parsed.queries.single.queryContract?.resultColumns.single.sourceColumn,
      'title',
    );
  });

  test('workspace project resolves relative paths', () {
    const project = WorkspaceProjectFile(
      databasePath: 'data/tasks.ddb',
      queryLibraryPath: 'queries.toml',
      autoOpenQueryIds: <String>['query-1'],
      importPlanPaths: <String>['imports/tasks.json'],
      exportIncludeHeaders: false,
      exportDelimiter: '|',
      preferredBranch: 'analysis',
      runRiskyQueriesOnBranch: true,
      qualityProfilePath: 'quality/team-profile.toml',
      qualityDefaultMode: 'sampled',
    );

    final parsed = WorkspaceProjectFile.fromToml(project.toToml());

    expect(
      parsed.resolveDatabasePath('/tmp/workspace/.dbench-project.toml'),
      '/tmp/workspace/data/tasks.ddb',
    );
    expect(
      parsed.resolveQueryLibraryPath('/tmp/workspace/.dbench-project.toml'),
      '/tmp/workspace/queries.toml',
    );
    expect(parsed.autoOpenQueryIds, <String>['query-1']);
    expect(parsed.importPlanPaths, <String>['imports/tasks.json']);
    expect(parsed.exportIncludeHeaders, isFalse);
    expect(parsed.exportDelimiter, '|');
    expect(parsed.preferredBranch, 'analysis');
    expect(parsed.runRiskyQueriesOnBranch, isTrue);
    expect(
      parsed.resolveQualityProfilePath('/tmp/workspace/.dbench-project.toml'),
      '/tmp/workspace/quality/team-profile.toml',
    );
    expect(parsed.qualityDefaultMode, 'sampled');
  });
}
