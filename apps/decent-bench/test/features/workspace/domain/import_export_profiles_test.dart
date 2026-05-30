import 'dart:convert';
import 'dart:io';

import 'package:decent_bench/features/workspace/domain/import_export_profiles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('round-trips import and export profile JSON', () {
    const document = ImportExportProfileDocument(
      configVersion: 1,
      importPlan: ImportPlanProfile(
        name: 'CSV import',
        sourceFormat: 'csv',
        headerRow: true,
        delimiter: ',',
        nativeTypeMappings: <String, String>{'created_at': 'TIMESTAMPTZ'},
        tableTargets: <String, String>{'Sheet1': 'contacts'},
      ),
      exportProfiles: <ExportProfile>[
        ExportProfile(
          id: 'json-lossless',
          name: 'JSON lossless',
          format: 'json',
          outputDirectory: 'exports',
          includeMetadata: true,
          nativeTypeMode: 'lossless',
        ),
      ],
    );

    final restored = ImportExportProfileDocument.fromJsonString(
      jsonEncode(document.toJson()),
    );

    expect(restored.configVersion, 1);
    expect(restored.importPlan.name, 'CSV import');
    expect(restored.importPlan.nativeTypeMappings['created_at'], 'TIMESTAMPTZ');
    expect(restored.exportProfiles.single.id, 'json-lossless');
    expect(restored.exportProfiles.single.format, 'json');
  });

  test(
    'loads profile documents from disk and rejects unsupported versions',
    () async {
      final dir = await Directory.systemTemp.createTemp('profile-test-');
      addTearDown(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });
      final path = p.join(dir.path, 'profile.json');
      await File(path).writeAsString(
        jsonEncode(<String, Object?>{
          'config_version': 1,
          'import': <String, Object?>{'name': 'Default'},
          'exports': <Object?>[],
        }),
      );

      final loaded = await ImportExportProfileDocument.loadFile(path);
      expect(loaded.importPlan.name, 'Default');

      await File(
        path,
      ).writeAsString(jsonEncode(<String, Object?>{'config_version': 2}));
      expect(
        () => ImportExportProfileDocument.loadFile(path),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
