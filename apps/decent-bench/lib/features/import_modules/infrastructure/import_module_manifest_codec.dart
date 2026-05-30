import '../domain/import_module_manifest.dart';
import 'import_module_manifest_parser.dart';

const _rootKeys = <String>{
  'schema_version',
  'id',
  'kind',
  'status',
  'priority',
  'legacy_format_key',
  'name',
  'family',
  'summary',
  'description',
  'note',
  'detection',
  'support',
  'capabilities',
  'adapter',
  'actions',
  'options',
  'type_mappings',
  'checks',
  'limitations',
  'documentation',
  'fixtures',
};

const _detectionKeys = <String>{
  'extensions',
  'mime_types',
  'filename_patterns',
  'magic_numbers',
  'priority',
};

const _supportKeys = <String>{
  'implementation',
  'availability',
  'min_app_version',
  'requires_dependency_review',
  'requires_adr',
};

const _capabilityKeys = <String>{
  'detect_by_extension',
  'detect_by_signature',
  'inspect_schema',
  'preview_rows',
  'import_full',
  'import_selected_tables',
  'supports_multiple_tables',
  'supports_archives',
  'supports_streaming_preview',
  'supports_streaming_import',
  'supports_cancellation',
  'supports_rejected_rows',
  'preserves_logical_types',
  'preserves_constraints',
  'preserves_indexes',
  'preserves_relationships',
  'can_export_recipe',
};

const _adapterKeys = <String>{'id', 'kind', 'protocol', 'entrypoint'};

const _actionKeys = <String>{'id', 'label', 'required'};

const _optionKeys = <String>{
  'id',
  'label',
  'type',
  'default',
  'required',
  'allowed_values',
};

const _typeMappingKeys = <String>{
  'source_type',
  'target_type',
  'fidelity',
  'notes',
};

const _checkKeys = <String>{
  'id',
  'name',
  'description',
  'default_enabled',
  'severity',
  'quality_profile',
};

const _limitationKeys = <String>{'id', 'severity', 'message'};

const _documentationKeys = <String>{
  'help_topic',
  'format_docs',
  'fixture_notes',
};

const _fixtureKeys = <String>{
  'id',
  'path',
  'purpose',
  'expected_tables',
  'expected_warnings',
  'generated',
};

class ImportModuleManifestCodec {
  const ImportModuleManifestCodec();

  ImportModuleManifest parse(String source) {
    final map = const ImportModuleManifestParser().parse(source);
    return fromMap(map);
  }

