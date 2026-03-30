import 'package:flutter/foundation.dart';

import '../logging/app_logger.dart';
import '../../features/workspace/domain/app_config.dart';
import 'decent_bench_theme.dart';
import 'theme_discovery_service.dart';
import 'theme_presets.dart';

class ThemeManager extends ChangeNotifier {
  ThemeManager({ThemeDiscoveryService? discoveryService, AppLogger? logger})
    : _discoveryService = discoveryService ?? ThemeDiscoveryService(),
      _logger = logger ?? const NoOpAppLogger(),
      _currentTheme = buildEmergencyTheme();

  final ThemeDiscoveryService _discoveryService;
  final AppLogger _logger;

  DecentBenchTheme _currentTheme;
  List<DecentBenchTheme> _availableThemes = <DecentBenchTheme>[
    buildEmergencyTheme(),
  ];
  String _resolvedThemesDirectory =
      ThemeDiscoveryService.resolveThemesDirectory(null);
  AppearanceSettings _lastAppearance = AppearanceSettings.defaults();

  DecentBenchTheme get currentTheme => _currentTheme;
  List<DecentBenchTheme> get availableThemes =>
      List<DecentBenchTheme>.unmodifiable(_availableThemes);
  String get resolvedThemesDirectory => _resolvedThemesDirectory;

  Future<void> loadFromConfig(AppearanceSettings appearance) async {
    _lastAppearance = appearance;
    final discovery = await _discoveryService.discover(
      configuredThemesDirectory: appearance.themesDir,
    );
    _resolvedThemesDirectory = discovery.resolvedThemesDirectory;
    _availableThemes = discovery.availableThemes;
    final suppressedBuiltInOverrideIds = <String>{};
    for (final log in discovery.logs) {
      final duplicateBuiltInOverrideId = _duplicateBuiltInOverrideId(
        log,
        discovery.builtInThemesById.keys.toSet(),
      );
      if (duplicateBuiltInOverrideId != null) {
        suppressedBuiltInOverrideIds.add(duplicateBuiltInOverrideId);
        continue;
      }
      final level = _logLevelForMessage(log);
      _logger.log(
        level: level,
        category: 'theme',
        operation: 'discover',
        message: log,
        details: <String, Object?>{
          'themes_dir': discovery.resolvedThemesDirectory,
        },
      );
    }
    if (suppressedBuiltInOverrideIds.isNotEmpty) {
      final themeIds = suppressedBuiltInOverrideIds.toList()..sort();
      _logger.info(
        category: 'theme',
        operation: 'discover',
        message:
            'Ignored ${themeIds.length} stale external built-in theme override${themeIds.length == 1 ? '' : 's'}.',
        details: <String, Object?>{
          'themes_dir': discovery.resolvedThemesDirectory,
          'theme_ids': themeIds,
        },
      );
    }

    final selected = discovery.availableThemesById[appearance.activeTheme];
    if (selected != null) {
      _currentTheme = selected;
      _logger.info(
        category: 'theme',
        operation: 'activate',
        message: 'Activated theme ${selected.id}.',
        details: <String, Object?>{
          'theme_id': selected.id,
          'themes_dir': _resolvedThemesDirectory,
        },
      );
      notifyListeners();
      return;
    }

    _logger.warning(
      category: 'theme',
      operation: 'activate',
      message:
          'Failed to activate "${appearance.activeTheme}". Falling back to built-in classic-dark.',
      details: <String, Object?>{
        'theme_id': appearance.activeTheme,
        'themes_dir': _resolvedThemesDirectory,
      },
    );
    _currentTheme =
        discovery.builtInThemesById['classic-dark'] ?? buildEmergencyTheme();
    notifyListeners();
  }

  Future<void> switchTheme(String themeId) async {
    for (final theme in _availableThemes) {
      if (theme.id == themeId) {
        _currentTheme = theme;
        _logger.info(
          category: 'theme',
          operation: 'preview',
          message: 'Previewing theme ${theme.id}.',
          details: <String, Object?>{'theme_id': theme.id},
        );
        notifyListeners();
        return;
      }
    }

    _logger.warning(
      category: 'theme',
      operation: 'preview',
      message:
          'Requested theme "$themeId" is not available. Keeping ${_currentTheme.id}.',
      details: <String, Object?>{
        'theme_id': themeId,
        'current_theme_id': _currentTheme.id,
      },
    );
  }

  Future<void> reload() => loadFromConfig(_lastAppearance);

  LogVerbosity _logLevelForMessage(String message) {
    if (message.startsWith('Skipping ') ||
        message.startsWith('Failed ') ||
        message.startsWith('Theme warning')) {
      return LogVerbosity.warning;
    }
    return LogVerbosity.information;
  }

  String? _duplicateBuiltInOverrideId(
    String message,
    Set<String> builtInThemeIds,
  ) {
    if (!message.startsWith('Skipping ')) {
      return null;
    }
    final match = RegExp(r': Theme ([A-Za-z0-9_-]+) ').firstMatch(message);
    if (match == null) {
      return null;
    }
    final themeId = match.group(1)!;
    return builtInThemeIds.contains(themeId) ? themeId : null;
  }
}
