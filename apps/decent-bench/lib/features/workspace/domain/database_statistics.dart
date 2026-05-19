import 'workspace_models.dart';

class DatabaseStatistics {
  const DatabaseStatistics({
    required this.databasePath,
    required this.databaseFileBytes,
    required this.walFileBytes,
    required this.shmFileBytes,
    required this.tableCount,
    required this.viewCount,
    required this.indexCount,
    required this.triggerCount,
    required this.temporaryObjectCount,
    required this.branchCount,
    required this.snapshotCount,
    required this.currentBranch,
    required this.branchWorkflowAvailable,
    required this.branchWorkflowMessage,
    required this.rowCountQueries,
  });

  final String? databasePath;
  final int? databaseFileBytes;
  final int? walFileBytes;
  final int? shmFileBytes;
  final int tableCount;
  final int viewCount;
  final int indexCount;
  final int triggerCount;
  final int temporaryObjectCount;
  final int branchCount;
  final int snapshotCount;
  final String currentBranch;
  final bool branchWorkflowAvailable;
  final String branchWorkflowMessage;
  final Map<String, String> rowCountQueries;

  bool get hasWalSidecar => (walFileBytes ?? 0) > 0;

  List<MapEntry<String, String>> get summaryRows {
    return <MapEntry<String, String>>[
      MapEntry('Database', databasePath ?? 'No database open'),
      MapEntry('Database file', _formatBytes(databaseFileBytes)),
      MapEntry('WAL sidecar', _formatBytes(walFileBytes)),
      MapEntry('SHM sidecar', _formatBytes(shmFileBytes)),
      MapEntry('Tables', '$tableCount'),
      MapEntry('Views', '$viewCount'),
      MapEntry('Indexes', '$indexCount'),
      MapEntry('Triggers', '$triggerCount'),
      MapEntry('Temporary objects', '$temporaryObjectCount'),
      MapEntry('Current branch', currentBranch),
      MapEntry('Branches', '$branchCount'),
      MapEntry('Snapshots', '$snapshotCount'),
      MapEntry(
        'Branch workflow',
        branchWorkflowAvailable ? 'Available' : branchWorkflowMessage,
      ),
    ];
  }

  List<String> get maintenanceHints {
    return <String>[
      if (hasWalSidecar)
        'A WAL sidecar is present. Consider checkpointing before archiving or copying this workspace.',
      if (!branchWorkflowAvailable) branchWorkflowMessage,
      if (temporaryObjectCount > 0)
        'Temporary objects exist only for the current database connection.',
      if (tableCount > 0)
        'Per-table row counts are lazy. Open the generated COUNT query when exact counts are needed.',
    ];
  }

  String toClipboardText() {
    final buffer = StringBuffer();
    for (final row in summaryRows) {
      buffer.writeln('${row.key}: ${row.value}');
    }
    if (maintenanceHints.isNotEmpty) {
      buffer.writeln('Maintenance hints:');
      for (final hint in maintenanceHints) {
        buffer.writeln('- $hint');
      }
    }
    return buffer.toString().trimRight();
  }
}

DatabaseStatistics buildDatabaseStatistics({
  required SchemaSnapshot schema,
  required WorkspaceBranchState branchState,
  String? databasePath,
  int? databaseFileBytes,
  int? walFileBytes,
  int? shmFileBytes,
}) {
  final temporaryObjectCount =
      schema.objects.where((object) => object.temporary).length +
      schema.indexes.where((index) => index.temporary).length +
      schema.triggers.where((trigger) => trigger.temporary).length;
  return DatabaseStatistics(
    databasePath: databasePath,
    databaseFileBytes: databaseFileBytes,
    walFileBytes: walFileBytes,
    shmFileBytes: shmFileBytes,
    tableCount: schema.tables.length,
    viewCount: schema.views.length,
    indexCount: schema.indexes.length,
    triggerCount: schema.triggers.length,
    temporaryObjectCount: temporaryObjectCount,
    branchCount: branchState.branches.length,
    snapshotCount: branchState.snapshots.length,
    currentBranch: branchState.currentBranch,
    branchWorkflowAvailable: branchState.isNativeBranchApiAvailable,
    branchWorkflowMessage: branchState.isNativeBranchApiAvailable
        ? 'Available'
        : branchState.nativeBranchApiUnavailableReason,
    rowCountQueries: <String, String>{
      for (final table in schema.tables)
        table.name:
            'SELECT COUNT(*) AS row_count\nFROM ${quoteSqlIdentifier(table.name)};',
    },
  );
}

String quoteSqlIdentifier(String value) {
  return '"${value.replaceAll('"', '""')}"';
}

String _formatBytes(int? value) {
  if (value == null) {
    return 'Unavailable';
  }
  if (value < 1024) {
    return '$value B';
  }
  final units = <String>['KB', 'MB', 'GB', 'TB'];
  var amount = value / 1024.0;
  var unitIndex = 0;
  while (amount >= 1024 && unitIndex < units.length - 1) {
    amount /= 1024.0;
    unitIndex++;
  }
  return '${amount.toStringAsFixed(amount >= 10 ? 1 : 2)} ${units[unitIndex]}';
}
