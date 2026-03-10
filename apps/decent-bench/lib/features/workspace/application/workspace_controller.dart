import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../domain/app_config.dart';
import '../domain/workspace_models.dart';
import '../infrastructure/app_config_store.dart';
import '../infrastructure/decentdb_bridge.dart';

class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    WorkspaceDatabaseGateway? gateway,
    WorkspaceConfigStore? configStore,
  }) : _gateway = gateway ?? DecentDbBridge(),
       _configStore = configStore ?? AppConfigStore();

  final WorkspaceDatabaseGateway _gateway;
  final WorkspaceConfigStore _configStore;

  AppConfig config = AppConfig.defaults();
  SchemaSnapshot schema = SchemaSnapshot.empty();
  QueryPhase queryPhase = QueryPhase.idle;
  List<String> resultColumns = const <String>[];
  List<Map<String, Object?>> resultRows = const <Map<String, Object?>>[];

  String? databasePath;
  String? engineVersion;
  String? nativeLibraryPath;
  String? activeCursorId;
  String? lastError;
  String? lastStatus;
  String? lastSql;
  List<Object?> lastParams = const <Object?>[];
  int? lastRowsAffected;
  Duration? lastQueryElapsed;
  bool isInitializing = true;
  bool isSchemaLoading = false;
  bool isBusy = false;
  bool isFetchingNextPage = false;
  bool isExporting = false;
  bool hasMoreRows = false;

  int _executionGeneration = 0;
  bool _disposed = false;

  bool get hasOpenDatabase => databasePath != null;

  bool get canRunQuery => hasOpenDatabase && !isBusy && !isExporting;

  bool get canCancelQuery =>
      queryPhase == QueryPhase.opening ||
      queryPhase == QueryPhase.running ||
      queryPhase == QueryPhase.fetching ||
      queryPhase == QueryPhase.cancelling;

  Future<void> initialize() async {
    if (!isInitializing) {
      return;
    }

    try {
      config = await _configStore.load();
      nativeLibraryPath = await _gateway.initialize();
      lastStatus = 'Ready.';
    } catch (error) {
      lastError = error.toString();
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
      _setError('Enter a DecentDB file path first.');
      return;
    }

    final file = File(normalized);
    try {
      if (createIfMissing) {
        if (await file.exists()) {
          _setError('Refusing to create over an existing file: $normalized');
          return;
        }
        await file.parent.create(recursive: true);
      } else if (!await file.exists()) {
        _setError('Database file does not exist: $normalized');
        return;
      }
    } on FileSystemException catch (error) {
      _setError(error.message);
      return;
    }

    isBusy = true;
    isSchemaLoading = true;
    queryPhase = QueryPhase.idle;
    lastError = null;
    lastStatus = createIfMissing
        ? 'Creating database...'
        : 'Opening database...';
    _clearResults();
    _safeNotify();

    try {
      final session = await _gateway.openDatabase(normalized);
      databasePath = session.path;
      engineVersion = session.engineVersion;
      config = config.pushRecentFile(session.path);
      await _configStore.save(config);
      await refreshSchema(showLoadingState: false);
      lastStatus =
          'Opened ${p.basename(session.path)} on DecentDB ${session.engineVersion}.';
    } catch (error) {
      _setError(error.toString());
    } finally {
      isBusy = false;
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
      lastError = null;
      lastStatus = 'Refreshing schema...';
      _safeNotify();
    }

    try {
      schema = await _gateway.loadSchema();
      lastStatus =
          'Loaded ${schema.tables.length} tables and ${schema.views.length} views.';
    } catch (error) {
      _setError(error.toString());
    } finally {
      isSchemaLoading = false;
      _safeNotify();
    }
  }

  Future<void> runSql({
    required String sql,
    required String parameterJson,
  }) async {
    if (!hasOpenDatabase) {
      _setError('Open or create a DecentDB file before running SQL.');
      return;
    }

    final trimmedSql = sql.trim();
    if (trimmedSql.isEmpty) {
      _setError('Enter SQL before pressing Run.');
      return;
    }

    final params = _parseParameters(parameterJson);
    if (params == null) {
      return;
    }

    final generation = ++_executionGeneration;
    final previousCursor = activeCursorId;
    activeCursorId = null;
    if (previousCursor != null) {
      unawaited(_gateway.cancelQuery(previousCursor));
    }

    isBusy = true;
    isFetchingNextPage = false;
    queryPhase = QueryPhase.opening;
    lastError = null;
    lastStatus = 'Executing SQL...';
    lastSql = trimmedSql;
    lastParams = params;
    lastRowsAffected = null;
    lastQueryElapsed = null;
    _clearResults();
    _safeNotify();

    try {
      final page = await _gateway.runQuery(
        sql: trimmedSql,
        params: params,
        pageSize: config.defaultPageSize,
      );
      if (!_isCurrentGeneration(generation)) {
        if (page.cursorId != null) {
          unawaited(_gateway.cancelQuery(page.cursorId!));
        }
        return;
      }

      _applyFirstPage(page);
      lastStatus = page.rowsAffected != null
          ? 'Statement completed with ${page.rowsAffected} affected rows.'
          : 'Loaded ${resultRows.length} rows from the first page.';
    } catch (error) {
      if (_isCurrentGeneration(generation)) {
        queryPhase = QueryPhase.failed;
        lastError = error.toString();
      }
    } finally {
      if (_isCurrentGeneration(generation)) {
        isBusy = false;
        _safeNotify();
      }
    }
  }

  Future<void> fetchNextPage() async {
    if (activeCursorId == null || isFetchingNextPage || !hasMoreRows) {
      return;
    }

    final generation = _executionGeneration;
    isFetchingNextPage = true;
    queryPhase = QueryPhase.fetching;
    lastError = null;
    _safeNotify();

    try {
      final page = await _gateway.fetchNextPage(
        cursorId: activeCursorId!,
        pageSize: config.defaultPageSize,
      );
      if (!_isCurrentGeneration(generation)) {
        if (page.cursorId != null) {
          unawaited(_gateway.cancelQuery(page.cursorId!));
        }
        return;
      }

      resultRows = <Map<String, Object?>>[...resultRows, ...page.rows];
      activeCursorId = page.cursorId;
      hasMoreRows = !page.done;
      lastQueryElapsed = (lastQueryElapsed ?? Duration.zero) + page.elapsed;
      queryPhase = page.done ? QueryPhase.completed : QueryPhase.running;
      lastStatus = page.done
          ? 'Loaded ${resultRows.length} total rows.'
          : 'Loaded ${resultRows.length} rows so far.';
    } catch (error) {
      if (_isCurrentGeneration(generation)) {
        queryPhase = QueryPhase.failed;
        lastError = error.toString();
      }
    } finally {
      if (_isCurrentGeneration(generation)) {
        isFetchingNextPage = false;
        _safeNotify();
      }
    }
  }

  Future<void> cancelActiveQuery() async {
    if (!canCancelQuery) {
      return;
    }

    final cursorId = activeCursorId;
    _executionGeneration++;
    activeCursorId = null;
    hasMoreRows = false;
    isBusy = false;
    isFetchingNextPage = false;
    queryPhase = QueryPhase.cancelled;
    lastStatus = 'Query cancelled. Late results will be ignored.';
    lastError = null;
    _safeNotify();

    if (cursorId != null) {
      try {
        await _gateway.cancelQuery(cursorId);
      } catch (_) {
        // Best-effort cancellation by design.
      }
    }
  }

  Future<void> exportCurrentQuery(String rawPath) async {
    final exportPath = rawPath.trim();
    if (lastSql == null || resultColumns.isEmpty) {
      _setError('Run a row-producing query before exporting CSV.');
      return;
    }
    if (exportPath.isEmpty) {
      _setError('Enter a CSV destination path first.');
      return;
    }

    isExporting = true;
    lastError = null;
    lastStatus = 'Exporting CSV...';
    _safeNotify();

    try {
      final result = await _gateway.exportCsv(
        sql: lastSql!,
        params: lastParams,
        pageSize: config.defaultPageSize,
        path: exportPath,
        delimiter: config.csvDelimiter,
        includeHeaders: config.csvIncludeHeaders,
      );
      lastStatus = 'Exported ${result.rowCount} rows to ${result.path}.';
    } catch (error) {
      _setError(error.toString());
    } finally {
      isExporting = false;
      _safeNotify();
    }
  }

  Future<void> updateDefaultPageSize(String rawValue) async {
    final parsed = int.tryParse(rawValue.trim());
    if (parsed == null || parsed <= 0) {
      _setError('Page size must be a positive integer.');
      return;
    }

    config = config.copyWith(defaultPageSize: parsed);
    await _persistConfig('Updated default page size to $parsed rows.');
  }

  Future<void> updateCsvDelimiter(String rawValue) async {
    if (rawValue.isEmpty) {
      _setError('CSV delimiter cannot be empty.');
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

  String suggestExportPath() {
    if (databasePath == null) {
      return p.join(Directory.current.path, 'decent-bench-export.csv');
    }
    final directory = p.dirname(databasePath!);
    final basename = p.basenameWithoutExtension(databasePath!);
    return p.join(directory, '$basename-query.csv');
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_gateway.dispose());
    super.dispose();
  }

  void _applyFirstPage(QueryResultPage page) {
    resultColumns = page.columns;
    resultRows = page.rows;
    activeCursorId = page.cursorId;
    hasMoreRows = !page.done;
    lastRowsAffected = page.rowsAffected;
    lastQueryElapsed = page.elapsed;
    queryPhase = page.done ? QueryPhase.completed : QueryPhase.running;
  }

  void _clearResults() {
    resultColumns = const <String>[];
    resultRows = const <Map<String, Object?>>[];
    lastRowsAffected = null;
    lastQueryElapsed = null;
    hasMoreRows = false;
  }

  List<Object?>? _parseParameters(String rawJson) {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) {
      return const <Object?>[];
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) {
        _setError('Parameters must be a JSON array such as [1, "alice"].');
        return null;
      }
      return decoded.cast<Object?>();
    } catch (error) {
      _setError('Could not parse parameter JSON: $error');
      return null;
    }
  }

  bool _isCurrentGeneration(int generation) =>
      generation == _executionGeneration;

  Future<void> _persistConfig(String statusMessage) async {
    try {
      await _configStore.save(config);
      lastStatus = statusMessage;
      lastError = null;
    } catch (error) {
      _setError(error.toString());
    } finally {
      _safeNotify();
    }
  }

  void _setError(String message) {
    lastError = message;
    lastStatus = null;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}
