class TableEditabilityState {
  const TableEditabilityState({
    required this.isEditable,
    required this.reason,
    this.tableName,
    this.primaryKeyColumn,
    this.primaryKeyResultColumn,
    this.editableColumns = const <String, String>{},
    this.insertableColumns = const <String, String>{},
    this.readOnlyColumns = const <String>{},
  });

  final bool isEditable;
  final String reason;
  final String? tableName;
  final String? primaryKeyColumn;
  final String? primaryKeyResultColumn;
  final Map<String, String> editableColumns;
  final Map<String, String> insertableColumns;
  final Set<String> readOnlyColumns;

  bool get canDeleteRows =>
      isEditable && tableName != null && primaryKeyResultColumn != null;

  bool get canInsertRows => isEditable && insertableColumns.isNotEmpty;

  bool canEditColumn(String columnName) =>
      editableColumns.containsKey(columnName);

  String get statusLabel {
    if (isEditable) {
      return 'Editable table: $tableName';
    }
    return 'Read-only results: $reason';
  }

  static const TableEditabilityState noResults = TableEditabilityState(
    isEditable: false,
    reason: 'Run a single-table SELECT before editing rows.',
  );
}

class TableEditCommitResult {
  const TableEditCommitResult({
    required this.success,
    required this.message,
    this.rowsAffected,
  });

  final bool success;
  final String message;
  final int? rowsAffected;
}
