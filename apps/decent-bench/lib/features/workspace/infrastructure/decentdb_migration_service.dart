import 'dart:io';

import 'package:path/path.dart' as p;

import 'decentdb_native_release_asset.dart';

typedef DecentDbMigrationToolPathResolver = Future<String> Function();
typedef DecentDbMigrationProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

class DecentDbMigrationResult {
  const DecentDbMigrationResult({
    required this.sourcePath,
    required this.destinationPath,
    required this.toolPath,
    required this.stdoutText,
    required this.stderrText,
    required this.elapsed,
  });

  final String sourcePath;
  final String destinationPath;
  final String toolPath;
  final String stdoutText;
  final String stderrText;
  final Duration elapsed;
}

class DecentDbInPlaceMigrationResult {
  const DecentDbInPlaceMigrationResult({
    required this.originalPath,
    required this.backupPath,
    required this.finalPath,
    required this.carryForwardSidecars,
    required this.toolPath,
    required this.stdoutText,
    required this.stderrText,
    required this.elapsed,
  });

  final String originalPath;
  final String backupPath;
  final String finalPath;
  final List<String> carryForwardSidecars;
  final String toolPath;
  final String stdoutText;
  final String stderrText;
  final Duration elapsed;
}

class DecentDbMigrationFailure implements Exception {
  const DecentDbMigrationFailure({
    required this.message,
    this.exitCode,
    this.stdoutText = '',
    this.stderrText = '',
    this.toolPath,
  });

  final String message;
  final int? exitCode;
  final String stdoutText;
  final String stderrText;
  final String? toolPath;

  String get detailText {
    final parts = <String>[
      message,
      if (exitCode != null) 'Exit code: $exitCode',
      if (toolPath != null && toolPath!.isNotEmpty) 'Tool: $toolPath',
      if (stdoutText.trim().isNotEmpty) 'Output:\n${stdoutText.trim()}',
      if (stderrText.trim().isNotEmpty) 'Error output:\n${stderrText.trim()}',
    ];
    return parts.join('\n\n');
  }

  @override
  String toString() => detailText;
}

class DecentDbMigrationService {
  DecentDbMigrationService({
    DecentDbMigrationToolPathResolver? toolPathResolver,
    DecentDbMigrationProcessRunner? processRunner,
    Map<String, String>? environment,
  }) : _toolPathResolver = toolPathResolver,
       _processRunner = processRunner ?? _defaultProcessRunner,
       _environment = environment ?? Platform.environment;

  static const String toolBaseName = 'decentdb-migrate';

  final DecentDbMigrationToolPathResolver? _toolPathResolver;
  final DecentDbMigrationProcessRunner _processRunner;
  final Map<String, String> _environment;

  static bool isUnsupportedFormatVersionMessage(String? message) {
    final normalized = message?.toLowerCase() ?? '';
    return normalized.contains('unsupported database format version') ||
        normalized.contains('unsupportedformatversion') ||
        normalized.contains('legacy format version') ||
        normalized.contains('database is in legacy format version');
  }

  static String migrationToolFileName({bool isWindows = false}) =>
      isWindows ? '$toolBaseName.exe' : toolBaseName;

  Future<String> suggestDestinationPath(String sourcePath) async {
    final directory = p.dirname(sourcePath);
    final baseName = p.basenameWithoutExtension(sourcePath).trim().isEmpty
        ? 'database'
        : p.basenameWithoutExtension(sourcePath).trim();
    final first = p.join(directory, '${baseName}_migrated.ddb');
    if (!await File(first).exists()) {
      return first;
    }
    for (var index = 2; index < 1000; index++) {
      final candidate = p.join(directory, '${baseName}_migrated_$index.ddb');
      if (!await File(candidate).exists()) {
        return candidate;
      }
    }
    return p.join(
      directory,
      '${baseName}_migrated_${DateTime.now().millisecondsSinceEpoch}.ddb',
    );
  }

