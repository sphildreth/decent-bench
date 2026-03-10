import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../domain/app_config.dart';
import '../domain/workspace_models.dart';
import '../domain/workspace_state.dart';
import '../infrastructure/app_config_store.dart';
import '../infrastructure/decentdb_bridge.dart';
import '../infrastructure/workspace_state_store.dart';

class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    WorkspaceDatabaseGateway? gateway,
    WorkspaceConfigStore? configStore,
    WorkspaceStateStore? workspaceStateStore,
  }) : _gateway = gateway ?? DecentDbBridge(),
       _configStore = configStore ?? AppConfigStore(),
       _workspaceStateStore = workspaceStateStore ?? FileWorkspaceStateStore() {
    _resetTabs(notify: false, resetCounters: true);
  }

  final WorkspaceDatabaseGateway _gateway;
  final WorkspaceConfigStore _configStore;
  final WorkspaceStateStore _workspaceStateStore;

  AppConfig config = AppConfig.defaults();
  SchemaSnapshot schema = SchemaSnapshot.empty();
  List<QueryTabState> tabs = const <QueryTabState>[];

  String? databasePath;
  String? engineVersion;
  String? nativeLibraryPath;
  String? workspaceError;
  String? workspaceMessage;
  bool isInitializing = true;
  bool isSchemaLoading = false;
  bool isOpeningDatabase = false;

  int _nextTabIdCounter = 1;
  int _nextTabTitleCounter = 1;
  String? _activeTabId;
  Timer? _workspaceSaveDebounce;
  bool _disposed = false;

  bool get hasOpenDatabase => databasePath != null;

  String get activeTabId => _activeTabId ?? tabs.first.id;

  QueryTabState get activeTab =>
      tabs.firstWhere((tab) => tab.id == activeTabId);

  bool get hasRunningTabs => tabs.any(
    (tab) =>
        tab.canCancel ||
        tab.isExporting ||
        tab.phase == QueryPhase.running ||
        tab.phase == QueryPhase.fetching,
  );

  bool get canRunActiveTab => canRunTab(activeTabId);

  bool get canCancelActiveTab => tabById(activeTabId)?.canCancel ?? false;

  QueryTabState? tabById(String tabId) {
    for (final tab in tabs) {
      if (tab.id == tabId) {
        return tab;
      }
    }
    return null;
  }

  bool canRunTab(String tabId) {
    final tab = tabById(tabId);
    if (tab == null || !hasOpenDatabase || tab.isExporting) {
      return false;
    }
    return switch (tab.phase) {
      QueryPhase.idle ||
      QueryPhase.completed ||
      QueryPhase.cancelled ||
      QueryPhase.failed => true,
      QueryPhase.opening ||
      QueryPhase.running ||
      QueryPhase.fetching ||
      QueryPhase.cancelling => false,
    };
  }

  Future<void> initialize() async {
    if (!isInitializing) {
      return;
    }

    try {
      config = await _configStore.load();
      nativeLibraryPath = await _gateway.initialize();
      workspaceMessage = 'Ready.';
      workspaceError = null;
    } catch (error) {
      workspaceError = error.toString();
      workspaceMessage = null;
    } finally {
      isInitializing = false;
      _safeNotify();
    }
  }

  Future<void> openDatabase(
    String rawPath, {
    required bool createIfMissing,
  }) async {
    final normalized = rawPath.trim();
    if (normalized.isEmpty) {
      _setWorkspaceError('Enter a DecentDB file path first.');
      return;
    }

    final file = File(normalized);
    try {
      if (createIfMissing) {
        if (await file.exists()) {
          _setWorkspaceError(
            'Refusing to create over an existing file: $normalized',
          );
          return;
        }
        await file.parent.create(recursive: true);
      } else if (!await file.exists()) {
        _setWorkspaceError('Database file does not exist: $normalized');
        return;
      }
    } on FileSystemException catch (error) {
      _setWorkspaceError(error.message);
      return;
    }

    _workspaceSaveDebounce?.cancel();
    await _cancelAllOpenCursors();

    isOpeningDatabase = true;
    isSchemaLoading = true;
    schema = SchemaSnapshot.empty();
    workspaceError = null;
    workspaceMessage = createIfMissing
        ? 'Creating database...'
        : 'Opening database...';
    _safeNotify();

    try {
      final session = await _gateway.openDatabase(normalized);
      databasePath = session.path;
      engineVersion = session.engineVersion;
      config = config.pushRecentFile(session.path);
      await _configStore.save(config);
      final restoredState = await _workspaceStateStore.load(session.path);
      _restoreTabs(restoredState, notify: false);
      await refreshSchema(showLoadingState: false);
      await _persistWorkspaceStateNow();
      workspaceMessage =
          'Opened ${p.basename(session.path)}'
          ' on DecentDB ${session.engineVersion}'
          ' with ${tabs.length} query tab${tabs.length == 1 ? '' : 's'}.';
    } catch (error) {
      databasePath = null;
      engineVersion = null;
      schema = SchemaSnapshot.empty();
      _setWorkspaceError(error.toString());
      _resetTabs(notify: false, resetCounters: true);
    } finally {
      isOpeningDatabase = false;
      isSchemaLoading = false;
      _safeNotify();
    }
  }

  Future<void> refreshSchema({bool showLoadingState = true}) async {
    if (!hasOpenDatabase) {
      return;
    }

    if (showLoadingState) {
      isSchemaLoading = true;
      workspaceError = null;
      workspaceMessage = 'Refreshing schema...';
      _safeNotify();
    }

    try {
      schema = await _gateway.loadSchema();
      workspaceMessage =
          'Loaded ${schema.tables.length} tables and ${schema.views.length} views.';
      workspaceError = null;
    } catch (error) {
      _setWorkspaceError(error.toString());
    } finally {
      isSchemaLoading = false;
      _safeNotify();
    }
  }

  void updateActiveSql(String value) {
    _mutateActiveTab((tab) => tab.copyWith(sql: value), persist: true);
  }

  void updateActiveParameterJson(String value) {
    _mutateActiveTab(
      (tab) => tab.copyWith(parameterJson: value),
      persist: true,
    );
  }

  void updateActiveExportPath(String value) {
    _mutateActiveTab((tab) => tab.copyWith(exportPath: value), persist: true);
  }

  void selectTab(String tabId) {
    if (tabById(tabId) == null || activeTabId == tabId) {
      return;
    }
    _activeTabId = tabId;
    _scheduleWorkspaceStateSave();
    _safeNotify();
  }

  void nextTab() {
    if (tabs.length < 2) {
      return;
    }
    final currentIndex = tabs.indexWhere((tab) => tab.id == activeTabId);
    final nextIndex = currentIndex < 0 ? 0 : (currentIndex + 1) % tabs.length;
    selectTab(tabs[nextIndex].id);
  }

  void previousTab() {
    if (tabs.length < 2) {
      return;
    }
    final currentIndex = tabs.indexWhere((tab) => tab.id == activeTabId);
    final nextIndex = currentIndex <= 0 ? tabs.length - 1 : currentIndex - 1;
    selectTab(tabs[nextIndex].id);
  }

  void createTab({String? sql}) {
    final title = _newTabTitle();
    final tab = QueryTabState.initial(
      id: _newTabId(),
      title: title,
      sql: sql ?? 'SELECT 1 AS ready;',
      exportPath: _suggestExportPathForTitle(title),
    );
    tabs = <QueryTabState>[...tabs, tab];
    _activeTabId = tab.id;
    _scheduleWorkspaceStateSave();
    _safeNotify();
  }

  Future<void> closeTab(String tabId) async {
    final closing = tabById(tabId);
    if (closing == null) {
      return;
    }

    final closingIndex = tabs.indexWhere((tab) => tab.id == tabId);

    if (closing.cursorId != null) {
      try {
        await _gateway.cancelQuery(closing.cursorId!);
      } catch (_) {
        // Best-effort cleanup.
      }
    }

    final remaining = tabs.where((tab) => tab.id != tabId).toList();
    if (remaining.isEmpty) {
      _resetTabs(notify: false);
    } else {
      tabs = remaining;
      if (_activeTabId == tabId) {
        final nextIndex = closingIndex.clamp(0, remaining.length - 1);
        _activeTabId = remaining[nextIndex].id;
      }
    }

    _scheduleWorkspaceStateSave();
    _safeNotify();
  }

  Future<void> runActiveTab() => runTab(activeTabId);

  Future<void> runTab(String tabId) async {
    final tab = tabById(tabId);
    if (tab == null || !canRunTab(tabId)) {
      return;
    }
    if (!hasOpenDatabase) {
      _setTabError(
        tabId,
        QueryErrorDetails(
          stage: QueryErrorStage.validation,
          message: 'Open or create a DecentDB file before running SQL.',
        ),
      );
      return;
    }

    final trimmedSql = tab.sql.trim();
    if (trimmedSql.isEmpty) {
      _setTabError(
        tabId,
        QueryErrorDetails(
          stage: QueryErrorStage.validation,
          message: 'Enter SQL before pressing Run.',
        ),
      );
      return;
    }

    final params = _parseParameters(tabId, tab.parameterJson);
    if (params == null) {
      return;
    }

    final generation = tab.executionGeneration + 1;
    final previousCursor = tab.cursorId;
    _mutateTab(
      tabId,
      (current) => current.copyWith(
        phase: QueryPhase.opening,
        resultColumns: const <String>[],
        resultRows: const <Map<String, Object?>>[],
        cursorId: null,
        error: null,
        statusMessage: 'Executing SQL...',
        lastSql: trimmedSql,
        lastParams: params,
        rowsAffected: null,
        elapsed: null,
        hasMoreRows: false,
        isResultPartial: false,
        executionGeneration: generation,
      ),
      notify: false,
    );
    _safeNotify();

    if (previousCursor != null) {
      unawaited(_gateway.cancelQuery(previousCursor));
    }

    try {
      final page = await _gateway.runQuery(
        sql: trimmedSql,
        params: params,
        pageSize: config.defaultPageSize,
      );
      if (!_isCurrentGeneration(tabId, generation)) {
        if (page.cursorId != null) {
          unawaited(_gateway.cancelQuery(page.cursorId!));
        }
        return;
      }

      _mutateTab(
        tabId,
        (current) => _applyFirstPage(
          current,
          page,
          statusMessage: page.rowsAffected != null
              ? 'Statement completed with ${page.rowsAffected} affected rows.'
              : 'Loaded ${page.rows.length} rows from the first page.',
        ),
        notify: false,
      );
    } catch (error) {
      if (_isCurrentGeneration(tabId, generation)) {
        _mutateTab(
          tabId,
          (current) => current.copyWith(
            phase: QueryPhase.failed,
            error: QueryErrorDetails.fromError(
              error,
              stage: QueryErrorStage.opening,
            ),
            statusMessage: null,
            cursorId: null,
            hasMoreRows: false,
          ),
          notify: false,
        );
      }
    } finally {
      _safeNotify();
    }
  }

  Future<void> fetchNextPage({String? tabId}) async {
    final resolvedTabId = tabId ?? activeTabId;
    final tab = tabById(resolvedTabId);
    if (tab == null ||
        tab.cursorId == null ||
        tab.phase == QueryPhase.fetching ||
        !tab.hasMoreRows) {
      return;
    }

    final generation = tab.executionGeneration;
    _mutateTab(
      resolvedTabId,
      (current) => current.copyWith(
        phase: QueryPhase.fetching,
        error: null,
        statusMessage: 'Loading the next page...',
      ),
      notify: false,
    );
    _safeNotify();

    try {
      final page = await _gateway.fetchNextPage(
        cursorId: tab.cursorId!,
        pageSize: config.defaultPageSize,
      );
      if (!_isCurrentGeneration(resolvedTabId, generation)) {
        if (page.cursorId != null) {
          unawaited(_gateway.cancelQuery(page.cursorId!));
        }
        return;
      }

      _mutateTab(
        resolvedTabId,
        (current) => current.copyWith(
          phase: page.done ? QueryPhase.completed : QueryPhase.running,
          resultRows: <Map<String, Object?>>[
            ...current.resultRows,
            ...page.rows,
          ],
          cursorId: page.cursorId,
          hasMoreRows: !page.done,
          elapsed: (current.elapsed ?? Duration.zero) + page.elapsed,
          statusMessage: page.done
              ? 'Loaded ${current.resultRows.length + page.rows.length} total rows.'
              : 'Loaded ${current.resultRows.length + page.rows.length} rows so far.',
        ),
        notify: false,
      );
    } catch (error) {
      if (_isCurrentGeneration(resolvedTabId, generation)) {
        _mutateTab(
          resolvedTabId,
          (current) => current.copyWith(
            phase: QueryPhase.failed,
            error: QueryErrorDetails.fromError(
              error,
              stage: QueryErrorStage.paging,
            ),
            statusMessage: null,
            cursorId: null,
            hasMoreRows: false,
          ),
          notify: false,
        );
      }
    } finally {
      _safeNotify();
    }
  }

  Future<void> cancelActiveQuery() => cancelTabQuery(activeTabId);

  Future<void> cancelTabQuery(String tabId) async {
    final tab = tabById(tabId);
    if (tab == null || !tab.canCancel) {
      return;
    }

    final generation = tab.executionGeneration + 1;
    final hasPartialRows = tab.resultRows.isNotEmpty;
    final cursorId = tab.cursorId;
    _mutateTab(
      tabId,
      (current) => current.copyWith(
        phase: QueryPhase.cancelling,
        error: null,
        statusMessage: 'Cancelling query...',
        cursorId: null,
        hasMoreRows: false,
        executionGeneration: generation,
      ),
      notify: false,
    );
    _safeNotify();

    if (cursorId != null) {
      try {
        await _gateway.cancelQuery(cursorId);
      } catch (error) {
        if (_isCurrentGeneration(tabId, generation)) {
          _mutateTab(
            tabId,
            (current) => current.copyWith(
              phase: QueryPhase.failed,
              error: QueryErrorDetails.fromError(
                error,
                stage: QueryErrorStage.cancellation,
              ),
              statusMessage: null,
            ),
            notify: false,
          );
          _safeNotify();
        }
        return;
      }
    }

    if (_isCurrentGeneration(tabId, generation)) {
      _mutateTab(
        tabId,
        (current) => current.copyWith(
          phase: QueryPhase.cancelled,
          error: null,
          statusMessage: hasPartialRows
              ? 'Query cancelled. Partial results remain visible.'
              : 'Query cancelled before a complete page was loaded.',
          isResultPartial: hasPartialRows,
          hasMoreRows: false,
        ),
        notify: false,
      );
      _safeNotify();
    }
  }

  Future<void> exportCurrentQuery() => exportTabQuery(activeTabId);

  Future<void> exportTabQuery(String tabId) async {
    final tab = tabById(tabId);
    if (tab == null) {
      return;
    }

    final exportPath = tab.exportPath.trim().isEmpty
        ? suggestExportPath(tabId)
        : tab.exportPath.trim();
    if (!tab.canExport) {
      _setTabError(
        tabId,
        QueryErrorDetails(
          stage: QueryErrorStage.export,
          message: 'Run a row-producing query before exporting CSV.',
        ),
      );
      return;
    }
    if (exportPath.isEmpty) {
      _setTabError(
        tabId,
        QueryErrorDetails(
          stage: QueryErrorStage.export,
          message: 'Enter a CSV destination path first.',
        ),
      );
      return;
    }

    _mutateTab(
      tabId,
      (current) => current.copyWith(
        isExporting: true,
        error: null,
        statusMessage: 'Exporting CSV...',
      ),
      notify: false,
    );
    _safeNotify();

    try {
      final result = await _gateway.exportCsv(
        sql: tab.lastSql!,
        params: tab.lastParams,
        pageSize: config.defaultPageSize,
        path: exportPath,
        delimiter: config.csvDelimiter,
        includeHeaders: config.csvIncludeHeaders,
      );
      _mutateTab(
        tabId,
        (current) => current.copyWith(
          isExporting: false,
          statusMessage: 'Exported ${result.rowCount} rows to ${result.path}.',
        ),
        notify: false,
      );
    } catch (error) {
      _mutateTab(
        tabId,
        (current) => current.copyWith(
          isExporting: false,
          error: QueryErrorDetails.fromError(
            error,
            stage: QueryErrorStage.export,
          ),
          statusMessage: null,
        ),
        notify: false,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> updateDefaultPageSize(String rawValue) async {
    final parsed = int.tryParse(rawValue.trim());
    if (parsed == null || parsed <= 0) {
      _setWorkspaceError('Page size must be a positive integer.');
      return;
    }

    config = config.copyWith(defaultPageSize: parsed);
    await _persistConfig('Updated default page size to $parsed rows.');
  }

  Future<void> updateCsvDelimiter(String rawValue) async {
    if (rawValue.isEmpty) {
      _setWorkspaceError('CSV delimiter cannot be empty.');
      return;
    }
    config = config.copyWith(csvDelimiter: rawValue);
    await _persistConfig('Updated CSV delimiter.');
  }

  Future<void> updateCsvIncludeHeaders(bool value) async {
    config = config.copyWith(csvIncludeHeaders: value);
    await _persistConfig(
      value
          ? 'CSV exports will include headers.'
          : 'CSV exports will omit headers.',
    );
  }

  Future<void> updateAutocompleteEnabled(bool value) async {
    config = config.copyWith(
      editorSettings: config.editorSettings.copyWith(
        autocompleteEnabled: value,
      ),
    );
    await _persistConfig(
      value ? 'SQL autocomplete enabled.' : 'SQL autocomplete disabled.',
    );
  }

  Future<void> updateAutocompleteMaxSuggestions(String rawValue) async {
    final parsed = int.tryParse(rawValue.trim());
    if (parsed == null || parsed <= 0) {
      _setWorkspaceError(
        'Autocomplete suggestions must be a positive integer.',
      );
      return;
    }
    config = config.copyWith(
      editorSettings: config.editorSettings.copyWith(
        autocompleteMaxSuggestions: parsed,
      ),
    );
    await _persistConfig('Updated autocomplete suggestion limit.');
  }

  Future<void> updateFormatterUppercaseKeywords(bool value) async {
    config = config.copyWith(
      editorSettings: config.editorSettings.copyWith(
        formatUppercaseKeywords: value,
      ),
    );
    await _persistConfig(
      value
          ? 'Formatter will uppercase SQL keywords.'
          : 'Formatter will preserve keyword casing.',
    );
  }

  Future<void> updateEditorIndentSpaces(String rawValue) async {
    final parsed = int.tryParse(rawValue.trim());
    if (parsed == null || parsed <= 0) {
      _setWorkspaceError('Indent spaces must be a positive integer.');
      return;
    }
    config = config.copyWith(
      editorSettings: config.editorSettings.copyWith(indentSpaces: parsed),
    );
    await _persistConfig('Updated SQL formatter indentation.');
  }

  Future<void> saveSnippet(SqlSnippet snippet) async {
    config = config.upsertSnippet(snippet);
    await _persistConfig('Saved snippet "${snippet.name}".');
  }

  Future<void> deleteSnippet(String snippetId) async {
    final existing = config.snippets.where((item) => item.id == snippetId);
    if (existing.isEmpty) {
      return;
    }
    config = config.removeSnippet(snippetId);
    await _persistConfig('Deleted snippet "${existing.first.name}".');
  }

  String createSnippetId() =>
      'snippet-${DateTime.now().microsecondsSinceEpoch.toString()}';

  String suggestExportPath([String? tabId]) {
    final tab = tabId == null ? activeTab : tabById(tabId) ?? activeTab;
    return _suggestExportPathForTitle(tab.title);
  }

  String? errorDetailsForTab(String tabId) {
    final tab = tabById(tabId);
    if (tab?.error == null) {
      return null;
    }
    return tab!.error!.toClipboardText(sql: tab.lastSql ?? tab.sql);
  }

  List<SchemaObjectSummary> filterSchemaObjects(String rawFilter) {
    final filter = rawFilter.trim().toLowerCase();
    if (filter.isEmpty) {
      return schema.objects;
    }
    return schema.objects.where((object) {
      if (object.name.toLowerCase().contains(filter)) {
        return true;
      }
      if (object.columns.any(
        (column) =>
            column.name.toLowerCase().contains(filter) ||
            column.type.toLowerCase().contains(filter) ||
            column.constraintSummaries.any(
              (summary) => summary.toLowerCase().contains(filter),
            ),
      )) {
        return true;
      }
      return schema
          .indexesForObject(object.name)
          .any(
            (index) =>
                index.name.toLowerCase().contains(filter) ||
                index.kind.toLowerCase().contains(filter) ||
                index.columns.any(
                  (column) => column.toLowerCase().contains(filter),
                ),
          );
    }).toList();
  }

  List<String> schemaNotesForObject(SchemaObjectSummary object) {
    return <String>[
      if (object.kind == SchemaObjectKind.table && object.ddl == null)
        'Table DDL is not exposed by the current DecentDB Dart schema API.',
      if (object.kind == SchemaObjectKind.view && object.ddl == null)
        'View definition text is not exposed for this object.',
      'Trigger metadata is not exposed by the current DecentDB Dart schema API.',
      'Generated-column metadata is not exposed by the current DecentDB Dart schema API.',
      'Temporary-object metadata is not exposed by the current DecentDB Dart schema API.',
    ];
  }

  @override
  void dispose() {
    _disposed = true;
    _workspaceSaveDebounce?.cancel();
    if (hasOpenDatabase) {
      unawaited(_persistWorkspaceStateNow());
    }
    unawaited(_gateway.dispose());
    super.dispose();
  }

  QueryTabState _applyFirstPage(
    QueryTabState tab,
    QueryResultPage page, {
    required String statusMessage,
  }) {
    return tab.copyWith(
      resultColumns: page.columns,
      resultRows: page.rows,
      cursorId: page.cursorId,
      rowsAffected: page.rowsAffected,
      elapsed: page.elapsed,
      hasMoreRows: !page.done,
      phase: page.done ? QueryPhase.completed : QueryPhase.running,
      statusMessage: statusMessage,
    );
  }

  Future<void> _cancelAllOpenCursors() async {
    for (final tab in tabs) {
      if (tab.cursorId == null) {
        continue;
      }
      try {
        await _gateway.cancelQuery(tab.cursorId!);
      } catch (_) {
        // Ignore stale cancellation failures during workspace switches.
      }
    }
  }

  List<Object?>? _parseParameters(String tabId, String rawJson) {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) {
      return const <Object?>[];
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) {
        _setTabError(
          tabId,
          const QueryErrorDetails(
            stage: QueryErrorStage.validation,
            message: 'Parameters must be a JSON array such as [1, "alice"].',
          ),
        );
        return null;
      }
      return decoded.cast<Object?>();
    } catch (error) {
      _setTabError(
        tabId,
        QueryErrorDetails(
          stage: QueryErrorStage.validation,
          message: 'Could not parse parameter JSON: $error',
        ),
      );
      return null;
    }
  }

  bool _isCurrentGeneration(String tabId, int generation) {
    final tab = tabById(tabId);
    return tab != null && tab.executionGeneration == generation;
  }

  void _setTabError(String tabId, QueryErrorDetails error) {
    _mutateTab(
      tabId,
      (current) => current.copyWith(
        phase: QueryPhase.failed,
        error: error,
        statusMessage: null,
      ),
      notify: false,
    );
    _safeNotify();
  }

  void _setWorkspaceError(String message) {
    workspaceError = message;
    workspaceMessage = null;
    _safeNotify();
  }

  Future<void> _persistConfig(String statusMessage) async {
    try {
      await _configStore.save(config);
      workspaceMessage = statusMessage;
      workspaceError = null;
    } catch (error) {
      workspaceError = error.toString();
      workspaceMessage = null;
    } finally {
      _safeNotify();
    }
  }

  void _mutateActiveTab(
    QueryTabState Function(QueryTabState current) transform, {
    bool persist = false,
  }) {
    _mutateTab(activeTabId, transform, persist: persist);
  }

  void _mutateTab(
    String tabId,
    QueryTabState Function(QueryTabState current) transform, {
    bool persist = false,
    bool notify = true,
  }) {
    final index = tabs.indexWhere((tab) => tab.id == tabId);
    if (index < 0) {
      return;
    }
    final updated = <QueryTabState>[...tabs];
    updated[index] = transform(updated[index]);
    tabs = updated;
    if (persist) {
      _scheduleWorkspaceStateSave();
    }
    if (notify) {
      _safeNotify();
    }
  }

  void _resetTabs({required bool notify, bool resetCounters = false}) {
    if (resetCounters) {
      _nextTabIdCounter = 1;
      _nextTabTitleCounter = 1;
    }
    final title = _newTabTitle();
    tabs = <QueryTabState>[
      QueryTabState.initial(
        id: _newTabId(),
        title: title,
        exportPath: _suggestExportPathForTitle(title),
      ),
    ];
    _activeTabId = tabs.first.id;
    if (notify) {
      _safeNotify();
    }
  }

  void _restoreTabs(
    PersistedWorkspaceState? persistedState, {
    required bool notify,
  }) {
    if (persistedState == null || persistedState.tabs.isEmpty) {
      _resetTabs(notify: notify, resetCounters: true);
      return;
    }

    final restoredTabs = <QueryTabState>[
      for (final draft in persistedState.tabs)
        QueryTabState.initial(
          id: draft.id,
          title: draft.title,
          sql: draft.sql,
          parameterJson: draft.parameterJson,
          exportPath: draft.exportPath.isEmpty
              ? _suggestExportPathForTitle(draft.title)
              : draft.exportPath,
        ),
    ];
    tabs = restoredTabs;
    _activeTabId =
        restoredTabs.any((tab) => tab.id == persistedState.activeTabId)
        ? persistedState.activeTabId
        : restoredTabs.first.id;
    _recomputeTabCounters();
    if (notify) {
      _safeNotify();
    }
  }

  void _recomputeTabCounters() {
    var maxId = 0;
    var maxTitle = 0;
    final idPattern = RegExp(r'^query-tab-(\d+)$');
    final titlePattern = RegExp(r'^Query (\d+)$');
    for (final tab in tabs) {
      final idMatch = idPattern.firstMatch(tab.id);
      if (idMatch != null) {
        maxId = maxId > int.parse(idMatch.group(1)!)
            ? maxId
            : int.parse(idMatch.group(1)!);
      }
      final titleMatch = titlePattern.firstMatch(tab.title);
      if (titleMatch != null) {
        maxTitle = maxTitle > int.parse(titleMatch.group(1)!)
            ? maxTitle
            : int.parse(titleMatch.group(1)!);
      }
    }
    _nextTabIdCounter = maxId + 1;
    _nextTabTitleCounter = maxTitle + 1;
  }

  String _newTabId() => 'query-tab-${_nextTabIdCounter++}';

  String _newTabTitle() => 'Query ${_nextTabTitleCounter++}';

  void _scheduleWorkspaceStateSave() {
    final currentDatabasePath = databasePath;
    if (currentDatabasePath == null) {
      return;
    }
    _workspaceSaveDebounce?.cancel();
    _workspaceSaveDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_persistWorkspaceStateNow(databasePath: currentDatabasePath));
    });
  }

  Future<void> _persistWorkspaceStateNow({String? databasePath}) async {
    final targetPath = databasePath ?? this.databasePath;
    if (targetPath == null) {
      return;
    }
    try {
      await _workspaceStateStore.save(targetPath, _serializeWorkspaceState());
    } catch (error) {
      workspaceError = 'Could not save workspace state: $error';
      workspaceMessage = null;
      _safeNotify();
    }
  }

  PersistedWorkspaceState _serializeWorkspaceState() {
    return PersistedWorkspaceState(
      schemaVersion: PersistedWorkspaceState.currentSchemaVersion,
      activeTabId: _activeTabId,
      tabs: <WorkspaceTabDraft>[
        for (final tab in tabs)
          WorkspaceTabDraft(
            id: tab.id,
            title: tab.title,
            sql: tab.sql,
            parameterJson: tab.parameterJson,
            exportPath: tab.exportPath.trim().isEmpty
                ? suggestExportPath(tab.id)
                : tab.exportPath,
          ),
      ],
    );
  }

  String _suggestExportPathForTitle(String title) {
    final safeTitle = title.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '-',
    );
    if (databasePath == null) {
      return p.join(
        Directory.current.path,
        'decent-bench-${safeTitle.isEmpty ? 'query' : safeTitle}.csv',
      );
    }
    final directory = p.dirname(databasePath!);
    final basename = p.basenameWithoutExtension(databasePath!);
    final suffix = safeTitle.isEmpty ? 'query' : safeTitle;
    return p.join(directory, '$basename-$suffix.csv');
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}
