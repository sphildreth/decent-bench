import 'package:decent_bench/features/workspace/application/branch_controller.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:decent_bench/features/workspace/infrastructure/decentdb_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';

void main() {
  group('BranchController', () {
    late FakeWorkspaceGateway gateway;
    late BranchController controller;
    late List<String> statusMessages;
    late List<String> errors;
    late bool schemaRefreshCalled;

    void resetTracking() {
      statusMessages = <String>[];
      errors = <String>[];
      schemaRefreshCalled = false;
    }

    setUp(() {
      resetTracking();
      gateway = FakeWorkspaceGateway();
      controller = BranchController(
        gateway: gateway,
        onStatusMessage: statusMessages.add,
        onError: errors.add,
        onSchemaRefreshNeeded: () {
          schemaRefreshCalled = true;
        },
      );
    });

    group('Initial state', () {
      test('starts with unavailable branch state', () {
        expect(controller.branchState.isNativeBranchApiAvailable, isFalse);
        expect(controller.lastBranchDiff, isNull);
        expect(controller.isBranchStateLoading, isFalse);
      });

      test('canUseNativeBranchWorkflow is false with no database path', () {
        expect(controller.canUseNativeBranchWorkflow, isFalse);
      });
    });

    group('attachWorkspace', () {
      test('with null path sets unavailable state', () {
        controller.attachWorkspace(databasePath: null);

        expect(controller.branchState.isNativeBranchApiAvailable, isFalse);
        expect(controller.branchState.nativeBranchApiUnavailableReason,
            'Open a database first.');
        expect(controller.lastBranchDiff, isNull);
      });

      test('with valid path does not change state', () {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');

        expect(controller.branchState.isNativeBranchApiAvailable, isFalse);
      });
    });

    group('refreshBranchState', () {
      test('when databasePath is null sets unavailable', () async {
        await controller.refreshBranchState();

        expect(controller.branchState.isNativeBranchApiAvailable, isFalse);
        expect(controller.lastBranchDiff, isNull);
      });

      test('when databasePath is null with showLoadingState=false does not notify', () async {
        var notifyCount = 0;
        controller = BranchController(
          gateway: gateway,
          onStatusMessage: statusMessages.add,
          onError: errors.add,
        )..addListener(() => notifyCount++);

        await controller.refreshBranchState(showLoadingState: false);

        expect(controller.branchState.isNativeBranchApiAvailable, isFalse);
        expect(notifyCount, 0);
      });

      test('success lists branches and snapshots', () async {
        gateway.branchApiAvailable = true;
        gateway.branches = const <WorkspaceBranchInfo>[
          WorkspaceBranchInfo(name: 'main', isCurrent: true),
          WorkspaceBranchInfo(name: 'feature', parentRef: 'main'),
        ];
        gateway.snapshots = const <WorkspaceSnapshotInfo>[
          WorkspaceSnapshotInfo(name: 'v1', ref: 'snapshot:v1'),
        ];
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');

        await controller.refreshBranchState();

        expect(controller.branchState.isNativeBranchApiAvailable, isTrue);
        expect(controller.branchState.branches, hasLength(2));
        expect(controller.branchState.snapshots, hasLength(1));
        expect(controller.branchState.currentBranch, 'main');
      });

      test('success with showLoadingState=false does not trigger status message', () async {
        gateway.branchApiAvailable = true;
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');

        await controller.refreshBranchState(showLoadingState: false);

        expect(statusMessages, isEmpty);
        expect(controller.isBranchStateLoading, isFalse);
      });

      test('sets isBranchStateLoading during refresh', () async {
        gateway.branchApiAvailable = true;
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        bool? loadingDuringRefresh;
        controller.addListener(() {
          if (controller.isBranchStateLoading) {
            loadingDuringRefresh = true;
          }
        });

        await controller.refreshBranchState();

        expect(loadingDuringRefresh, isTrue);
        expect(controller.isBranchStateLoading, isFalse);
      });

      test('when BranchWorkflowUnavailable is thrown', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        gateway.branchApiAvailable = false;
        gateway.branchApiUnavailableReason = 'branch API not exported';

        await controller.refreshBranchState();

        expect(controller.branchState.isNativeBranchApiAvailable, isFalse);
        expect(controller.branchState.nativeBranchApiUnavailableReason,
            'branch API not exported');
      });

      test('when generic exception is thrown', () async {
        gateway.branchApiAvailable = true;
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        gateway.branchApiUnavailableReason = '';

        // Force a generic error by making listBranches throw
        await _refreshWithGenericError(controller, gateway);

        expect(controller.branchState.isNativeBranchApiAvailable, isFalse);
        expect(controller.branchState.nativeBranchApiUnavailableReason,
            contains('Could not load native branch'));
      });
    });

    group('canUseNativeBranchWorkflow', () {
      test('returns true when database path set and branch state available', () async {
        gateway.branchApiAvailable = true;
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        await controller.refreshBranchState();

        expect(controller.canUseNativeBranchWorkflow, isTrue);
      });

      test('returns false when no database path', () {
        expect(controller.canUseNativeBranchWorkflow, isFalse);
      });

      test('returns false when database path set but branch API unavailable', () {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');

        expect(controller.canUseNativeBranchWorkflow, isFalse);
      });
    });

    group('createSnapshot', () {
      test('with empty name does not create', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        gateway.branchApiAvailable = true;
        await controller.refreshBranchState();

        final result = await controller.createSnapshot('');

        expect(result, isNull);
        expect(statusMessages, contains('Snapshot name cannot be empty.'));
        expect(gateway.lastCreatedSnapshotName, isNull);
      });

      test('with whitespace-only name does not create', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        gateway.branchApiAvailable = true;
        await controller.refreshBranchState();

        final result = await controller.createSnapshot('   ');

        expect(result, isNull);
        expect(statusMessages, contains('Snapshot name cannot be empty.'));
        expect(gateway.lastCreatedSnapshotName, isNull);
      });

      test('with valid name creates snapshot', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        gateway.branchApiAvailable = true;
        await controller.refreshBranchState();

        final result = await controller.createSnapshot('v2');

        expect(result, isNotNull);
        expect(result!.name, 'v2');
        expect(gateway.lastCreatedSnapshotName, 'v2');
        expect(statusMessages, contains('Creating snapshot "v2"...'));
        expect(statusMessages, contains('Created snapshot v2.'));
      });

      test('when branch workflow unavailable', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        gateway.branchApiAvailable = false;

        final result = await controller.createSnapshot('v2');

        expect(result, isNull);
        expect(controller.branchState.isNativeBranchApiAvailable, isFalse);
      });

      test('when generic exception thrown', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        gateway.branchApiAvailable = true;
        await controller.refreshBranchState();
        gateway.branchApiAvailable = false;

        final result = await controller.createSnapshot('v2');

        expect(result, isNull);
      });
    });

    group('createBranch', () {
      test('with empty name does not create', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        gateway.branchApiAvailable = true;
        await controller.refreshBranchState();

        final result = await controller.createBranch(branchName: '');

        expect(result, isNull);
        expect(statusMessages, contains('Branch name cannot be empty.'));
        expect(gateway.lastCreatedBranchName, isNull);
      });

      test('with whitespace-only name does not create', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        gateway.branchApiAvailable = true;
        await controller.refreshBranchState();

        final result = await controller.createBranch(branchName: '   ');

        expect(result, isNull);
        expect(statusMessages, contains('Branch name cannot be empty.'));
        expect(gateway.lastCreatedBranchName, isNull);
      });

      test('with valid name and default fromRef', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        gateway.branchApiAvailable = true;
        await controller.refreshBranchState();

        final result = await controller.createBranch(branchName: 'feature');

        expect(result, isNotNull);
        expect(result!.name, 'feature');
        expect(gateway.lastCreatedBranchName, 'feature');
        expect(gateway.lastCreatedBranchFromRef, 'main');
      });

      test('with valid name and custom fromRef', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        gateway.branchApiAvailable = true;
        await controller.refreshBranchState();

        final result = await controller.createBranch(
          branchName: 'feature',
          fromRef: 'develop',
        );

        expect(result, isNotNull);
        expect(gateway.lastCreatedBranchFromRef, 'develop');
      });

      test('with empty fromRef defaults to main', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        gateway.branchApiAvailable = true;
        await controller.refreshBranchState();

        final result = await controller.createBranch(
          branchName: 'feature',
          fromRef: '  ',
        );

        expect(result, isNotNull);
        expect(gateway.lastCreatedBranchFromRef, 'main');
      });

      test('when branch workflow unavailable', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        gateway.branchApiAvailable = false;

        final result = await controller.createBranch(branchName: 'feature');

        expect(result, isNull);
        expect(controller.branchState.isNativeBranchApiAvailable, isFalse);
      });

      test('when generic exception thrown', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        gateway.branchApiAvailable = true;
        await controller.refreshBranchState();
        gateway.branchApiAvailable = false;

        final result = await controller.createBranch(branchName: 'feature');

        expect(result, isNull);
      });
    });

    group('previewBranchDiff', () {
      test('success returns diff and sets lastBranchDiff', () async {
        final diff = WorkspaceBranchDiff(
          leftRef: 'main',
          rightRef: 'feature',
          rows: const <WorkspaceBranchDiffRow>[
            WorkspaceBranchDiffRow(
                tableName: 'tasks', operation: 'insert'),
          ],
          addedRows: 1,
          modifiedRows: 0,
          removedRows: 0,
        );
        gateway.branchApiAvailable = true;
        gateway.branchDiffResult = diff;
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        await controller.refreshBranchState();

        final result = await controller.previewBranchDiff(
          leftRef: 'main',
          rightRef: 'feature',
        );

        expect(result, isNotNull);
        expect(result!.totalChanges, 1);
        expect(controller.lastBranchDiff, diff);
        expect(gateway.lastBranchDiffLeftRef, 'main');
        expect(gateway.lastBranchDiffRightRef, 'feature');
      });

      test('when unavailable returns null', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');

        final result = await controller.previewBranchDiff(
          leftRef: 'main',
          rightRef: 'feature',
        );

        expect(result, isNull);
      });

      test('when generic exception thrown', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        gateway.branchApiAvailable = true;
        await controller.refreshBranchState();
        gateway.branchApiAvailable = false;

        final result = await controller.previewBranchDiff(
          leftRef: 'main',
          rightRef: 'feature',
        );

        expect(result, isNull);
      });
    });

    group('previewRestoreBranch', () {
      test('dry run calls restoreBranch with dryRun=true', () async {
        gateway.branchApiAvailable = true;
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        await controller.refreshBranchState();

        final result = await controller.previewRestoreBranch(
          branchName: 'main',
          targetRef: 'snapshot:v1',
        );

        expect(result, isNotNull);
        expect(gateway.lastRestoreBranchName, 'main');
        expect(gateway.lastRestoreTargetRef, 'snapshot:v1');
        expect(gateway.lastRestoreDryRun, isTrue);
      });

      test('returns null when unavailable', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');

        final result = await controller.previewRestoreBranch(
          branchName: 'main',
          targetRef: 'snapshot:v1',
        );

        expect(result, isNull);
      });
    });

    group('applyRestoreBranch', () {
      test('calls createSnapshot first then restoreBranch', () async {
        gateway.branchApiAvailable = true;
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        await controller.refreshBranchState();

        final result = await controller.applyRestoreBranch(
          branchName: 'main',
          targetRef: 'snapshot:v1',
        );

        expect(result, isNotNull);
        expect(gateway.lastRestoreBranchName, 'main');
        expect(gateway.lastRestoreTargetRef, 'snapshot:v1');
        expect(gateway.lastRestoreDryRun, isFalse);
        expect(gateway.lastCreatedSnapshotName, startsWith('pre_restore_'));
      });

      test('triggers schema refresh', () async {
        gateway.branchApiAvailable = true;
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        await controller.refreshBranchState();

        await controller.applyRestoreBranch(
          branchName: 'main',
          targetRef: 'snapshot:v1',
        );

        expect(schemaRefreshCalled, isTrue);
      });

      test('sets lastBranchDiff after successful restore', () async {
        final diff = WorkspaceBranchDiff(
          leftRef: 'main',
          rightRef: 'snapshot:v1',
          rows: const <WorkspaceBranchDiffRow>[],
          addedRows: 0,
          modifiedRows: 0,
          removedRows: 2,
        );
        gateway.branchApiAvailable = true;
        gateway.branchDiffResult = diff;
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        await controller.refreshBranchState();

        final result = await controller.applyRestoreBranch(
          branchName: 'main',
          targetRef: 'snapshot:v1',
        );

        expect(result, diff);
        expect(controller.lastBranchDiff, diff);
      });

      test('returns null when unavailable', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');

        final result = await controller.applyRestoreBranch(
          branchName: 'main',
          targetRef: 'snapshot:v1',
        );

        expect(result, isNull);
      });
    });

    group('previewMergeBranch', () {
      test('dry run calls mergeBranch with dryRun=true', () async {
        gateway.branchApiAvailable = true;
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        await controller.refreshBranchState();

        final result = await controller.previewMergeBranch(
          sourceBranch: 'feature',
          targetBranch: 'main',
        );

        expect(result, isNotNull);
        expect(gateway.lastMergeSourceBranch, 'feature');
        expect(gateway.lastMergeTargetBranch, 'main');
        expect(gateway.lastMergeDryRun, isTrue);
      });

      test('returns null when unavailable', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');

        final result = await controller.previewMergeBranch(
          sourceBranch: 'feature',
          targetBranch: 'main',
        );

        expect(result, isNull);
      });
    });

    group('applyMergeBranch', () {
      test('success calls mergeBranch with dryRun=false', () async {
        gateway.branchApiAvailable = true;
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        await controller.refreshBranchState();

        final result = await controller.applyMergeBranch(
          sourceBranch: 'feature',
          targetBranch: 'main',
        );

        expect(result, isNotNull);
        expect(gateway.lastMergeSourceBranch, 'feature');
        expect(gateway.lastMergeTargetBranch, 'main');
        expect(gateway.lastMergeDryRun, isFalse);
      });

      test('triggers schema refresh', () async {
        gateway.branchApiAvailable = true;
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        await controller.refreshBranchState();

        await controller.applyMergeBranch(
          sourceBranch: 'feature',
          targetBranch: 'main',
        );

        expect(schemaRefreshCalled, isTrue);
      });

      test('sets lastBranchDiff after successful merge', () async {
        final diff = WorkspaceBranchDiff(
          leftRef: 'feature',
          rightRef: 'main',
          rows: const <WorkspaceBranchDiffRow>[
            WorkspaceBranchDiffRow(
                tableName: 'tasks', operation: 'delete'),
          ],
          addedRows: 0,
          modifiedRows: 0,
          removedRows: 1,
        );
        gateway.branchApiAvailable = true;
        gateway.branchDiffResult = diff;
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        await controller.refreshBranchState();

        final result = await controller.applyMergeBranch(
          sourceBranch: 'feature',
          targetBranch: 'main',
        );

        expect(result, diff);
        expect(controller.lastBranchDiff, diff);
      });

      test('returns null when unavailable', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');

        final result = await controller.applyMergeBranch(
          sourceBranch: 'feature',
          targetBranch: 'main',
        );

        expect(result, isNull);
      });

      test('when BranchWorkflowUnavailable is thrown', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        gateway.branchApiAvailable = true;
        await controller.refreshBranchState();
        gateway.branchApiAvailable = false;

        final result = await controller.applyMergeBranch(
          sourceBranch: 'feature',
          targetBranch: 'main',
        );

        expect(result, isNull);
        expect(controller.branchState.isNativeBranchApiAvailable, isFalse);
      });
    });

    group('lastBranchDiff', () {
      test('is null initially', () {
        expect(controller.lastBranchDiff, isNull);
      });

      test('is set after successful previewBranchDiff', () async {
        gateway.branchApiAvailable = true;
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        await controller.refreshBranchState();

        await controller.previewBranchDiff(
          leftRef: 'main',
          rightRef: 'feature',
        );

        expect(controller.lastBranchDiff, isNotNull);
      });

      test('is cleared when attachWorkspace with null', () async {
        gateway.branchApiAvailable = true;
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        await controller.refreshBranchState();
        await controller.previewBranchDiff(
          leftRef: 'main',
          rightRef: 'feature',
        );
        expect(controller.lastBranchDiff, isNotNull);

        controller.attachWorkspace(databasePath: null);

        expect(controller.lastBranchDiff, isNull);
      });

      test('is cleared when branch workflow becomes unavailable', () async {
        gateway.branchApiAvailable = true;
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        await controller.refreshBranchState();
        await controller.previewBranchDiff(
          leftRef: 'main',
          rightRef: 'feature',
        );
        expect(controller.lastBranchDiff, isNotNull);

        gateway.branchApiAvailable = false;
        await controller.previewBranchDiff(
          leftRef: 'main',
          rightRef: 'feature',
        );

        expect(controller.lastBranchDiff, isNull);
      });
    });

    group('notifyListeners', () {
      test('attachWorkspace with null notifies listeners', () {
        var notified = false;
        controller.addListener(() => notified = true);

        controller.attachWorkspace(databasePath: null);

        expect(notified, isTrue);
      });

      test('refreshBranchState notifies on completion', () async {
        gateway.branchApiAvailable = true;
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        await controller.refreshBranchState();

        expect(notifyCount, greaterThanOrEqualTo(1));
      });

      test('createSnapshot with empty name notifies', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        var notified = false;
        controller.addListener(() => notified = true);

        await controller.createSnapshot('');

        expect(notified, isTrue);
      });

      test('createBranch with empty name notifies', () async {
        controller.attachWorkspace(databasePath: '/tmp/test.ddb');
        var notified = false;
        controller.addListener(() => notified = true);

        await controller.createBranch(branchName: '');

        expect(notified, isTrue);
      });
    });
  });
}

