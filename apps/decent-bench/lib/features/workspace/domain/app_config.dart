import 'dart:convert';

export 'sql_snippet_model.dart';
export 'editor_settings_model.dart';
export 'logging_settings_model.dart';
export 'write_queue_settings_model.dart';
export 'appearance_settings_model.dart';
export 'window_placement_model.dart';
export 'database_open_settings_model.dart';

import 'sql_snippet_model.dart';
import 'editor_settings_model.dart';
import 'logging_settings_model.dart';
import 'write_queue_settings_model.dart';
import 'appearance_settings_model.dart';
import 'window_placement_model.dart';
import 'database_open_settings_model.dart';
import 'workspace_shell_preferences.dart';

class AppConfig {
  static const int currentConfigVersion = 4;
  static const int defaultPageSizeValue = 1000;
  static const int defaultQueryHistoryLimitValue = 40;
  static const int defaultQueryTimeoutSeconds = 60;
  static const String defaultCsvDelimiter = ',';
  static const bool defaultCsvIncludeHeaders = true;
  static const int maxRecentFiles = 8;
  static const Object _unset = Object();

  const AppConfig({
    required this.configVersion,
    required this.appearance,
    required this.logging,
    required this.writeQueue,
    required this.databaseOpen,
    required this.recentFiles,
    required this.defaultPageSize,
    required this.queryHistoryLimit,
    required this.queryTimeoutSeconds,
    required this.csvDelimiter,
    required this.csvIncludeHeaders,
    required this.editorSettings,
    required this.shellPreferences,
    required this.windowPlacement,
    required this.shortcutBindings,
    required this.snippets,
  });

  final int configVersion;
  final AppearanceSettings appearance;
  final LoggingSettings logging;
  final WriteQueueSettings writeQueue;
  final DatabaseOpenSettings databaseOpen;
  final List<String> recentFiles;
  final int defaultPageSize;
  final int queryHistoryLimit;
  final int queryTimeoutSeconds;
  final String csvDelimiter;
  final bool csvIncludeHeaders;
  final EditorSettings editorSettings;
  final WorkspaceShellPreferences shellPreferences;
  final WindowPlacement? windowPlacement;
  final Map<String, String> shortcutBindings;
  final List<SqlSnippet> snippets;

  factory AppConfig.defaults() {
    return AppConfig(
      configVersion: currentConfigVersion,
      appearance: AppearanceSettings.defaults(),
      logging: LoggingSettings.defaults(),
      writeQueue: WriteQueueSettings.defaults(),
      databaseOpen: DatabaseOpenSettings.defaults(),
      recentFiles: const <String>[],
      defaultPageSize: defaultPageSizeValue,
      queryHistoryLimit: defaultQueryHistoryLimitValue,
      queryTimeoutSeconds: defaultQueryTimeoutSeconds,
      csvDelimiter: defaultCsvDelimiter,
      csvIncludeHeaders: defaultCsvIncludeHeaders,
      editorSettings: EditorSettings.defaults(),
      shellPreferences: WorkspaceShellPreferences.defaults(),
      windowPlacement: null,
      shortcutBindings: defaultShortcutBindings(),
      snippets: defaultSnippets(),
    );
  }

  AppConfig copyWith({
    int? configVersion,
    AppearanceSettings? appearance,
    LoggingSettings? logging,
    WriteQueueSettings? writeQueue,
    DatabaseOpenSettings? databaseOpen,
    List<String>? recentFiles,
    int? defaultPageSize,
    int? queryHistoryLimit,
    int? queryTimeoutSeconds,
    String? csvDelimiter,
    bool? csvIncludeHeaders,
    EditorSettings? editorSettings,
    WorkspaceShellPreferences? shellPreferences,
    Object? windowPlacement = _unset,
    Map<String, String>? shortcutBindings,
    List<SqlSnippet>? snippets,
  }) {
    return AppConfig(
      configVersion: configVersion ?? this.configVersion,
      appearance: appearance ?? this.appearance,
      logging: logging ?? this.logging,
      writeQueue: writeQueue ?? this.writeQueue,
      databaseOpen: databaseOpen ?? this.databaseOpen,
      recentFiles: recentFiles ?? this.recentFiles,
      defaultPageSize: defaultPageSize ?? this.defaultPageSize,
      queryHistoryLimit: queryHistoryLimit ?? this.queryHistoryLimit,
      queryTimeoutSeconds: queryTimeoutSeconds ?? this.queryTimeoutSeconds,
      csvDelimiter: csvDelimiter ?? this.csvDelimiter,
      csvIncludeHeaders: csvIncludeHeaders ?? this.csvIncludeHeaders,
      editorSettings: editorSettings ?? this.editorSettings,
      shellPreferences: shellPreferences ?? this.shellPreferences,
      windowPlacement: windowPlacement == _unset
          ? this.windowPlacement
          : windowPlacement as WindowPlacement?,
      shortcutBindings: shortcutBindings ?? this.shortcutBindings,
      snippets: snippets ?? this.snippets,
    );
  }

