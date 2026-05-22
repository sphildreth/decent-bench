import 'package:decent_bench/features/import_modules/domain/import_module_manifest.dart';
import 'package:decent_bench/features/import_modules/infrastructure/builtin_import_module_catalog.dart';
import 'package:decent_bench/features/import_modules/infrastructure/import_module_catalog.dart';
import 'package:decent_bench/features/import_modules/infrastructure/import_module_registry_adapter.dart';

import '../domain/import_models.dart';

class ImportFormatRegistry {
  ImportFormatRegistry._({
    ImportModuleCatalog? catalog,
    ImportModuleRegistryAdapter adapter = const ImportModuleRegistryAdapter(),
  }) : catalog = catalog ?? builtinImportModuleCatalog,
       _adapter = adapter {
    _formats = List<ImportFormatDefinition>.unmodifiable(
      this.catalog.modules.map(_adapter.toFormatDefinition),
    );
    _byKey = <ImportFormatKey, ImportFormatDefinition>{
      for (final format in _formats) format.key: format,
    };
  }

  static final ImportFormatRegistry instance = ImportFormatRegistry._();

  final ImportModuleCatalog catalog;
  final ImportModuleRegistryAdapter _adapter;
  late final List<ImportFormatDefinition> _formats;
  late final Map<ImportFormatKey, ImportFormatDefinition> _byKey;

  List<ImportFormatDefinition> get formats => _formats;

  ImportModuleManifest moduleForKey(ImportFormatKey key) {
    return catalog.forLegacyFormatKey(key.name);
  }

  ImportModuleManifest moduleForPath(String path) {
    return catalog.detectByPath(path) ?? moduleForKey(ImportFormatKey.unknown);
  }

  ImportFormatDefinition forKey(ImportFormatKey key) {
    final format = _byKey[key];
    if (format == null) {
      throw StateError('Unknown import format `${key.name}`.');
    }
    return format;
  }

  ImportFormatDefinition? forExtension(String extension) {
    final module = catalog.forExtension(extension);
    return module == null ? null : forKey(_keyForModule(module));
  }

  ImportFormatDefinition detectByPath(String path) {
    final module = catalog.detectByPath(path);
    return module == null
        ? forKey(ImportFormatKey.unknown)
        : forKey(_keyForModule(module));
  }

  List<String> implementedExtensions() => catalog.implementedExtensions();

  ImportFormatKey _keyForModule(ImportModuleManifest module) {
    return ImportFormatKey.values.byName(module.legacyFormatKey);
  }
}
