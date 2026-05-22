import 'dart:io';

import 'package:decent_bench/app/headless_quality_runner.dart';
import 'package:decent_bench/app/startup_launch_options.dart';

Future<void> main(List<String> args) async {
  final cliDecision = parseStartupCliDecision(<String>['quality', ...args]);

  switch (cliDecision.behavior) {
    case StartupCliBehavior.runHeadlessQuality:
      exit(await runHeadlessQualityCli(cliDecision.headlessQualityOptions!));
    case StartupCliBehavior.printHelp:
    case StartupCliBehavior.printVersion:
      stdout.writeln(cliDecision.output ?? '');
      return;
    case StartupCliBehavior.printError:
      stderr.writeln(cliDecision.output ?? '');
      exit(cliDecision.exitCode);
    case StartupCliBehavior.runHeadlessImport:
    case StartupCliBehavior.launchApp:
      stderr.writeln(
        'The quality helper only supports `dbench quality` flags, `--help`, and `--version`.',
      );
      exit(2);
  }
}
