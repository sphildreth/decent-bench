import '../domain/import_module_manifest.dart';
import 'import_module_adapter_registry.dart';

class ImportModuleValidationException implements Exception {
  const ImportModuleValidationException(this.message);

  final String message;

  @override
  String toString() => 'ImportModuleValidationException: $message';
}

class ImportModuleValidator {
  const ImportModuleValidator();

  void validateManifest(
    ImportModuleManifest manifest, {
    ImportModuleAdapterRegistry adapterRegistry =
        ImportModuleAdapterRegistry.builtin,
  }) {
    if (manifest.schemaVersion != 1) {
      throw ImportModuleValidationException(
        'Module `${manifest.id}` uses unsupported schema version ${manifest.schemaVersion}.',
      );
    }
    _validateSnakeCase(manifest.id, 'module id');
    _validateNonEmpty(manifest.name, 'name', manifest.id);
    _validateNonEmpty(
      manifest.legacyFormatKey,
      'legacy format key',
      manifest.id,
    );
    _validateNonEmpty(manifest.summary, 'summary', manifest.id);
    _validateNonEmpty(manifest.description, 'description', manifest.id);
    for (final extension in manifest.detection.extensions) {
      if (!extension.startsWith('.') || extension != extension.toLowerCase()) {
        throw ImportModuleValidationException(
          'Module `${manifest.id}` has invalid extension `$extension`.',
        );
      }
    }
    _validateUnique(
      manifest.actions.map((action) => action.id),
      'action',
      manifest.id,
    );
    _validateUnique(
      manifest.options.map((option) => option.id),
      'option',
      manifest.id,
    );
    if (manifest.status == ImportModuleStatus.complete &&
        !manifest.isImplemented) {
      throw ImportModuleValidationException(
        'Complete module `${manifest.id}` must reference an implemented adapter.',
      );
    }
    if (manifest.status == ImportModuleStatus.partial &&
        manifest.limitations.isEmpty) {
      throw ImportModuleValidationException(
        'Partial module `${manifest.id}` must declare at least one limitation.',
      );
    }
    if ((manifest.status == ImportModuleStatus.complete ||
            manifest.status == ImportModuleStatus.partial) &&
        manifest.documentation.formatDocs.isEmpty) {
      throw ImportModuleValidationException(
        'Implemented module `${manifest.id}` must declare documentation.',
      );
    }
    if ((manifest.status == ImportModuleStatus.complete ||
            manifest.status == ImportModuleStatus.partial) &&
        manifest.documentation.fixtureNotes.isEmpty &&
        manifest.fixtures.isEmpty) {
      throw ImportModuleValidationException(
        'Implemented module `${manifest.id}` must declare fixture coverage.',
      );
    }
    if (manifest.adapter.kind == ImportModuleAdapterKind.none &&
        manifest.isImplemented) {
      throw ImportModuleValidationException(
        'Implemented module `${manifest.id}` must not use adapter kind `none`.',
      );
    }
    final adapter = adapterRegistry.maybeForId(manifest.adapter.id);
    if (adapter == null) {
      throw ImportModuleValidationException(
        'Module `${manifest.id}` references unknown adapter `${manifest.adapter.id}`.',
      );
    }
    if (manifest.isImplemented && !adapter.executable) {
      throw ImportModuleValidationException(
        'Implemented module `${manifest.id}` references non-executable adapter `${adapter.id}`.',
      );
    }
  }

  void validateCatalog(
    List<ImportModuleManifest> manifests, {
    ImportModuleAdapterRegistry adapterRegistry =
        ImportModuleAdapterRegistry.builtin,
  }) {
    final ids = <String>{};
    final legacyFormatKeys = <String>{};
    final extensions = <String, String>{};
    for (final manifest in manifests) {
      validateManifest(manifest, adapterRegistry: adapterRegistry);
      if (!ids.add(manifest.id)) {
        throw ImportModuleValidationException(
          'Duplicate import module id `${manifest.id}`.',
        );
      }
      if (!legacyFormatKeys.add(manifest.legacyFormatKey)) {
        throw ImportModuleValidationException(
          'Duplicate legacy format key `${manifest.legacyFormatKey}`.',
        );
      }
      for (final extension in manifest.detection.extensions) {
        final owner = extensions[extension];
        if (owner != null) {
          throw ImportModuleValidationException(
            'Extension `$extension` is owned by both `$owner` and `${manifest.id}`.',
          );
        }
        extensions[extension] = manifest.id;
      }
    }
  }

  void _validateUnique(Iterable<String> ids, String kind, String moduleId) {
    final seen = <String>{};
    for (final id in ids) {
      _validateSnakeCase(id, '$kind id');
      if (!seen.add(id)) {
        throw ImportModuleValidationException(
          'Module `$moduleId` has duplicate $kind id `$id`.',
        );
      }
    }
  }

  void _validateSnakeCase(String value, String label) {
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(value)) {
      throw ImportModuleValidationException(
        'Invalid $label `$value`; expected lowercase snake_case.',
      );
    }
  }

  void _validateNonEmpty(String value, String label, String moduleId) {
    if (value.trim().isEmpty) {
      throw ImportModuleValidationException(
        'Module `$moduleId` has empty $label.',
      );
    }
  }
}
