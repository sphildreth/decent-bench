import 'dart:convert';
import 'dart:io';

import 'package:decent_bench/app/headless_quality_runner.dart';
import 'package:decent_bench/app/startup_launch_options.dart';
import 'package:decent_bench/features/workspace/domain/data_quality_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/fakes.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('headless_quality_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('runs quality profile and writes JSON report', () async {
    final databasePath = p.join(tempDir.path, 'workspace.ddb');
    final profilePath = p.join(tempDir.path, 'profile.toml');
    final outputPath = p.join(tempDir.path, 'quality.json');
    await File(databasePath).writeAsString('');
    await File(profilePath).writeAsString(
      QualityProfileDocument.empty(
        name: 'CLI profile',
        now: DateTime.utc(2026, 5, 22),
      ).copyWith(profileId: 'profile-1').toToml(),
    );
    final stdoutLines = <String>[];
    final stderrLines = <String>[];

    final exitCode = await runHeadlessQualityCli(
      HeadlessQualityCliOptions(
        databasePath: databasePath,
        profilePath: profilePath,
        outputPath: outputPath,
        format: 'json',
        silent: true,
      ),
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
      workspaceGateway: FakeWorkspaceGateway(),
    );

    expect(exitCode, 0);
    expect(stderrLines, isEmpty);
    expect(File(outputPath).existsSync(), isTrue);
    final cliReport = jsonDecode(stdoutLines.single) as Map<String, Object?>;
    expect(cliReport['status'], 'completed');
    final qualityReport =
        jsonDecode(await File(outputPath).readAsString()) as Map;
    expect(qualityReport['report_schema_version'], 1);
  });

  test('returns usage error for invalid profile', () async {
    final databasePath = p.join(tempDir.path, 'workspace.ddb');
    final profilePath = p.join(tempDir.path, 'profile.toml');
    final outputPath = p.join(tempDir.path, 'quality.json');
    await File(databasePath).writeAsString('');
    await File(profilePath).writeAsString('name = ""');
    final stderrLines = <String>[];

    final exitCode = await runHeadlessQualityCli(
      HeadlessQualityCliOptions(
        databasePath: databasePath,
        profilePath: profilePath,
        outputPath: outputPath,
        format: 'json',
        silent: true,
      ),
      stdoutWriter: (_) {},
      stderrWriter: stderrLines.add,
      workspaceGateway: FakeWorkspaceGateway(),
    );

    expect(exitCode, 2);
    expect(stderrLines.single, contains('Invalid quality profile'));
  });
}
