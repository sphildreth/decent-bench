import '../domain/import_module_manifest.dart';
import 'import_module_validator.dart';

class ImportModuleCatalog {
  ImportModuleCatalog(
    Iterable<ImportModuleManifest> modules, {
    ImportModuleValidator validator = const ImportModuleValidator(),
  }) {
    final sorted = modules.toList(growable: false)..sort(_compareModules);
    validator.validateCatalog(sorted);
    _modules = List<ImportModuleManifest>.unmodifiable(sorted);
    _byId = <String, ImportModuleManifest>{
      for (final module in _modules) module.id: module,
    };
    _byLegacyFormatKey = <String, ImportModuleManifest>{
      for (final module in _modules) module.legacyFormatKey: module,
    };
    _extensions =
        <_ModuleExtension>[
          for (final module in _modules)
            for (final extension in module.detection.extensions)
              _ModuleExtension(extension, module),
        ]..sort((left, right) {
          final length = right.extension.length.compareTo(
            left.extension.length,
          );
          if (length != 0) {
            return length;
          }
          return left.extension.compareTo(right.extension);
        });
  }

  late final List<ImportModuleManifest> _modules;
  late final Map<String, ImportModuleManifest> _byId;
  late final Map<String, ImportModuleManifest> _byLegacyFormatKey;
  late final List<_ModuleExtension> _extensions;

  List<ImportModuleManifest> get modules => _modules;

  ImportModuleManifest forId(String id) {
    final module = _byId[id];
    if (module == null) {
      throw StateError('Unknown import module `$id`.');
    }
    return module;
  }

  ImportModuleManifest? maybeForId(String id) => _byId[id];

  ImportModuleManifest forLegacyFormatKey(String key) {
    final module = _byLegacyFormatKey[key];
    if (module == null) {
      throw StateError('Unknown import format key `$key`.');
    }
    return module;
  }

  ImportModuleManifest? maybeForLegacyFormatKey(String key) {
    return _byLegacyFormatKey[key];
  }

  List<ImportModuleManifest> byFamily(ImportModuleFamily family) {
    return _modules
        .where((module) => module.family == family)
        .toList(growable: false);
  }

  List<ImportModuleManifest> byStatus(ImportModuleStatus status) {
    return _modules
        .where((module) => module.status == status)
        .toList(growable: false);
  }

  ImportModuleManifest? forExtension(String extension) {
    final normalized = extension.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    for (final entry in _extensions) {
      if (entry.extension == normalized) {
        return entry.module;
      }
    }
    return null;
  }

  ImportModuleManifest? detectByPath(String path) {
    final normalized = path.toLowerCase();
    for (final entry in _extensions) {
      if (normalized.endsWith(entry.extension)) {
        return entry.module;
      }
    }
    return null;
  }

  List<String> implementedExtensions() {
    final result = <String>{};
    for (final module in _modules) {
      if (module.isImplemented) {
        result.addAll(module.detection.extensions);
      }
    }
    return result.toList()..sort();
  }

  static int _compareModules(
    ImportModuleManifest left,
    ImportModuleManifest right,
  ) {
    final priority = _priorityOrder(
      left.priority,
    ).compareTo(_priorityOrder(right.priority));
    if (priority != 0) {
      return priority;
    }
    final family = left.family.name.compareTo(right.family.name);
    if (family != 0) {
      return family;
    }
    return left.name.compareTo(right.name);
  }

  static int _priorityOrder(ImportModulePriority priority) {
    return switch (priority) {
      ImportModulePriority.p0 => 0,
      ImportModulePriority.p1 => 1,
      ImportModulePriority.p2 => 2,
      ImportModulePriority.p3 => 3,
      ImportModulePriority.p4 => 4,
      ImportModulePriority.none => 5,
    };
  }
}

class _ModuleExtension {
  const _ModuleExtension(this.extension, this.module);

  final String extension;
  final ImportModuleManifest module;
}
