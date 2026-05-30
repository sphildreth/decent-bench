import 'dart:io';

import 'package:decent_bench/features/import_modules/domain/import_module_manifest.dart';
import 'package:decent_bench/features/import_modules/infrastructure/builtin_import_module_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundled help covers supported built-in modules', () {
    final help = File('assets/help/importing-data.md').readAsStringSync();
    final gettingStarted = File(
      'assets/help/getting-started.md',
    ).readAsStringSync();
    final combined = '$help\n$gettingStarted';

    for (final module in builtinImportModuleCatalog.modules) {
      if (module.status != ImportModuleStatus.complete &&
          module.status != ImportModuleStatus.partial) {
        continue;
      }
      expect(
        combined,
        contains(module.name),
        reason:
            'supported import module ${module.id} must be mentioned in help.',
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
      'Generic Delimited Text',
      'Structured documents',
      'HTML Tables',
      'Excel',
      'SQLite',
      'SQL Dump',
      'ZIP Wrapper',
    ]) {
      expect(combined, contains(phrase));
    }
  });
}
