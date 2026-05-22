import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/data_quality_models.dart';
import '../domain/data_quality_reports.dart';
import '../domain/data_quality_rules.dart';
import '../domain/workspace_models.dart';
import '../infrastructure/data_quality_report_writer.dart';
import '../infrastructure/data_quality_repository.dart';
import '../infrastructure/data_quality_runner.dart';

class DataQualityController extends ChangeNotifier {
  DataQualityController({
    required DataQualityRunner runner,
    required DataQualityRepository repository,
    DataQualityReportWriter? reportWriter,
  }) : _runner = runner,
       _repository = repository,
       _reportWriter = reportWriter ?? const DataQualityReportWriter();

  final DataQualityRunner _runner;
  final DataQualityRepository _repository;
  final DataQualityReportWriter _reportWriter;

  String? databasePath;
  SchemaSnapshot schema = SchemaSnapshot.empty();
  List<QualityProfileDocument> profiles = const <QualityProfileDocument>[];
  QualityProfileDocument? currentProfile;
  QualityRunResult? currentRun;
  List<QualityRunResult> recentRuns = const <QualityRunResult>[];
  DataQualityProgress? progress;
  QualityFreshnessStatus freshness = QualityFreshnessStatus.noRun;
  String? errorMessage;
  String? selectedTableName;
  ValidationIssueSummary? selectedIssue;

  DataQualityCancellationToken? _activeCancellation;

  bool get isRunning => currentRun?.status == QualityRunStatus.running;
  bool get hasDatabase =>
      databasePath != null && databasePath!.trim().isNotEmpty;

  Future<void> attachWorkspace({
    required String? databasePath,
    required SchemaSnapshot schema,
  }) async {
    this.databasePath = databasePath;
    this.schema = schema;
    errorMessage = null;
    if (databasePath == null || databasePath.trim().isEmpty) {
      profiles = const <QualityProfileDocument>[];
      currentProfile = null;
      currentRun = null;
      recentRuns = const <QualityRunResult>[];
      freshness = QualityFreshnessStatus.noRun;
      notifyListeners();
      return;
    }
    await loadProfiles();
    await loadRecentRuns();
    if (currentProfile == null) {
      final defaultProfile = const DefaultQualityProfileBuilder().build(
        schema: schema,
      );
      currentProfile = defaultProfile;
    }
    freshness = computeFreshness(currentRun);
    notifyListeners();
  }

  Future<void> loadProfiles() async {
    final path = databasePath;
    if (path == null) {
      return;
    }
    profiles = await _repository.loadProfiles(path);
    currentProfile = await _repository.loadDefaultProfile(path);
    currentProfile ??= profiles.isEmpty ? null : profiles.first;
    notifyListeners();
  }

  Future<void> saveProfile(QualityProfileDocument profile) async {
    final path = _requireDatabasePath();
    await _repository.saveProfile(databasePath: path, profile: profile);
    await _repository.setDefaultProfile(
      databasePath: path,
      profileId: profile.profileId,
    );
    currentProfile = profile;
    await loadProfiles();
  }

  Future<void> deleteProfile(String profileId) async {
    final path = _requireDatabasePath();
    await _repository.deleteProfile(databasePath: path, profileId: profileId);
    await loadProfiles();
  }

  Future<void> duplicateProfile(QualityProfileDocument profile) async {
    final now = DateTime.now().toUtc();
    final copy = profile.copyWith(
      profileId: generateQualityUuid(),
      name: '${profile.name} Copy',
      createdAt: now,
      updatedAt: now,
      rules: <ValidationRule>[
        for (final rule in profile.rules)
          rule.copyWith(id: generateQualityUuid()),
      ],
    );
    await saveProfile(copy);
  }

  Future<void> importProfile(String sourcePath) async {
    final path = _requireDatabasePath();
    final profile = await _repository.importProfileFromPath(
      databasePath: path,
      sourcePath: sourcePath,
    );
    await _repository.setDefaultProfile(
      databasePath: path,
      profileId: profile.profileId,
    );
    await loadProfiles();
  }

  Future<void> exportProfile({
    required QualityProfileDocument profile,
    required String destinationPath,
  }) async {
    await _repository.exportProfileToPath(
      profile: profile,
      destinationPath: destinationPath,
    );
  }

  Future<void> loadRecentRuns() async {
    final path = databasePath;
    if (path == null) {
      return;
    }
    recentRuns = await _repository.loadRecentRuns(path);
    currentRun = recentRuns.isEmpty ? currentRun : recentRuns.first;
    freshness = computeFreshness(currentRun);
    notifyListeners();
  }

