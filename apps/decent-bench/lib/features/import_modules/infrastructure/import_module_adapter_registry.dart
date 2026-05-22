import '../domain/import_module_manifest.dart';

class ImportModuleAdapterDefinition {
  const ImportModuleAdapterDefinition({
    required this.id,
    required this.kind,
    required this.description,
    this.executable = true,
  });

  final String id;
  final ImportModuleAdapterKind kind;
  final String description;
  final bool executable;
}

class ImportModuleAdapterRegistry {
  const ImportModuleAdapterRegistry(this.adapters);

  static const ImportModuleAdapterRegistry builtin =
      ImportModuleAdapterRegistry(<ImportModuleAdapterDefinition>[
        ImportModuleAdapterDefinition(
          id: 'direct_open_decentdb',
          kind: ImportModuleAdapterKind.dartBuiltin,
          description: 'Opens existing DecentDB files without import.',
        ),
        ImportModuleAdapterDefinition(
          id: 'generic_delimited',
          kind: ImportModuleAdapterKind.dartGeneric,
          description: 'Uses the generic delimited text preview/import path.',
        ),
        ImportModuleAdapterDefinition(
          id: 'generic_structured',
          kind: ImportModuleAdapterKind.dartGeneric,
          description: 'Uses the generic structured document path.',
        ),
        ImportModuleAdapterDefinition(
          id: 'generic_html_table',
          kind: ImportModuleAdapterKind.dartGeneric,
          description: 'Uses the generic HTML table extraction path.',
        ),
        ImportModuleAdapterDefinition(
          id: 'legacy_excel',
          kind: ImportModuleAdapterKind.legacyWizard,
          description: 'Routes to the existing Excel import wizard.',
        ),
        ImportModuleAdapterDefinition(
          id: 'legacy_sqlite',
          kind: ImportModuleAdapterKind.legacyWizard,
          description: 'Routes to the existing SQLite import wizard.',
        ),
        ImportModuleAdapterDefinition(
          id: 'legacy_sql_dump',
          kind: ImportModuleAdapterKind.legacyWizard,
          description: 'Routes to the existing SQL dump import wizard.',
        ),
        ImportModuleAdapterDefinition(
          id: 'zip_wrapper',
          kind: ImportModuleAdapterKind.wrapper,
          description: 'Discovers and extracts supported ZIP entries.',
        ),
        ImportModuleAdapterDefinition(
          id: 'gzip_wrapper',
          kind: ImportModuleAdapterKind.wrapper,
          description: 'Unwraps GZip and tar+gzip sources.',
        ),
        ImportModuleAdapterDefinition(
          id: 'bzip2_wrapper',
          kind: ImportModuleAdapterKind.wrapper,
          description: 'Unwraps BZip2 and tar+bzip2 sources.',
        ),
        ImportModuleAdapterDefinition(
          id: 'none',
          kind: ImportModuleAdapterKind.none,
          description: 'Unavailable module placeholder.',
          executable: false,
        ),
      ]);

  final List<ImportModuleAdapterDefinition> adapters;

  ImportModuleAdapterDefinition? maybeForId(String id) {
    for (final adapter in adapters) {
      if (adapter.id == id) {
        return adapter;
      }
    }
    return null;
  }

  ImportModuleAdapterDefinition forId(String id) {
    final adapter = maybeForId(id);
    if (adapter == null) {
      throw StateError('Unknown import module adapter `$id`.');
    }
    return adapter;
  }

  bool contains(String id) => maybeForId(id) != null;
}
