import 'app_metadata.dart';

typedef StartupNoticeHandler =
    Future<void> Function(String title, String message);
typedef StartupOpenDatabaseHandler = Future<void> Function(String path);
typedef StartupStartImportHandler = Future<void> Function(String path);

class HeadlessImportCliOptions {
  const HeadlessImportCliOptions({
    required this.sourcePath,
    required this.targetPath,
    this.planPath,
    this.silent = false,
  });

  final String sourcePath;
  final String targetPath;
  final String? planPath;
  final bool silent;
}

class StartupLaunchOptions {
  const StartupLaunchOptions({
    this.openDatabasePath,
    this.importSourcePath,
    this.startupNotice,
  });

  final String? openDatabasePath;
  final String? importSourcePath;
  final String? startupNotice;

  bool get hasPendingAction =>
      (openDatabasePath != null && openDatabasePath!.trim().isNotEmpty) ||
      (importSourcePath != null && importSourcePath!.trim().isNotEmpty) ||
      (startupNotice != null && startupNotice!.trim().isNotEmpty);
}

enum StartupCliBehavior {
  launchApp,
  runHeadlessImport,
  printHelp,
  printVersion,
  printError,
}

class StartupCliDecision {
  const StartupCliDecision._({
    required this.behavior,
    this.launchOptions = const StartupLaunchOptions(),
    this.headlessImportOptions,
    this.output,
    this.exitCode = 0,
  });

  const StartupCliDecision.launch(StartupLaunchOptions launchOptions)
    : this._(
        behavior: StartupCliBehavior.launchApp,
        launchOptions: launchOptions,
      );

  const StartupCliDecision.runHeadlessImport(
    HeadlessImportCliOptions headlessImportOptions,
  ) : this._(
        behavior: StartupCliBehavior.runHeadlessImport,
        headlessImportOptions: headlessImportOptions,
      );

  const StartupCliDecision.printHelp(String output)
    : this._(behavior: StartupCliBehavior.printHelp, output: output);

  const StartupCliDecision.printVersion(String output)
    : this._(behavior: StartupCliBehavior.printVersion, output: output);

  const StartupCliDecision.printError(String output, {int exitCode = 2})
    : this._(
        behavior: StartupCliBehavior.printError,
        output: output,
        exitCode: exitCode,
      );

  final StartupCliBehavior behavior;
  final StartupLaunchOptions launchOptions;
  final HeadlessImportCliOptions? headlessImportOptions;
  final String? output;
  final int exitCode;

  bool get shouldExit => behavior != StartupCliBehavior.launchApp;
}

StartupCliDecision parseStartupCliDecision(List<String> rawArgs) {
  for (final rawArg in rawArgs) {
    final argument = rawArg.trim();
    if (argument.isEmpty) {
      continue;
    }
    if (argument == '--help' || argument == '-h') {
      return StartupCliDecision.printHelp(buildStartupHelpText());
    }
    if (argument == '--version' || argument == '-v') {
      return StartupCliDecision.printVersion(
        '$kDecentBenchDisplayName $kDecentBenchVersion',
      );
    }
  }

  final parsedArgs = _parseStartupCliArguments(rawArgs);
  final errorMessage = parsedArgs.errorMessage?.trim();
  if (errorMessage != null && errorMessage.isNotEmpty) {
    return StartupCliDecision.printError(
      buildStartupCliErrorText(errorMessage),
    );
  }
  if (parsedArgs.headlessImportOptions != null) {
    return StartupCliDecision.runHeadlessImport(
      parsedArgs.headlessImportOptions!,
    );
  }
  return StartupCliDecision.launch(parsedArgs.launchOptions);
}

StartupLaunchOptions parseStartupLaunchOptions(List<String> rawArgs) {
  return _parseStartupCliArguments(rawArgs).launchOptions;
}

Future<void> applyStartupLaunchOptions(
  StartupLaunchOptions launchOptions, {
  required StartupNoticeHandler showNotice,
  required StartupOpenDatabaseHandler openDatabase,
  required StartupStartImportHandler startImport,
}) async {
  final startupNotice = launchOptions.startupNotice?.trim();
  if (startupNotice != null && startupNotice.isNotEmpty) {
    await showNotice('Command-line import', startupNotice);
    return;
  }

  final openDatabasePath = launchOptions.openDatabasePath?.trim();
  if (openDatabasePath != null && openDatabasePath.isNotEmpty) {
    await openDatabase(openDatabasePath);
    return;
  }

  final importSourcePath = launchOptions.importSourcePath?.trim();
  if (importSourcePath == null || importSourcePath.isEmpty) {
    return;
  }

  await startImport(importSourcePath);
}

