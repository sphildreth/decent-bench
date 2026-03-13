import 'dart:io';

import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/startup_launch_options.dart';

void main(List<String> args) {
  final cliDecision = parseStartupCliDecision(args);
  switch (cliDecision.behavior) {
    case StartupCliBehavior.launchApp:
      WidgetsFlutterBinding.ensureInitialized();
      runApp(DecentBenchApp(startupLaunchOptions: cliDecision.launchOptions));
      return;
    case StartupCliBehavior.runHeadlessImport:
      stderr.writeln(buildHeadlessImportUnavailableText());
      exitCode = 2;
      return;
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
