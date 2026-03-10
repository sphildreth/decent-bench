import 'package:decent_bench/features/workspace/domain/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppConfig round-trips to TOML', () {
    final config = AppConfig.defaults().copyWith(
      recentFiles: const <String>['/tmp/a.ddb', '/tmp/b.ddb'],
      defaultPageSize: 250,
      csvDelimiter: ';',
      csvIncludeHeaders: false,
    );

    final parsed = AppConfig.fromToml(config.toToml());

    expect(parsed.recentFiles, config.recentFiles);
    expect(parsed.defaultPageSize, 250);
    expect(parsed.csvDelimiter, ';');
    expect(parsed.csvIncludeHeaders, isFalse);
  });

  test('pushRecentFile keeps unique ordering and trims the list', () {
    var config = AppConfig.defaults();
    for (var i = 0; i < AppConfig.maxRecentFiles + 2; i++) {
      config = config.pushRecentFile('/tmp/$i.ddb');
    }

    config = config.pushRecentFile('/tmp/3.ddb');

    expect(config.recentFiles.first, '/tmp/3.ddb');
    expect(config.recentFiles.length, AppConfig.maxRecentFiles);
    expect(config.recentFiles.where((item) => item == '/tmp/3.ddb').length, 1);
  });
}
