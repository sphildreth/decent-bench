import 'package:decent_bench/features/import/domain/import_models.dart';
import 'package:decent_bench/features/import/infrastructure/import_execution_service.dart';
import 'package:decent_bench/features/import/infrastructure/import_format_registry.dart';
import 'package:decent_bench/features/import/infrastructure/import_preview_service.dart';

import '../domain/import_module_manifest.dart';
import 'import_module_adapter_registry.dart';

class ImportModuleAdapterDispatcher {
  ImportModuleAdapterDispatcher({
    ImportFormatRegistry? formatRegistry,
    ImportModuleAdapterRegistry adapterRegistry =
        ImportModuleAdapterRegistry.builtin,
    ImportPreviewService? previewService,
    ImportExecutionService? executionService,
  }) : _formatRegistry = formatRegistry ?? ImportFormatRegistry.instance,
       _adapterRegistry = adapterRegistry,
       _previewService = previewService ?? ImportPreviewService(),
       _executionService = executionService ?? ImportExecutionService();

  final ImportFormatRegistry _formatRegistry;
  final ImportModuleAdapterRegistry _adapterRegistry;
  final ImportPreviewService _previewService;
  final ImportExecutionService _executionService;

  Future<GenericImportInspection> inspectGeneric({
    required String sourcePath,
    required ImportFormatDefinition format,
    required GenericImportOptions options,
  }) {
    _requireExecutableGenericAdapter(format);
    return _previewService.inspect(
      sourcePath: sourcePath,
      format: format,
      options: options,
    );
  }

  Stream<GenericImportUpdate> executeGeneric({
    required GenericImportRequest request,
  }) {
    _requireExecutableGenericAdapter(_formatRegistry.forKey(request.formatKey));
    return _executionService.execute(request: request);
  }

  ImportModuleAdapterDefinition adapterForFormat(
    ImportFormatDefinition format,
  ) {
    final module = _formatRegistry.moduleForKey(format.key);
    return _adapterRegistry.forId(module.adapter.id);
  }

  void _requireExecutableGenericAdapter(ImportFormatDefinition format) {
    final module = _formatRegistry.moduleForKey(format.key);
    if (module.support.implementation !=
        ImportModuleImplementation.genericWizard) {
      throw StateError(
        'Import module `${module.id}` does not use the generic import adapter.',
      );
    }
    final adapter = _adapterRegistry.forId(module.adapter.id);
    if (!adapter.executable ||
        adapter.kind != ImportModuleAdapterKind.dartGeneric) {
      throw StateError(
        'Import module `${module.id}` does not have an executable generic adapter.',
      );
    }
  }
}