  ImportModuleManifest fromMap(Map<String, Object?> map) {
    _assertAllowedKeys(map, 'manifest root', _rootKeys);

    final detection = _section(map, 'detection');
    final support = _section(map, 'support');
    final capabilities = _section(map, 'capabilities');
    final adapter = _section(map, 'adapter');
    final documentation = _section(map, 'documentation');
    _assertAllowedKeys(detection, '[detection]', _detectionKeys);
    _assertAllowedKeys(support, '[support]', _supportKeys);
    _assertAllowedKeys(capabilities, '[capabilities]', _capabilityKeys);
    _assertAllowedKeys(adapter, '[adapter]', _adapterKeys);
    _assertAllowedKeys(documentation, '[documentation]', _documentationKeys);

    return ImportModuleManifest(
      schemaVersion: _int(map, 'schema_version'),
      id: _string(map, 'id'),
      kind: _enumValue(
        ImportModuleKind.values,
        _string(map, 'kind'),
        _moduleKindName,
      ),
      status: _enumValue(
        ImportModuleStatus.values,
        _string(map, 'status'),
        _moduleStatusName,
      ),
      priority: _enumValue(
        ImportModulePriority.values,
        _string(map, 'priority'),
        _modulePriorityName,
      ),
      legacyFormatKey: _string(map, 'legacy_format_key'),
      name: _string(map, 'name'),
      family: _enumValue(
        ImportModuleFamily.values,
        _string(map, 'family'),
        _moduleFamilyName,
      ),
      summary: _string(map, 'summary'),
      description: _string(map, 'description'),
      note: _optionalString(map, 'note'),
      detection: ImportModuleDetection(
        extensions: _stringList(detection, 'extensions'),
        mimeTypes: _stringList(detection, 'mime_types'),
        filenamePatterns: _stringList(detection, 'filename_patterns'),
        magicNumbers: _stringList(detection, 'magic_numbers'),
        priority: _optionalInt(detection, 'priority') ?? 0,
      ),
      support: ImportModuleSupport(
        implementation: _enumValue(
          ImportModuleImplementation.values,
          _string(support, 'implementation'),
          _moduleImplementationName,
        ),
        availability: _optionalString(support, 'availability') ?? 'builtin',
        minAppVersion: _optionalString(support, 'min_app_version') ?? '0.0.0',
        requiresDependencyReview:
            _optionalBool(support, 'requires_dependency_review') ?? false,
        requiresAdr: _optionalBool(support, 'requires_adr') ?? false,
      ),
      capabilities: ImportModuleCapabilities(
        detectByExtension:
            _optionalBool(capabilities, 'detect_by_extension') ?? true,
        detectBySignature:
            _optionalBool(capabilities, 'detect_by_signature') ?? false,
        inspectSchema: _optionalBool(capabilities, 'inspect_schema') ?? false,
        previewRows: _optionalBool(capabilities, 'preview_rows') ?? false,
        importFull: _optionalBool(capabilities, 'import_full') ?? false,
        importSelectedTables:
            _optionalBool(capabilities, 'import_selected_tables') ?? false,
        supportsMultipleTables:
            _optionalBool(capabilities, 'supports_multiple_tables') ?? false,
        supportsArchives:
            _optionalBool(capabilities, 'supports_archives') ?? false,
        supportsStreamingPreview:
            _optionalBool(capabilities, 'supports_streaming_preview') ?? false,
        supportsStreamingImport:
            _optionalBool(capabilities, 'supports_streaming_import') ?? false,
        supportsCancellation:
            _optionalBool(capabilities, 'supports_cancellation') ?? false,
        supportsRejectedRows:
            _optionalBool(capabilities, 'supports_rejected_rows') ?? false,
        preservesLogicalTypes:
            _optionalBool(capabilities, 'preserves_logical_types') ?? false,
        preservesConstraints:
            _optionalBool(capabilities, 'preserves_constraints') ?? false,
        preservesIndexes:
            _optionalBool(capabilities, 'preserves_indexes') ?? false,
        preservesRelationships:
            _optionalBool(capabilities, 'preserves_relationships') ?? false,
        canExportRecipe:
            _optionalBool(capabilities, 'can_export_recipe') ?? false,
      ),
      adapter: ImportModuleAdapterRef(
        id: _string(adapter, 'id'),
        kind: _enumValue(
          ImportModuleAdapterKind.values,
          _string(adapter, 'kind'),
          _moduleAdapterKindName,
        ),
        protocol: _string(adapter, 'protocol'),
        entrypoint: _optionalString(adapter, 'entrypoint'),
      ),
      actions: _tableArray(map, 'actions', allowedKeys: _actionKeys)
          .map(
            (entry) => ImportModuleAction(
              id: _string(entry, 'id'),
              label: _string(entry, 'label'),
              required: _optionalBool(entry, 'required') ?? false,
            ),
          )
          .toList(growable: false),
      options: _tableArray(map, 'options', allowedKeys: _optionKeys)
          .map(
            (entry) => ImportModuleOption(
              id: _string(entry, 'id'),
              label: _string(entry, 'label'),
              type: _enumValue(
                ImportModuleOptionType.values,
                _string(entry, 'type'),
                _moduleOptionTypeName,
              ),
              required: _optionalBool(entry, 'required') ?? false,
              defaultValue: entry['default'],
              allowedValues: _stringList(entry, 'allowed_values'),
            ),
          )
          .toList(growable: false),
      typeMappings:
          _tableArray(map, 'type_mappings', allowedKeys: _typeMappingKeys)
              .map(
                (entry) => ImportModuleTypeMapping(
                  sourceType: _string(entry, 'source_type'),
                  targetType: _string(entry, 'target_type'),
                  fidelity: _enumValue(
                    ImportModuleTypeFidelity.values,
                    _string(entry, 'fidelity'),
                    _moduleTypeFidelityName,
                  ),
                  notes: _string(entry, 'notes'),
                ),
              )
              .toList(growable: false),
      checks: _tableArray(map, 'checks', allowedKeys: _checkKeys)
          .map(
            (entry) => ImportModuleCheck(
              id: _string(entry, 'id'),
              name: _string(entry, 'name'),
              description: _string(entry, 'description'),
              defaultEnabled: _optionalBool(entry, 'default_enabled') ?? false,
              severity: _optionalString(entry, 'severity') ?? 'warning',
              qualityProfile: _optionalString(entry, 'quality_profile'),
            ),
          )
          .toList(growable: false),
      limitations: _tableArray(map, 'limitations', allowedKeys: _limitationKeys)
          .map(
            (entry) => ImportModuleLimitation(
              id: _string(entry, 'id'),
              severity: _string(entry, 'severity'),
              message: _string(entry, 'message'),
            ),
          )
          .toList(growable: false),
      documentation: ImportModuleDocumentation(
        helpTopic: _string(documentation, 'help_topic'),
        formatDocs: _string(documentation, 'format_docs'),
        fixtureNotes: _string(documentation, 'fixture_notes'),
      ),
      fixtures: _tableArray(map, 'fixtures', allowedKeys: _fixtureKeys)
          .map(
            (entry) => ImportModuleFixture(
              id: _string(entry, 'id'),
              path: _string(entry, 'path'),
              purpose: _string(entry, 'purpose'),
              expectedTables: _stringList(entry, 'expected_tables'),
              expectedWarnings: _stringList(entry, 'expected_warnings'),
              generated: _optionalBool(entry, 'generated') ?? false,
            ),
          )
          .toList(growable: false),
    );
  }

