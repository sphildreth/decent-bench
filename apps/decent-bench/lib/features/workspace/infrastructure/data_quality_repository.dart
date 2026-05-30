import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../app/app_support_paths.dart';
import '../domain/data_quality_models.dart';

class DataQualityRepository {
  DataQualityRepository({Directory? rootOverride})
    : _rootOverride = rootOverride;

  final Directory? _rootOverride;

  Directory workspaceQualityDirectory(String databasePath) {
    final root =
        _rootOverride ??
        Directory(AppSupportPaths.resolveWorkspaceStateDirectoryPath());
    final encoded = base64Url
        .encode(utf8.encode(databasePath))
        .replaceAll('=', '');
    return Directory(p.join(root.path, encoded, 'quality'));
  }

  Directory _profilesDirectory(String databasePath) {
    return Directory(
      p.join(workspaceQualityDirectory(databasePath).path, 'profiles'),
    );
  }

  Directory _runsDirectory(String databasePath) {
    return Directory(
      p.join(workspaceQualityDirectory(databasePath).path, 'runs'),
    );
  }

  Directory _importsDirectory(String databasePath) {
    return Directory(
      p.join(workspaceQualityDirectory(databasePath).path, 'imports'),
    );
  }

  File _defaultProfileFile(String databasePath) {
    return File(
      p.join(
        workspaceQualityDirectory(databasePath).path,
        'default-profile.json',
      ),
    );
  }