  AppConfig pushRecentFile(String path) {
    final updated = <String>[
      path,
      ...recentFiles.where((item) => item != path),
    ];
    return copyWith(recentFiles: updated.take(maxRecentFiles).toList());
  }

  AppConfig upsertSnippet(SqlSnippet snippet) {
    final existingIndex = snippets.indexWhere((item) => item.id == snippet.id);
    final updated = <SqlSnippet>[...snippets];
    if (existingIndex >= 0) {
      updated[existingIndex] = snippet;
    } else {
      updated.add(snippet);
    }
    updated.sort((left, right) => left.name.compareTo(right.name));
    return copyWith(snippets: updated);
  }

  AppConfig removeSnippet(String snippetId) {
    return copyWith(
      snippets: snippets.where((item) => item.id != snippetId).toList(),
    );
  }

  String toToml() {
    final layout = shellPreferences.normalized();
    final buffer = StringBuffer()
      ..writeln('# Decent Bench configuration')
      ..writeln('config_version = $configVersion')
      ..writeln('default_page_size = $defaultPageSize')
      ..writeln('query_history_limit = $queryHistoryLimit')
      ..writeln('query_timeout_seconds = $queryTimeoutSeconds')
      ..writeln('csv_delimiter = ${jsonEncode(csvDelimiter)}')
      ..writeln('csv_include_headers = $csvIncludeHeaders')
      ..writeln('recent_files = ${jsonEncode(recentFiles)}')
      ..writeln(
        'editor_autocomplete_enabled = ${editorSettings.autocompleteEnabled}',
      )
      ..writeln(
        'editor_autocomplete_max_suggestions = ${editorSettings.autocompleteMaxSuggestions}',
      )
      ..writeln(
        'editor_format_uppercase_keywords = ${editorSettings.formatUppercaseKeywords}',
      )
      ..writeln('editor_indent_spaces = ${editorSettings.indentSpaces}')
      ..writeln('editor_show_line_numbers = ${editorSettings.showLineNumbers}')
      ..writeln('editor_snippet_count = ${snippets.length}')
      ..writeln()
      ..writeln('[appearance]')
      ..writeln('active_theme = ${jsonEncode(appearance.activeTheme)}');

    if (appearance.themesDir != null &&
        appearance.themesDir!.trim().isNotEmpty) {
      buffer.writeln('themes_dir = ${jsonEncode(appearance.themesDir)}');
    }

    buffer
      ..writeln()
      ..writeln('[logging]')
      ..writeln('verbosity = ${jsonEncode(logging.verbosity.tomlValue)}')
      ..writeln('log_directory = ${jsonEncode(logging.logDirectory)}')
      ..writeln()
      ..writeln('[write_queue]')
      ..writeln('enabled = ${writeQueue.enabled}')
      ..writeln('capacity = ${writeQueue.capacity}')
      ..writeln('default_timeout_ms = ${writeQueue.defaultTimeoutMs}')
      ..writeln('max_batch = ${writeQueue.maxBatch}')
      ..writeln('max_group_delay_us = ${writeQueue.maxGroupDelayUs}')
      ..writeln()
      ..writeln('[database_open]')
      ..writeln('profile = ${jsonEncode(databaseOpen.profile)}')
      ..writeln('plan_cache_enabled = ${databaseOpen.planCacheEnabled}');
    if (databaseOpen.planCacheMaxBytes != null) {
      buffer.writeln('plan_cache_max_bytes = ${databaseOpen.planCacheMaxBytes}');
    }

    final window = windowPlacement?.normalized();
    if (window != null) {
      buffer
        ..writeln()
        ..writeln('[window]')
        ..writeln('state = ${jsonEncode(window.state.tomlValue)}')
        ..writeln('x = ${window.x}')
        ..writeln('y = ${window.y}')
        ..writeln('width = ${window.width}')
        ..writeln('height = ${window.height}');
      if (window.displayId != null) {
        buffer.writeln('display_id = ${jsonEncode(window.displayId)}');
      }
      if (window.displayX != null) {
        buffer.writeln('display_x = ${window.displayX}');
      }
      if (window.displayY != null) {
        buffer.writeln('display_y = ${window.displayY}');
      }
      if (window.displayWidth != null) {
        buffer.writeln('display_width = ${window.displayWidth}');
      }
      if (window.displayHeight != null) {
        buffer.writeln('display_height = ${window.displayHeight}');
      }
    }

    buffer
      ..writeln()
      ..writeln('[layout]')
      ..writeln(
        'left_column_fraction = ${_formatDouble(layout.leftColumnFraction)}',
      )
      ..writeln('left_top_fraction = ${_formatDouble(layout.leftTopFraction)}')
      ..writeln(
        'right_top_fraction = ${_formatDouble(layout.rightTopFraction)}',
      )
      ..writeln('show_schema_explorer = ${layout.showSchemaExplorer}')
      ..writeln('show_properties_pane = ${layout.showPropertiesPane}')
      ..writeln('show_results_pane = ${layout.showResultsPane}')
      ..writeln('show_status_bar = ${layout.showStatusBar}')
      ..writeln('editor_zoom = ${_formatDouble(layout.editorZoom)}')
      ..writeln(
        'active_results_tab = ${jsonEncode(WorkspaceShellPreferences.encodeResultsTab(layout.activeResultsTab))}',
      )
      ..writeln()
      ..writeln('[shortcuts]');

    final sortedShortcutKeys = shortcutBindings.keys.toList()..sort();
    for (final key in sortedShortcutKeys) {
      buffer.writeln('$key = ${jsonEncode(shortcutBindings[key])}');
    }

    for (final snippet in snippets) {
      buffer
        ..writeln()
        ..writeln('[[editor_snippets]]')
        ..writeln('id = ${jsonEncode(snippet.id)}')
        ..writeln('name = ${jsonEncode(snippet.name)}')
        ..writeln('trigger = ${jsonEncode(snippet.trigger)}')
        ..writeln('description = ${jsonEncode(snippet.description)}')
        ..writeln('body = ${jsonEncode(snippet.body)}');
    }
    return buffer.toString();
  }