  Map<String, Object?> _section(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is Map<String, Object?>) {
      return value;
    }
    throw ImportModuleManifestException('Missing section `[$key]`.');
  }

  List<Map<String, Object?>> _tableArray(
    Map<String, Object?> map,
    String key, {
    required Set<String> allowedKeys,
  }) {
    final value = map[key];
    if (value == null) {
      return const <Map<String, Object?>>[];
    }
    if (value is List<Map<String, Object?>>) {
      for (final entry in value) {
        _assertAllowedKeys(entry, '[[$key]]', allowedKeys);
      }
      return value;
    }
    throw ImportModuleManifestException('Expected `[[$key]]` table array.');
  }

  void _assertAllowedKeys(
    Map<String, Object?> map,
    String label,
    Set<String> allowedKeys,
  ) {
    final unknownKeys =
        map.keys
            .where((key) => !allowedKeys.contains(key))
            .toList(growable: false)
          ..sort();
    if (unknownKeys.isEmpty) {
      return;
    }
    throw ImportModuleManifestException(
      'Unknown $label key(s): ${unknownKeys.join(', ')}.',
    );
  }

  T _enumValue<T extends Enum>(
    List<T> values,
    String value,
    String Function(T value) encode,
  ) {
    for (final enumValue in values) {
      if (encode(enumValue) == value) {
        return enumValue;
      }
    }
    throw ImportModuleManifestException('Unknown enum value `$value`.');
  }

  String _string(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is String) {
      return value;
    }
    throw ImportModuleManifestException('Missing string key `$key`.');
  }

  String? _optionalString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    throw ImportModuleManifestException('Expected string key `$key`.');
  }

  int _int(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is int) {
      return value;
    }
    throw ImportModuleManifestException('Missing integer key `$key`.');
  }

  int? _optionalInt(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    throw ImportModuleManifestException('Expected integer key `$key`.');
  }

  bool? _optionalBool(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    throw ImportModuleManifestException('Expected boolean key `$key`.');
  }

  List<String> _stringList(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) {
      return const <String>[];
    }
    if (value is List<Object?> && value.every((item) => item is String)) {
      return value.cast<String>();
    }
    throw ImportModuleManifestException('Expected string array key `$key`.');
  }
}

String _moduleKindName(ImportModuleKind value) {
  return switch (value) {
    ImportModuleKind.source => 'source',
    ImportModuleKind.wrapper => 'wrapper',
    ImportModuleKind.directOpen => 'direct_open',
    ImportModuleKind.template => 'template',
    ImportModuleKind.profile => 'profile',
  };
}

