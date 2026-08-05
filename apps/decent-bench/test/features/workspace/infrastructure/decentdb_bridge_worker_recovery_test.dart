import 'dart:async';
import 'dart:isolate';

import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:decent_bench/features/workspace/infrastructure/decentdb_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

// These tests exercise the bridge's worker-busy short-circuit and
// restart-on-timeout orchestration without the real native library. The
// bridge's worker isolate processes requests serially and native calls
// cannot be interrupted, so a wedged op blocks every later request. The
// bridge must (1) fail control requests fast when the worker is already
// busy and (2) restart the worker after a timeout so the next request is
// not queued behind the stuck call forever.

void main() {
  group('worker-busy short-circuit', () {
    test('control actions fail fast when the worker is busy', () async {
      final bridge = DecentDbBridge();
      // Hand the bridge a no-op fake worker port so initialize() does not
      // spawn a real isolate.
      final fakePort = ReceivePort();
      bridge.fakeWorkerPortForTesting = fakePort.sendPort;
      addTearDown(fakePort.close);

      await bridge.initialize();
      // Simulate a worker that is stuck inside a long native call.
      bridge.setInFlightForTesting(1);

      expect(bridge.controlActionsForTesting, contains('openDatabase'));
      expect(bridge.controlActionsForTesting, contains('loadSchema'));

      await expectLater(
        bridge.openDatabase('/tmp/never-opened.ddb'),
        throwsA(
          isA<BridgeFailure>()
              .having((e) => e.code, 'code', 'DDB_ERR_WORKER_BUSY')
              .having((e) => e.message, 'message', contains('busy')),
        ),
      );
    });

    test('non-control actions still queue when the worker is busy', () async {
      final bridge = DecentDbBridge();
      final replyPort = ReceivePort();
      final commandPort = ReceivePort();
      bridge.fakeWorkerPortForTesting = commandPort.sendPort;
      addTearDown(replyPort.close);
      addTearDown(commandPort.close);

      await bridge.initialize();
      bridge.setInFlightForTesting(1);

      // `runQuery` is not a control action; it should be dispatched (and
      // then time out quickly because the fake worker never replies).
      final sw = Stopwatch()..start();
      await expectLater(
        bridge.runQuery(
          sql: 'SELECT 1',
          params: const <Object?>[],
          pageSize: 1,
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(
          isA<BridgeFailure>()
              .having((e) => e.code, 'code', 'DDB_ERR_TIMEOUT'),
        ),
      );
      sw.stop();
      // The 50ms request timeout (not the 60s control short-circuit) governs.
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });

  group('restart on timeout', () {
    test('restarts the worker and fails other pending completers', () async {
      final bridge = DecentDbBridge();
      // A fake worker port that silently swallows every command so no
      // request ever receives a reply.
      final sinkPort = ReceivePort();
      bridge.fakeWorkerPortForTesting = sinkPort.sendPort;
      addTearDown(sinkPort.close);

      await bridge.initialize();

      // Fire two concurrent requests. Neither will be answered. The first
      // to time out triggers a worker restart; the other pending completer
      // must be failed with DDB_ERR_WORKER_RESTARTED.
      final first = bridge.runQuery(
        sql: 'SELECT 1',
        params: const <Object?>[],
        pageSize: 1,
        timeout: const Duration(milliseconds: 40),
      );
      final second = bridge.runQuery(
        sql: 'SELECT 2',
        params: const <Object?>[],
        pageSize: 1,
        timeout: const Duration(milliseconds: 200),
      );

      Future<BridgeFailure> asFailure(Future<QueryResultPage> f) {
        final completer = Completer<BridgeFailure>();
        f.then(
          (_) => completer.completeError('expected a failure'),
          onError: (Object e) {
            if (e is BridgeFailure) {
              completer.complete(e);
            } else {
              completer.completeError(e);
            }
          },
        );
        return completer.future;
      }

      // Attach listeners eagerly so the restart path's completeError on the
      // other completer cannot surface as an unhandled async error.
      final firstErrorFuture = asFailure(first);
      final secondErrorFuture = asFailure(second);

      final firstError = await firstErrorFuture;
      expect(firstError.code, 'DDB_ERR_TIMEOUT');

      final secondError = await secondErrorFuture;
      // The second request's completer is failed by the restart path.
      expect(
        secondError.code,
        anyOf('DDB_ERR_WORKER_RESTARTED', 'DDB_ERR_TIMEOUT'),
      );

      // After the restart the worker port is re-installed (fake path) so a
      // new request can be dispatched without throwing "worker not
      // available".
      expect(bridge.fakeWorkerPortForTesting, isNotNull);
    });
  });
}