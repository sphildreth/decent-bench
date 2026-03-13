import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:decentdb/decentdb.dart';
import 'package:path/path.dart' as p;

import '../features/import/application/import_manager.dart';
import '../features/import/domain/import_models.dart';
import '../features/import/infrastructure/import_execution_service.dart';
import '../features/import/infrastructure/import_preview_service.dart';
import '../features/workspace/domain/excel_import_models.dart';
import '../features/workspace/domain/sql_dump_import_models.dart';
import '../features/workspace/domain/sqlite_import_models.dart';
import '../features/workspace/infrastructure/decentdb_bridge.dart';
import '../features/workspace/infrastructure/native_library_resolver.dart';
import 'startup_launch_options.dart';

typedef HeadlessImportLineWriter = void Function(String line);

class HeadlessImportCliReport {
  const HeadlessImportCliReport({
    required this.sourcePath,
    required this.resolvedSourcePath,
    required this.targetPath,
    required this.formatKey,
    required this.formatLabel,
    required this.importedTables,
    required this.rowsCopiedByTable,
    required this.totalRowsCopied,
    required this.warnings,
    required this.statusMessage,
    required this.rolledBack,
    required this.databaseTables,
  });

  final String sourcePath;
  final String resolvedSourcePath;
  final String targetPath;
  final String formatKey;
  final String formatLabel;
  final List<String> importedTables;
  final Map<String, int> rowsCopiedByTable;
  final int totalRowsCopied;
  final List<String> warnings;
  final String statusMessage;
  final bool rolledBack;
  final List<HeadlessImportedTableReport> databaseTables;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'status': rolledBack ? 'rolled_back' : 'completed',
      'source_path': sourcePath,
      'resolved_source_path': resolvedSourcePath,
      'target_path': targetPath,
      'format_key': formatKey,
      'format_label': formatLabel,
      'imported_tables': importedTables,
      'rows_copied_by_table': rowsCopiedByTable,
      'total_rows_copied': totalRowsCopied,
      'warnings': warnings,
      'status_message': statusMessage,
      'rolled_back': rolledBack,
      'database_tables': <Map<String, Object?>>[
        for (final table in databaseTables) table.toJson(),
      ],
    };
  }
}

class HeadlessImportedTableReport {
  const HeadlessImportedTableReport({
    required this.name,
    required this.rowCount,
    required this.columns,
  });

  final String name;
  final int rowCount;
  final List<HeadlessImportedColumnReport> columns;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'row_count': rowCount,
      'column_count': columns.length,
      'columns': <Map<String, Object?>>[
        for (final column in columns) column.toJson(),
      ],
    };
  }
}

class HeadlessImportedColumnReport {
  const HeadlessImportedColumnReport({required this.name, required this.type});

  final String name;
  final String type;

  Map<String, Object?> toJson() {
    return <String, Object?>{'name': name, 'type': type};
  }
}

class _ResolvedHeadlessImportSource {
  const _ResolvedHeadlessImportSource({
    required this.originalSourcePath,
    required this.resolvedSourcePath,
    required this.format,
    required this.warnings,
  });

  final String originalSourcePath;
  final String resolvedSourcePath;
  final ImportFormatDefinition format;
  final List<String> warnings;
}

