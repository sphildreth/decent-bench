import 'dart:io';

import '../domain/import_module_manifest.dart';

class ImportModuleFixtureLoader {
  const ImportModuleFixtureLoader({this.rootPath = 'import_modules/builtin'});

  final String rootPath;

  List<ResolvedImportModuleFixture> fixturesFor(ImportModuleManifest module) {
    return <ResolvedImportModuleFixture>[
      for (final fixture in module.fixtures)
        ResolvedImportModuleFixture(
          moduleId: module.id,
          fixture: fixture,
          path: '$rootPath/${module.id}/${fixture.path}',
        ),
    ];
  }

  List<ResolvedImportModuleFixture> executableFixturesFor(
    ImportModuleManifest module,
  ) {
    return fixturesFor(module)
        .where((fixture) => fixture.exists && !fixture.fixture.generated)
        .toList(growable: false);
  }
}

class ResolvedImportModuleFixture {
  const ResolvedImportModuleFixture({
    required this.moduleId,
    required this.fixture,
    required this.path,
  });

  final String moduleId;
  final ImportModuleFixture fixture;
  final String path;

  bool get exists => File(path).existsSync();
}
