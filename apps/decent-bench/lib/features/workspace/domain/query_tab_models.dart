import 'query_phase_models.dart';
import 'query_contract_models.dart';

class QueryMessageEntry {
  const QueryMessageEntry({
    required this.level,
    required this.message,
    required this.timestamp,
  });

  final QueryMessageLevel level;
  final String message;
  final DateTime timestamp;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'level': level.name,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory QueryMessageEntry.fromJson(Map<String, Object?> map) {
    return QueryMessageEntry(
      level: switch (map['level'] as String? ?? 'info') {
        'warning' => QueryMessageLevel.warning,
        'error' => QueryMessageLevel.error,
        _ => QueryMessageLevel.info,
      },
      message: map['message'] as String? ?? '',
      timestamp: DateTime.parse(
        map['timestamp'] as String? ??
            DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
      ),
    );
  }
}

class QueryHistoryEntry {
  const QueryHistoryEntry({
    required this.sql,
    required this.parameterJson,
    required this.ranAt,
    required this.outcome,
    required this.elapsed,
    required this.rowsLoaded,
    required this.rowsAffected,
    this.errorMessage,
  });

  final String sql;
  final String parameterJson;
  final DateTime ranAt;
  final QueryHistoryOutcome outcome;
  final Duration elapsed;
  final int? rowsLoaded;
  final int? rowsAffected;
  final String? errorMessage;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'sql': sql,
      'parameterJson': parameterJson,
      'ranAt': ranAt.toIso8601String(),
      'outcome': outcome.name,
      'elapsedMs': elapsed.inMilliseconds,
      'rowsLoaded': rowsLoaded,
      'rowsAffected': rowsAffected,
      'errorMessage': errorMessage,
    };
  }

  factory QueryHistoryEntry.fromJson(Map<String, Object?> map) {
    return QueryHistoryEntry(
      sql: map['sql']! as String,
      parameterJson: map['parameterJson'] as String? ?? '',
      ranAt: DateTime.parse(map['ranAt']! as String),
      outcome: switch (map['outcome'] as String? ?? 'completed') {
        'failed' => QueryHistoryOutcome.failed,
        'cancelled' => QueryHistoryOutcome.cancelled,
        _ => QueryHistoryOutcome.completed,
      },
      elapsed: Duration(milliseconds: map['elapsedMs'] as int? ?? 0),
      rowsLoaded: map['rowsLoaded'] as int?,
      rowsAffected: map['rowsAffected'] as int?,
      errorMessage: map['errorMessage'] as String?,
    );
  }
}

class QueryExecutionPlanState {
  const QueryExecutionPlanState({
    required this.columns,
    required this.rows,
    required this.isLoading,
    this.errorMessage,
  });

  const QueryExecutionPlanState.idle()
    : columns = const <String>[],
      rows = const <Map<String, Object?>>[],
      isLoading = false,
      errorMessage = null;

  const QueryExecutionPlanState.loading()
    : columns = const <String>[],
      rows = const <Map<String, Object?>>[],
      isLoading = true,
      errorMessage = null;

  final List<String> columns;
  final List<Map<String, Object?>> rows;
  final bool isLoading;
  final String? errorMessage;

  bool get hasData => columns.isNotEmpty || rows.isNotEmpty;