  Future<void> saveProfile({
    required String databasePath,
    required QualityProfileDocument profile,
  }) async {
    final errors = profile.validate();
    if (errors.isNotEmpty) {
      throw FormatException(
        'Invalid quality profile: ${errors.map((item) => item.toString()).join('; ')}',
      );
    }
    final file = File(
      p.join(
        _profilesDirectory(databasePath).path,
        '${profile.profileId}.toml',
      ),
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(profile.toToml());
  }

  Future<List<QualityProfileDocument>> loadProfiles(String databasePath) async {
    final directory = _profilesDirectory(databasePath);
    if (!await directory.exists()) {
      return const <QualityProfileDocument>[];
    }
    final profiles = <QualityProfileDocument>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.toml')) {
        continue;
      }
      profiles.add(
        QualityProfileDocument.fromToml(await entity.readAsString()),
      );
    }
    profiles.sort((left, right) => left.name.compareTo(right.name));
    return profiles;
  }

  Future<QualityProfileDocument?> loadProfileById({
    required String databasePath,
    required String profileId,
  }) async {
    final file = File(
      p.join(_profilesDirectory(databasePath).path, '$profileId.toml'),
    );
    if (!await file.exists()) {
      return null;
    }
    return QualityProfileDocument.fromToml(await file.readAsString());
  }

  Future<QualityProfileDocument> importProfileFromPath({
    required String databasePath,
    required String sourcePath,
  }) async {
    _rejectPathTraversal(sourcePath);
    final profile = QualityProfileDocument.fromToml(
      await File(sourcePath).readAsString(),
    );
    await saveProfile(databasePath: databasePath, profile: profile);
    return profile;
  }

  Future<void> exportProfileToPath({
    required QualityProfileDocument profile,
    required String destinationPath,
  }) async {
    _rejectPathTraversal(destinationPath);
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(profile.toToml());
  }

  Future<void> deleteProfile({
    required String databasePath,
    required String profileId,
  }) async {
    final file = File(
      p.join(_profilesDirectory(databasePath).path, '$profileId.toml'),
    );
    if (await file.exists()) {
      await file.delete();
    }
    final defaultId = await loadDefaultProfileId(databasePath);
    if (defaultId == profileId) {
      final pointer = _defaultProfileFile(databasePath);
      if (await pointer.exists()) {
        await pointer.delete();
      }
    }
  }

  Future<void> setDefaultProfile({
    required String databasePath,
    required String profileId,
  }) async {
    final file = _defaultProfileFile(databasePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(<String, Object?>{'profile_id': profileId}),
    );
  }

  Future<String?> loadDefaultProfileId(String databasePath) async {
    final file = _defaultProfileFile(databasePath);
    if (!await file.exists()) {
      return null;
    }
    final map = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    return map['profile_id'] as String?;
  }

  Future<QualityProfileDocument?> loadDefaultProfile(
    String databasePath,
  ) async {
    final id = await loadDefaultProfileId(databasePath);
    if (id == null || id.trim().isEmpty) {
      return null;
    }
    return loadProfileById(databasePath: databasePath, profileId: id);
  }

  Future<void> saveRunResult({
    required String databasePath,
    required QualityRunResult result,
  }) async {
    final file = File(
      p.join(
        _runsDirectory(databasePath).path,
        result.runId,
        'quality-result.json',
      ),
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(result.toJson()),
    );
  }

  Future<QualityRunResult?> loadRunResult({
    required String databasePath,
    required String runId,
  }) async {
    final file = File(
      p.join(_runsDirectory(databasePath).path, runId, 'quality-result.json'),
    );
    if (!await file.exists()) {
      return null;
    }
    return QualityRunResult.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, Object?>,
    );
  }

  Future<List<QualityRunResult>> loadRecentRuns(String databasePath) async {
    final directory = _runsDirectory(databasePath);
    if (!await directory.exists()) {
      return const <QualityRunResult>[];
    }
    final runs = <QualityRunResult>[];
    await for (final entity in directory.list()) {
      if (entity is! Directory) {
        continue;
      }
      final file = File(p.join(entity.path, 'quality-result.json'));
      if (!await file.exists()) {
        continue;
      }
      runs.add(
        QualityRunResult.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, Object?>,
        ),
      );
    }
    runs.sort((left, right) => right.startedAt.compareTo(left.startedAt));
    return runs;
  }

  Future<void> saveViolationDetails({
    required String databasePath,
    required String runId,
    required String issueId,
    required List<ViolationRowReference> rows,
  }) async {
    final file = violationDetailsFile(
      databasePath: databasePath,
      runId: runId,
      issueId: issueId,
    );
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    try {
      for (final row in rows) {
        sink.writeln(jsonEncode(row.toJson()));
      }
    } finally {
      await sink.close();
    }
  }

  File violationDetailsFile({
    required String databasePath,
    required String runId,
    required String issueId,
  }) {
    return File(
      p.join(
        _runsDirectory(databasePath).path,
        runId,
        'violations',
        '$issueId.jsonl',
      ),
    );
  }

  Future<List<ViolationRowReference>> loadViolationPage({
    required String databasePath,
    required String runId,
    required String issueId,
    required int pageSize,
    required int pageIndex,
  }) async {
    final file = violationDetailsFile(
      databasePath: databasePath,
      runId: runId,
      issueId: issueId,
    );
    if (!await file.exists()) {
      return const <ViolationRowReference>[];
    }
    final start = pageSize * pageIndex;
    final rows = <ViolationRowReference>[];
    var index = 0;
    await for (final line
        in file
            .openRead()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (index++ < start) {
        continue;
      }
      if (rows.length >= pageSize) {
        break;
      }
      if (line.trim().isEmpty) {
        continue;
      }
      rows.add(
        ViolationRowReference.fromJson(
          jsonDecode(line) as Map<String, Object?>,
        ),
      );
    }
    return rows;
  }

  Future<void> saveImportReconciliation({
    required String databasePath,
    required ImportReconciliationSummary reconciliation,
  }) async {
    final id = reconciliation.importJobId ?? generateQualityUuid();
    final file = File(p.join(_importsDirectory(databasePath).path, '$id.json'));
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(reconciliation.toJson()),
    );
  }

  Future<ImportReconciliationSummary?> loadLatestImportReconciliation({
    required String databasePath,
    String? tableName,
  }) async {
    final directory = _importsDirectory(databasePath);
    if (!await directory.exists()) {
      return null;
    }
    final records = <ImportReconciliationSummary>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) {
        continue;
      }
      final record = ImportReconciliationSummary.fromJson(
        jsonDecode(await entity.readAsString()) as Map<String, Object?>,
      );
      if (tableName == null ||
          record.tableMappings.any((item) => item.targetTable == tableName)) {
        records.add(record);
      }
    }
    records.sort((left, right) {
      final leftTime = left.completedAt ?? left.startedAt ?? DateTime(0);
      final rightTime = right.completedAt ?? right.startedAt ?? DateTime(0);
      return rightTime.compareTo(leftTime);
    });
    return records.isEmpty ? null : records.first;
  }

  void _rejectPathTraversal(String path) {
    final parts = p.split(p.normalize(path));
    if (parts.contains('..')) {
      throw const FormatException(
        'Quality file paths must not contain path traversal.',
      );
    }
  }
}