String buildStartupHelpText() {
  return '$kDecentBenchDisplayName $kDecentBenchVersion\n'
      '\n'
      'Usage:\n'
      '  dbench\n'
      '  dbench /path/to/workspace.ddb\n'
      '  dbench --import <path>\n'
      '  dbench --in <source-path> --out <target.ddb> [--plan <plan.json>] [--silent]\n'
      '\n'
      'Options:\n'
      '  -h, --help\n'
      '      Show this help text and exit.\n'
      '  -v, --version\n'
      '      Show the application version and exit.\n'
      '  --import <path>\n'
      '      Launch the interactive import wizard for <path>.\n'
      '  --import=<path>\n'
      '      Same as above, using the inline form.\n'
      '  --in <path>\n'
      '      Run a headless import from <path>. Requires --out.\n'
      '  --in=<path>\n'
      '      Same as above, using the inline form.\n'
      '  --out <path.ddb>\n'
      '      Write the headless import result to <path.ddb>. Requires --in.\n'
      '  --out=<path.ddb>\n'
      '      Same as above, using the inline form.\n'
      '  --plan <path.json>\n'
      '      Apply a headless import plan. Only valid with --in and --out.\n'
      '  --plan=<path.json>\n'
      '      Same as above, using the inline form.\n'
      '  --silent\n'
      '      Suppress headless progress output. Only valid with --in and --out.\n'
      '\n'
      'Examples:\n'
      '  dbench\n'
      '  dbench /path/to/workspace.ddb\n'
      '  dbench --import /path/to/source.sqlite\n'
      '  dbench --import=/path/to/report.xlsx\n'
      '  dbench --in /path/to/source.xlsx --out /tmp/import.ddb\n'
      '  dbench --in /path/to/source.sqlite --out /tmp/import.ddb --plan /tmp/import-plan.json\n'
      '\n'
      'Notes:\n'
      '  Passing a .ddb path opens that database in the desktop UI.\n'
      '  `--import` always opens the interactive import wizard.\n'
      '  `--in`/`--out` are reserved for headless import.\n'
      '  Headless import execution is not implemented yet in this build.';
}

String buildHeadlessImportUnavailableText() {
  return 'Headless import mode is not implemented yet in this build.\n'
      '\n'
      'Planned syntax:\n'
      '  dbench --in <source-path> --out <target.ddb> [--plan <plan.json>] [--silent]\n'
      '\n'
      'Use `dbench --help` for details.';
}

String buildStartupCliErrorText(String message) {
  return '$message\n'
      '\n'
      'Use `dbench --help` for usage.';
}

bool _looksLikeDecentDbPath(String value) {
  return value.trim().toLowerCase().endsWith('.ddb');
}

class _ParsedStartupCliArguments {
  const _ParsedStartupCliArguments({
    required this.launchOptions,
    this.headlessImportOptions,
    this.errorMessage,
  });

  final StartupLaunchOptions launchOptions;
  final HeadlessImportCliOptions? headlessImportOptions;
  final String? errorMessage;
}

