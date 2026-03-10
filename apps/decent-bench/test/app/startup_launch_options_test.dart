import 'package:decent_bench/app/startup_launch_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses --import filename form', () {
    final options = parseStartupLaunchOptions(<String>[
      '--import',
      '/tmp/source.xlsx',
    ]);

    expect(options.importSourcePath, '/tmp/source.xlsx');
    expect(options.startupNotice, isNull);
  });

  test('parses --import=filename form', () {
    final options = parseStartupLaunchOptions(<String>[
      '--import=/tmp/source.sqlite',
    ]);

    expect(options.importSourcePath, '/tmp/source.sqlite');
    expect(options.startupNotice, isNull);
  });

  test('reports a notice when --import is missing a filename', () {
    final options = parseStartupLaunchOptions(<String>['--import']);

    expect(options.importSourcePath, isNull);
    expect(options.startupNotice, '`--import` expects a filename.');
  });
}