  Future<QualityRunResult?> startRun([QualityRunRequest? request]) async {
    final path = _requireDatabasePath();
    if (isRunning) {
      errorMessage = 'A quality run is already running.';
      notifyListeners();
      return null;
    }
    final profile =
        currentProfile ??
        const DefaultQualityProfileBuilder().build(schema: schema);
    final runRequest =
        request ??
        QualityRunRequest(
          targetKind: selectedTableName == null
              ? QualityTargetKind.database
              : QualityTargetKind.table,
          targetDatabasePath: path,
          targetTable: selectedTableName,
          targetQueryId: null,
          targetQuerySql: null,
          profileId: profile.profileId,
          profilePath: null,
          mode: profile.defaultMode,
          sampleRowLimit: profile.sampleRowLimit,
          includeProfiling: true,
          includeValidation: true,
          includeImportReconciliation: profile.includeImportReconciliation,
          includeDuplicateChecks: profile.includeDuplicateChecks,
          requestedAt: DateTime.now().toUtc(),
        );
    _activeCancellation = DataQualityCancellationToken();
    currentRun = QualityRunResult(
      runId: generateQualityUuid(),
      profileId: profile.profileId,
      targetKind: runRequest.targetKind,
      targetLabel: selectedTableName ?? 'Database',
      databasePath: path,
      startedAt: DateTime.now().toUtc(),
      completedAt: null,
      status: QualityRunStatus.running,
      mode: runRequest.mode,
      sampleRowLimit: runRequest.mode == QualityRunMode.sampled
          ? runRequest.sampleRowLimit
          : null,
      schemaFingerprint: '',
      schemaFingerprintAlgorithm: 'schema-json-sha256-v1',
      dataFingerprints: const <QualityDataFingerprint>[],
      profileSummaries: const <TableQualitySummary>[],
      validationIssues: const <ValidationIssueSummary>[],
      importReconciliation: null,
      duplicateSummaries: const <DuplicateSummary>[],
      errorMessage: null,
      warningMessages: const <String>[],
      detailStorePath: null,
    );
    progress = const DataQualityProgress(phase: 'Starting');
    freshness = QualityFreshnessStatus.running;
    errorMessage = null;
    notifyListeners();

    final result = await _runner.runQuality(
      request: runRequest,
      schema: schema,
      profile: profile,
      onProgress: (update) {
        progress = update;
        notifyListeners();
      },
      cancellationToken: _activeCancellation,
    );
    currentRun = result;
    progress = null;
    _activeCancellation = null;
    await _repository.saveRunResult(databasePath: path, result: result);
    await loadRecentRuns();
    freshness = computeFreshness(result);
    notifyListeners();
    return result;
  }

  void cancelRun() {
    _activeCancellation?.cancel();
    progress = const DataQualityProgress(phase: 'Cancelling');
    notifyListeners();
  }

  QualityFreshnessStatus computeFreshness(QualityRunResult? result) {
    if (result == null) {
      return QualityFreshnessStatus.noRun;
    }
    if (result.status == QualityRunStatus.running) {
      return QualityFreshnessStatus.running;
    }
    if (result.status == QualityRunStatus.failed) {
      return QualityFreshnessStatus.failed;
    }
    if (result.schemaFingerprint.isEmpty) {
      return QualityFreshnessStatus.stale;
    }
    final currentSchemaFingerprint = _runner.computeSchemaFingerprint(schema);
    if (result.schemaFingerprint != currentSchemaFingerprint) {
      return QualityFreshnessStatus.stale;
    }
    return QualityFreshnessStatus.fresh;
  }

  Future<List<ViolationRowReference>> loadViolationPage({
    required ValidationIssueSummary issue,
    required int pageSize,
    required int pageIndex,
  }) {
    final path = _requireDatabasePath();
    return _runner.loadViolationPage(
      databasePath: path,
      issue: issue,
      pageSize: pageSize,
      pageIndex: pageIndex,
    );
  }

  Future<void> exportReport(QualityReportOptions options) async {
    final run = currentRun;
    if (run == null) {
      throw StateError('Run a quality profile before exporting a report.');
    }
    await _reportWriter.writeReport(result: run, options: options);
  }

  Future<void> recordImportReconciliation(
    ImportReconciliationSummary reconciliation, {
    String? targetDatabasePath,
  }) async {
    final path = targetDatabasePath ?? databasePath;
    if (path == null || path.trim().isEmpty) {
      return;
    }
    await _repository.saveImportReconciliation(
      databasePath: path,
      reconciliation: reconciliation,
    );
  }

  void selectTable(String? tableName) {
    selectedTableName = tableName;
    notifyListeners();
  }

  void selectIssue(ValidationIssueSummary? issue) {
    selectedIssue = issue;
    notifyListeners();
  }

  String _requireDatabasePath() {
    final path = databasePath;
    if (path == null || path.trim().isEmpty) {
      throw StateError('Open a DecentDB file before using data quality.');
    }
    return path;
  }
}
