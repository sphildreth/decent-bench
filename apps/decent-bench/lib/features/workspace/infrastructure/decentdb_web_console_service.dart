import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'decentdb_cli_resolver.dart';

typedef DecentDbCliProcessStarter =
    Future<DecentDbCliProcessHandle> Function(
      String executable,
      List<String> arguments,
    );

class DecentDbWebConsoleLogLine {
  const DecentDbWebConsoleLogLine({
    required this.timestamp,
    required this.isError,
    required this.line,
  });

  final DateTime timestamp;
  final bool isError;
  final String line;
}

class DecentDbWebConsoleSession {
  DecentDbWebConsoleSession._({
    required this.cliPath,
    required this.databasePath,
    required this.arguments,
    required this.startedAt,
    required this.environment,
    required Completer<int> doneCompleter,
  }) : _doneCompleter = doneCompleter;

  final String cliPath;
  final String databasePath;
  final List<String> arguments;
  final DateTime startedAt;
  final Map<String, String> environment;

  final List<String> stdoutLines = <String>[];
  final List<String> stderrLines = <String>[];

  Uri? consoleUri;
  int? consolePort;
  int? exitCode;
  DateTime? exitedAt;

  final Completer<int> _doneCompleter;
  final StreamController<DecentDbWebConsoleLogLine> _logsController =
      StreamController<DecentDbWebConsoleLogLine>.broadcast();

  Stream<DecentDbWebConsoleLogLine> get logs => _logsController.stream;
  Future<int> get done => _doneCompleter.future;
  bool get isRunning => exitCode == null;

  void _recordStdout(String line, DateTime timestamp) {
    stdoutLines.add(line);
    _logsController.add(
      DecentDbWebConsoleLogLine(
        timestamp: timestamp,
        isError: false,
        line: line,
      ),
    );
  }

  void _recordStderr(String line, DateTime timestamp) {
    stderrLines.add(line);
    _logsController.add(
      DecentDbWebConsoleLogLine(
        timestamp: timestamp,
        isError: true,
        line: line,
      ),
    );
  }

  void _markExited(int code, DateTime timestamp) {
    exitCode = code;
    exitedAt = timestamp;
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete(code);
    }
  }

  Future<void> _closeLogs() => _logsController.close();
}

class DecentDbWebConsoleService {
  DecentDbWebConsoleService({
    DecentDbCliPathResolver? cliPathResolver,
    DecentDbCliProcessStarter? processStarter,
    DateTime Function()? now,
  }) : _cliPathResolver = cliPathResolver,
       _processStarter = processStarter ?? _defaultProcessStarter,
       _now = now ?? DateTime.now;

  final DecentDbCliPathResolver? _cliPathResolver;
  final DecentDbCliProcessStarter _processStarter;
  final DateTime Function() _now;

  _RunningWebConsoleSession? _running;

  DecentDbWebConsoleSession? get activeSession => _running?.session;

