import 'workspace_model_helpers.dart';

class BranchWorkflowUnavailable implements Exception {
  const BranchWorkflowUnavailable([this.message]);

  final String? message;

  @override
  String toString() => message ?? 'Branch workflow is unavailable.';
}

class WorkspaceBranchInfo {
  const WorkspaceBranchInfo({
    required this.name,
    this.isCurrent = false,
    this.parentRef,
    this.createdAt,
  });

  final String name;
  final bool isCurrent;
  final String? parentRef;
  final DateTime? createdAt;

  factory WorkspaceBranchInfo.fromMap(Map<String, Object?> map) {
    return WorkspaceBranchInfo(
      name: map['name']! as String,
      isCurrent: map['isCurrent'] as bool? ?? false,
      parentRef: map['parentRef'] as String?,
      createdAt: map['createdAt'] is String
          ? DateTime.tryParse(map['createdAt'] as String)
          : null,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'isCurrent': isCurrent,
      if (parentRef != null) 'parentRef': parentRef,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}

class WorkspaceSnapshotInfo {
  const WorkspaceSnapshotInfo({
    required this.name,
    required this.ref,
    this.branch,
    this.createdAt,
  });

  final String name;
  final String ref;
  final String? branch;
  final DateTime? createdAt;

  factory WorkspaceSnapshotInfo.fromMap(Map<String, Object?> map) {
    return WorkspaceSnapshotInfo(
      name: map['name']! as String,
      ref: map['ref']! as String,
      branch: map['branch'] as String?,
      createdAt: map['createdAt'] is String
          ? DateTime.tryParse(map['createdAt'] as String)
          : null,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'ref': ref,
      if (branch != null) 'branch': branch,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}

class WorkspaceBranchDiffRow {
  const WorkspaceBranchDiffRow({
    required this.tableName,
    required this.operation,
    this.primaryKey,
    this.before,
    this.after,
  });

  final String tableName;
  final String operation;
  final String? primaryKey;
  final Map<String, Object?>? before;
  final Map<String, Object?>? after;

  factory WorkspaceBranchDiffRow.fromMap(Map<String, Object?> map) {
    return WorkspaceBranchDiffRow(
      tableName: map['tableName']! as String,
      operation: map['operation']! as String,
      primaryKey: map['primaryKey'] as String?,
      before: asStringMap(map['before']),
      after: asStringMap(map['after']),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'tableName': tableName,
      'operation': operation,
      if (primaryKey != null) 'primaryKey': primaryKey,
      if (before != null) 'before': before,
      if (after != null) 'after': after,
    };
  }
}

class WorkspaceBranchDiff {
  const WorkspaceBranchDiff({
    required this.leftRef,
    required this.rightRef,
    required this.rows,
    required this.addedRows,
    required this.modifiedRows,
    required this.removedRows,
  });

  final String leftRef;
  final String rightRef;
  final List<WorkspaceBranchDiffRow> rows;
  final int addedRows;
  final int modifiedRows;
  final int removedRows;

  int get totalChanges => addedRows + modifiedRows + removedRows;

  factory WorkspaceBranchDiff.fromMap(Map<String, Object?> map) {
    return WorkspaceBranchDiff(
      leftRef: map['leftRef']! as String,
      rightRef: map['rightRef']! as String,
      rows: asMapList(
        map['rows'],
      ).map(WorkspaceBranchDiffRow.fromMap).toList(growable: false),
      addedRows: map['addedRows'] as int? ?? 0,
      modifiedRows: map['modifiedRows'] as int? ?? 0,
      removedRows: map['removedRows'] as int? ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'leftRef': leftRef,
      'rightRef': rightRef,
      'rows': <Map<String, Object?>>[for (final row in rows) row.toJson()],
      'addedRows': addedRows,
      'modifiedRows': modifiedRows,
      'removedRows': removedRows,
    };
  }

  static const WorkspaceBranchDiff empty = WorkspaceBranchDiff(
    leftRef: '',
    rightRef: '',
    rows: <WorkspaceBranchDiffRow>[],
    addedRows: 0,
    modifiedRows: 0,
    removedRows: 0,
  );
}

class WorkspaceBranchState {
  const WorkspaceBranchState({
    required this.currentBranch,
    required this.isNativeBranchApiAvailable,
    required this.nativeBranchApiUnavailableReason,
    required this.branches,
    required this.snapshots,
  });

  final String currentBranch;
  final bool isNativeBranchApiAvailable;
  final String nativeBranchApiUnavailableReason;
  final List<WorkspaceBranchInfo> branches;
  final List<WorkspaceSnapshotInfo> snapshots;

  factory WorkspaceBranchState.unavailable(String reason) {
    return WorkspaceBranchState(
      currentBranch: 'main',
      isNativeBranchApiAvailable: false,
      nativeBranchApiUnavailableReason: reason,
      branches: const <WorkspaceBranchInfo>[],
      snapshots: const <WorkspaceSnapshotInfo>[],
    );
  }

  factory WorkspaceBranchState.fromMap(Map<String, Object?> map) {
    return WorkspaceBranchState(
      currentBranch: map['currentBranch']! as String,
      isNativeBranchApiAvailable:
          map['isNativeBranchApiAvailable'] as bool? ?? false,
      nativeBranchApiUnavailableReason:
          map['nativeBranchApiUnavailableReason'] as String? ??
          'Native branch APIs are unavailable.',
      branches: asMapList(
        map['branches'],
      ).map(WorkspaceBranchInfo.fromMap).toList(growable: false),
      snapshots: asMapList(
        map['snapshots'],
      ).map(WorkspaceSnapshotInfo.fromMap).toList(growable: false),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'currentBranch': currentBranch,
      'isNativeBranchApiAvailable': isNativeBranchApiAvailable,
      'nativeBranchApiUnavailableReason': nativeBranchApiUnavailableReason,
      'branches': <Map<String, Object?>>[
        for (final branch in branches) branch.toJson(),
      ],
      'snapshots': <Map<String, Object?>>[
        for (final snapshot in snapshots) snapshot.toJson(),
      ],
    };
  }

  String get branchLabel {
    if (!isNativeBranchApiAvailable) {
      return 'Branch workflow unavailable';
    }
    return 'Branch: $currentBranch, ${branches.length} branches, ${snapshots.length} snapshots';
  }
}