Future<int> runHeadlessImportCli(
  HeadlessImportCliOptions options, {
  HeadlessImportLineWriter? stdoutWriter,
  HeadlessImportLineWriter? stderrWriter,
  ImportManager? importManager,
  ImportPreviewService? previewService,
  ImportExecutionService? genericExecutionService,
  WorkspaceDatabaseGateway? workspaceGateway,
  NativeLibraryResolver? nativeLibraryResolver,
}) async {
  final HeadlessImportLineWriter writeStdout = stdoutWriter ?? stdout.writeln;
  final HeadlessImportLineWriter writeStderr = stderrWriter ?? stderr.writeln;
  final manager = importManager ?? ImportManager();
  final preview = previewService ?? ImportPreviewService();
  final resolver = nativeLibraryResolver ?? NativeLibraryResolver();
  final genericExecution =
      genericExecutionService ?? ImportExecutionService(resolver: resolver);
  final gateway = workspaceGateway ?? DecentDbBridge(resolver: resolver);
  final disposeGateway = workspaceGateway == null;

  String? extractedSourcePath;
  Directory? extractedDirectory;

  try {
    if (options.planPath != null) {
      writeStderr(
        'Headless import plan execution is not implemented yet. Remove `--plan` for now.',
      );
      return 2;
    }

    final sourcePath = options.sourcePath.trim();
    final targetPath = options.targetPath.trim();
    if (sourcePath.isEmpty) {
      writeStderr('Headless import requires a source path.');
      return 2;
    }
    if (targetPath.isEmpty) {
      writeStderr('Headless import requires a target `.ddb` path.');
      return 2;
    }
    if (!File(sourcePath).existsSync()) {
      writeStderr('Source file not found: $sourcePath');
      return 1;
    }

    final resolved = await _resolveSourceForHeadlessImport(
      manager: manager,
      sourcePath: sourcePath,
    );
    extractedSourcePath = resolved.resolvedSourcePath == sourcePath
        ? null
        : resolved.resolvedSourcePath;
    extractedDirectory = extractedSourcePath == null
        ? null
        : Directory(p.dirname(extractedSourcePath));

    if (resolved.format.isDirectOpen) {
      writeStderr(
        'Headless import does not accept DecentDB sources. Open `.ddb` files with `dbench <file.ddb>` instead.',
      );
      return 1;
    }

    if (!options.silent) {
      for (final warning in resolved.warnings) {
        writeStderr('Warning: $warning');
      }
      writeStderr(
        'Importing ${p.basename(resolved.resolvedSourcePath)} as ${resolved.format.label}...',
      );
    }

    final report = switch (resolved.format.implementationKind) {
      ImportImplementationKind.genericWizard => await _runGenericHeadlessImport(
        source: resolved,
        targetPath: targetPath,
        previewService: preview,
        executionService: genericExecution,
        silent: options.silent,
        writeStderr: writeStderr,
        libraryResolver: resolver,
      ),
      ImportImplementationKind.legacyWizard => await _runLegacyHeadlessImport(
        source: resolved,
        targetPath: targetPath,
        gateway: gateway,
        silent: options.silent,
        writeStderr: writeStderr,
        libraryResolver: resolver,
      ),
      _ => throw StateError(
        'Format ${resolved.format.label} is not available for headless import.',
      ),
    };

    writeStdout(jsonEncode(report.toJson()));
    if (!options.silent) {
      writeStderr(report.statusMessage);
    }
    return report.rolledBack ? 1 : 0;
  } catch (error) {
    writeStderr('Headless import failed: $error');
    return 1;
  } finally {
    if (disposeGateway) {
      await gateway.dispose();
    }
    if (extractedDirectory != null && extractedDirectory.existsSync()) {
      await extractedDirectory.delete(recursive: true);
    }
  }
}