_ParsedStartupCliArguments _parseStartupCliArguments(List<String> rawArgs) {
  String? openDatabasePath;
  String? importSourcePath;
  String? startupNotice;
  String? headlessInputPath;
  String? headlessOutputPath;
  String? headlessPlanPath;
  bool headlessSilent = false;
  bool sawImportFlag = false;
  String? errorMessage;

  for (var index = 0; index < rawArgs.length; index++) {
    final argument = rawArgs[index].trim();
    if (argument.isEmpty) {
      continue;
    }

    if (argument == '--import') {
      sawImportFlag = true;
      if (importSourcePath != null) {
        errorMessage ??= '`--import` can only be specified once.';
        continue;
      }
      final nextIndex = index + 1;
      if (nextIndex >= rawArgs.length) {
        startupNotice ??= '`--import` expects a filename.';
        continue;
      }

      final value = rawArgs[nextIndex].trim();
      if (value.isEmpty || value.startsWith('--')) {
        startupNotice ??= '`--import` expects a filename.';
        continue;
      }

      importSourcePath = value;
      index = nextIndex;
      continue;
    }

    if (argument.startsWith('--import=')) {
      sawImportFlag = true;
      if (importSourcePath != null) {
        errorMessage ??= '`--import` can only be specified once.';
        continue;
      }
      final value = argument.substring('--import='.length).trim();
      if (value.isEmpty) {
        startupNotice ??= '`--import` expects a filename.';
        continue;
      }
      importSourcePath = value;
      continue;
    }

    if (argument == '--in') {
      if (headlessInputPath != null) {
        errorMessage ??= '`--in` can only be specified once.';
        continue;
      }
      final nextIndex = index + 1;
      if (nextIndex >= rawArgs.length) {
        errorMessage ??= '`--in` expects a filename.';
        continue;
      }
      final value = rawArgs[nextIndex].trim();
      if (value.isEmpty || value.startsWith('--')) {
        errorMessage ??= '`--in` expects a filename.';
        continue;
      }
      headlessInputPath = value;
      index = nextIndex;
      continue;
    }

    if (argument.startsWith('--in=')) {
      if (headlessInputPath != null) {
        errorMessage ??= '`--in` can only be specified once.';
        continue;
      }
      final value = argument.substring('--in='.length).trim();
      if (value.isEmpty) {
        errorMessage ??= '`--in` expects a filename.';
        continue;
      }
      headlessInputPath = value;
      continue;
    }

    if (argument == '--out') {
      if (headlessOutputPath != null) {
        errorMessage ??= '`--out` can only be specified once.';
        continue;
      }
      final nextIndex = index + 1;
      if (nextIndex >= rawArgs.length) {
        errorMessage ??= '`--out` expects a filename.';
        continue;
      }
      final value = rawArgs[nextIndex].trim();
      if (value.isEmpty || value.startsWith('--')) {
        errorMessage ??= '`--out` expects a filename.';
        continue;
      }
      headlessOutputPath = value;
      index = nextIndex;
      continue;
    }

    if (argument.startsWith('--out=')) {
      if (headlessOutputPath != null) {
        errorMessage ??= '`--out` can only be specified once.';
        continue;
      }
      final value = argument.substring('--out='.length).trim();
      if (value.isEmpty) {
        errorMessage ??= '`--out` expects a filename.';
        continue;
      }
      headlessOutputPath = value;
      continue;
    }

    if (argument == '--plan') {
      if (headlessPlanPath != null) {
        errorMessage ??= '`--plan` can only be specified once.';
        continue;
      }
      final nextIndex = index + 1;
      if (nextIndex >= rawArgs.length) {
        errorMessage ??= '`--plan` expects a filename.';
        continue;
      }
      final value = rawArgs[nextIndex].trim();
      if (value.isEmpty || value.startsWith('--')) {
        errorMessage ??= '`--plan` expects a filename.';
        continue;
      }
      headlessPlanPath = value;
      index = nextIndex;
      continue;
    }

    if (argument.startsWith('--plan=')) {
      if (headlessPlanPath != null) {
        errorMessage ??= '`--plan` can only be specified once.';
        continue;
      }
      final value = argument.substring('--plan='.length).trim();
      if (value.isEmpty) {
        errorMessage ??= '`--plan` expects a filename.';
        continue;
      }
      headlessPlanPath = value;
      continue;
    }

    if (argument == '--silent') {
      if (headlessSilent) {
        errorMessage ??= '`--silent` can only be specified once.';
        continue;
      }
      headlessSilent = true;
      continue;
    }

    if (argument.startsWith('-')) {
      errorMessage ??= 'Unknown option: $argument.';
      continue;
    }

    if (_looksLikeDecentDbPath(argument)) {
      if (openDatabasePath != null) {
        errorMessage ??= 'Only one positional .ddb path may be provided.';
        continue;
      }
      openDatabasePath = argument;
      continue;
    }

    errorMessage ??=
        'Unexpected positional argument: $argument. '
        'Use `--import <path>` for the interactive wizard or '
        '`--in <path>` for headless import.';
  }

  final hasHeadlessArgs =
      headlessInputPath != null ||
      headlessOutputPath != null ||
      headlessPlanPath != null ||
      headlessSilent;
  if (errorMessage == null && sawImportFlag && hasHeadlessArgs) {
    errorMessage = '`--import` cannot be combined with headless import flags.';
  }
  if (errorMessage == null &&
      openDatabasePath != null &&
      (sawImportFlag || hasHeadlessArgs)) {
    errorMessage =
        'A positional .ddb path cannot be combined with `--import` or headless import flags.';
  }
  if (errorMessage == null &&
      headlessInputPath == null &&
      headlessOutputPath != null) {
    errorMessage = '`--out` requires `--in`.';
  }
  if (errorMessage == null &&
      headlessInputPath != null &&
      headlessOutputPath == null) {
    errorMessage = '`--in` requires `--out`.';
  }
  if (errorMessage == null &&
      headlessPlanPath != null &&
      (headlessInputPath == null || headlessOutputPath == null)) {
    errorMessage = '`--plan` is only valid with `--in` and `--out`.';
  }
  if (errorMessage == null &&
      headlessSilent &&
      (headlessInputPath == null || headlessOutputPath == null)) {
    errorMessage = '`--silent` is only valid with `--in` and `--out`.';
  }

  final launchOptions = StartupLaunchOptions(
    openDatabasePath: openDatabasePath,
    importSourcePath: importSourcePath,
    startupNotice: startupNotice,
  );
  if (errorMessage != null) {
    return _ParsedStartupCliArguments(
      launchOptions: launchOptions,
      errorMessage: errorMessage,
    );
  }

  if (headlessInputPath != null && headlessOutputPath != null) {
    return _ParsedStartupCliArguments(
      launchOptions: launchOptions,
      headlessImportOptions: HeadlessImportCliOptions(
        sourcePath: headlessInputPath,
        targetPath: headlessOutputPath,
        planPath: headlessPlanPath,
        silent: headlessSilent,
      ),
    );
  }

  return _ParsedStartupCliArguments(launchOptions: launchOptions);
}
