import 'dart:io';

import 'package:decent_bench/features/import_modules/domain/import_module_manifest.dart';
import 'package:decent_bench/features/import_modules/infrastructure/builtin_import_module_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('design import format documentation covers built-in modules', () {
    final formatsDoc = File(
      '../../design/IMPORT_FORMATS.md',
    ).readAsStringSync();

    expect(formatsDoc, contains('module catalog'));
    for (final module in builtinImportModuleCatalog.modules) {
      if (module.status == ImportModuleStatus.notStarted) {
        continue;
      }
      expect(
        formatsDoc,
        contains(module.name),
        reason: 'design/IMPORT_FORMATS.md must mention ${module.id}.',
      );
    }
  });

  test('bundled help describes complete and partial import families', () {
    final help = File('assets/help/importing-data.md').readAsStringSync();
    final gettingStarted = File(
      'assets/help/getting-started.md',
    ).readAsStringSync();
    final combined = '$help\n$gettingStarted';

    for (final phrase in <String>[
      'Delimited text',
      'Structured documents',
      'HTML tables',
      'Excel',
      'SQLite',
      'SQL dumps',
      'Archive wrappers',
    ]) {
      expect(combined, contains(phrase));
    }
  });
}