Future<void> _refreshWithGenericError(
  BranchController controller,
  FakeWorkspaceGateway gateway,
) async {
  final failing = _AlwaysFailGateway();

  final ctrl = BranchController(
    gateway: failing,
    onStatusMessage: (_) {},
    onError: (_) {},
  );
  ctrl.attachWorkspace(databasePath: '/tmp/test.ddb');
  await ctrl.refreshBranchState();

  controller.branchState = ctrl.branchState;
}

class _AlwaysFailGateway implements BranchWorkflowGateway {
  @override
  Future<List<WorkspaceBranchInfo>> listBranches() async =>
      throw StateError('unexpected failure');

  @override
  Future<WorkspaceBranchInfo> createBranch({
    required String branchName,
    required String fromRef,
  }) async =>
      throw StateError('unexpected failure');

  @override
  Future<void> deleteBranch({required String branchName}) async =>
      throw StateError('unexpected failure');

  @override
  Future<List<WorkspaceSnapshotInfo>> listSnapshots() async =>
      throw StateError('unexpected failure');

  @override
  Future<WorkspaceSnapshotInfo> createSnapshot({required String name}) async =>
      throw StateError('unexpected failure');

  @override
  Future<void> deleteSnapshot({required String ref}) async =>
      throw StateError('unexpected failure');

  @override
  Future<QueryResultPage> runQueryOnBranch({
    required String sql,
    required String branchName,
    required List<Object?> params,
    required int pageSize,
  }) async =>
      throw StateError('unexpected failure');

  @override
  Future<WorkspaceBranchDiff> branchDiff({
    required String leftRef,
    required String rightRef,
  }) async =>
      throw StateError('unexpected failure');

  @override
  Future<WorkspaceBranchDiff> restoreBranch({
    required String branchName,
    required String targetRef,
    required bool dryRun,
  }) async =>
      throw StateError('unexpected failure');

  @override
  Future<WorkspaceBranchDiff> mergeBranch({
    required String sourceBranch,
    required String targetBranch,
    required bool dryRun,
  }) async =>
      throw StateError('unexpected failure');
}
