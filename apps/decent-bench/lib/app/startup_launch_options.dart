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

class HeadlessQualityCliOptions {
  const HeadlessQualityCliOptions({
    required this.databasePath,
    required this.profilePath,
    required this.outputPath,
    required this.format,
    this.targetTable,
    this.mode,
    this.sampleRowLimit,
    this.includeSampleValues = false,
    this.includeViolationDetails = false,
    this.silent = false,
  });

  final String databasePath;
  final String profilePath;
  final String outputPath;
  final String format;
  final String? targetTable;
  final String? mode;
  final int? sampleRowLimit;
  final bool includeSampleValues;
  final bool includeViolationDetails;
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
  runHeadlessQuality,
  printHelp,
  printVersion,
  printError,
}

class StartupCliDecision {
  const StartupCliDecision._({
    required this.behavior,
    this.launchOptions = const StartupLaunchOptions(),
    this.headlessImportOptions,
    this.headlessQualityOptions,
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

  const StartupCliDecision.runHeadlessQuality(
    HeadlessQualityCliOptions headlessQualityOptions,
  ) : this._(
        behavior: StartupCliBehavior.runHeadlessQuality,
        headlessQualityOptions: headlessQualityOptions,
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
  final HeadlessQualityCliOptions? headlessQualityOptions;
  final String? output;
  final int exitCode;

  bool get shouldExit => behavior != StartupCliBehavior.launchApp;
}

StartupCliDecision parseStartupCliDecision(List<String> rawArgs) {
  final firstCommand = rawArgs
      .map((argument) => argument.trim())
      .where((argument) => argument.isNotEmpty)
      .cast<String?>()
      .firstWhere((argument) => argument != null, orElse: () => null);
  if (firstCommand == 'quality') {
    final parsedQuality = _parseHeadlessQualityCliArguments(
      rawArgs.skipWhile((argument) => argument.trim().isEmpty).skip(1).toList(),
    );
    final errorMessage = parsedQuality.errorMessage?.trim();
    if (errorMessage != null && errorMessage.isNotEmpty) {
      return StartupCliDecision.printError(
        '$errorMessage\n\nUse `dbench quality --help` for usage.',
      );
    }
    if (parsedQuality.output != null) {
      return StartupCliDecision.printHelp(parsedQuality.output!);
    }
    return StartupCliDecision.runHeadlessQuality(parsedQuality.options!);
  }

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
      '  dbench quality --database <workspace.ddb> --profile <quality-profile.toml> --out <quality-report.json> --format json\n'
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
      '      Reserved for future headless import plan support. Parsed now, but rejected at execution time.\n'
      '  --plan=<path.json>\n'
      '      Same as above, using the inline form.\n'
      '  --silent\n'
      '      Suppress headless progress output. Only valid with --in and --out.\n'
      '  quality\n'
      '      Run a headless data quality profile and export a quality report. Use `dbench quality --help` for quality-specific flags.\n'
      '\n'
      'Examples:\n'
      '  dbench\n'
      '  dbench /path/to/workspace.ddb\n'
      '  dbench --import /path/to/source.sqlite\n'
      '  dbench --import=/path/to/report.xlsx\n'
      '  dbench --in /path/to/source.xlsx --out /tmp/import.ddb\n'
      '  dbench --in /path/to/source.sqlite --out /tmp/import.ddb --plan /tmp/import-plan.json\n'
      '  dbench quality --database /tmp/workspace.ddb --profile /tmp/profile.toml --out /tmp/quality-report.json --format json\n'
      '\n'
      'Notes:\n'
      '  Passing a .ddb path opens that database in the desktop UI.\n'
      '  `--import` always opens the interactive import wizard.\n'
      '  `--in`/`--out` are reserved for headless import.\n'
      '  Headless import writes progress to stderr and a final JSON summary to stdout.\n'
      '  `--plan` is reserved for future plan-file execution and is not implemented yet.';
}

String buildStartupCliErrorText(String message) {
  return '$message\n'
      '\n'
      'Use `dbench --help` for usage.';
}

String buildHeadlessQualityHelpText() {
  return '$kDecentBenchDisplayName $kDecentBenchVersion\n'
      '\n'
      'Usage:\n'
      '  dbench quality --database <workspace.ddb> --profile <quality-profile.toml> --out <quality-report.json> --format <json|markdown|html>\n'
      '\n'
      'Required flags:\n'
      '  --database <path.ddb>\n'
      '      DecentDB database file to scan.\n'
      '  --profile <path.toml>\n'
      '      Quality profile TOML file.\n'
      '  --out <path>\n'
      '      Quality report destination.\n'
      '  --format <json|markdown|html>\n'
      '      Quality report format.\n'
      '\n'
      'Optional flags:\n'
      '  --target-table <name>\n'
      '      Run the quality profile against one table.\n'
      '  --mode <full|sampled>\n'
      '      Override the profile default run mode.\n'
      '  --sample-row-limit <n>\n'
      '      Override the profile sample row limit.\n'
      '  --include-sample-values\n'
      '      Include source sample values in the report.\n'
      '  --include-violation-details\n'
      '      Include violation detail samples in the report.\n'
      '  --silent\n'
      '      Suppress non-error progress output.\n'
      '\n'
      'Exit codes:\n'
      '  0 completed with no error-severity issues\n'
      '  1 completed with one or more error-severity issues\n'
      '  2 usage or profile validation error\n'
      '  3 database open or schema load failure\n'
      '  4 quality run failed\n'
      '  5 report export failed\n'
      '  130 cancelled';
}

bool _looksLikeDecentDbPath(String value) {
  return value.trim().toLowerCase().endsWith('.ddb');
}

class _ParsedHeadlessQualityCliArguments {
  const _ParsedHeadlessQualityCliArguments({
    this.options,
    this.output,
    this.errorMessage,
  });

  final HeadlessQualityCliOptions? options;
  final String? output;
  final String? errorMessage;
}

_ParsedHeadlessQualityCliArguments _parseHeadlessQualityCliArguments(
  List<String> rawArgs,
) {
  String? databasePath;
  String? profilePath;
  String? outputPath;
  String? format;
  String? targetTable;
  String? mode;
  int? sampleRowLimit;
  var includeSampleValues = false;
  var includeViolationDetails = false;
  var silent = false;
  String? errorMessage;

  for (var index = 0; index < rawArgs.length; index++) {
    final argument = rawArgs[index].trim();
    if (argument.isEmpty) {
      continue;
    }
    if (argument == '--help' || argument == '-h') {
      return _ParsedHeadlessQualityCliArguments(
        output: buildHeadlessQualityHelpText(),
      );
    }

    String? readValue(String flagName) {
      final nextIndex = index + 1;
      if (nextIndex >= rawArgs.length) {
        errorMessage ??= '`$flagName` expects a value.';
        return null;
      }
      final value = rawArgs[nextIndex].trim();
      if (value.isEmpty || value.startsWith('--')) {
        errorMessage ??= '`$flagName` expects a value.';
        return null;
      }
      index = nextIndex;
      return value;
    }

    if (argument == '--database') {
      if (databasePath != null) {
        errorMessage ??= '`--database` can only be specified once.';
        continue;
      }
      databasePath = readValue('--database');
      continue;
    }
    if (argument.startsWith('--database=')) {
      if (databasePath != null) {
        errorMessage ??= '`--database` can only be specified once.';
        continue;
      }
      databasePath = argument.substring('--database='.length).trim();
      continue;
    }
    if (argument == '--profile') {
      if (profilePath != null) {
        errorMessage ??= '`--profile` can only be specified once.';
        continue;
      }
      profilePath = readValue('--profile');
      continue;
    }
    if (argument.startsWith('--profile=')) {
      if (profilePath != null) {
        errorMessage ??= '`--profile` can only be specified once.';
        continue;
      }
      profilePath = argument.substring('--profile='.length).trim();
      continue;
    }
    if (argument == '--out') {
      if (outputPath != null) {
        errorMessage ??= '`--out` can only be specified once.';
        continue;
      }
      outputPath = readValue('--out');
      continue;
    }
    if (argument.startsWith('--out=')) {
      if (outputPath != null) {
        errorMessage ??= '`--out` can only be specified once.';
        continue;
      }
      outputPath = argument.substring('--out='.length).trim();
      continue;
    }
    if (argument == '--format') {
      if (format != null) {
        errorMessage ??= '`--format` can only be specified once.';
        continue;
      }
      format = readValue('--format');
      continue;
    }
    if (argument.startsWith('--format=')) {
      if (format != null) {
        errorMessage ??= '`--format` can only be specified once.';
        continue;
      }
      format = argument.substring('--format='.length).trim();
      continue;
    }
    if (argument == '--target-table') {
      if (targetTable != null) {
        errorMessage ??= '`--target-table` can only be specified once.';
        continue;
      }
      targetTable = readValue('--target-table');
      continue;
    }
    if (argument.startsWith('--target-table=')) {
      if (targetTable != null) {
        errorMessage ??= '`--target-table` can only be specified once.';
        continue;
      }
      targetTable = argument.substring('--target-table='.length).trim();
      continue;
    }
    if (argument == '--mode') {
      if (mode != null) {
        errorMessage ??= '`--mode` can only be specified once.';
        continue;
      }
      mode = readValue('--mode');
      continue;
    }
    if (argument.startsWith('--mode=')) {
      if (mode != null) {
        errorMessage ??= '`--mode` can only be specified once.';
        continue;
      }
      mode = argument.substring('--mode='.length).trim();
      continue;
    }
    if (argument == '--sample-row-limit') {
      if (sampleRowLimit != null) {
        errorMessage ??= '`--sample-row-limit` can only be specified once.';
        continue;
      }
      final rawValue = readValue('--sample-row-limit');
      sampleRowLimit = rawValue == null ? null : int.tryParse(rawValue);
      if (sampleRowLimit == null || sampleRowLimit < 1) {
        errorMessage ??= '`--sample-row-limit` expects a positive integer.';
      }
      continue;
    }
    if (argument.startsWith('--sample-row-limit=')) {
      if (sampleRowLimit != null) {
        errorMessage ??= '`--sample-row-limit` can only be specified once.';
        continue;
      }
      sampleRowLimit = int.tryParse(
        argument.substring('--sample-row-limit='.length).trim(),
      );
      if (sampleRowLimit == null || sampleRowLimit < 1) {
        errorMessage ??= '`--sample-row-limit` expects a positive integer.';
      }
      continue;
    }
    if (argument == '--include-sample-values') {
      includeSampleValues = true;
      continue;
    }
    if (argument == '--include-violation-details') {
      includeViolationDetails = true;
      continue;
    }
    if (argument == '--silent') {
      silent = true;
      continue;
    }
    errorMessage ??= 'Unknown quality option: $argument.';
  }

  if (errorMessage == null &&
      (databasePath == null || databasePath.trim().isEmpty)) {
    errorMessage = '`dbench quality` requires `--database`.';
  }
  if (errorMessage == null &&
      (profilePath == null || profilePath.trim().isEmpty)) {
    errorMessage = '`dbench quality` requires `--profile`.';
  }
  if (errorMessage == null &&
      (outputPath == null || outputPath.trim().isEmpty)) {
    errorMessage = '`dbench quality` requires `--out`.';
  }
  if (errorMessage == null && (format == null || format.trim().isEmpty)) {
    errorMessage = '`dbench quality` requires `--format`.';
  }
  if (errorMessage == null &&
      format != null &&
      !const <String>{'json', 'markdown', 'html'}.contains(format)) {
    errorMessage = '`--format` must be one of json, markdown, or html.';
  }
  if (errorMessage == null &&
      mode != null &&
      !const <String>{'full', 'sampled'}.contains(mode)) {
    errorMessage = '`--mode` must be full or sampled.';
  }

  if (errorMessage != null) {
    return _ParsedHeadlessQualityCliArguments(errorMessage: errorMessage);
  }
  return _ParsedHeadlessQualityCliArguments(
    options: HeadlessQualityCliOptions(
      databasePath: databasePath!,
      profilePath: profilePath!,
      outputPath: outputPath!,
      format: format!,
      targetTable: targetTable,
      mode: mode,
      sampleRowLimit: sampleRowLimit,
      includeSampleValues: includeSampleValues,
      includeViolationDetails: includeViolationDetails,
      silent: silent,
    ),
  );
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