  QueryExecutionPlanState copyWith({
    List<String>? columns,
    List<Map<String, Object?>>? rows,
    bool? isLoading,
    Object? errorMessage = QueryTabState._unset,
  }) {
    return QueryExecutionPlanState(
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == QueryTabState._unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class QueryTabState {
  const QueryTabState({
    required this.id,
    required this.title,
    required this.sql,
    required this.parameterJson,
    required this.exportPath,
    required this.phase,
    required this.resultColumns,
    required this.resultRows,
    required this.cursorId,
    required this.error,
    required this.statusMessage,
    required this.lastSql,
    required this.lastParameterJson,
    required this.lastParams,
    required this.lastRunStartedAt,
    required this.rowsAffected,
    required this.elapsed,
    required this.hasMoreRows,
    required this.isExporting,
    required this.isResultPartial,
    required this.executionGeneration,
    required this.executionPlan,
    required this.queryContract,
    required this.messageHistory,
    required this.queryHistory,
  });

  static const Object _unset = Object();

  final String id;
  final String title;
  final String sql;
  final String parameterJson;
  final String exportPath;
  final QueryPhase phase;
  final List<String> resultColumns;
  final List<Map<String, Object?>> resultRows;
  final String? cursorId;
  final QueryErrorDetails? error;
  final String? statusMessage;
  final String? lastSql;
  final String? lastParameterJson;
  final List<Object?> lastParams;
  final DateTime? lastRunStartedAt;
  final int? rowsAffected;
  final Duration? elapsed;
  final bool hasMoreRows;
  final bool isExporting;
  final bool isResultPartial;
  final int executionGeneration;
  final QueryExecutionPlanState executionPlan;
  final QueryContract? queryContract;
  final List<QueryMessageEntry> messageHistory;
  final List<QueryHistoryEntry> queryHistory;

  factory QueryTabState.initial({
    required String id,
    required String title,
    String sql = 'SELECT 1 AS ready;',
    String parameterJson = '',
    String exportPath = '',
  }) {
    return QueryTabState(
      id: id,
      title: title,
      sql: sql,
      parameterJson: parameterJson,
      exportPath: exportPath,
      phase: QueryPhase.idle,
      resultColumns: const <String>[],
      resultRows: const <Map<String, Object?>>[],
      cursorId: null,
      error: null,
      statusMessage: null,
      lastSql: null,
      lastParameterJson: null,
      lastParams: const <Object?>[],
      lastRunStartedAt: null,
      rowsAffected: null,
      elapsed: null,
      hasMoreRows: false,
      isExporting: false,
      isResultPartial: false,
      executionGeneration: 0,
      executionPlan: const QueryExecutionPlanState.idle(),
      queryContract: null,
      messageHistory: const <QueryMessageEntry>[],
      queryHistory: const <QueryHistoryEntry>[],
    );
  }

  bool get canCancel =>
      phase == QueryPhase.opening ||
      phase == QueryPhase.running ||
      phase == QueryPhase.fetching ||
      phase == QueryPhase.cancelling;

  bool get canExport =>
      lastSql != null && resultColumns.isNotEmpty && !isExporting;

  bool get hasResultData => resultColumns.isNotEmpty || rowsAffected != null;

  List<QueryParameterContract> get parameterContracts =>
      queryContract?.parameters ?? const <QueryParameterContract>[];

  List<QueryResultColumnContract> get resultColumnContracts =>
      queryContract?.resultColumns ?? const <QueryResultColumnContract>[];

  QueryResultColumnContract? resultContractForColumn(String columnName) {
    for (final column in resultColumnContracts) {
      if (column.name == columnName) {
        return column;
      }
    }
    final ordinal = resultColumns.indexOf(columnName);
    if (ordinal < 0) {
      return null;
    }
    for (final column in resultColumnContracts) {
      if (column.ordinal == ordinal) {
        return column;
      }
    }
    return null;
  }

  QueryTabState copyWith({
    String? id,
    String? title,
    String? sql,
    String? parameterJson,
    String? exportPath,
    QueryPhase? phase,
    List<String>? resultColumns,
    List<Map<String, Object?>>? resultRows,
    Object? cursorId = _unset,
    Object? error = _unset,
    Object? statusMessage = _unset,
    Object? lastSql = _unset,
    Object? lastParameterJson = _unset,
    List<Object?>? lastParams,
    Object? lastRunStartedAt = _unset,
    Object? rowsAffected = _unset,
    Object? elapsed = _unset,
    bool? hasMoreRows,
    bool? isExporting,
    bool? isResultPartial,
    int? executionGeneration,
    QueryExecutionPlanState? executionPlan,
    Object? queryContract = _unset,
    List<QueryMessageEntry>? messageHistory,
    List<QueryHistoryEntry>? queryHistory,
  }) {
    return QueryTabState(
      id: id ?? this.id,
      title: title ?? this.title,
      sql: sql ?? this.sql,
      parameterJson: parameterJson ?? this.parameterJson,
      exportPath: exportPath ?? this.exportPath,
      phase: phase ?? this.phase,
      resultColumns: resultColumns ?? this.resultColumns,
      resultRows: resultRows ?? this.resultRows,
      cursorId: cursorId == _unset ? this.cursorId : cursorId as String?,
      error: error == _unset ? this.error : error as QueryErrorDetails?,
      statusMessage: statusMessage == _unset
          ? this.statusMessage
          : statusMessage as String?,
      lastSql: lastSql == _unset ? this.lastSql : lastSql as String?,
      lastParameterJson: lastParameterJson == _unset
          ? this.lastParameterJson
          : lastParameterJson as String?,
      lastParams: lastParams ?? this.lastParams,
      lastRunStartedAt: lastRunStartedAt == _unset
          ? this.lastRunStartedAt
          : lastRunStartedAt as DateTime?,
      rowsAffected: rowsAffected == _unset
          ? this.rowsAffected
          : rowsAffected as int?,
      elapsed: elapsed == _unset ? this.elapsed : elapsed as Duration?,
      hasMoreRows: hasMoreRows ?? this.hasMoreRows,
      isExporting: isExporting ?? this.isExporting,
      isResultPartial: isResultPartial ?? this.isResultPartial,
      executionGeneration: executionGeneration ?? this.executionGeneration,
      executionPlan: executionPlan ?? this.executionPlan,
      queryContract: queryContract == _unset
          ? this.queryContract
          : queryContract as QueryContract?,
      messageHistory: messageHistory ?? this.messageHistory,
      queryHistory: queryHistory ?? this.queryHistory,
    );
  }
}
