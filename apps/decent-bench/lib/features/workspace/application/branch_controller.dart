import 'package:flutter/foundation.dart';

import '../../../app/logging/app_logger.dart';
import '../domain/workspace_models.dart';
import '../infrastructure/decentdb_bridge.dart';

class BranchController extends ChangeNotifier {
  BranchController({
    required BranchWorkflowGateway gateway,
    AppLogger? logger,
    VoidCallback? onSchemaRefreshNeeded,
    void Function(String message)? onStatusMessage,
    void Function(String error)? onError,
  }) : _gateway = gateway,
       _logger = logger ?? const NoOpAppLogger(),
       _onSchemaRefreshNeeded = onSchemaRefreshNeeded,
       _onStatusMessage = onStatusMessage,
       _onError = onError;

  final BranchWorkflowGateway _gateway;
  final AppLogger _logger;
  final VoidCallback? _onSchemaRefreshNeeded;
  final void Function(String message)? _onStatusMessage;
  final void Function(String error)? _onError;

  static const String nativeBranchApiUnavailableReason =
      'Native DecentDB branch and snapshot operations require a public Dart '
      'binding API. Decent Bench does not call private binding internals or '
      'C ABI surfaces that are not exported by the public Dart package.';

  WorkspaceBranchState branchState = WorkspaceBranchState.unavailable(
    nativeBranchApiUnavailableReason,
  );
  WorkspaceBranchDiff? lastBranchDiff;
  bool isBranchStateLoading = false;

  String? _databasePath;

  bool get canUseNativeBranchWorkflow =>
      _databasePath != null && branchState.isNativeBranchApiAvailable;

  void attachWorkspace({required String? databasePath}) {
    _databasePath = databasePath;
    if (databasePath == null) {
      branchState = WorkspaceBranchState.unavailable('Open a database first.');
      lastBranchDiff = null;
      notifyListeners();
    }
  }

  Future<void> refreshBranchState({bool showLoadingState = true}) async {
    if (_databasePath == null) {
      branchState = WorkspaceBranchState.unavailable('Open a database first.');
      lastBranchDiff = null;
      if (showLoadingState) {
        notifyListeners();
      }
      return;
    }

    if (showLoadingState) {
      isBranchStateLoading = true;
      _onStatusMessage?.call('Refreshing branch and snapshot state...');
      notifyListeners();
    }

    try {
      final branches = await _gateway.listBranches();
      final snapshots = await _gateway.listSnapshots();
      final currentBranch = _currentBranchName(branches);
      branchState = WorkspaceBranchState(
        currentBranch: currentBranch,
        isNativeBranchApiAvailable: true,
        nativeBranchApiUnavailableReason: '',
        branches: branches,
        snapshots: snapshots,
      );
      if (showLoadingState) {
        _onStatusMessage?.call(
          'Loaded ${branches.length} branches and '
          '${snapshots.length} snapshots.',
        );
      }
      _logger.info(
        category: 'branch',
        operation: 'refresh_branch_state',
        message: 'Loaded branch and snapshot state.',
        databasePath: _databasePath,
        details: <String, Object?>{
          'current_branch': currentBranch,
          'branch_count': branches.length,
          'snapshot_count': snapshots.length,
        },
      );
    } on BranchWorkflowUnavailable catch (error) {
      _setBranchWorkflowUnavailable(
        error.message ?? nativeBranchApiUnavailableReason,
        setMessage: showLoadingState,
        notify: false,
      );
    } catch (error, stackTrace) {
      _setBranchWorkflowUnavailable(
        'Could not load native branch and snapshot state: $error',
        setMessage: showLoadingState,
        notify: false,
      );
      _logger.warning(
        category: 'branch',
        operation: 'refresh_branch_state',
        message: 'Branch and snapshot state refresh failed.',
        databasePath: _databasePath,
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      isBranchStateLoading = false;
      notifyListeners();
    }
  }

  Future<WorkspaceSnapshotInfo?> createSnapshot(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _onStatusMessage?.call('Snapshot name cannot be empty.');
      notifyListeners();
      return null;
    }
    if (!canUseNativeBranchWorkflow) {
      _setBranchWorkflowUnavailable(
        branchState.nativeBranchApiUnavailableReason,
      );
      return null;
    }
    try {
      _onStatusMessage?.call('Creating snapshot "$trimmed"...');
      notifyListeners();
      final snapshot = await _gateway.createSnapshot(name: trimmed);
      _onStatusMessage?.call('Created snapshot ${snapshot.name}.');
      await refreshBranchState(showLoadingState: false);
      notifyListeners();
      return snapshot;
    } on BranchWorkflowUnavailable catch (error) {
      _setBranchWorkflowUnavailable(
        error.message ?? nativeBranchApiUnavailableReason,
      );
      return null;
    } catch (error) {
      _onError?.call(error.toString());
      return null;
    }
  }

