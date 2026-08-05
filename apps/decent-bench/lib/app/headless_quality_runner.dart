import 'dart:convert';
import 'dart:io';

import '../features/workspace/domain/data_quality_models.dart';
import '../features/workspace/domain/data_quality_reports.dart';
import '../features/workspace/infrastructure/data_quality_report_writer.dart';
import '../features/workspace/infrastructure/data_quality_repository.dart';
import '../features/workspace/infrastructure/data_quality_runner.dart';
import '../features/workspace/infrastructure/decentdb_bridge.dart';
import '../features/workspace/infrastructure/decentdb_migration_service.dart';
import '../features/workspace/infrastructure/native_library_resolver.dart';
import 'startup_launch_options.dart';

typedef HeadlessQualityLineWriter = void Function(String line);

class HeadlessQualityCliReport {
  const HeadlessQualityCliReport({
    required this.databasePath,
    required this.profilePath,
    required this.outputPath,
    required this.format,
    required this.status,
    required this.runId,
    required this.tablesScanned,
    required this.validationIssues,
    required this.errorIssues,
    required this.warningIssues,
    required this.infoIssues,
    required this.elapsedMilliseconds,
  });

  final String databasePath;
  final String profilePath;
  final String outputPath;
  final String format;
  final String status;
  final String runId;
  final int tablesScanned;
  final int validationIssues;
  final int errorIssues;
  final int warningIssues;
  final int infoIssues;
  final int elapsedMilliseconds;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'database_path': databasePath,
      'profile_path': profilePath,
      'output_path': outputPath,
      'format': format,
      'status': status,
      'run_id': runId,
      'tables_scanned': tablesScanned,
      'validation_issues': validationIssues,
      'error_issues': errorIssues,
      'warning_issues': warningIssues,
      'info_issues': infoIssues,
      'elapsed_ms': elapsedMilliseconds,
    };
  }
}

