enum ImportModuleKind { source, wrapper, directOpen, template, profile }

enum ImportModuleStatus {
  complete,
  partial,
  planned,
  investigate,
  deferred,
  candidate,
  notStarted,
}

enum ImportModulePriority { p0, p1, p2, p3, p4, none }

enum ImportModuleFamily {
  decentdb,
  delimitedText,
  spreadsheet,
  structuredDocument,
  database,
  databaseDump,
  analytical,
  legacyBusiness,
  webMarkup,
  compressedArchive,
  logsEvents,
  geospatial,
  dataScience,
  finance,
  healthcare,
  calendarContacts,
  dataLake,
  other,
}

enum ImportModuleImplementation {
  directOpen,
  genericWizard,
  dedicatedWizard,
  wrapper,
  recognizedUnsupported,
  workerBacked,
  unknown,
}

enum ImportModuleAdapterKind {
  none,
  dartBuiltin,
  dartGeneric,
  legacyWizard,
  worker,
  wrapper,
}

enum ImportModuleOptionType {
  boolean,
  integer,
  string,
  enumeration,
  stringList,
}

enum ImportModuleTypeFidelity {
  exact,
  losslessWithMetadata,
  losslessWithTimezoneNote,
  coerced,
  stringified,
  unsupported,
}

class ImportModuleManifest {
  const ImportModuleManifest({
    required this.schemaVersion,
    required this.id,
    required this.kind,
    required this.status,
    required this.priority,
    required this.name,
    required this.family,
    required this.summary,
    required this.description,
    this.note,
    required this.detection,
    required this.support,
    required this.capabilities,
    required this.adapter,
    required this.actions,
    this.options = const <ImportModuleOption>[],
    this.typeMappings = const <ImportModuleTypeMapping>[],
    this.checks = const <ImportModuleCheck>[],
    this.limitations = const <ImportModuleLimitation>[],
    required this.documentation,
    this.fixtures = const <ImportModuleFixture>[],
    required this.legacyFormatKey,
  });

  final int schemaVersion;
  final String id;
  final ImportModuleKind kind;
  final ImportModuleStatus status;
  final ImportModulePriority priority;
  final String name;
  final ImportModuleFamily family;
  final String summary;
  final String description;
  final String? note;
  final ImportModuleDetection detection;
  final ImportModuleSupport support;
  final ImportModuleCapabilities capabilities;
  final ImportModuleAdapterRef adapter;
  final List<ImportModuleAction> actions;
  final List<ImportModuleOption> options;
  final List<ImportModuleTypeMapping> typeMappings;
  final List<ImportModuleCheck> checks;
  final List<ImportModuleLimitation> limitations;
  final ImportModuleDocumentation documentation;
  final List<ImportModuleFixture> fixtures;
  final String legacyFormatKey;

  bool get isImplemented =>
      support.implementation == ImportModuleImplementation.directOpen ||
      support.implementation == ImportModuleImplementation.genericWizard ||
      support.implementation == ImportModuleImplementation.dedicatedWizard ||
      support.implementation == ImportModuleImplementation.wrapper;

  bool get isUnavailable =>
      support.implementation ==
          ImportModuleImplementation.recognizedUnsupported ||
      support.implementation == ImportModuleImplementation.unknown ||
      adapter.kind == ImportModuleAdapterKind.none;
}

class ImportModuleDetection {
  const ImportModuleDetection({
    this.extensions = const <String>[],
    this.mimeTypes = const <String>[],
    this.filenamePatterns = const <String>[],
    this.magicNumbers = const <String>[],
    this.priority = 0,
  });

  final List<String> extensions;
  final List<String> mimeTypes;
  final List<String> filenamePatterns;
  final List<String> magicNumbers;
  final int priority;
}

class ImportModuleSupport {
  const ImportModuleSupport({
    required this.implementation,
    this.availability = 'builtin',
    this.minAppVersion = '0.0.0',
    this.requiresDependencyReview = false,
    this.requiresAdr = false,
  });

  final ImportModuleImplementation implementation;
  final String availability;
  final String minAppVersion;
  final bool requiresDependencyReview;
  final bool requiresAdr;
}

class ImportModuleCapabilities {
  const ImportModuleCapabilities({
    this.detectByExtension = true,
    this.detectBySignature = false,
    this.inspectSchema = false,
    this.previewRows = false,
    this.importFull = false,
    this.importSelectedTables = false,
    this.supportsMultipleTables = false,
    this.supportsArchives = false,
    this.supportsStreamingPreview = false,
    this.supportsStreamingImport = false,
    this.supportsCancellation = false,
    this.supportsRejectedRows = false,
    this.preservesLogicalTypes = false,
    this.preservesConstraints = false,
    this.preservesIndexes = false,
    this.preservesRelationships = false,
    this.canExportRecipe = false,
  });

  final bool detectByExtension;
  final bool detectBySignature;
  final bool inspectSchema;
  final bool previewRows;
  final bool importFull;
  final bool importSelectedTables;
  final bool supportsMultipleTables;
  final bool supportsArchives;
  final bool supportsStreamingPreview;
  final bool supportsStreamingImport;
  final bool supportsCancellation;
  final bool supportsRejectedRows;
  final bool preservesLogicalTypes;
  final bool preservesConstraints;
  final bool preservesIndexes;
  final bool preservesRelationships;
  final bool canExportRecipe;
}

class ImportModuleAdapterRef {
  const ImportModuleAdapterRef({
    required this.id,
    required this.kind,
    required this.protocol,
    this.entrypoint,
  });

  final String id;
  final ImportModuleAdapterKind kind;
  final String protocol;
  final String? entrypoint;
}

class ImportModuleAction {
  const ImportModuleAction({
    required this.id,
    required this.label,
    this.required = false,
  });

  final String id;
  final String label;
  final bool required;
}

class ImportModuleOption {
  const ImportModuleOption({
    required this.id,
    required this.label,
    required this.type,
    this.required = false,
    this.defaultValue,
    this.allowedValues = const <String>[],
  });

  final String id;
  final String label;
  final ImportModuleOptionType type;
  final bool required;
  final Object? defaultValue;
  final List<String> allowedValues;
}

class ImportModuleTypeMapping {
  const ImportModuleTypeMapping({
    required this.sourceType,
    required this.targetType,
    required this.fidelity,
    required this.notes,
  });

  final String sourceType;
  final String targetType;
  final ImportModuleTypeFidelity fidelity;
  final String notes;
}

class ImportModuleCheck {
  const ImportModuleCheck({
    required this.id,
    required this.name,
    required this.description,
    this.defaultEnabled = false,
    this.severity = 'warning',
    this.qualityProfile,
  });

  final String id;
  final String name;
  final String description;
  final bool defaultEnabled;
  final String severity;
  final String? qualityProfile;
}

class ImportModuleLimitation {
  const ImportModuleLimitation({
    required this.id,
    required this.severity,
    required this.message,
  });

  final String id;
  final String severity;
  final String message;
}

class ImportModuleDocumentation {
  const ImportModuleDocumentation({
    required this.helpTopic,
    required this.formatDocs,
    required this.fixtureNotes,
  });

  final String helpTopic;
  final String formatDocs;
  final String fixtureNotes;
}

class ImportModuleFixture {
  const ImportModuleFixture({
    required this.id,
    required this.path,
    required this.purpose,
    this.expectedTables = const <String>[],
    this.expectedWarnings = const <String>[],
    this.generated = false,
  });

  final String id;
  final String path;
  final String purpose;
  final List<String> expectedTables;
  final List<String> expectedWarnings;
  final bool generated;
}