Future<_ResolvedHeadlessImportSource> _resolveSourceForHeadlessImport({
  required ImportManager manager,
  required String sourcePath,
}) async {
  final detection = await manager.detectSource(sourcePath);
  if (!detection.isSupported) {
    throw StateError(
      'Unsupported import source: ${detection.format.label} ($sourcePath).',
    );
  }

  if (!detection.isWrapper) {
    return _ResolvedHeadlessImportSource(
      originalSourcePath: sourcePath,
      resolvedSourcePath: sourcePath,
      format: detection.format,
      warnings: detection.warnings,
    );
  }

  if (detection.archiveCandidates.isEmpty) {
    throw StateError(
      'No supported import source was found inside `${p.basename(sourcePath)}`.',
    );
  }
  if (detection.archiveCandidates.length != 1) {
    final choices = detection.archiveCandidates
        .map((candidate) => candidate.displayName)
        .join(', ');
    throw StateError(
      '`${p.basename(sourcePath)}` contains multiple import candidates. Headless import currently requires a single inner file. Candidates: $choices',
    );
  }

  final candidate = detection.archiveCandidates.single;
  final extractedPath = await manager.extractArchiveCandidate(
    archivePath: sourcePath,
    wrapperKey: detection.format.key,
    candidate: candidate,
  );
  final extractedDetection = await manager.detectSource(extractedPath);
  if (!extractedDetection.isSupported || extractedDetection.isWrapper) {
    throw StateError(
      'Unable to resolve a supported inner source from `${p.basename(sourcePath)}`.',
    );
  }
  return _ResolvedHeadlessImportSource(
    originalSourcePath: sourcePath,
    resolvedSourcePath: extractedPath,
    format: extractedDetection.format,
    warnings: <String>[
      ...detection.warnings,
      'Extracted `${candidate.displayName}` from `${p.basename(sourcePath)}` for import.',
      ...extractedDetection.warnings,
    ],
  );
}

Future<HeadlessImportCliReport> _runGenericHeadlessImport({
  required _ResolvedHeadlessImportSource source,
  required String targetPath,
  required ImportPreviewService previewService,
  required ImportExecutionService executionService,
  required bool silent,
  required HeadlessImportLineWriter writeStderr,
  required NativeLibraryResolver libraryResolver,
}) async {
  final options = defaultGenericImportOptionsFor(source.format.key);
  final inspection = await previewService.inspect(
    sourcePath: source.resolvedSourcePath,
    format: source.format,
    options: options,
  );
  if (inspection.tables.isEmpty) {
    throw StateError(
      'No importable tables were detected in `${p.basename(source.resolvedSourcePath)}`.',
    );
  }
  if (!silent) {
    for (final warning in inspection.warnings) {
      writeStderr('Warning: $warning');
    }
  }

  final request = GenericImportRequest(
    jobId: _createHeadlessJobId('generic'),
    sourcePath: source.resolvedSourcePath,
    targetPath: targetPath,
    importIntoExistingTarget: false,
    replaceExistingTarget: true,
    formatKey: source.format.key,
    options: inspection.options,
    tables: inspection.tables,
  );
  final summary = await _consumeGenericImport(
    executionService.execute(request: request),
    silent: silent,
    writeStderr: writeStderr,
  );
  return _buildImportReport(
    source: source,
    targetPath: targetPath,
    format: source.format,
    importedTables: summary.importedTables,
    rowsCopiedByTable: summary.rowsCopiedByTable,
    warnings: <String>[
      ...source.warnings,
      ...inspection.warnings,
      ...summary.warnings,
    ],
    statusMessage: summary.statusMessage,
    rolledBack: summary.rolledBack,
    libraryResolver: libraryResolver,
  );
}

