import 'package:decent_bench/features/import/domain/import_models.dart';

import '../domain/import_module_manifest.dart';

class ImportModuleRegistryAdapter {
  const ImportModuleRegistryAdapter();

  ImportFormatDefinition toFormatDefinition(ImportModuleManifest module) {
    return ImportFormatDefinition(
      key: ImportFormatKey.values.byName(module.legacyFormatKey),
      label: module.name,
      family: toImportFamily(module.family),
      supportState: toImportSupportState(module.status),
      extensions: module.detection.extensions,
      implementationKind: toImportImplementationKind(
        module.support.implementation,
      ),
      description: module.description,
      note: module.note ?? _limitationNote(module),
    );
  }

  ImportFamily toImportFamily(ImportModuleFamily family) {
    return switch (family) {
      ImportModuleFamily.decentdb => ImportFamily.database,
      ImportModuleFamily.delimitedText => ImportFamily.delimitedText,
      ImportModuleFamily.spreadsheet => ImportFamily.spreadsheet,
      ImportModuleFamily.structuredDocument => ImportFamily.structuredDocument,
      ImportModuleFamily.database => ImportFamily.database,
      ImportModuleFamily.databaseDump => ImportFamily.databaseDump,
      ImportModuleFamily.analytical => ImportFamily.analytical,
      ImportModuleFamily.legacyBusiness => ImportFamily.legacyBusiness,
      ImportModuleFamily.webMarkup => ImportFamily.webMarkup,
      ImportModuleFamily.compressedArchive => ImportFamily.compressedArchive,
      ImportModuleFamily.logsEvents => ImportFamily.logsEvents,
      ImportModuleFamily.geospatial => ImportFamily.structuredDocument,
      ImportModuleFamily.dataScience => ImportFamily.analytical,
      ImportModuleFamily.finance => ImportFamily.structuredDocument,
      ImportModuleFamily.healthcare => ImportFamily.structuredDocument,
      ImportModuleFamily.calendarContacts => ImportFamily.structuredDocument,
      ImportModuleFamily.dataLake => ImportFamily.analytical,
      ImportModuleFamily.other => ImportFamily.delimitedText,
    };
  }

  ImportSupportState toImportSupportState(ImportModuleStatus status) {
    return switch (status) {
      ImportModuleStatus.complete => ImportSupportState.complete,
      ImportModuleStatus.partial => ImportSupportState.partial,
      ImportModuleStatus.planned => ImportSupportState.planned,
      ImportModuleStatus.investigate => ImportSupportState.investigate,
      ImportModuleStatus.deferred => ImportSupportState.deferred,
      ImportModuleStatus.candidate => ImportSupportState.notStarted,
      ImportModuleStatus.notStarted => ImportSupportState.notStarted,
    };
  }

  ImportImplementationKind toImportImplementationKind(
    ImportModuleImplementation implementation,
  ) {
    return switch (implementation) {
      ImportModuleImplementation.directOpen =>
        ImportImplementationKind.directOpen,
      ImportModuleImplementation.genericWizard =>
        ImportImplementationKind.genericWizard,
      ImportModuleImplementation.dedicatedWizard =>
        ImportImplementationKind.legacyWizard,
      ImportModuleImplementation.wrapper => ImportImplementationKind.wrapper,
      ImportModuleImplementation.recognizedUnsupported =>
        ImportImplementationKind.recognizedUnsupported,
      ImportModuleImplementation.workerBacked =>
        ImportImplementationKind.genericWizard,
      ImportModuleImplementation.unknown => ImportImplementationKind.unknown,
    };
  }

  String? _limitationNote(ImportModuleManifest module) {
    if (module.limitations.isEmpty) {
      return null;
    }
    return module.limitations.first.message;
  }
}
