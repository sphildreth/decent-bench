import 'package:decent_bench/app/startup_launch_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns a help decision for --help', () {
    final decision = parseStartupCliDecision(<String>['--help']);

    expect(decision.behavior, StartupCliBehavior.printHelp);
    expect(decision.shouldExit, isTrue);
    expect(decision.output, contains('Usage:'));
    expect(decision.output, contains('dbench /path/to/workspace.ddb'));
    expect(decision.output, contains('--import <path>'));
    expect(decision.output, contains('--in <path>'));
    expect(decision.output, contains('--out <path.ddb>'));
    expect(decision.output, contains('--plan <path.json>'));
    expect(decision.output, contains('--silent'));
    expect(decision.output, contains('--version'));
  });

  test('returns a version decision for --version', () {
    final decision = parseStartupCliDecision(<String>['--version']);

    expect(decision.behavior, StartupCliBehavior.printVersion);
    expect(decision.shouldExit, isTrue);
    expect(decision.output, contains('Decent Bench'));
  });

  test('parses --import filename form', () {
    final options = parseStartupLaunchOptions(<String>[
      '--import',
      '/tmp/source.xlsx',
    ]);

    expect(options.openDatabasePath, isNull);
    expect(options.importSourcePath, '/tmp/source.xlsx');
    expect(options.startupNotice, isNull);
  });

  test('parses a positional .ddb path for direct open', () {
    final options = parseStartupLaunchOptions(<String>['/tmp/workspace.ddb']);

    expect(options.openDatabasePath, '/tmp/workspace.ddb');
    expect(options.importSourcePath, isNull);
    expect(options.startupNotice, isNull);
  });

  test('parses --import=filename form', () {
    final options = parseStartupLaunchOptions(<String>[
      '--import=/tmp/source.sqlite',
    ]);

    expect(options.openDatabasePath, isNull);
    expect(options.importSourcePath, '/tmp/source.sqlite');
    expect(options.startupNotice, isNull);
  });

  test('reports a notice when --import is missing a filename', () {
    final options = parseStartupLaunchOptions(<String>['--import']);

    expect(options.openDatabasePath, isNull);
    expect(options.importSourcePath, isNull);
    expect(options.startupNotice, '`--import` expects a filename.');
  });

  test('returns a headless import decision for --in/--out', () {
    final decision = parseStartupCliDecision(<String>[
      '--in',
      '/tmp/source.sqlite',
      '--out',
      '/tmp/output.ddb',
    ]);

    expect(decision.behavior, StartupCliBehavior.runHeadlessImport);
    expect(decision.shouldExit, isTrue);
    expect(decision.headlessImportOptions?.sourcePath, '/tmp/source.sqlite');
    expect(decision.headlessImportOptions?.targetPath, '/tmp/output.ddb');
    expect(decision.headlessImportOptions?.planPath, isNull);
    expect(decision.headlessImportOptions?.silent, isFalse);
  });

  test('parses inline headless import options', () {
    final decision = parseStartupCliDecision(<String>[
      '--in=/tmp/source.xlsx',
      '--out=/tmp/output.ddb',
      '--plan=/tmp/import-plan.json',
      '--silent',
    ]);

    expect(decision.behavior, StartupCliBehavior.runHeadlessImport);
    expect(decision.headlessImportOptions?.sourcePath, '/tmp/source.xlsx');
    expect(decision.headlessImportOptions?.targetPath, '/tmp/output.ddb');
    expect(decision.headlessImportOptions?.planPath, '/tmp/import-plan.json');
    expect(decision.headlessImportOptions?.silent, isTrue);
  });

  test('rejects --in without --out', () {
    final decision = parseStartupCliDecision(<String>[
      '--in',
      '/tmp/source.sqlite',
    ]);

    expect(decision.behavior, StartupCliBehavior.printError);
    expect(decision.output, contains('`--in` requires `--out`.'));
  });

  test('rejects --plan without headless import mode', () {
    final decision = parseStartupCliDecision(<String>[
      '--plan',
      '/tmp/import-plan.json',
    ]);

    expect(decision.behavior, StartupCliBehavior.printError);
    expect(
      decision.output,
      contains('`--plan` is only valid with `--in` and `--out`.'),
    );
  });

  test('rejects --silent without headless import mode', () {
    final decision = parseStartupCliDecision(<String>['--silent']);

    expect(decision.behavior, StartupCliBehavior.printError);
    expect(
      decision.output,
      contains('`--silent` is only valid with `--in` and `--out`.'),
    );
  });

  test('rejects combining --import with headless import flags', () {
    final decision = parseStartupCliDecision(<String>[
      '--import',
      '/tmp/source.xlsx',
      '--in',
      '/tmp/source.sqlite',
      '--out',
      '/tmp/output.ddb',
    ]);

    expect(decision.behavior, StartupCliBehavior.printError);
    expect(
      decision.output,
      contains('`--import` cannot be combined with headless import flags.'),
    );
  });

  test('rejects combining a positional .ddb path with headless flags', () {
    final decision = parseStartupCliDecision(<String>[
      '/tmp/workspace.ddb',
      '--in',
      '/tmp/source.sqlite',
      '--out',
      '/tmp/output.ddb',
    ]);

    expect(decision.behavior, StartupCliBehavior.printError);
    expect(
      decision.output,
      contains(
        'A positional .ddb path cannot be combined with `--import` or headless import flags.',
      ),
    );
  });

  test('dispatches a positional .ddb path to direct open', () async {
    String? openedPath;
    String? importedPath;
    String? noticeTitle;
    String? noticeMessage;

    await applyStartupLaunchOptions(
      const StartupLaunchOptions(openDatabasePath: '/tmp/workspace.ddb'),
      showNotice: (title, message) async {
        noticeTitle = title;
        noticeMessage = message;
      },
      openDatabase: (path) async {
        openedPath = path;
      },
      startImport: (path) async {
        importedPath = path;
      },
    );

    expect(openedPath, '/tmp/workspace.ddb');
    expect(importedPath, isNull);
    expect(noticeTitle, isNull);
    expect(noticeMessage, isNull);
  });

  test('dispatches --import paths to the import flow', () async {
    String? openedPath;
    String? importedPath;

    await applyStartupLaunchOptions(
      const StartupLaunchOptions(importSourcePath: '/tmp/source.xlsx'),
      showNotice: (ignoredTitle, ignoredMessage) async {},
      openDatabase: (path) async {
        openedPath = path;
      },
      startImport: (path) async {
        importedPath = path;
      },
    );

    expect(openedPath, isNull);
    expect(importedPath, '/tmp/source.xlsx');
  });

  test('dispatches startup notices before open/import actions', () async {
    String? openedPath;
    String? importedPath;
    String? noticeTitle;
    String? noticeMessage;

    await applyStartupLaunchOptions(
      const StartupLaunchOptions(
        openDatabasePath: '/tmp/workspace.ddb',
        importSourcePath: '/tmp/source.xlsx',
        startupNotice: '`--import` expects a filename.',
      ),
      showNotice: (title, message) async {
        noticeTitle = title;
        noticeMessage = message;
      },
      openDatabase: (path) async {
        openedPath = path;
      },
      startImport: (path) async {
        importedPath = path;
      },
    );

    expect(noticeTitle, 'Command-line import');
    expect(noticeMessage, '`--import` expects a filename.');
    expect(openedPath, isNull);
    expect(importedPath, isNull);
  });

  test('builds a headless import unavailable message', () {
    final message = buildHeadlessImportUnavailableText();

    expect(message, contains('Headless import mode is not implemented yet'));
    expect(message, contains('--in <source-path> --out <target.ddb>'));
  });
}