Future<HeadlessImportCliReport> _runLegacyHeadlessImport({
  required _ResolvedHeadlessImportSource source,
  required String targetPath,
  required WorkspaceDatabaseGateway gateway,
  required bool silent,
  required HeadlessImportLineWriter writeStderr,
  required NativeLibraryResolver libraryResolver,
}) async {
  await gateway.initialize();

  switch (source.format.key) {
    case ImportFormatKey.sqlite:
      final inspection = await gateway.inspectSqliteSource(
        sourcePath: source.resolvedSourcePath,
      );
      if (inspection.tables.isEmpty) {
        throw StateError(
          'No user tables were found in `${p.basename(source.resolvedSourcePath)}`.',
        );
      }
      if (!silent) {
        for (final warning in inspection.warnings) {
          writeStderr('Warning: $warning');
        }
      }
      final summary = await _consumeSqliteImport(
        gateway.importSqlite(
          request: SqliteImportRequest(
            jobId: _createHeadlessJobId('sqlite'),
            sourcePath: source.resolvedSourcePath,
            targetPath: targetPath,
            importIntoExistingTarget: false,
            replaceExistingTarget: true,
            tables: inspection.tables,
          ),
        ),
        silent: silent,
        writeStderr: writeStderr,
      );
      return _buildImportReport(
        source: source,
        targetPath: targetPath,
        format: source.format,
        importedTables: summary.importedTables,
        rowsCopiedByTable: summary.rowsCopiedByTable,
        warnings: <String>[
          ...source.warnings,
          ...inspection.warnings,
          ...summary.warnings,
        ],
        statusMessage: summary.statusMessage,
        rolledBack: summary.rolledBack,
        libraryResolver: libraryResolver,
      );
    case ImportFormatKey.xlsx:
    case ImportFormatKey.xls:
      final inspection = await gateway.inspectExcelSource(
        sourcePath: source.resolvedSourcePath,
        headerRow: true,
      );
      if (inspection.sheets.isEmpty) {
        throw StateError(
          'No worksheets were found in `${p.basename(source.resolvedSourcePath)}`.',
        );
      }
      if (!silent) {
        for (final warning in inspection.warnings) {
          writeStderr('Warning: $warning');
        }
      }
      final summary = await _consumeExcelImport(
        gateway.importExcel(
          request: ExcelImportRequest(
            jobId: _createHeadlessJobId('excel'),
            sourcePath: source.resolvedSourcePath,
            targetPath: targetPath,
            importIntoExistingTarget: false,
            replaceExistingTarget: true,
            headerRow: inspection.headerRow,
            sheets: inspection.sheets,
          ),
        ),
        silent: silent,
        writeStderr: writeStderr,
      );
      return _buildImportReport(
        source: source,
        targetPath: targetPath,
        format: source.format,
        importedTables: summary.importedTables,
        rowsCopiedByTable: summary.rowsCopiedByTable,
        warnings: <String>[
          ...source.warnings,
          ...inspection.warnings,
          ...summary.warnings,
        ],
        statusMessage: summary.statusMessage,
        rolledBack: summary.rolledBack,
        libraryResolver: libraryResolver,
      );
    case ImportFormatKey.sqlDump:
      final inspection = await gateway.inspectSqlDumpSource(
        sourcePath: source.resolvedSourcePath,
        encoding: 'auto',
      );
      if (inspection.tables.isEmpty) {
        throw StateError(
          'No supported CREATE TABLE statements were parsed from `${p.basename(source.resolvedSourcePath)}`.',
        );
      }
      if (!silent) {
        for (final warning in inspection.warnings) {
          writeStderr('Warning: $warning');
        }
      }
      final summary = await _consumeSqlDumpImport(
        gateway.importSqlDump(
          request: SqlDumpImportRequest(
            jobId: _createHeadlessJobId('sql-dump'),
            sourcePath: source.resolvedSourcePath,
            targetPath: targetPath,
            importIntoExistingTarget: false,
            replaceExistingTarget: true,
            encoding: inspection.requestedEncoding,
            tables: inspection.tables,
          ),
        ),
        silent: silent,
        writeStderr: writeStderr,
      );
      return _buildImportReport(
        source: source,
        targetPath: targetPath,
        format: source.format,
        importedTables: summary.importedTables,
        rowsCopiedByTable: summary.rowsCopiedByTable,
        warnings: <String>[
          ...source.warnings,
          ...inspection.warnings,
          ...summary.warnings,
        ],
        statusMessage: summary.statusMessage,
        rolledBack: summary.rolledBack,
        libraryResolver: libraryResolver,
      );
    default:
      throw StateError(
        'Format ${source.format.label} is not available for headless import.',
      );
  }
}

