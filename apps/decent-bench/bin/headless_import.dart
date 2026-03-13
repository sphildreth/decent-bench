import 'dart:io';

import 'package:decent_bench/app/headless_import_runner.dart';
import 'package:decent_bench/app/startup_launch_options.dart';

Future<void> main(List<String> args) async {
  final cliDecision = parseStartupCliDecision(args);

  switch (cliDecision.behavior) {
    case StartupCliBehavior.runHeadlessImport:
      exit(await runHeadlessImportCli(cliDecision.headlessImportOptions!));
    case StartupCliBehavior.printHelp:
    case StartupCliBehavior.printVersion:
      stdout.writeln(cliDecision.output ?? '');
      return;
    case StartupCliBehavior.printError:
      stderr.writeln(cliDecision.output ?? '');
      exit(cliDecision.exitCode);
    case StartupCliBehavior.launchApp:
      stderr.writeln(
        'The headless import helper only supports `--in`/`--out`, `--help`, and `--version`.',
      );
      exit(2);
  }
}