  Future<DecentDbMigrationResult> migrate({
    required String sourcePath,
    required String destinationPath,
  }) async {
    final normalizedSource = p.normalize(sourcePath.trim());
    final normalizedDestination = p.normalize(destinationPath.trim());
    if (normalizedSource.isEmpty) {
      throw const DecentDbMigrationFailure(
        message: 'Choose a legacy DecentDB source file to migrate.',
      );
    }
    if (normalizedDestination.isEmpty) {
      throw const DecentDbMigrationFailure(
        message: 'Choose a destination path for the migrated database.',
      );
    }
    if (p.equals(normalizedSource, normalizedDestination)) {
      throw const DecentDbMigrationFailure(
        message:
            'Migration writes to a new DecentDB file. Choose a destination different from the source file.',
      );
    }

    final sourceFile = File(normalizedSource);
    if (!await sourceFile.exists()) {
      throw DecentDbMigrationFailure(
        message:
            'Legacy DecentDB source file does not exist: $normalizedSource',
      );
    }
    final destinationFile = File(normalizedDestination);
    if (await destinationFile.exists()) {
      throw DecentDbMigrationFailure(
        message:
            'The migration destination already exists. Choose a new file so the original data is not overwritten: $normalizedDestination',
      );
    }

    await destinationFile.parent.create(recursive: true);
    final toolPath = await resolveToolPath();
    final stopwatch = Stopwatch()..start();
    final result = await _processRunner(toolPath, <String>[
      '--source',
      normalizedSource,
      '--dest',
      normalizedDestination,
    ]);
    stopwatch.stop();

    final stdoutText = _processText(result.stdout);
    final stderrText = _processText(result.stderr);
    if (result.exitCode != 0) {
      throw DecentDbMigrationFailure(
        message: 'DecentDB migration failed.',
        exitCode: result.exitCode,
        stdoutText: stdoutText,
        stderrText: stderrText,
        toolPath: toolPath,
      );
    }
    if (!await destinationFile.exists()) {
      throw DecentDbMigrationFailure(
        message:
            'DecentDB migration completed but did not create the expected destination file.',
        exitCode: result.exitCode,
        stdoutText: stdoutText,
        stderrText: stderrText,
        toolPath: toolPath,
      );
    }

    return DecentDbMigrationResult(
      sourcePath: normalizedSource,
      destinationPath: normalizedDestination,
      toolPath: toolPath,
      stdoutText: stdoutText,
      stderrText: stderrText,
      elapsed: stopwatch.elapsed,
    );
  }

  static const String _inPlaceBackupSuffix = '.v13.bak';

  static const List<String> _carryForwardSidecarSuffixes = <String>[
    '.wal',
    '.sync-journal',
  ];

  static const List<String> _rebuildableSidecarSuffixes = <String>[
    '.coord',
  ];

  static String backupPathFor(String sourcePath) {
    final normalized = p.normalize(sourcePath.trim());
    return '$normalized$_inPlaceBackupSuffix';
  }

  static Iterable<String> candidateCarryForwardSidecarPaths(String sourcePath) {
    return _carryForwardSidecarSuffixes.map((suffix) => '$sourcePath$suffix');
  }

  static Iterable<String> candidateRebuildableSidecarPaths(String sourcePath) {
    return _rebuildableSidecarSuffixes.map((suffix) => '$sourcePath$suffix');
  }

  Future<String> suggestInPlaceTempPath(String sourcePath) async {
    final directory = p.dirname(sourcePath);
    final baseName = p.basenameWithoutExtension(sourcePath).trim().isEmpty
        ? 'database'
        : p.basenameWithoutExtension(sourcePath).trim();
    final extension = p.extension(sourcePath).isEmpty
        ? '.ddb'
        : p.extension(sourcePath);
    final stamp =
        '${DateTime.now().millisecondsSinceEpoch}_${_randomToken()}';
    return p.join(directory, '$baseName.migrate.$stamp$extension');
  }

  static String _randomToken() {
    final mix = DateTime.now().microsecondsSinceEpoch ^
        DateTime.now().microsecondsSinceEpoch;
    final hex = mix.toRadixString(16);
    if (hex.length >= 10) {
      return hex.substring(0, 10);
    }
    return hex.padLeft(10, '0');
  }

