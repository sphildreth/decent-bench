import 'workspace_models.dart';

enum ResultChartType { line, bar, pie, scatter }

class ResultVisualizationModel {
  const ResultVisualizationModel({
    required this.chartType,
    required this.xColumn,
    required this.yColumn,
    required this.points,
    required this.loadedRows,
    required this.truncated,
  });

  final ResultChartType chartType;
  final String xColumn;
  final String yColumn;
  final List<ResultChartPoint> points;
  final int loadedRows;
  final bool truncated;

  bool get hasData => points.isNotEmpty;
}

class ResultChartPoint {
  const ResultChartPoint({required this.xLabel, required this.y, this.x});

  final String xLabel;
  final double? x;
  final double y;
}

class ResultVisualizationColumns {
  const ResultVisualizationColumns({
    required this.xColumns,
    required this.yColumns,
  });

  final List<String> xColumns;
  final List<String> yColumns;
}

ResultVisualizationColumns inferVisualizationColumns({
  required List<String> columns,
  required List<Map<String, Object?>> rows,
  QueryTabState? tab,
}) {
  final xColumns = <String>[];
  final yColumns = <String>[];
  for (final column in columns) {
    final contract = tab?.resultContractForColumn(column);
    final descriptor = contract?.nativeTypeDescriptor;
    final numeric = _isNumericColumn(column, rows, descriptor);
    if (numeric) {
      yColumns.add(column);
    }
    if (!numeric || _hasNumericValues(column, rows)) {
      xColumns.add(column);
    }
  }
  return ResultVisualizationColumns(
    xColumns: xColumns.isEmpty ? columns : xColumns,
    yColumns: yColumns,
  );
}

ResultVisualizationModel buildResultVisualizationModel({
  required ResultChartType chartType,
  required String xColumn,
  required String yColumn,
  required List<Map<String, Object?>> rows,
  int maxRows = 500,
}) {
  final points = <ResultChartPoint>[];
  for (final row in rows.take(maxRows)) {
    final y = _asDouble(row[yColumn]);
    if (y == null) {
      continue;
    }
    points.add(
      ResultChartPoint(
        xLabel: formatCellValue(row[xColumn]),
        x: _asDouble(row[xColumn]),
        y: y,
      ),
    );
  }
  return ResultVisualizationModel(
    chartType: chartType,
    xColumn: xColumn,
    yColumn: yColumn,
    points: points,
    loadedRows: rows.length,
    truncated: rows.length > maxRows,
  );
}

bool _isNumericColumn(
  String column,
  List<Map<String, Object?>> rows,
  NativeTypeDescriptor? descriptor,
) {
  if (descriptor?.family == NativeTypeFamily.numeric) {
    return true;
  }
  return _hasNumericValues(column, rows);
}

bool _hasNumericValues(String column, List<Map<String, Object?>> rows) {
  var seen = 0;
  var numeric = 0;
  for (final row in rows) {
    final value = row[column];
    if (value == null) {
      continue;
    }
    seen++;
    if (_asDouble(value) != null) {
      numeric++;
    }
  }
  return seen > 0 && numeric == seen;
}

double? _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}
