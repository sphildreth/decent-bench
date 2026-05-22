import '../domain/import_models.dart';
import '../infrastructure/import_detection_service.dart';
import '../infrastructure/import_format_registry.dart';
import '../../import_modules/domain/import_module_manifest.dart';

class ImportManager {
  ImportManager({
    ImportFormatRegistry? registry,
    ImportDetectionService? detectionService,
  }) : registry = registry ?? ImportFormatRegistry.instance,
       detectionService =
           detectionService ?? ImportDetectionService(registry: registry);

  final ImportFormatRegistry registry;
  final ImportDetectionService detectionService;

  Future<ImportDetectionResult> detectSource(String sourcePath) {
    return detectionService.detect(sourcePath);
  }

  ImportModuleManifest moduleForDetection(ImportDetectionResult detection) {
    if (detection.moduleId != null) {
      final module = registry.catalog.maybeForId(detection.moduleId!);
      if (module != null) {
        return module;
      }
    }
    return registry.moduleForKey(detection.format.key);
  }

  Future<String> extractArchiveCandidate({
    required String archivePath,
    required ImportFormatKey wrapperKey,
    required ImportArchiveCandidate candidate,
  }) {
    return detectionService.extractArchiveCandidate(
      archivePath: archivePath,
      wrapperKey: wrapperKey,
      candidate: candidate,
    );
  }
}
