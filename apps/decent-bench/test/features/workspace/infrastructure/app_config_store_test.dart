import 'dart:io';

import 'package:decent_bench/features/workspace/domain/app_config.dart';
import 'package:decent_bench/features/workspace/domain/workspace_shell_preferences.dart';
import 'package:decent_bench/features/workspace/infrastructure/app_config_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppConfig round-trips editor settings and snippets to TOML', () {
    final config = AppConfig.defaults().copyWith(
      appearance: const AppearanceSettings(
        activeTheme: 'classic-light',
        themesDir: '/tmp/themes',
      ),
      logging: const LoggingSettings(verbosity: LogVerbosity.debug, logDirectory: 'logs'),
      writeQueue: const WriteQueueSettings(
        enabled: true,
        capacity: 32,
        defaultTimeoutMs: 250,
        maxBatch: 8,
        maxGroupDelayUs: 1000,
      ),
      recentFiles: const <String>['/tmp/a.ddb', '/tmp/b.ddb'],
      defaultPageSize: 250,
      queryHistoryLimit: 12,
      csvDelimiter: ';',
      csvIncludeHeaders: false,
      editorSettings: const EditorSettings(
        autocompleteEnabled: false,
        autocompleteMaxSuggestions: 20,
        formatUppercaseKeywords: false,
        indentSpaces: 4,
        showLineNumbers: false,
      ),
      windowPlacement: const WindowPlacement(
        x: -1800,
        y: 120,
        width: 1440,
        height: 900,
        state: WindowPlacementState.maximized,
        displayId: r'\\.\DISPLAY2',
        displayX: -1920,
        displayY: 0,
        displayWidth: 1920,
        displayHeight: 1080,
      ),
      shellPreferences: const WorkspaceShellPreferences(
        leftColumnFraction: 0.33,
        leftTopFraction: 0.61,
        rightTopFraction: 0.57,
        showSchemaExplorer: true,
        showPropertiesPane: false,
        showResultsPane: true,
        showStatusBar: false,
        editorZoom: 1.1,
        activeResultsTab: ResultsPaneTab.messages,
      ),
      shortcutBindings: <String, String>{
        ...AppConfig.defaultShortcutBindings(),
        'file_exit': 'Ctrl+Shift+Q',
      },
      snippets: const <SqlSnippet>[
        SqlSnippet(
          id: 'custom',
          name: 'Custom',
          trigger: 'custom',
          description: 'A custom snippet',
          body: 'SELECT * FROM custom_table;',
        ),
      ],
    );

    final toml = config.toToml();
    final parsed = AppConfig.fromToml(toml);

    expect(toml, contains('editor_snippet_count = 1'));
    expect(toml, contains('[appearance]'));
    expect(toml, contains('active_theme = "classic-light"'));
    expect(toml, contains('[logging]'));
    expect(toml, contains('verbosity = "debug"'));
    expect(toml, contains('[write_queue]'));
    expect(toml, contains('enabled = true'));
    expect(toml, contains('[window]'));
    expect(toml, contains('state = "maximized"'));
    expect(toml, contains(r'display_id = "\\\\.\\DISPLAY2"'));
    expect(toml, contains('[layout]'));
    expect(toml, contains('[shortcuts]'));
    expect(toml, contains('[[editor_snippets]]'));
    expect(parsed.configVersion, AppConfig.currentConfigVersion);
    expect(parsed.appearance.activeTheme, 'classic-light');
    expect(parsed.appearance.themesDir, '/tmp/themes');
    expect(parsed.logging.verbosity, LogVerbosity.debug);
    expect(parsed.writeQueue.enabled, isTrue);
    expect(parsed.writeQueue.capacity, 32);
    expect(parsed.writeQueue.defaultTimeoutMs, 250);
    expect(parsed.writeQueue.maxBatch, 8);
    expect(parsed.writeQueue.maxGroupDelayUs, 1000);
    expect(
      parsed.writeQueue.toDecentDbOpenOptions(),
      'write_queue_enabled=true;write_queue_capacity=32;'
      'write_queue_default_timeout_ms=250;write_queue_max_batch=8;'
      'write_queue_max_group_delay_us=1000',
    );
    expect(parsed.recentFiles, config.recentFiles);
    expect(parsed.defaultPageSize, 250);
    expect(parsed.queryHistoryLimit, 12);
    expect(parsed.csvDelimiter, ';');
    expect(parsed.csvIncludeHeaders, isFalse);
    expect(parsed.editorSettings.autocompleteEnabled, isFalse);
    expect(parsed.editorSettings.autocompleteMaxSuggestions, 20);
    expect(parsed.editorSettings.formatUppercaseKeywords, isFalse);
    expect(parsed.editorSettings.indentSpaces, 4);
    expect(parsed.editorSettings.showLineNumbers, isFalse);
    expect(parsed.windowPlacement, config.windowPlacement);
    expect(parsed.shellPreferences.leftColumnFraction, closeTo(0.33, 0.001));
    expect(parsed.shellPreferences.showPropertiesPane, isFalse);
    expect(parsed.shellPreferences.showStatusBar, isFalse);
    expect(parsed.shellPreferences.activeResultsTab, ResultsPaneTab.messages);
    expect(parsed.shortcutBindings['file_exit'], 'Ctrl+Shift+Q');
    expect(parsed.snippets.single.trigger, 'custom');
  });

  test('empty snippet lists persist without reintroducing defaults', () {
    final config = AppConfig.defaults().copyWith(
      snippets: const <SqlSnippet>[],
    );

    final parsed = AppConfig.fromToml(config.toToml());

    expect(parsed.snippets, isEmpty);
  });

  test('legacy config without version loads Phase 3 defaults', () {
    const legacyToml = '''
default_page_size = 500
csv_delimiter = ","
csv_include_headers = true
recent_files = ["/tmp/example.ddb"]
''';

    final parsed = AppConfig.fromToml(legacyToml);

    expect(parsed.configVersion, AppConfig.currentConfigVersion);
    expect(
      parsed.appearance.activeTheme,
      AppearanceSettings.defaultActiveTheme,
    );
    expect(parsed.defaultPageSize, 500);
    expect(parsed.writeQueue, WriteQueueSettings.defaults());
    expect(parsed.windowPlacement, isNull);
    expect(parsed.queryHistoryLimit, AppConfig.defaultQueryHistoryLimitValue);
    expect(parsed.editorSettings.autocompleteEnabled, isTrue);
    expect(parsed.shellPreferences, isNotNull);
    expect(
      parsed.shortcutBindings['tools_run_query'],
      AppConfig.defaultShortcutBindings()['tools_run_query'],
    );
    expect(parsed.snippets, isNotEmpty);
  });

  test('legacy inline snippet payload still loads', () {
    const legacyToml = '''
editor_snippets = [{"id":"custom","name":"Custom","trigger":"custom","description":"Legacy","body":"SELECT 1;"}]
''';

    final parsed = AppConfig.fromToml(legacyToml);

    expect(parsed.snippets.single.id, 'custom');
    expect(parsed.snippets.single.description, 'Legacy');
  });

  test('invalid persisted window bounds are ignored', () {
    const toml = '''
[window]
state = "maximized"
x = 100
y = 100
width = 120
height = 80
''';

    final parsed = AppConfig.fromToml(toml);

    expect(parsed.windowPlacement, isNull);
  });

  test('AppConfigStore reads and writes the TOML file on disk', () async {
    final file = File(
      '${Directory.systemTemp.path}/decent-bench-config-${DateTime.now().microsecondsSinceEpoch}.toml',
    );
    final store = AppConfigStore(fileOverride: file);
    final config = AppConfig.defaults().copyWith(
      defaultPageSize: 333,
      csvDelimiter: '|',
      editorSettings: const EditorSettings(
        autocompleteEnabled: false,
        autocompleteMaxSuggestions: 18,
        formatUppercaseKeywords: false,
        indentSpaces: 4,
        showLineNumbers: false,
      ),
      shortcutBindings: <String, String>{
        ...AppConfig.defaultShortcutBindings(),
        'tools_run_query': 'Ctrl+Shift+Enter',
      },
    );

    addTearDown(() async {
      if (await file.exists()) {
        await file.delete();
      }
    });

    await store.save(config);

    final rawToml = await file.readAsString();
    final loaded = await store.load();

    expect(store.describeLocation(), file.path);
    expect(rawToml, contains('default_page_size = 333'));
    expect(rawToml, contains('csv_delimiter = "|"'));
    expect(rawToml, contains('tools_run_query = "Ctrl+Shift+Enter"'));
    expect(loaded.defaultPageSize, 333);
    expect(loaded.csvDelimiter, '|');
    expect(loaded.editorSettings.autocompleteEnabled, isFalse);
    expect(loaded.editorSettings.showLineNumbers, isFalse);
    expect(loaded.shortcutBindings['tools_run_query'], 'Ctrl+Shift+Enter');
  });

  test('pushRecentFile keeps unique ordering and trims the list', () {
    var config = AppConfig.defaults();
    for (var i = 0; i < AppConfig.maxRecentFiles + 2; i++) {
      config = config.pushRecentFile('/tmp/$i.ddb');
    }

    config = config.pushRecentFile('/tmp/3.ddb');

    expect(config.recentFiles.first, '/tmp/3.ddb');
    expect(config.recentFiles.length, AppConfig.maxRecentFiles);
    expect(config.recentFiles.where((item) => item == '/tmp/3.ddb').length, 1);
  });

  test('snippet helpers update and remove snippets deterministically', () {
    final original = AppConfig.defaults();
    final inserted = original.upsertSnippet(
      const SqlSnippet(
        id: 'ad-hoc',
        name: 'Ad Hoc',
        trigger: 'adhoc',
        body: 'SELECT 1;',
      ),
    );
    final updated = inserted.upsertSnippet(
      const SqlSnippet(
        id: 'ad-hoc',
        name: 'Ad Hoc',
        trigger: 'adhoc',
        description: 'Updated',
        body: 'SELECT 2;',
      ),
    );

    expect(
      updated.snippets.where((snippet) => snippet.id == 'ad-hoc').single.body,
      'SELECT 2;',
    );
    expect(
      updated.removeSnippet('ad-hoc').snippets.any((s) => s.id == 'ad-hoc'),
      isFalse,
    );
  });
}