  Future<DecentDbInPlaceMigrationResult> migrateInPlace({
    required String sourcePath,
  }) async {
    final normalizedSource = p.normalize(sourcePath.trim());
    if (normalizedSource.isEmpty) {
      throw const DecentDbMigrationFailure(
        message: 'Choose a legacy DecentDB source file to migrate in place.',
      );
    }
    final sourceFile = File(normalizedSource);
    if (!await sourceFile.exists()) {
      throw DecentDbMigrationFailure(
        message:
            'Legacy DecentDB source file does not exist: $normalizedSource',
      );
    }

    final backupPath = backupPathFor(normalizedSource);
    final backupFile = File(backupPath);
    if (await backupFile.exists()) {
      throw DecentDbMigrationFailure(
        message:
            'A backup already exists at the expected in-place location. '
            'Move or rename $backupPath so the migration can preserve the '
            'previous original.',
      );
    }
    final originalSidecarPaths = <String>[];
    for (final candidate in candidateCarryForwardSidecarPaths(normalizedSource)) {
      if (await File(candidate).exists()) {
        originalSidecarPaths.add(candidate);
      }
    }

    final tempDestination = await suggestInPlaceTempPath(normalizedSource);
    final tempDestinationFile = File(tempDestination);
    final tempWal = File('$tempDestination.wal');
    if (await tempDestinationFile.exists() || await tempWal.exists()) {
      throw DecentDbMigrationFailure(
        message:
            'Temporary migration destination is not clean. Remove $tempDestination '
            '(and any .wal sidecar) and retry.',
      );
    }

    final stopwatch = Stopwatch()..start();
    String toolPath = '';
    String stdoutText = '';
    String stderrText = '';
    try {
      final migrationResult = await migrate(
        sourcePath: normalizedSource,
        destinationPath: tempDestination,
      );
      toolPath = migrationResult.toolPath;
      stdoutText = migrationResult.stdoutText;
      stderrText = migrationResult.stderrText;
    } catch (error) {
      await _safeDelete(tempDestinationFile);
      await _safeDelete(tempWal);
      rethrow;
    }

    if (!await tempDestinationFile.exists()) {
      await _safeDelete(tempWal);
      throw DecentDbMigrationFailure(
        message:
            'DecentDB migration completed but did not create the expected '
            'temporary destination file. The original file is untouched.',
        exitCode: 0,
        stdoutText: stdoutText,
        stderrText: stderrText,
        toolPath: toolPath,
      );
    }

    try {
      await sourceFile.rename(backupPath);
    } catch (error) {
      await _safeDelete(tempDestinationFile);
      await _safeDelete(tempWal);
      throw DecentDbMigrationFailure(
        message:
            'Migration succeeded but moving the original file aside failed. '
            'The original database at $normalizedSource is unchanged.',
        stdoutText: stdoutText,
        stderrText: stderrText,
        toolPath: toolPath,
      );
    }

    final sidecarBackupPaths = <String>[];
    for (final originalSidecarPath in originalSidecarPaths) {
      final sidecarFile = File(originalSidecarPath);
      if (!await sidecarFile.exists()) {
        continue;
      }
      final carriedDestination = '$originalSidecarPath$_inPlaceBackupSuffix';
      try {
        await sidecarFile.rename(carriedDestination);
        sidecarBackupPaths.add(carriedDestination);
      } catch (error) {
        await _restoreInPlaceArtifacts(
          sourceFile: sourceFile,
          backupPath: backupPath,
          originalSidecarPaths: originalSidecarPaths,
          sidecarBackupPaths: sidecarBackupPaths,
        );
        await _safeDelete(tempDestinationFile);
        await _safeDelete(tempWal);
        throw DecentDbMigrationFailure(
          message:
              'Migration succeeded but preserving a sidecar next to the backup '
              'failed. The original database at $normalizedSource has been '
              'restored from $backupPath.',
          stdoutText: stdoutText,
          stderrText: stderrText,
          toolPath: toolPath,
        );
      }
    }

    try {
      await tempDestinationFile.rename(normalizedSource);
    } catch (error) {
      await _restoreInPlaceArtifacts(
        sourceFile: sourceFile,
        backupPath: backupPath,
        originalSidecarPaths: originalSidecarPaths,
        sidecarBackupPaths: sidecarBackupPaths,
      );
      throw DecentDbMigrationFailure(
        message:
            'Migration succeeded but installing the upgraded file into place '
            'failed. The original database at $normalizedSource has been '
            'restored from $backupPath.',
        stdoutText: stdoutText,
        stderrText: stderrText,
        toolPath: toolPath,
      );
    }

    await _safeDelete(tempWal);
    stopwatch.stop();
    return DecentDbInPlaceMigrationResult(
      originalPath: normalizedSource,
      backupPath: backupPath,
      finalPath: normalizedSource,
      carryForwardSidecars: sidecarBackupPaths,
      toolPath: toolPath,
      stdoutText: stdoutText,
      stderrText: stderrText,
      elapsed: stopwatch.elapsed,
    );
  }