Future<GenericImportSummary> _consumeGenericImport(
  Stream<GenericImportUpdate> updates, {
  required bool silent,
  required HeadlessImportLineWriter writeStderr,
}) {
  final completer = Completer<GenericImportSummary>();
  late final StreamSubscription<GenericImportUpdate> subscription;
  subscription = updates.listen((update) {
    switch (update.kind) {
      case GenericImportUpdateKind.progress:
        final progress = update.progress;
        if (!silent && progress != null) {
          writeStderr(
            _formatProgressLine(
              label: progress.currentTable,
              completed: progress.completedTables,
              total: progress.totalTables,
              copied: progress.currentTableRowsCopied,
              rowCount: progress.currentTableRowCount,
              message: progress.message,
            ),
          );
        }
        break;
      case GenericImportUpdateKind.completed:
        completer.complete(update.summary!);
        break;
      case GenericImportUpdateKind.cancelled:
        completer.completeError(
          StateError(update.summary?.statusMessage ?? 'Import was cancelled.'),
        );
        break;
      case GenericImportUpdateKind.failed:
        completer.completeError(StateError(update.message ?? 'Import failed.'));
        break;
    }
  }, onError: completer.completeError);
  return completer.future.whenComplete(subscription.cancel);
}

Future<SqliteImportSummary> _consumeSqliteImport(
  Stream<SqliteImportUpdate> updates, {
  required bool silent,
  required HeadlessImportLineWriter writeStderr,
}) {
  final completer = Completer<SqliteImportSummary>();
  late final StreamSubscription<SqliteImportUpdate> subscription;
  subscription = updates.listen((update) {
    switch (update.kind) {
      case SqliteImportUpdateKind.progress:
        final progress = update.progress;
        if (!silent && progress != null) {
          writeStderr(
            _formatProgressLine(
              label: progress.currentTable,
              completed: progress.completedTables,
              total: progress.totalTables,
              copied: progress.currentTableRowsCopied,
              rowCount: progress.currentTableRowCount,
              message: progress.message,
            ),
          );
        }
        break;
      case SqliteImportUpdateKind.completed:
        completer.complete(update.summary!);
        break;
      case SqliteImportUpdateKind.cancelled:
        completer.completeError(
          StateError(update.summary?.statusMessage ?? 'Import was cancelled.'),
        );
        break;
      case SqliteImportUpdateKind.failed:
        completer.completeError(StateError(update.message ?? 'Import failed.'));
        break;
    }
  }, onError: completer.completeError);
  return completer.future.whenComplete(subscription.cancel);
}

Future<ExcelImportSummary> _consumeExcelImport(
  Stream<ExcelImportUpdate> updates, {
  required bool silent,
  required HeadlessImportLineWriter writeStderr,
}) {
  final completer = Completer<ExcelImportSummary>();
  late final StreamSubscription<ExcelImportUpdate> subscription;
  subscription = updates.listen((update) {
    switch (update.kind) {
      case ExcelImportUpdateKind.progress:
        final progress = update.progress;
        if (!silent && progress != null) {
          writeStderr(
            _formatProgressLine(
              label: progress.currentSheet,
              completed: progress.completedSheets,
              total: progress.totalSheets,
              copied: progress.currentSheetRowsCopied,
              rowCount: progress.currentSheetRowCount,
              message: progress.message,
            ),
          );
        }
        break;
      case ExcelImportUpdateKind.completed:
        completer.complete(update.summary!);
        break;
      case ExcelImportUpdateKind.cancelled:
        completer.completeError(
          StateError(update.summary?.statusMessage ?? 'Import was cancelled.'),
        );
        break;
      case ExcelImportUpdateKind.failed:
        completer.completeError(StateError(update.message ?? 'Import failed.'));
        break;
    }
  }, onError: completer.completeError);
  return completer.future.whenComplete(subscription.cancel);
}

