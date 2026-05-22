import 'dart:io';

import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/headless_import_runner.dart';
import 'app/headless_quality_runner.dart';
import 'app/startup_launch_options.dart';

Future<void> main(List<String> args) async {
  final cliDecision = parseStartupCliDecision(args);
  switch (cliDecision.behavior) {
    case StartupCliBehavior.launchApp:
      WidgetsFlutterBinding.ensureInitialized();
      runApp(DecentBenchApp(startupLaunchOptions: cliDecision.launchOptions));
      return;
    case StartupCliBehavior.runHeadlessImport:
      exit(await runHeadlessImportCli(cliDecision.headlessImportOptions!));
    case StartupCliBehavior.runHeadlessQuality:
      exit(await runHeadlessQualityCli(cliDecision.headlessQualityOptions!));
    case StartupCliBehavior.printHelp:
    case StartupCliBehavior.printVersion:
      stdout.writeln(cliDecision.output ?? '');
      return;
    case StartupCliBehavior.printError:
      stderr.writeln(cliDecision.output ?? '');
      exitCode = cliDecision.exitCode;
      return;
  }
}