  static AppConfig fromToml(String source) {
    var config = AppConfig.defaults();
    final parsedSnippets = <SqlSnippet>[];
    Map<String, Object?>? pendingSnippet;
    int? declaredSnippetCount;
    String? currentTable;
    var windowState = WindowPlacementState.normal;
    int? windowX;
    int? windowY;
    int? windowWidth;
    int? windowHeight;
    String? windowDisplayId;
    int? windowDisplayX;
    int? windowDisplayY;
    int? windowDisplayWidth;
    int? windowDisplayHeight;

    void flushSnippet() {
      if (pendingSnippet == null) {
        return;
      }
      try {
        parsedSnippets.add(SqlSnippet.fromJson(pendingSnippet!));
      } catch (_) {
        // Ignore malformed snippet entries and keep loading the rest.
      }
      pendingSnippet = null;
    }

    for (final rawLine in const LineSplitter().convert(source)) {
      final commentFree = _stripTomlComment(rawLine).trim();
      if (commentFree.isEmpty) {
        continue;
      }
      if (commentFree.startsWith('[[') && commentFree.endsWith(']]')) {
        flushSnippet();
        currentTable = commentFree.substring(2, commentFree.length - 2).trim();
        if (currentTable == 'editor_snippets') {
          pendingSnippet = <String, Object?>{};
        }
        continue;
      }
      if (commentFree.startsWith('[') && commentFree.endsWith(']')) {
        flushSnippet();
        currentTable = commentFree.substring(1, commentFree.length - 1).trim();
        continue;
      }
      if (!commentFree.contains('=')) {
        continue;
      }

      final separatorIndex = commentFree.indexOf('=');
      final key = commentFree.substring(0, separatorIndex).trim();
      final value = commentFree.substring(separatorIndex + 1).trim();

      if (pendingSnippet != null && currentTable == 'editor_snippets') {
        final parsed = _decodeJsonString(value);
        if (parsed != null &&
            const <String>{
              'id',
              'name',
              'trigger',
              'description',
              'body',
            }.contains(key)) {
          pendingSnippet![key] = parsed;
        }
        continue;
      }

      final qualifiedKey = currentTable == null ? key : '$currentTable.$key';
      switch (qualifiedKey) {
        case 'config_version':
          final parsed = int.tryParse(value);
          if (parsed != null && parsed >= 0) {
            config = config.copyWith(configVersion: parsed);
          }
          break;
        case 'appearance.active_theme':
          final parsed = _decodeJsonString(value);
          if (parsed != null && parsed.trim().isNotEmpty) {
            config = config.copyWith(
              appearance: config.appearance.copyWith(
                activeTheme: parsed.trim(),
              ),
            );
          }
          break;
        case 'appearance.themes_dir':
          final parsed = _decodeJsonString(value);
          if (parsed != null) {
            config = config.copyWith(
              appearance: config.appearance.copyWith(
                themesDir: parsed.trim().isEmpty ? null : parsed.trim(),
              ),
            );
          }
          break;
        case 'logging.verbosity':
          final parsed = _decodeJsonString(value);
          if (parsed != null && parsed.trim().isNotEmpty) {
            config = config.copyWith(
              logging: config.logging.copyWith(
                verbosity: LogVerbosity.parse(parsed),
              ),
            );
          }
          break;
        case 'logging.log_directory':
          final parsed = _decodeJsonString(value);
          if (parsed != null && parsed.trim().isNotEmpty) {
            config = config.copyWith(
              logging: config.logging.copyWith(
                logDirectory: parsed.trim(),
              ),
            );
          }
          break;
        case 'write_queue.enabled':
          final parsed = _parseBool(value);
          if (parsed != null) {
            config = config.copyWith(
              writeQueue: config.writeQueue.copyWith(enabled: parsed),
            );
          }
          break;
        case 'write_queue.capacity':
          final parsed = int.tryParse(value);
          if (parsed != null && parsed > 0) {
            config = config.copyWith(
              writeQueue: config.writeQueue.copyWith(capacity: parsed),
            );
          }
          break;
        case 'write_queue.default_timeout_ms':
          final parsed = int.tryParse(value);
          if (parsed != null && parsed >= 0) {
            config = config.copyWith(
              writeQueue: config.writeQueue.copyWith(defaultTimeoutMs: parsed),
            );
          }
          break;
        case 'write_queue.max_batch':
          final parsed = int.tryParse(value);
          if (parsed != null && parsed > 0) {
            config = config.copyWith(
              writeQueue: config.writeQueue.copyWith(maxBatch: parsed),
            );
          }
          break;
        case 'write_queue.max_group_delay_us':
          final parsed = int.tryParse(value);
          if (parsed != null && parsed >= 0) {
            config = config.copyWith(
              writeQueue: config.writeQueue.copyWith(maxGroupDelayUs: parsed),
            );
          }
          break;
        case 'database_open.profile':
          final parsed = _decodeJsonString(value);
          if (parsed != null &&
              kDatabaseProfiles.contains(parsed.trim().toLowerCase())) {
            config = config.copyWith(
              databaseOpen: config.databaseOpen.copyWith(
                profile: parsed.trim().toLowerCase(),
              ),
            );
          }
          break;
        case 'database_open.plan_cache_enabled':
          final parsed = _parseBool(value);
          if (parsed != null) {
            config = config.copyWith(
              databaseOpen: config.databaseOpen.copyWith(
                planCacheEnabled: parsed,
              ),
            );
          }
          break;
        case 'database_open.plan_cache_max_bytes':
          final parsed = int.tryParse(value);
          if (parsed != null && parsed > 0) {
            config = config.copyWith(
              databaseOpen: config.databaseOpen.copyWith(
                planCacheMaxBytes: parsed,
              ),
            );
          }
          break;
        case 'window.state':
          final parsed = _decodeJsonString(value);
          if (parsed != null) {
            windowState = WindowPlacementState.parse(parsed);
          }
          break;
        case 'window.x':
          windowX = int.tryParse(value);
          break;
        case 'window.y':
          windowY = int.tryParse(value);
          break;
        case 'window.width':
          windowWidth = int.tryParse(value);
          break;
        case 'window.height':
          windowHeight = int.tryParse(value);
          break;
        case 'window.display_id':
          windowDisplayId = _decodeJsonString(value);
          break;
        case 'window.display_x':
          windowDisplayX = int.tryParse(value);
          break;
        case 'window.display_y':
          windowDisplayY = int.tryParse(value);
          break;
        case 'window.display_width':
          windowDisplayWidth = int.tryParse(value);
          break;
        case 'window.display_height':
          windowDisplayHeight = int.tryParse(value);
          break;
        case 'default_page_size':
          final parsed = int.tryParse(value);
          if (parsed != null && parsed > 0) {
            config = config.copyWith(defaultPageSize: parsed);
          }
          break;
        case 'query_history_limit':
          final parsed = int.tryParse(value);
          if (parsed != null && parsed > 0) {
            config = config.copyWith(queryHistoryLimit: parsed);
          }
          break;
        case 'csv_delimiter':
          final parsed = _decodeJsonString(value);
          if (parsed != null && parsed.isNotEmpty) {
            config = config.copyWith(csvDelimiter: parsed);
          }
          break;
        case 'csv_include_headers':
          final parsed = _parseBool(value);
          if (parsed != null) {
            config = config.copyWith(csvIncludeHeaders: parsed);
          }
          break;
        case 'recent_files':
          final parsed = _decodeStringList(value);
          if (parsed != null) {
            config = config.copyWith(
              recentFiles: parsed.take(maxRecentFiles).toList(),
            );
          }
          break;
        case 'editor_autocomplete_enabled':
          final parsed = _parseBool(value);
          if (parsed != null) {
            config = config.copyWith(
              editorSettings: config.editorSettings.copyWith(
                autocompleteEnabled: parsed,
              ),
            );
          }
          break;
        case 'editor_autocomplete_max_suggestions':
          final parsed = int.tryParse(value);
          if (parsed != null && parsed > 0) {
            config = config.copyWith(
              editorSettings: config.editorSettings.copyWith(
                autocompleteMaxSuggestions: parsed,
              ),
            );
          }
          break;
        case 'editor_format_uppercase_keywords':
          final parsed = _parseBool(value);
          if (parsed != null) {
            config = config.copyWith(
              editorSettings: config.editorSettings.copyWith(
                formatUppercaseKeywords: parsed,
              ),
            );
          }
          break;
        case 'editor_indent_spaces':
          final parsed = int.tryParse(value);
          if (parsed != null && parsed > 0) {
            config = config.copyWith(
              editorSettings: config.editorSettings.copyWith(
                indentSpaces: parsed,
              ),
            );
          }
          break;
        case 'editor_show_line_numbers':
          final parsed = _parseBool(value);
          if (parsed != null) {
            config = config.copyWith(
              editorSettings: config.editorSettings.copyWith(
                showLineNumbers: parsed,
              ),
            );
          }
          break;
        case 'editor_snippet_count':
          final parsed = int.tryParse(value);
          if (parsed != null && parsed >= 0) {
            declaredSnippetCount = parsed;
          }
          break;
        case 'editor_snippets':
          final parsed = _decodeSnippetList(value);
          if (parsed != null) {
            config = config.copyWith(snippets: parsed);
          }
          break;
        case 'layout.left_column_fraction':
          final parsed = double.tryParse(value);
          if (parsed != null) {
            config = config.copyWith(
              shellPreferences: config.shellPreferences.copyWith(
                leftColumnFraction: parsed,
              ),
            );
          }
          break;
        case 'layout.left_top_fraction':
          final parsed = double.tryParse(value);
          if (parsed != null) {
            config = config.copyWith(
              shellPreferences: config.shellPreferences.copyWith(
                leftTopFraction: parsed,
              ),
            );
          }
          break;
        case 'layout.right_top_fraction':
          final parsed = double.tryParse(value);
          if (parsed != null) {
            config = config.copyWith(
              shellPreferences: config.shellPreferences.copyWith(
                rightTopFraction: parsed,
              ),
            );
          }
          break;
        case 'layout.show_schema_explorer':
          final parsed = _parseBool(value);
          if (parsed != null) {
            config = config.copyWith(
              shellPreferences: config.shellPreferences.copyWith(
                showSchemaExplorer: parsed,
              ),
            );
          }
          break;
        case 'layout.show_properties_pane':
          final parsed = _parseBool(value);
          if (parsed != null) {
            config = config.copyWith(
              shellPreferences: config.shellPreferences.copyWith(
                showPropertiesPane: parsed,
              ),
            );
          }
          break;
        case 'layout.show_results_pane':
          final parsed = _parseBool(value);
          if (parsed != null) {
            config = config.copyWith(
              shellPreferences: config.shellPreferences.copyWith(
                showResultsPane: parsed,
              ),
            );
          }
          break;
        case 'layout.show_status_bar':
          final parsed = _parseBool(value);
          if (parsed != null) {
            config = config.copyWith(
              shellPreferences: config.shellPreferences.copyWith(
                showStatusBar: parsed,
              ),
            );
          }
          break;
        case 'layout.editor_zoom':
          final parsed = double.tryParse(value);
          if (parsed != null) {
            config = config.copyWith(
              shellPreferences: config.shellPreferences.copyWith(
                editorZoom: parsed,
              ),
            );
          }
          break;
        case 'layout.active_results_tab':
          final parsed = _decodeJsonString(value);
          if (parsed != null) {
            config = config.copyWith(
              shellPreferences: config.shellPreferences.copyWith(
                activeResultsTab: WorkspaceShellPreferences.parseResultsTab(
                  parsed,
                ),
              ),
            );
          }
          break;
        default:
          if (qualifiedKey.startsWith('shortcuts.')) {
            final parsed = _decodeJsonString(value);
            if (parsed != null && parsed.isNotEmpty) {
              final updated = <String, String>{
                ...config.shortcutBindings,
                key: parsed,
              };
              config = config.copyWith(shortcutBindings: updated);
            }
          }
          break;
      }
    }

    flushSnippet();
    if (declaredSnippetCount != null || parsedSnippets.isNotEmpty) {
      config = config.copyWith(snippets: parsedSnippets);
    }
    final parsedWindowPlacement = _buildWindowPlacement(
      x: windowX,
      y: windowY,
      width: windowWidth,
      height: windowHeight,
      state: windowState,
      displayId: windowDisplayId,
      displayX: windowDisplayX,
      displayY: windowDisplayY,
      displayWidth: windowDisplayWidth,
      displayHeight: windowDisplayHeight,
    );
    if (parsedWindowPlacement != null) {
      config = config.copyWith(windowPlacement: parsedWindowPlacement);
    }

    return config.copyWith(
      configVersion: config.configVersion == 0
          ? currentConfigVersion
          : config.configVersion,
      shellPreferences: config.shellPreferences.normalized(),
    );
  }