Future<int> runHeadlessQualityCli(
  HeadlessQualityCliOptions options, {
  HeadlessQualityLineWriter? stdoutWriter,
  HeadlessQualityLineWriter? stderrWriter,
  WorkspaceDatabaseGateway? workspaceGateway,
  DataQualityRepository? repository,
  DataQualityRunner? runner,
  DataQualityReportWriter reportWriter = const DataQualityReportWriter(),
  NativeLibraryResolver? nativeLibraryResolver,
}) async {
  final HeadlessQualityLineWriter writeStdout = stdoutWriter ?? stdout.writeln;
  final HeadlessQualityLineWriter writeStderr = stderrWriter ?? stderr.writeln;
  final resolver = nativeLibraryResolver ?? NativeLibraryResolver();
  final gateway = workspaceGateway ?? DecentDbBridge(resolver: resolver);
  final disposeGateway = workspaceGateway == null;
  final qualityRepository = repository ?? DataQualityRepository();
  final qualityRunner =
      runner ??
      DataQualityRunner(gateway: gateway, repository: qualityRepository);
  final started = DateTime.now();

  try {
    final databasePath = options.databasePath.trim();
    final profilePath = options.profilePath.trim();
    final outputPath = options.outputPath.trim();
    final format = _parseReportFormat(options.format);
    if (format == null) {
      writeStderr('Quality report format must be json, markdown, or html.');
      return 2;
    }
    if (!File(profilePath).existsSync()) {
      writeStderr('Quality profile not found: $profilePath');
      return 2;
    }
    if (!File(databasePath).existsSync()) {
      writeStderr('Database file not found: $databasePath');
      return 3;
    }

    final profile = QualityProfileDocument.fromToml(
      await File(profilePath).readAsString(),
    );
    final profileErrors = profile.validate();
    if (profileErrors.isNotEmpty) {
      writeStderr(
        'Invalid quality profile: ${profileErrors.map((error) => error.toString()).join('; ')}',
      );
      return 2;
    }

    if (!options.silent) {
      writeStderr('Database: $databasePath');
      writeStderr('Profile: ${profile.name}');
    }

    try {
      await gateway.openDatabase(databasePath);
    } catch (error) {
      writeStderr('Could not open database: $error');
      if (DecentDbMigrationService.isUnsupportedFormatVersionMessage(
        error.toString(),
      )) {
        writeStderr(
          'This file uses a legacy DecentDB on-disk format. Run the official '
          'decentdb-migrate tool to upgrade it in place, then re-run this '
          'command. For example: decentdb-migrate --source <db> '
          '--dest <db>.upgraded.ddb',
        );
      }
      return 3;
    }

    final schema = await (() async {
      try {
        return await gateway.loadSchema();
      } catch (error) {
        writeStderr('Could not load database schema: $error');
        return null;
      }
    })();
    if (schema == null) {
      return 3;
    }

    final mode = _parseRunMode(options.mode) ?? profile.defaultMode;
    final sampleRowLimit = options.sampleRowLimit ?? profile.sampleRowLimit;
    if (!options.silent) {
      writeStderr('Mode: ${mode.wireName}');
      if (options.targetTable != null) {
        writeStderr('Target table: ${options.targetTable}');
      }
    }

    final request = QualityRunRequest(
      targetKind: options.targetTable == null
          ? QualityTargetKind.database
          : QualityTargetKind.table,
      targetDatabasePath: databasePath,
      targetTable: options.targetTable,
      targetQueryId: null,
      targetQuerySql: null,
      profileId: profile.profileId,
      profilePath: profilePath,
      mode: mode,
      sampleRowLimit: sampleRowLimit,
      includeProfiling: true,
      includeValidation: true,
      includeImportReconciliation: profile.includeImportReconciliation,
      includeDuplicateChecks: profile.includeDuplicateChecks,
      requestedAt: DateTime.now().toUtc(),
    );

    final result = await qualityRunner.runQuality(
      request: request,
      schema: schema,
      profile: profile,
      onProgress: options.silent
          ? null
          : (progress) {
              final table = progress.currentTable == null
                  ? ''
                  : ' ${progress.currentTable}';
              final rule = progress.currentRule == null
                  ? ''
                  : ' ${progress.currentRule}';
              writeStderr('${progress.phase}$table$rule');
            },
    );

    if (result.status == QualityRunStatus.cancelled) {
      writeStderr('Quality run cancelled.');
      return 130;
    }
    if (result.status == QualityRunStatus.failed) {
      writeStderr(result.errorMessage ?? 'Quality run failed.');
      return 4;
    }

    try {
      await reportWriter.writeReport(
        result: result,
        options: QualityReportOptions(
          format: format,
          destinationPath: outputPath,
          includeSampleValues: options.includeSampleValues,
          includeViolationDetailRows: options.includeViolationDetails,
          includeImportReconciliation: profile.includeImportReconciliation,
          includeRuleDefinitions: true,
          freshnessStatus: QualityFreshnessStatus.fresh,
        ),
      );
    } catch (error) {
      writeStderr('Could not write quality report: $error');
      return 5;
    }

    final report = HeadlessQualityCliReport(
      databasePath: databasePath,
      profilePath: profilePath,
      outputPath: outputPath,
      format: format.wireName,
      status: result.status.wireName,
      runId: result.runId,
      tablesScanned: result.profileSummaries.length,
      validationIssues: result.validationIssues.length,
      errorIssues: result.errorIssueCount,
      warningIssues: result.warningIssueCount,
      infoIssues: result.infoIssueCount,
      elapsedMilliseconds: DateTime.now().difference(started).inMilliseconds,
    );
    writeStdout(jsonEncode(report.toJson()));
    if (!options.silent) {
      writeStderr('Quality report written to $outputPath');
    }
    return result.errorIssueCount > 0 ? 1 : 0;
  } on FormatException catch (error) {
    writeStderr('Invalid quality command input: ${error.message}');
    return 2;
  } finally {
    if (disposeGateway) {
      await gateway.dispose();
    }
  }
}

QualityReportFormat? _parseReportFormat(String value) {
  return switch (value.trim().toLowerCase()) {
    'json' => QualityReportFormat.json,
    'markdown' || 'md' => QualityReportFormat.markdown,
    'html' => QualityReportFormat.html,
    _ => null,
  };
}

QualityRunMode? _parseRunMode(String? value) {
  return switch (value?.trim().toLowerCase()) {
    'full' => QualityRunMode.full,
    'sampled' => QualityRunMode.sampled,
    _ => null,
  };
}
