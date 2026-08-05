import 'dart:io';

import 'package:decent_bench/features/workspace/infrastructure/decentdb_doctor_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DecentDbDoctorService.buildDoctorArguments', () {
    test('uses --format=json and --checks=all by default', () {
      final args = DecentDbDoctorService.buildDoctorArguments(
        databasePath: '/tmp/foo.ddb',
      );
      expect(args, <String>[
        'doctor',
        '--db',
        '/tmp/foo.ddb',
        '--format=json',
        '--checks=all',
        '--include-recommendations=true',
      ]);
    });

    test('passes through selected categories and verification flags', () {
      final args = DecentDbDoctorService.buildDoctorArguments(
        databasePath: '/tmp/foo.ddb',
        checks: <String>['header', 'wal'],
        verifyAllIndexes: true,
        verifyIndexes: <String>['idx_a', 'idx_b'],
        maxIndexVerify: 64,
      );
      expect(args, contains('--checks=header,wal'));
      expect(args, contains('--verify-indexes'));
      expect(args, contains('--verify-index=idx_a'));
      expect(args, contains('--verify-index=idx_b'));
      expect(args, contains('--max-index-verify=64'));
    });
  });

  test('parses CLI JSON findings and surfaces non-zero exit codes', () async {
    final stdout = '''
{
  "findings": [
    {
      "id": "wal.recovery_pending",
      "severity": "warning",
      "category": "wal",
      "message": "WAL recovery was triggered on last open.",
      "recommendation": "Run a checkpoint."
    },
    {
      "id": "header.format_upgrade",
      "severity": "info",
      "category": "header",
      "message": "Format 14 is current."
    }
  ]
}
''';
    final service = DecentDbDoctorService(
      cliPathResolver: () async => '/usr/local/bin/decentdb',
      commandRunner: (_, _) async => ProcessResult(12, 2, stdout, ''),
    );

    final report = await service.runDoctor(databasePath: '/tmp/foo.ddb');
    expect(report.findings.length, 2);
    expect(report.findings.first.severity, 'warning');
    expect(report.findings.first.category, 'wal');
    expect(report.findings.last.message, contains('Format 14'));
    expect(report.exitCode, 2,
        reason: 'non-zero exit is expected for unhealthy DB; not a failure');
    expect(report.degraded, isFalse);
  });

  test('falls back to sys.* views when the CLI emits no JSON output',
      () async {
    final service = DecentDbDoctorService(
      cliPathResolver: () async => '/usr/local/bin/decentdb',
      commandRunner: (_, _) async => ProcessResult(12, 1, '', 'tool missing'),
      sysViewRunner: (sql) async {
        if (sql.contains('doctor_findings')) {
          return <Map<String, Object?>>[
            <String, Object?>{
              'id': 'sys.doctor_fallback',
              'severity': 'info',
              'category': 'header',
              'message': 'Falling back to sys views',
            },
          ];
        }
        return const <Map<String, Object?>>[];
      },
    );

    final report = await service.runDoctor(databasePath: '/tmp/foo.ddb');
    expect(report.source, DecentDbDoctorSource.sysViews);
    expect(report.degraded, isTrue,
        reason: 'degraded flag must be set so UI does not misread this');
    expect(report.findings.single.id, 'sys.doctor_fallback');
  });

  test('throws when CLI fails and no sys.* runner is provided', () async {
    final service = DecentDbDoctorService(
      cliPathResolver: () async => '/usr/local/bin/decentdb',
      commandRunner: (_, _) async => ProcessResult(12, 1, '', 'boom'),
    );
    await expectLater(
      service.runDoctor(databasePath: '/tmp/foo.ddb'),
      throwsA(isA<DecentDbDoctorFailure>()),
    );
  });

  test('runSysViewFallback merges doctor_findings and fix_plan rows',
      () async {
    final service = DecentDbDoctorService(
      sysViewRunner: (sql) async {
        if (sql.contains('doctor_findings')) {
          return <Map<String, Object?>>[
            <String, Object?>{
              'id': 'wal.recovery_pending',
              'severity': 'warning',
              'category': 'wal',
              'message': 'Pending WAL recovery.',
              'recommendation': 'Checkpoint.',
            },
          ];
        }
        if (sql.contains('fix_plan')) {
          return <Map<String, Object?>>[
            <String, Object?>{
              'id': 'fix.wal_checkpoint',
              'severity': 'info',
              'category': 'wal',
              'message': 'Run a manual checkpoint.',
              'recommendation': 'PRAGMA wal_checkpoint(TRUNCATE);',
            },
          ];
        }
        return const <Map<String, Object?>>[];
      },
    );
    final report = await service.runSysViewFallback(
      databasePath: '/tmp/foo.ddb',
    );
    expect(report.source, DecentDbDoctorSource.sysViews);
    expect(report.degraded, isTrue);
    expect(report.findings.map((f) => f.id),
        <String>['wal.recovery_pending', 'fix.wal_checkpoint']);
  });
}