  static WindowPlacement? _buildWindowPlacement({
    required int? x,
    required int? y,
    required int? width,
    required int? height,
    required WindowPlacementState state,
    required String? displayId,
    required int? displayX,
    required int? displayY,
    required int? displayWidth,
    required int? displayHeight,
  }) {
    if (x == null || y == null || width == null || height == null) {
      return null;
    }
    if (width < WindowPlacement.minimumWidth ||
        height < WindowPlacement.minimumHeight) {
      return null;
    }
    return WindowPlacement(
      x: x,
      y: y,
      width: width,
      height: height,
      state: state,
      displayId: displayId == null || displayId.trim().isEmpty
          ? null
          : displayId.trim(),
      displayX: displayX,
      displayY: displayY,
      displayWidth: displayWidth != null && displayWidth > 0
          ? displayWidth
          : null,
      displayHeight: displayHeight != null && displayHeight > 0
          ? displayHeight
          : null,
    );
  }

  static Map<String, String> defaultShortcutBindings() {
    return const <String, String>{
      'edit_copy': 'Ctrl+C',
      'edit_find': 'Ctrl+F',
      'edit_find_next': 'F3',
      'edit_paste': 'Ctrl+V',
      'edit_redo': 'Ctrl+Shift+Z',
      'edit_select_all': 'Ctrl+A',
      'edit_undo': 'Ctrl+Z',
      'export_results_csv': 'Ctrl+Shift+C',
      'file_new': 'Ctrl+N',
      'file_open': 'Ctrl+O',
      'file_save': 'Ctrl+S',
      'file_save_as': 'Ctrl+Shift+S',
      'file_exit': 'Ctrl+Q',
      'help_docs': 'F1',
      'import_open_wizard': 'Ctrl+Shift+I',
      'tools_format_sql': 'Ctrl+Shift+F',
      'tools_new_query_tab': 'Ctrl+T',
      'tools_run_query': 'Ctrl+Enter',
      'tools_run_buffer': 'Ctrl+Alt+Enter',
      'tools_stop_query': 'Esc',
      'view_reset_layout': 'Ctrl+Shift+R',
      'view_command_palette': 'Ctrl+Shift+P',
      'view_zoom_in': 'Ctrl+=',
      'view_zoom_out': 'Ctrl+-',
      'view_zoom_reset': 'Ctrl+0',
    };
  }

