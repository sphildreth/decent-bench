import 'dart:io';

import 'package:decent_bench/features/import/domain/import_models.dart';
import 'package:decent_bench/features/import/infrastructure/import_format_registry.dart';
import 'package:decent_bench/features/import_modules/domain/import_module_manifest.dart';
import 'package:decent_bench/features/import_modules/infrastructure/builtin_import_module_catalog.dart';
import 'package:decent_bench/features/import_modules/infrastructure/import_module_adapter_dispatcher.dart';
import 'package:decent_bench/features/import_modules/infrastructure/import_module_adapter_registry.dart';
import 'package:decent_bench/features/import_modules/infrastructure/import_module_catalog.dart';
import 'package:decent_bench/features/import_modules/infrastructure/import_module_manifest_codec.dart';
import 'package:decent_bench/features/import_modules/infrastructure/import_module_manifest_parser.dart';
import 'package:decent_bench/features/import_modules/infrastructure/import_module_option_defaults.dart';
import 'package:decent_bench/features/import_modules/infrastructure/import_module_validator.dart';
import 'package:decent_bench/features/import_modules/test_support/import_module_fixture_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Import module manifests', () {
    test('parses the schema example manifest', () {
      final source = File(
        'import_modules/schema/import_module_manifest.example.toml',
      ).readAsStringSync();

      final module = const ImportModuleManifestCodec().parse(source);

      expect(module.id, 'csv');
      expect(module.legacyFormatKey, ImportFormatKey.csv.name);
      expect(module.description, contains('header detection'));
      expect(module.options.map((option) => option.id), contains('encoding'));
      expect(module.documentation.helpTopic, 'importing-data');
    });

    test('rejects duplicate keys in one manifest section', () {
      expect(
        () => const ImportModuleManifestParser().parse('''
schema_version = 1
schema_version = 1
'''),
        throwsA(isA<ImportModuleManifestException>()),
      );
    });

    test('rejects unknown manifest keys', () {
      final source = File(
        'import_modules/schema/import_module_manifest.example.toml',
      ).readAsStringSync();

      expect(
        () => const ImportModuleManifestCodec().parse(
          source.replaceFirst('[detection]', 'unexpected = true\n[detection]'),
        ),
        throwsA(isA<ImportModuleManifestException>()),
      );
      expect(
        () => const ImportModuleManifestCodec().parse(
          source.replaceFirst(
            'extensions = [".csv"]',
            'extensions = [".csv"]\nunexpected = true',
          ),
        ),
        throwsA(isA<ImportModuleManifestException>()),
      );
    });

    test(
      'loads every built-in module TOML and validates documentation files',
      () {
        final modules = _loadModuleTomlCatalog();
        const validator = ImportModuleValidator();
        validator.validateCatalog(modules);

        expect(modules, hasLength(ImportFormatKey.values.length));
        for (final module in modules) {
          final moduleDir = Directory('import_modules/builtin/${module.id}');
          expect(File('${moduleDir.path}/README.md').existsSync(), isTrue);
          expect(
            File(
              '${moduleDir.path}/${module.documentation.fixtureNotes}',
            ).existsSync(),
            isTrue,
          );
          final readme = File('${moduleDir.path}/README.md').readAsStringSync();
          for (final heading in <String>[
            '## Status',
            '## Extensions',
            '## Capabilities',
            '## Type Fidelity',
            '## Limitations',
            '## Fixtures',
          ]) {
            expect(
              readme,
              contains(heading),
              reason: '${module.id} README is missing $heading.',
            );
          }
        }
      },
    );

    test(
      'compiled catalog matches TOML identity, status, and extension data',
      () {
        final parsedById = <String, ImportModuleManifest>{
          for (final module in _loadModuleTomlCatalog()) module.id: module,
        };

        for (final compiled in builtinImportModuleCatalog.modules) {
          final parsed = parsedById[compiled.id];
          expect(parsed, isNotNull, reason: compiled.id);
          expect(parsed!.legacyFormatKey, compiled.legacyFormatKey);
          expect(parsed.status, compiled.status);
          expect(
            parsed.support.implementation,
            compiled.support.implementation,
          );
          expect(parsed.detection.extensions, compiled.detection.extensions);
        }
      },
    );
  });

  group('Import module catalog', () {
    test('has one module for every current ImportFormatKey', () {
      final keys = builtinImportModuleCatalog.modules
          .map((module) => module.legacyFormatKey)
          .toSet();

      expect(keys, ImportFormatKey.values.map((key) => key.name).toSet());
    });

    test('detects compound archive extensions before their suffixes', () {
      expect(
        builtinImportModuleCatalog.detectByPath('/tmp/export.tar.gz')!.id,
        'gzip_archive',
      );
      expect(
        builtinImportModuleCatalog.detectByPath('/tmp/export.tar.bz2')!.id,
        'bzip2_archive',
      );
      expect(
        builtinImportModuleCatalog.detectByPath('/tmp/export.tar.xz')!.id,
        'xz_archive',
      );
    });

    test('fails duplicate ids and duplicate extensions', () {
      final csv = builtinImportModuleCatalog.forId('csv');
      expect(
        () => ImportModuleCatalog(<ImportModuleManifest>[csv, csv]),
        throwsA(isA<ImportModuleValidationException>()),
      );

      final duplicateExtension = ImportModuleManifest(
        schemaVersion: 1,
        id: 'duplicate_csv',
        kind: ImportModuleKind.source,
        status: ImportModuleStatus.planned,
        priority: ImportModulePriority.p4,
        legacyFormatKey: 'duplicateCsv',
        name: 'Duplicate CSV',
        family: ImportModuleFamily.delimitedText,
        summary: 'Duplicate extension test.',
        description: 'Duplicate extension test.',
        detection: const ImportModuleDetection(extensions: <String>['.csv']),
        support: const ImportModuleSupport(
          implementation: ImportModuleImplementation.recognizedUnsupported,
        ),
        capabilities: const ImportModuleCapabilities(),
        adapter: const ImportModuleAdapterRef(
          id: 'none',
          kind: ImportModuleAdapterKind.none,
          protocol: 'dart_import_adapter_v1',
        ),
        actions: const <ImportModuleAction>[
          ImportModuleAction(
            id: 'recognize_source',
            label: 'Recognize Source',
            required: true,
          ),
        ],
        documentation: const ImportModuleDocumentation(
          helpTopic: 'importing-data',
          formatDocs: 'README.md',
          fixtureNotes: 'fixtures/README.md',
        ),
      );
      expect(
        () => ImportModuleCatalog(<ImportModuleManifest>[
          csv,
          duplicateExtension,
        ]),
        throwsA(isA<ImportModuleValidationException>()),
      );
    });
  });

  group('Registry compatibility', () {
    test('derives current import definitions from the module catalog', () {
      final registry = ImportFormatRegistry.instance;

      expect(registry.forKey(ImportFormatKey.csv).label, 'CSV');
      expect(
        registry.forKey(ImportFormatKey.sqlite).implementationKind,
        ImportImplementationKind.legacyWizard,
      );
      expect(
        registry.forKey(ImportFormatKey.parquet).supportState,
        ImportSupportState.planned,
      );
      expect(registry.detectByPath('/tmp/data.csv').key, ImportFormatKey.csv);
      expect(
        registry.detectByPath('/tmp/data.tar.bz2').key,
        ImportFormatKey.bzip2Archive,
      );
    });

    test('keeps option defaults declared by modules compatible', () {
      expect(
        defaultGenericImportOptionsForModule(ImportFormatKey.csv).delimiter,
        ',',
      );
      expect(
        defaultGenericImportOptionsForModule(ImportFormatKey.tsv).delimiter,
        '\t',
      );
      expect(
        defaultGenericImportOptionsForModule(
          ImportFormatKey.json,
        ).structuredStrategy,
        StructuredImportStrategy.normalize,
      );
      expect(
        defaultGenericImportOptionsForModule(
          ImportFormatKey.xml,
        ).structuredStrategy,
        StructuredImportStrategy.flatten,
      );
      expect(
        defaultGenericImportOptionsForModule(
          ImportFormatKey.htmlTable,
        ).preserveHtmlMetadata,
        isTrue,
      );
    });
  });

  group('Adapter registry', () {
    test('contains all adapters referenced by executable modules', () {
      for (final module in builtinImportModuleCatalog.modules) {
        final adapter = ImportModuleAdapterRegistry.builtin.maybeForId(
          module.adapter.id,
        );
        expect(adapter, isNotNull, reason: module.id);
        if (module.isImplemented) {
          expect(adapter!.executable, isTrue, reason: module.id);
        }
      }
    });

    test(
      'dispatcher routes generic preview through registered adapter',
      () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'decent-bench-module-dispatcher-',
        );
        try {
          final file = File('${tempDir.path}/people.csv')
            ..writeAsStringSync('id,name\n1,Ada\n');
          final registry = ImportFormatRegistry.instance;
          final dispatcher = ImportModuleAdapterDispatcher(
            formatRegistry: registry,
          );

          final inspection = await dispatcher.inspectGeneric(
            sourcePath: file.path,
            format: registry.forKey(ImportFormatKey.csv),
            options: defaultGenericImportOptionsForModule(ImportFormatKey.csv),
          );

          expect(inspection.tables.single.targetName, 'people');
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      },
    );
  });

  group('Fixture loader', () {
    test('resolves generated fixture notes for complete modules', () {
      const loader = ImportModuleFixtureLoader();
      final fixtures = loader.fixturesFor(
        builtinImportModuleCatalog.forId('csv'),
      );

      expect(fixtures, isNotEmpty);
      expect(fixtures.single.exists, isTrue);
      expect(fixtures.single.fixture.generated, isTrue);
    });
  });
}

List<ImportModuleManifest> _loadModuleTomlCatalog() {
  final codec = const ImportModuleManifestCodec();
  final files =
      Directory('import_modules/builtin')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('/module.toml'))
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));
  return <ImportModuleManifest>[
    for (final file in files) codec.parse(file.readAsStringSync()),
  ];
}
