import 'dart:io';

import 'package:decent_bench/app/theme_system/decent_bench_theme.dart';
import 'package:decent_bench/app/theme_system/theme_discovery_service.dart';
import 'package:decent_bench/app/theme_system/theme_manager.dart';
import 'package:decent_bench/app/theme_system/theme_presets.dart';
import 'package:decent_bench/features/workspace/domain/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('built-in fallback theme loads when external theme fails', () async {
    final directory = await Directory.systemTemp.createTemp(
      'decent-bench-themes-invalid-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File('${directory.path}/broken.toml');
    await file.writeAsString('''
name = "Broken"
id = "broken"
version = "1.0.0"

[compatibility]
min_decent_bench_version = "0.1.0"

[colors]
accent = "#12"
''');

    final manager = ThemeManager();
    addTearDown(manager.dispose);

    await manager.loadFromConfig(
      AppearanceSettings(activeTheme: 'broken', themesDir: directory.path),
    );

    expect(manager.currentTheme.id, 'classic-dark');
    expect(
      manager.availableThemes.any((theme) => theme.id == 'broken'),
      isFalse,
    );
  });

  test('previewed themes can be restored from saved config', () async {
    final manager = ThemeManager();
    addTearDown(manager.dispose);

    const savedAppearance = AppearanceSettings(
      activeTheme: 'classic-dark',
      themesDir: null,
    );

    await manager.loadFromConfig(savedAppearance);
    expect(manager.currentTheme.id, 'classic-dark');

    await manager.switchTheme('classic-light');
    expect(manager.currentTheme.id, 'classic-light');

    await manager.loadFromConfig(savedAppearance);
    expect(manager.currentTheme.id, 'classic-dark');
  });

  test(
    'stale external built-in overrides are summarized instead of warned individually',
    () async {
      final logger = RecordingAppLogger(minimumLevel: LogVerbosity.debug);
      final manager = ThemeManager(
        discoveryService: _FakeThemeDiscoveryService(),
        logger: logger,
      );
      addTearDown(manager.dispose);

      await manager.loadFromConfig(
        const AppearanceSettings(activeTheme: 'classic-dark'),
      );

      expect(
        logger.entries.where(
          (entry) =>
              entry.category == 'theme' &&
              entry.level == LogVerbosity.warning &&
              entry.message.contains('classic-dark'),
        ),
        isEmpty,
      );
      expect(
        logger.entries.any(
          (entry) =>
              entry.category == 'theme' &&
              entry.level == LogVerbosity.information &&
              entry.message.contains(
                'Ignored 2 stale external built-in theme overrides.',
              ),
        ),
        isTrue,
      );
    },
  );
}

class _FakeThemeDiscoveryService extends ThemeDiscoveryService {
  @override
  Future<ThemeDiscoveryResult> discover({
    String? configuredThemesDirectory,
  }) async {
    final classicDark = buildEmergencyTheme(
      id: 'classic-dark',
      name: 'Classic Dark',
    );
    final classicLight = buildEmergencyTheme(
      brightness: Brightness.light,
      id: 'classic-light',
      name: 'Classic Light',
    );
    return ThemeDiscoveryResult(
      availableThemesById: <String, DecentBenchTheme>{
        'classic-dark': classicDark,
      },
      builtInThemesById: <String, DecentBenchTheme>{
        'classic-dark': classicDark,
        'classic-light': classicLight,
      },
      resolvedThemesDirectory: '/tmp/themes',
      logs: const <String>[
        'Skipping /tmp/themes/classic-dark.toml: Theme classic-dark is incompatible with Decent Bench 1.0.0.',
        'Skipping /tmp/themes/classic-light.toml: Theme classic-light is incompatible with Decent Bench 1.0.0.',
        'Skipping /tmp/themes/custom.toml: Theme custom is incompatible with Decent Bench 1.0.0.',
      ],
    );
  }
}
