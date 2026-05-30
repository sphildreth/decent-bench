import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:decent_bench/features/workspace/infrastructure/decentdb_web_console_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'launches decentdb serve with secure defaults and tracks endpoint metadata',
    () async {
      String? capturedExecutable;
      List<String>? capturedArguments;
      final process = _FakeCliProcess();
      final service = DecentDbWebConsoleService(
        cliPathResolver: () async => '/tmp/decentdb',
        processStarter: (executable, arguments) async {
          capturedExecutable = executable;
          capturedArguments = arguments;
          return process;
        },
        now: () => DateTime.utc(2026, 5, 21, 12),
      );

      final session = await service.launch(databasePath: '/tmp/current.ddb');

      expect(capturedExecutable, '/tmp/decentdb');
      expect(capturedArguments, <String>[
        'serve',
        '--db=/tmp/current.ddb',
        '--read-only',
        '--open',
      ]);

      process.stdoutController.add(
        utf8.encode('ready: http://127.0.0.1:43123/?token=abc123\n'),
      );
      process.stderrController.add(utf8.encode('info: waiting for requests\n'));

      await Future<void>.delayed(Duration.zero);

      expect(session.consolePort, 43123);
      expect(session.consoleUri?.host, '127.0.0.1');
      expect(
        session.stdoutLines,
        contains('ready: http://127.0.0.1:43123/?token=abc123'),
      );
      expect(session.stderrLines, contains('info: waiting for requests'));
      expect(session.isRunning, isTrue);

      process.completeExit(0);
      await session.done;
      await Future<void>.delayed(Duration.zero);

      expect(session.exitCode, 0);
      expect(session.isRunning, isFalse);
      expect(service.activeSession, isNull);
    },
  );

  test(
    'shutdown terminates the running session and clears active state',
    () async {
      late final _FakeCliProcess process;
      process = _FakeCliProcess(
        onKill: (signal) {
          if (signal == ProcessSignal.sigterm) {
            process.completeExit(0);
          }
        },
      );
      final service = DecentDbWebConsoleService(
        cliPathResolver: () async => '/tmp/decentdb',
        processStarter: (_, _) async => process,
      );

      final session = await service.launch(databasePath: '/tmp/current.ddb');
      final stopped = await service.shutdown();

      expect(stopped, same(session));
      expect(process.killSignals, contains(ProcessSignal.sigterm));
      expect(session.exitCode, 0);
      expect(service.activeSession, isNull);
    },
  );

  test('rejects launching a second session while one is running', () async {
    final process = _FakeCliProcess();
    final service = DecentDbWebConsoleService(
      cliPathResolver: () async => '/tmp/decentdb',
      processStarter: (_, _) async => process,
    );

    await service.launch(databasePath: '/tmp/current.ddb');

    await expectLater(
      service.launch(databasePath: '/tmp/other.ddb'),
      throwsA(isA<StateError>()),
    );

    process.completeExit(0);
    await service.shutdown();
  });

  test('buildServeArguments omits optional flags when disabled', () {
    final arguments = DecentDbWebConsoleService.buildServeArguments(
      databasePath: '/tmp/current.ddb',
      readOnly: false,
      openBrowser: false,
      host: '127.0.0.1',
      port: 8123,
    );

    expect(arguments, <String>[
      'serve',
      '--db=/tmp/current.ddb',
      '--host=127.0.0.1',
      '--port=8123',
    ]);
  });

  test('buildServeArguments rejects non-localhost host values', () {
    expect(
      () => DecentDbWebConsoleService.buildServeArguments(
        databasePath: '/tmp/current.ddb',
        host: '0.0.0.0',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}

class _FakeCliProcess implements DecentDbCliProcessHandle {
  _FakeCliProcess({this.onKill});

  final void Function(ProcessSignal signal)? onKill;

  final StreamController<List<int>> stdoutController =
      StreamController<List<int>>.broadcast();
  final StreamController<List<int>> stderrController =
      StreamController<List<int>>.broadcast();
  final Completer<int> _exitCodeCompleter = Completer<int>();

  final List<ProcessSignal> killSignals = <ProcessSignal>[];

  @override
  Stream<List<int>> get stdout => stdoutController.stream;

  @override
  Stream<List<int>> get stderr => stderrController.stream;

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  void completeExit(int code) {
    if (_exitCodeCompleter.isCompleted) {
      return;
    }
    _exitCodeCompleter.complete(code);
    stdoutController.close();
    stderrController.close();
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killSignals.add(signal);
    onKill?.call(signal);
    return true;
  }
}