  static List<SqlSnippet> defaultSnippets() {
    return const <SqlSnippet>[
      SqlSnippet(
        id: 'cte',
        name: 'Recursive CTE',
        trigger: 'cte',
        description: 'Start a WITH RECURSIVE query.',
        body:
            'WITH RECURSIVE seed AS (\n'
            '  SELECT 1 AS id\n'
            '  UNION ALL\n'
            '  SELECT id + 1\n'
            '  FROM seed\n'
            '  WHERE id < 10\n'
            ')\n'
            'SELECT *\n'
            'FROM seed;',
      ),
      SqlSnippet(
        id: 'window',
        name: 'Window Function',
        trigger: 'window',
        description: 'Add a ROW_NUMBER window expression.',
        body:
            'SELECT\n'
            '  *,\n'
            '  ROW_NUMBER() OVER (PARTITION BY category ORDER BY id) AS row_num\n'
            'FROM your_table;',
      ),
      SqlSnippet(
        id: 'json_each',
        name: 'JSON Each',
        trigger: 'json',
        description: 'Use json_each as a table-valued function.',
        body:
            'SELECT entry.key, entry.value\n'
            "FROM json_each('{\"name\":\"decent\",\"type\":\"bench\"}') AS entry;",
      ),
      SqlSnippet(
        id: 'explain',
        name: 'Explain Analyze',
        trigger: 'explain',
        description: 'Profile a query plan.',
        body:
            'EXPLAIN ANALYZE\n'
            'SELECT *\n'
            'FROM your_table\n'
            'WHERE id = \$1;',
      ),
      SqlSnippet(
        id: 'native_types',
        name: 'Native Types Table',
        trigger: 'native',
        description: 'Create a table with DecentDB native semantic types.',
        body:
            'CREATE TABLE native_sample (\n'
            '  id INT64 PRIMARY KEY,\n'
            "  status ENUM('draft', 'published') NOT NULL,\n"
            '  seen_at TIMESTAMPTZ,\n'
            '  service_ip IPADDR,\n'
            '  service_net CIDR,\n'
            '  device_mac MACADDR\n'
            ');',
      ),
      SqlSnippet(
        id: 'spatial_nearby',
        name: 'Spatial Nearby Query',
        trigger: 'spatial',
        description: 'Filter geography points by distance in meters.',
        body:
            'SELECT id, name, ST_AsText(geog) AS wkt\n'
            'FROM places\n'
            'WHERE ST_DWithin(geog, ST_GeogPoint(\$1, \$2), \$3)\n'
            'ORDER BY geog <-> ST_GeogPoint(\$1, \$2);',
      ),
    ];
  }

