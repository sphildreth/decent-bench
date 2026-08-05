import 'dart:convert';
import 'dart:io';

import 'decentdb_cli_resolver.dart';

typedef DecentDbCliCommandRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

const List<String> kDoctorCategories = <String>[
  'header',
  'storage',
  'wal',
  'fragmentation',
  'schema',
  'statistics',
  'indexes',
  'compatibility',
];

enum DecentDbDoctorSource { cli, sysViews, none }

class DecentDbDoctorFinding {
  const DecentDbDoctorFinding({
    required this.id,
    required this.severity,
    required this.category,
    required this.message,
    this.recommendation,
  });

  final String id;
  final String severity;
  final String category;
  final String message;
  final String? recommendation;

  factory DecentDbDoctorFinding.fromJson(Map<String, Object?> json) {
    final severity = (json['severity'] as String? ?? 'info').toLowerCase();
    final category = (json['category'] as String? ?? 'other').toLowerCase();
    return DecentDbDoctorFinding(
      id: (json['id'] as String? ?? '${category}_$severity').trim(),
      severity: severity,
      category: category,
      message: (json['message'] as String? ?? '').trim(),
      recommendation: (json['recommendation'] as String? ??
              json['recommendations'] as String?)
          ?.trim(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'severity': severity,
        'category': category,
        'message': message,
        if (recommendation != null) 'recommendation': recommendation,
      };
}

class DecentDbDoctorReport {
  const DecentDbDoctorReport({
    required this.databasePath,
    required this.cliPath,
    required this.arguments,
    required this.findings,
    required this.source,
    required this.stdoutText,
    required this.stderrText,
    required this.exitCode,
    required this.elapsed,
    required this.degraded,
  });

  final String databasePath;
  final String cliPath;
  final List<String> arguments;
  final List<DecentDbDoctorFinding> findings;
  final DecentDbDoctorSource source;
  final String stdoutText;
  final String stderrText;
  final int exitCode;
  final Duration elapsed;

  /// When `true`, the report is known to be incomplete (e.g. CLI was
  /// unavailable and the in-process sys.* fallback was used). UI must
  /// surface this so users don't mistake it for a clean bill of health.
  final bool degraded;

  bool get hasFindings => findings.isNotEmpty;

  Iterable<DecentDbDoctorFinding> byCategory(String category) sync* {
    for (final finding in findings) {
      if (finding.category == category) {
        yield finding;
      }
    }
  }

  Iterable<DecentDbDoctorFinding> bySeverity(String severity) sync* {
    for (final finding in findings) {
      if (finding.severity == severity) {
        yield finding;
      }
    }
  }
}

class DecentDbDoctorFailure implements Exception {
  const DecentDbDoctorFailure({
    required this.message,
    required this.cliPath,
    required this.arguments,
    required this.exitCode,
    required this.stdoutText,
    required this.stderrText,
  });

  final String message;
  final String cliPath;
  final List<String> arguments;
  final int exitCode;
  final String stdoutText;
  final String stderrText;

  String toDisplayMessage() {
    final parts = <String>[
      message,
      if (cliPath.isNotEmpty)
        'Command: $cliPath ${arguments.join(' ')}',
      'Exit code: $exitCode',
      if (stdoutText.trim().isNotEmpty) 'Output:\n${stdoutText.trim()}',
      if (stderrText.trim().isNotEmpty) 'Error output:\n${stderrText.trim()}',
    ];
    return parts.join('\n\n');
  }

  @override
  String toString() => toDisplayMessage();
}

/// Reads findings via `sys.doctor_findings` / `sys.fix_plan` for fallback
/// use when the CLI cannot be resolved. Pass any function that runs the
/// SQL and returns the row map list (e.g. via the workspace bridge).
typedef DecentDbSysViewRunner =
    Future<List<Map<String, Object?>>> Function(String sql);

class DecentDbDoctorService {
  DecentDbDoctorService({
    DecentDbCliPathResolver? cliPathResolver,
    DecentDbCliCommandRunner? commandRunner,
    DecentDbSysViewRunner? sysViewRunner,
  })  : _cliPathResolver = cliPathResolver,
        _commandRunner = commandRunner ?? _defaultCommandRunner,
        _sysViewRunner = sysViewRunner;

  final DecentDbCliPathResolver? _cliPathResolver;
  final DecentDbCliCommandRunner _commandRunner;
  final DecentDbSysViewRunner? _sysViewRunner;

  /// Builds the doctor CLI argument list. Exposed for testing.
  static List<String> buildDoctorArguments({
    required String databasePath,
    String? format,
    List<String> checks = const <String>[],
    bool includeRecommendations = true,
    bool verifyAllIndexes = false,
    List<String> verifyIndexes = const <String>[],
    int? maxIndexVerify,
  }) {
    final args = <String>[
      'doctor',
      '--db', databasePath,
      if (format != null) '--format=$format' else '--format=json',
      if (checks.isNotEmpty)
        '--checks=${checks.join(',')}'
      else
        '--checks=all',
      '--include-recommendations=$includeRecommendations',
      if (verifyAllIndexes) '--verify-indexes',
      for (final name in verifyIndexes)
        if (name.trim().isNotEmpty) '--verify-index=${name.trim()}',
      if (maxIndexVerify != null) '--max-index-verify=$maxIndexVerify',
    ];
    return args;
  }

  Future<DecentDbDoctorReport> runDoctor({
    required String databasePath,
    List<String> checks = const <String>[],
    bool verifyAllIndexes = false,
    List<String> verifyIndexes = const <String>[],
    int? maxIndexVerify,
  }) async {
    final normalizedPath = databasePath.trim();
    if (normalizedPath.isEmpty) {
      throw const DecentDbDoctorFailure(
        message: 'Choose an open database to diagnose.',
        cliPath: '',
        arguments: <String>[],
        exitCode: -1,
        stdoutText: '',
        stderrText: '',
      );
    }

    final String cliPath;
    try {
      cliPath = await (_cliPathResolver ?? DecentDbCliResolver().resolve)();
    } on DecentDbCliResolutionFailure catch (e) {
      if (_sysViewRunner != null) {
        return await _runSysViewFallback(
          databasePath: normalizedPath,
          cliPath: '',
          arguments: const <String>[],
          stdoutText: '',
          stderrText: e.toDisplayMessage(),
          exitCode: -1,
          elapsed: Duration.zero,
        );
      }
      rethrow;
    }
    final args = buildDoctorArguments(
      databasePath: normalizedPath,
      checks: checks,
      verifyAllIndexes: verifyAllIndexes,
      verifyIndexes: verifyIndexes,
      maxIndexVerify: maxIndexVerify,
    );

    final stopwatch = Stopwatch()..start();
    final result = await _commandRunner(cliPath, args);
    stopwatch.stop();

    final stdoutText = _processText(result.stdout);
    final stderrText = _processText(result.stderr);

    if (result.exitCode != 0 && stdoutText.trim().isEmpty) {
      // The CLI failed AND did not emit JSON we can parse. Try fallback.
      if (_sysViewRunner != null) {
        return await _runSysViewFallback(
          databasePath: normalizedPath,
          cliPath: cliPath,
          arguments: args,
          stdoutText: stdoutText,
          stderrText: stderrText,
          exitCode: result.exitCode,
          elapsed: stopwatch.elapsed,
        );
      }
      throw DecentDbDoctorFailure(
        message: 'DecentDB doctor failed without JSON output.',
        cliPath: cliPath,
        arguments: args,
        exitCode: result.exitCode,
        stdoutText: stdoutText,
        stderrText: stderrText,
      );
    }

    final findings = _parseFindingsFromJson(stdoutText);
    return DecentDbDoctorReport(
      databasePath: normalizedPath,
      cliPath: cliPath,
      arguments: List<String>.unmodifiable(args),
      findings: findings,
      source: DecentDbDoctorSource.cli,
      stdoutText: stdoutText,
      stderrText: stderrText,
      exitCode: result.exitCode,
      elapsed: stopwatch.elapsed,
      degraded: false,
    );
  }

  /// Runs the in-process `sys.doctor_findings` / `sys.fix_plan` fallback
  /// path. Used when the CLI cannot be invoked.
  Future<DecentDbDoctorReport> runSysViewFallback({
    required String databasePath,
    Duration? fallbackTimeout,
  }) async {
    final runner = _sysViewRunner;
    if (runner == null) {
      throw const DecentDbDoctorFailure(
        message: 'No in-process sys.* runner was provided.',
        cliPath: '',
        arguments: <String>[],
        exitCode: -1,
        stdoutText: '',
        stderrText: '',
      );
    }
    final stopwatch = Stopwatch()..start();
    final findings = <DecentDbDoctorFinding>[];
    try {
      final findingsRows = await runner('SELECT * FROM sys.doctor_findings');
      for (final row in findingsRows) {
        findings.add(DecentDbDoctorFinding.fromJson(row));
      }
    } catch (error) {
      stopwatch.stop();
      throw DecentDbDoctorFailure(
        message:
            'sys.doctor_findings query failed: $error',
        cliPath: '',
        arguments: const <String>[],
        exitCode: -1,
        stdoutText: '',
        stderrText: error.toString(),
      );
    }
    try {
      final fixRows = await runner('SELECT * FROM sys.fix_plan');
      for (final row in fixRows) {
        findings.add(DecentDbDoctorFinding.fromJson(row));
      }
    } catch (_) {
      // sys.fix_plan is optional; ignore query errors.
    }
    stopwatch.stop();
    return DecentDbDoctorReport(
      databasePath: databasePath.trim(),
      cliPath: '',
      arguments: const <String>[],
      findings: List<DecentDbDoctorFinding>.unmodifiable(findings),
      source: DecentDbDoctorSource.sysViews,
      stdoutText: '',
      stderrText: '',
      exitCode: 0,
      elapsed: stopwatch.elapsed,
      degraded: true,
    );
  }

  Future<DecentDbDoctorReport> _runSysViewFallback({
    required String databasePath,
    required String cliPath,
    required List<String> arguments,
    required String stdoutText,
    required String stderrText,
    required int exitCode,
    required Duration elapsed,
  }) async {
    if (_sysViewRunner == null) {
      throw DecentDbDoctorFailure(
        message: 'DecentDB doctor failed without JSON output.',
        cliPath: cliPath,
        arguments: arguments,
        exitCode: exitCode,
        stdoutText: stdoutText,
        stderrText: stderrText,
      );
    }
    final fallback = await runSysViewFallback(databasePath: databasePath);
    return DecentDbDoctorReport(
      databasePath: fallback.databasePath,
      cliPath: cliPath,
      arguments: List<String>.unmodifiable(arguments),
      findings: fallback.findings,
      source: DecentDbDoctorSource.sysViews,
      stdoutText: stdoutText,
      stderrText: stderrText,
      exitCode: exitCode,
      elapsed: elapsed,
      degraded: true,
    );
  }

  static List<DecentDbDoctorFinding> _parseFindingsFromJson(
    String stdoutText,
  ) {
    final trimmed = stdoutText.trim();
    if (trimmed.isEmpty) {
      return const <DecentDbDoctorFinding>[];
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return const <DecentDbDoctorFinding>[];
    }
    if (decoded is Map<String, Object?>) {
      final findings = decoded['findings'];
      if (findings is List) {
        return _decodeList(findings);
      }
    }
    if (decoded is List) {
      return _decodeList(decoded);
    }
    return const <DecentDbDoctorFinding>[];
  }

  static List<DecentDbDoctorFinding> _decodeList(List<dynamic> raw) {
    final findings = <DecentDbDoctorFinding>[];
    for (final item in raw) {
      if (item is Map<String, Object?>) {
        findings.add(DecentDbDoctorFinding.fromJson(item));
      } else if (item is Map) {
        findings.add(DecentDbDoctorFinding.fromJson(
            item.cast<String, Object?>()));
      }
    }
    return List<DecentDbDoctorFinding>.unmodifiable(findings);
  }

  static Future<ProcessResult> _defaultCommandRunner(
    String executable,
    List<String> arguments,
  ) {
    return Process.run(executable, arguments, runInShell: false);
  }

  static String _processText(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value;
    }
    if (value is List<int>) {
      return utf8.decode(value, allowMalformed: true);
    }
    return value.toString();
  }
}