  Future<DecentDbWebConsoleSession> launch({
    required String databasePath,
    bool readOnly = true,
    bool openBrowser = true,
    String? host,
    int? port,
    Map<String, String>? environment,
  }) async {
    final existing = _running;
    if (existing != null && existing.session.isRunning) {
      throw StateError('DecentDB Web Console is already running.');
    }

    final cliPath = await (_cliPathResolver ?? DecentDbCliResolver().resolve)();
    final arguments = buildServeArguments(
      databasePath: databasePath,
      readOnly: readOnly,
      openBrowser: openBrowser,
      host: host,
      port: port,
    );
    final process = await _processStarter(cliPath, arguments);

    final session = DecentDbWebConsoleSession._(
      cliPath: cliPath,
      databasePath: databasePath,
      arguments: List<String>.unmodifiable(arguments),
      startedAt: _now(),
      environment: Map<String, String>.unmodifiable(environment ?? const {}),
      doneCompleter: Completer<int>(),
    );

    final stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          session._recordStdout(line, _now());
          _captureEndpointMetadata(session, line);
        });
    final stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          session._recordStderr(line, _now());
          _captureEndpointMetadata(session, line);
        });

    _running = _RunningWebConsoleSession(
      session: session,
      process: process,
      stdoutSubscription: stdoutSubscription,
      stderrSubscription: stderrSubscription,
    );

    unawaited(
      process.exitCode.then((code) async {
        session._markExited(code, _now());
        await stdoutSubscription.cancel();
        await stderrSubscription.cancel();
        await session._closeLogs();
        if (identical(_running?.session, session)) {
          _running = null;
        }
      }),
    );

    return session;
  }

  Future<DecentDbWebConsoleSession?> shutdown({
    Duration gracefulTimeout = const Duration(seconds: 2),
  }) async {
    final running = _running;
    if (running == null) {
      return null;
    }

    if (running.session.isRunning) {
      running.process.kill();
      final exitedGracefully = await running.session.done
          .then((_) => true)
          .catchError((_) => false)
          .timeout(gracefulTimeout, onTimeout: () => false);

      if (!exitedGracefully && running.session.isRunning) {
        running.process.kill(ProcessSignal.sigkill);
      }
    }

    await running.session.done;
    if (identical(_running?.session, running.session)) {
      _running = null;
    }
    return running.session;
  }

  static List<String> buildServeArguments({
    required String databasePath,
    bool readOnly = true,
    bool openBrowser = true,
    String? host,
    int? port,
  }) {
    final args = <String>['serve', '--db=$databasePath'];
    if (readOnly) {
      args.add('--read-only');
    }
    if (openBrowser) {
      args.add('--open');
    }
    if (host != null && host.trim().isNotEmpty) {
      final normalizedHost = host.trim();
      if (!_isLocalhostHost(normalizedHost)) {
        throw ArgumentError.value(
          host,
          'host',
          'DecentDB Web Console only supports localhost binding.',
        );
      }
      args.add('--host=$normalizedHost');
    }
    if (port != null) {
      args.add('--port=$port');
    }
    return args;
  }

  static bool _isLocalhostHost(String host) {
    final normalized = host.trim().toLowerCase();
    return normalized == '127.0.0.1' ||
        normalized == 'localhost' ||
        normalized == '::1';
  }

  void _captureEndpointMetadata(
    DecentDbWebConsoleSession session,
    String line,
  ) {
    if (session.consoleUri == null) {
      final uriMatch = RegExp(r'https?://[^\s]+').firstMatch(line);
      if (uriMatch != null) {
        final parsed = Uri.tryParse(uriMatch.group(0)!);
        if (parsed != null) {
          session.consoleUri = parsed;
          if (parsed.hasPort) {
            session.consolePort = parsed.port;
          }
          return;
        }
      }
    }

    if (session.consolePort == null) {
      final portMatch = RegExp(
        r'(?:127\.0\.0\.1|localhost):(?<port>\d{2,5})',
      ).firstMatch(line);
      final rawPort = portMatch?.namedGroup('port');
      final parsedPort = rawPort == null ? null : int.tryParse(rawPort);
      if (parsedPort != null) {
        session.consolePort = parsedPort;
      }
    }
  }

  static Future<DecentDbCliProcessHandle> _defaultProcessStarter(
    String executable,
    List<String> arguments,
  ) async {
    final process = await Process.start(
      executable,
      arguments,
      runInShell: false,
    );
    return _IoDecentDbCliProcessHandle(process);
  }
}

class _RunningWebConsoleSession {
  const _RunningWebConsoleSession({
    required this.session,
    required this.process,
    required this.stdoutSubscription,
    required this.stderrSubscription,
  });

  final DecentDbWebConsoleSession session;
  final DecentDbCliProcessHandle process;
  final StreamSubscription<String> stdoutSubscription;
  final StreamSubscription<String> stderrSubscription;
}

abstract class DecentDbCliProcessHandle {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  Future<int> get exitCode;
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]);
}

class _IoDecentDbCliProcessHandle implements DecentDbCliProcessHandle {
  const _IoDecentDbCliProcessHandle(this._process);

  final Process _process;

  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    return _process.kill(signal);
  }
}