Future<SqlDumpImportSummary> _consumeSqlDumpImport(
  Stream<SqlDumpImportUpdate> updates, {
  required bool silent,
  required HeadlessImportLineWriter writeStderr,
}) {
  final completer = Completer<SqlDumpImportSummary>();
  late final StreamSubscription<SqlDumpImportUpdate> subscription;
  subscription = updates.listen((update) {
    switch (update.kind) {
      case SqlDumpImportUpdateKind.progress:
        final progress = update.progress;
        if (!silent && progress != null) {
          writeStderr(
            _formatProgressLine(
              label: progress.currentTable,
              completed: progress.completedTables,
              total: progress.totalTables,
              copied: progress.currentTableRowsCopied,
              rowCount: progress.currentTableRowCount,
              message: progress.message,
            ),
          );
        }
        break;
      case SqlDumpImportUpdateKind.completed:
        completer.complete(update.summary!);
        break;
      case SqlDumpImportUpdateKind.cancelled:
        completer.completeError(
          StateError(update.summary?.statusMessage ?? 'Import was cancelled.'),
        );
        break;
      case SqlDumpImportUpdateKind.failed:
        completer.completeError(StateError(update.message ?? 'Import failed.'));
        break;
    }
  }, onError: completer.completeError);
  return completer.future.whenComplete(subscription.cancel);
}

Future<HeadlessImportCliReport> _buildImportReport({
  required _ResolvedHeadlessImportSource source,
  required String targetPath,
  required ImportFormatDefinition format,
  required List<String> importedTables,
  required Map<String, int> rowsCopiedByTable,
  required List<String> warnings,
  required String statusMessage,
  required bool rolledBack,
  required NativeLibraryResolver libraryResolver,
}) async {
  final libraryPath = await libraryResolver.resolve();
  final database = Database.open(targetPath, libraryPath: libraryPath);
  try {
    final tables = database.schema.listTablesInfo()
      ..sort((left, right) => left.name.compareTo(right.name));
    final tableReports = <HeadlessImportedTableReport>[
      for (final table in tables)
        HeadlessImportedTableReport(
          name: table.name,
          rowCount: _loadTableRowCount(database, table.name),
          columns: <HeadlessImportedColumnReport>[
            for (final column in table.columns)
              HeadlessImportedColumnReport(
                name: column.name,
                type: column.type,
              ),
          ],
        ),
    ];
    final totalRowsCopied = rowsCopiedByTable.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    return HeadlessImportCliReport(
      sourcePath: source.originalSourcePath,
      resolvedSourcePath: source.resolvedSourcePath,
      targetPath: targetPath,
      formatKey: format.key.name,
      formatLabel: format.label,
      importedTables: importedTables,
      rowsCopiedByTable: rowsCopiedByTable,
      totalRowsCopied: totalRowsCopied,
      warnings: _dedupeStrings(warnings),
      statusMessage: statusMessage,
      rolledBack: rolledBack,
      databaseTables: tableReports,
    );
  } finally {
    database.close();
  }
}

int _loadTableRowCount(Database database, String tableName) {
  final rows = database.query(
    'SELECT COUNT(*) AS row_count FROM ${_quoteIdentifier(tableName)}',
  );
  if (rows.isEmpty) {
    return 0;
  }
  final value = rows.first['row_count'];
  return switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text) ?? 0,
    _ => 0,
  };
}

String _quoteIdentifier(String value) {
  return '"${value.replaceAll('"', '""')}"';
}

List<String> _dedupeStrings(Iterable<String> values) {
  final seen = <String>{};
  final unique = <String>[];
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || !seen.add(trimmed)) {
      continue;
    }
    unique.add(trimmed);
  }
  return unique;
}

String _createHeadlessJobId(String prefix) {
  return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}

String _formatProgressLine({
  required String label,
  required int completed,
  required int total,
  required int copied,
  required int rowCount,
  required String message,
}) {
  final cleanLabel = label.trim().isEmpty ? 'item' : label;
  return '[$completed/$total] $cleanLabel $copied/$rowCount rows - $message';
}