String _moduleStatusName(ImportModuleStatus value) {
  return switch (value) {
    ImportModuleStatus.complete => 'complete',
    ImportModuleStatus.partial => 'partial',
    ImportModuleStatus.planned => 'planned',
    ImportModuleStatus.investigate => 'investigate',
    ImportModuleStatus.deferred => 'deferred',
    ImportModuleStatus.candidate => 'candidate',
    ImportModuleStatus.notStarted => 'not_started',
  };
}

String _modulePriorityName(ImportModulePriority value) {
  return switch (value) {
    ImportModulePriority.p0 => 'P0',
    ImportModulePriority.p1 => 'P1',
    ImportModulePriority.p2 => 'P2',
    ImportModulePriority.p3 => 'P3',
    ImportModulePriority.p4 => 'P4',
    ImportModulePriority.none => 'none',
  };
}

String _moduleFamilyName(ImportModuleFamily value) {
  return switch (value) {
    ImportModuleFamily.decentdb => 'decentdb',
    ImportModuleFamily.delimitedText => 'delimited_text',
    ImportModuleFamily.spreadsheet => 'spreadsheet',
    ImportModuleFamily.structuredDocument => 'structured_document',
    ImportModuleFamily.database => 'database',
    ImportModuleFamily.databaseDump => 'database_dump',
    ImportModuleFamily.analytical => 'analytical',
    ImportModuleFamily.legacyBusiness => 'legacy_business',
    ImportModuleFamily.webMarkup => 'web_markup',
    ImportModuleFamily.compressedArchive => 'compressed_archive',
    ImportModuleFamily.logsEvents => 'logs_events',
    ImportModuleFamily.geospatial => 'geospatial',
    ImportModuleFamily.dataScience => 'data_science',
    ImportModuleFamily.finance => 'finance',
    ImportModuleFamily.healthcare => 'healthcare',
    ImportModuleFamily.calendarContacts => 'calendar_contacts',
    ImportModuleFamily.dataLake => 'data_lake',
    ImportModuleFamily.other => 'other',
  };
}

String _moduleImplementationName(ImportModuleImplementation value) {
  return switch (value) {
    ImportModuleImplementation.directOpen => 'direct_open',
    ImportModuleImplementation.genericWizard => 'generic_wizard',
    ImportModuleImplementation.dedicatedWizard => 'dedicated_wizard',
    ImportModuleImplementation.wrapper => 'wrapper',
    ImportModuleImplementation.recognizedUnsupported =>
      'recognized_unsupported',
    ImportModuleImplementation.workerBacked => 'worker_backed',
    ImportModuleImplementation.unknown => 'unknown',
  };
}

String _moduleAdapterKindName(ImportModuleAdapterKind value) {
  return switch (value) {
    ImportModuleAdapterKind.none => 'none',
    ImportModuleAdapterKind.dartBuiltin => 'dart_builtin',
    ImportModuleAdapterKind.dartGeneric => 'dart_generic',
    ImportModuleAdapterKind.legacyWizard => 'legacy_wizard',
    ImportModuleAdapterKind.worker => 'worker',
    ImportModuleAdapterKind.wrapper => 'wrapper',
  };
}

String _moduleOptionTypeName(ImportModuleOptionType value) {
  return switch (value) {
    ImportModuleOptionType.boolean => 'boolean',
    ImportModuleOptionType.integer => 'integer',
    ImportModuleOptionType.string => 'string',
    ImportModuleOptionType.enumeration => 'enumeration',
    ImportModuleOptionType.stringList => 'string_list',
  };
}

String _moduleTypeFidelityName(ImportModuleTypeFidelity value) {
  return switch (value) {
    ImportModuleTypeFidelity.exact => 'exact',
    ImportModuleTypeFidelity.losslessWithMetadata => 'lossless_with_metadata',
    ImportModuleTypeFidelity.losslessWithTimezoneNote =>
      'lossless_with_timezone_note',
    ImportModuleTypeFidelity.coerced => 'coerced',
    ImportModuleTypeFidelity.stringified => 'stringified',
    ImportModuleTypeFidelity.unsupported => 'unsupported',
  };
}