  static String? _decodeJsonString(String raw) {
    try {
      final parsed = jsonDecode(raw);
      return parsed is String ? parsed : null;
    } catch (_) {
      return null;
    }
  }

  static List<String>? _decodeStringList(String raw) {
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) {
        return null;
      }
      return parsed.whereType<String>().toList();
    } catch (_) {
      return null;
    }
  }

  static List<SqlSnippet>? _decodeSnippetList(String raw) {
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) {
        return null;
      }
      return parsed
          .whereType<Map>()
          .map(
            (item) => SqlSnippet.fromJson(
              item.map((key, value) => MapEntry(key as String, value)),
            ),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  static bool? _parseBool(String raw) {
    if (raw == 'true') {
      return true;
    }
    if (raw == 'false') {
      return false;
    }
    return null;
  }

  static String _stripTomlComment(String rawLine) {
    final buffer = StringBuffer();
    var insideString = false;
    var escaping = false;
    for (var i = 0; i < rawLine.length; i++) {
      final char = rawLine[i];
      if (escaping) {
        buffer.write(char);
        escaping = false;
        continue;
      }
      if (char == r'\') {
        buffer.write(char);
        if (insideString) {
          escaping = true;
        }
        continue;
      }
      if (char == '"') {
        insideString = !insideString;
        buffer.write(char);
        continue;
      }
      if (char == '#' && !insideString) {
        break;
      }
      buffer.write(char);
    }
    return buffer.toString();
  }

  static String _formatDouble(double value) {
    final formatted = value.toStringAsFixed(3);
    return formatted
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
