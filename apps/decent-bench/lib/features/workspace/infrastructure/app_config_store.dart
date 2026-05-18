import 'dart:io';

import '../../../app/app_support_paths.dart';
import '../../../app/logging/app_logger.dart';
import '../domain/app_config.dart';

abstract class WorkspaceConfigStore {
  Future<AppConfig> load();

  Future<void> save(AppConfig config);

  String describeLocation();
}

class AppConfigStore implements WorkspaceConfigStore {
  AppConfigStore({File? fileOverride, AppLogger? logger})
    : _fileOverride = fileOverride,
      _logger = logger ?? const NoOpAppLogger();

  final File? _fileOverride;
  final AppLogger _logger;

  @override
  Future<AppConfig> load() async {
    final file = _resolveFile();
    if (!await file.exists()) {
      _logger.info(
        category: 'config',
        operation: 'load',
        message: 'Config file does not exist; using defaults.',
        details: <String, Object?>{'path': file.path},
      );
      return AppConfig.defaults();
    }
    try {
      final config = AppConfig.fromToml(await file.readAsString());
      _logger.info(
        category: 'config',
        operation: 'load',
        message: 'Loaded application configuration.',
        details: <String, Object?>{
          'path': file.path,
          'theme_id': config.appearance.activeTheme,
          'verbosity': config.logging.verbosity.name,
        },
      );
      return config;
    } catch (error, stackTrace) {
      _logger.error(
        category: 'config',
        operation: 'load',
        message: 'Failed to load config file; using defaults.',
        details: <String, Object?>{'path': file.path},
        error: error,
        stackTrace: stackTrace,
      );
      return AppConfig.defaults();
    }
  }

  @override
  Future<void> save(AppConfig config) async {
    final file = _resolveFile();
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(config.toToml());
      _logger.info(
        category: 'config',
        operation: 'save',
        message: 'Saved application configuration.',
        details: <String, Object?>{
          'path': file.path,
          'theme_id': config.appearance.activeTheme,
          'verbosity': config.logging.verbosity.name,
        },
      );
    } catch (error, stackTrace) {
      _logger.error(
        category: 'config',
        operation: 'save',
        message: 'Failed to save application configuration.',
        details: <String, Object?>{'path': file.path},
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  String describeLocation() => _resolveFile().path;

  File _resolveFile() {
    if (_fileOverride != null) {
      return _fileOverride;
    }
    return File(AppSupportPaths.resolveConfigFilePath());
  }
}