  Future<WorkspaceBranchInfo?> createBranch({
    required String branchName,
    String fromRef = 'main',
  }) async {
    final trimmed = branchName.trim();
    final sourceRef = fromRef.trim().isEmpty ? 'main' : fromRef.trim();
    if (trimmed.isEmpty) {
      _onStatusMessage?.call('Branch name cannot be empty.');
      notifyListeners();
      return null;
    }
    if (!canUseNativeBranchWorkflow) {
      _setBranchWorkflowUnavailable(
        branchState.nativeBranchApiUnavailableReason,
      );
      return null;
    }
    try {
      _onStatusMessage?.call('Creating branch "$trimmed"...');
      notifyListeners();
      final branch = await _gateway.createBranch(
        branchName: trimmed,
        fromRef: sourceRef,
      );
      _onStatusMessage?.call('Created branch ${branch.name}.');
      await refreshBranchState(showLoadingState: false);
      notifyListeners();
      return branch;
    } on BranchWorkflowUnavailable catch (error) {
      _setBranchWorkflowUnavailable(
        error.message ?? nativeBranchApiUnavailableReason,
      );
      return null;
    } catch (error) {
      _onError?.call(error.toString());
      return null;
    }
  }

  Future<WorkspaceBranchDiff?> previewBranchDiff({
    required String leftRef,
    required String rightRef,
  }) async {
    if (!canUseNativeBranchWorkflow) {
      _setBranchWorkflowUnavailable(
        branchState.nativeBranchApiUnavailableReason,
      );
      return null;
    }
    try {
      final diff = await _gateway.branchDiff(
        leftRef: leftRef.trim(),
        rightRef: rightRef.trim(),
      );
      lastBranchDiff = diff;
      _onStatusMessage?.call(
        'Diff loaded: ${diff.totalChanges} row changes across '
        '${diff.rows.map((row) => row.tableName).toSet().length} tables.',
      );
      notifyListeners();
      return diff;
    } on BranchWorkflowUnavailable catch (error) {
      _setBranchWorkflowUnavailable(
        error.message ?? nativeBranchApiUnavailableReason,
      );
      return null;
    } catch (error) {
      _onError?.call(error.toString());
      return null;
    }
  }

  Future<WorkspaceBranchDiff?> previewRestoreBranch({
    required String branchName,
    required String targetRef,
  }) async {
    return _restoreBranch(
      branchName: branchName,
      targetRef: targetRef,
      dryRun: true,
    );
  }

  Future<WorkspaceBranchDiff?> applyRestoreBranch({
    required String branchName,
    required String targetRef,
  }) async {
    return _restoreBranch(
      branchName: branchName,
      targetRef: targetRef,
      dryRun: false,
    );
  }

  Future<WorkspaceBranchDiff?> previewMergeBranch({
    required String sourceBranch,
    required String targetBranch,
  }) async {
    return _mergeBranch(
      sourceBranch: sourceBranch,
      targetBranch: targetBranch,
      dryRun: true,
    );
  }