  Future<void> _safeDelete(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> _restoreInPlaceArtifacts({
    required File sourceFile,
    required String backupPath,
    required List<String> originalSidecarPaths,
    required List<String> sidecarBackupPaths,
  }) async {
    if (await sourceFile.exists()) {
      try {
        await sourceFile.delete();
      } catch (_) {}
    }
    if (await File(backupPath).exists()) {
      try {
        await File(backupPath).rename(sourceFile.path);
      } catch (_) {}
    }
    final reversed = sidecarBackupPaths.reversed.toList();
    for (var i = 0; i < reversed.length; i++) {
      final backupForSidecar = reversed[i];
      final originalSidecarPath = originalSidecarPaths[
          originalSidecarPaths.length - 1 - i];
      if (!await File(originalSidecarPath).exists() &&
          await File(backupForSidecar).exists()) {
        try {
          await File(backupForSidecar).rename(originalSidecarPath);
        } catch (_) {}
      }
    }
  }

  Future<String> resolveToolPath() async {
    final injectedResolver = _toolPathResolver;
    if (injectedResolver != null) {
      return injectedResolver();
    }

    for (final candidate in _configuredToolCandidates()) {
      if (candidate.isNotEmpty && File(candidate).existsSync()) {
        return candidate;
      }
    }

    try {
      return await DecentDbNativeReleaseAsset.locate()
          .ensureMigrationToolAvailable();
    } catch (error) {
      final pathCandidate = _findExecutableOnPath(
        migrationToolFileName(isWindows: Platform.isWindows),
      );
      if (pathCandidate != null) {
        return pathCandidate;
      }

      throw DecentDbMigrationFailure(
        message:
            'Unable to resolve the official decentdb-migrate tool. Install it from the DecentDB release bundle, place it on PATH, or set DECENTDB_MIGRATE_PATH.',
        stderrText: error.toString(),
      );
    }
  }

  Iterable<String> _configuredToolCandidates() sync* {
    yield _environment['DECENTDB_MIGRATE_PATH'] ?? '';
    yield _environment['DECENTDB_MIGRATE'] ?? '';

    final toolFile = migrationToolFileName(isWindows: Platform.isWindows);
    final executableDir = p.dirname(Platform.resolvedExecutable);
    yield p.join(executableDir, toolFile);
    yield p.join(executableDir, 'bin', toolFile);
    yield p.join(executableDir, 'libexec', toolFile);

    yield* DecentDbNativeReleaseAsset.cachedMigrationToolCandidates(
      searchRoots: <String>[Directory.current.path, executableDir],
      platform: _currentNativeAssetPlatform(),
    );
  }

  String? _findExecutableOnPath(String executableName) {
    final pathValue = _environment['PATH'];
    if (pathValue == null || pathValue.trim().isEmpty) {
      return null;
    }
    for (final directory in pathValue.split(Platform.isWindows ? ';' : ':')) {
      if (directory.trim().isEmpty) {
        continue;
      }
      final candidate = p.join(directory, executableName);
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  static Future<ProcessResult> _defaultProcessRunner(
    String executable,
    List<String> arguments,
  ) {
    return Process.run(executable, arguments, runInShell: false);
  }

  static String _processText(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is List<int>) {
      return String.fromCharCodes(value);
    }
    return value.toString();
  }

  static DecentDbNativeAssetPlatform _currentNativeAssetPlatform() {
    if (Platform.isLinux) {
      return DecentDbNativeAssetPlatform.linux;
    }
    if (Platform.isMacOS) {
      return DecentDbNativeAssetPlatform.macos;
    }
    if (Platform.isWindows) {
      return DecentDbNativeAssetPlatform.windows;
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
}