  Future<WorkspaceBranchDiff?> applyMergeBranch({
    required String sourceBranch,
    required String targetBranch,
  }) async {
    return _mergeBranch(
      sourceBranch: sourceBranch,
      targetBranch: targetBranch,
      dryRun: false,
    );
  }

  Future<WorkspaceBranchDiff?> _restoreBranch({
    required String branchName,
    required String targetRef,
    required bool dryRun,
  }) async {
    if (!canUseNativeBranchWorkflow) {
      _setBranchWorkflowUnavailable(
        branchState.nativeBranchApiUnavailableReason,
      );
      return null;
    }
    try {
      if (!dryRun) {
        await _gateway.createSnapshot(name: _preRestoreSnapshotName());
      }
      final diff = await _gateway.restoreBranch(
        branchName: branchName.trim(),
        targetRef: targetRef.trim(),
        dryRun: dryRun,
      );
      lastBranchDiff = diff;
      _onStatusMessage?.call(
        dryRun
            ? 'Restore dry run loaded ${diff.totalChanges} row changes.'
            : 'Restored ${branchName.trim()} to ${targetRef.trim()}.',
      );
      if (!dryRun) {
        _onSchemaRefreshNeeded?.call();
        await refreshBranchState(showLoadingState: false);
      }
      notifyListeners();
      return diff;
    } on BranchWorkflowUnavailable catch (error) {
      _setBranchWorkflowUnavailable(
        error.message ?? nativeBranchApiUnavailableReason,
      );
      return null;
    } catch (error) {
      _onError?.call(error.toString());
      return null;
    }
  }

  Future<WorkspaceBranchDiff?> _mergeBranch({
    required String sourceBranch,
    required String targetBranch,
    required bool dryRun,
  }) async {
    if (!canUseNativeBranchWorkflow) {
      _setBranchWorkflowUnavailable(
        branchState.nativeBranchApiUnavailableReason,
      );
      return null;
    }
    try {
      final diff = await _gateway.mergeBranch(
        sourceBranch: sourceBranch.trim(),
        targetBranch: targetBranch.trim(),
        dryRun: dryRun,
      );
      lastBranchDiff = diff;
      _onStatusMessage?.call(
        dryRun
            ? 'Merge dry run loaded ${diff.totalChanges} row changes.'
            : 'Merged ${sourceBranch.trim()} into ${targetBranch.trim()}.',
      );
      if (!dryRun) {
        _onSchemaRefreshNeeded?.call();
        await refreshBranchState(showLoadingState: false);
      }
      notifyListeners();
      return diff;
    } on BranchWorkflowUnavailable catch (error) {
      _setBranchWorkflowUnavailable(
        error.message ?? nativeBranchApiUnavailableReason,
      );
      return null;
    } catch (error) {
      _onError?.call(error.toString());
      return null;
    }
  }

  String _currentBranchName(List<WorkspaceBranchInfo> branches) {
    for (final branch in branches) {
      if (branch.isCurrent) {
        return branch.name;
      }
    }
    return branches.isEmpty ? 'main' : branches.first.name;
  }

  String _preRestoreSnapshotName() {
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9A-Za-z]+'), '_')
        .replaceAll(RegExp(r'_+$'), '');
    return 'pre_restore_$stamp';
  }

  void _setBranchWorkflowUnavailable(
    String reason, {
    bool setMessage = true,
    bool notify = true,
  }) {
    branchState = WorkspaceBranchState.unavailable(
      reason.trim().isEmpty ? nativeBranchApiUnavailableReason : reason,
    );
    lastBranchDiff = null;
    if (setMessage) {
      _onStatusMessage?.call(
        'Native branch workflow unavailable: '
        '${branchState.nativeBranchApiUnavailableReason}',
      );
    }
    _logger.info(
      category: 'branch',
      operation: 'branch_workflow_unavailable',
      message: 'Native branch workflow unavailable.',
      databasePath: _databasePath,
      details: <String, Object?>{
        'reason': branchState.nativeBranchApiUnavailableReason,
      },
    );
    if (notify) {
      notifyListeners();
    }
  }
}
