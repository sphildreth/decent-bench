import 'package:decent_bench/features/import/domain/import_models.dart';
import 'package:decent_bench/features/import/infrastructure/import_format_registry.dart';

import '../domain/import_module_manifest.dart';

GenericImportOptions defaultGenericImportOptionsForModule(
  ImportFormatKey key, {
  ImportFormatRegistry? registry,
}) {
  final module = (registry ?? ImportFormatRegistry.instance).moduleForKey(key);
  var options = const GenericImportOptions();
  for (final option in module.options) {
    options = _applyOptionDefault(options, option);
  }
  return options;
}

GenericImportOptions _applyOptionDefault(
  GenericImportOptions options,
  ImportModuleOption option,
) {
  return switch (option.id) {
    'header_row' => options.copyWith(
      headerRow: option.defaultValue as bool? ?? options.headerRow,
    ),
    'delimiter' => options.copyWith(
      delimiter: option.defaultValue as String? ?? options.delimiter,
    ),
    'quote_character' => options.copyWith(
      quoteCharacter: option.defaultValue as String? ?? options.quoteCharacter,
    ),
    'escape_character' => options.copyWith(
      escapeCharacter:
          option.defaultValue as String? ?? options.escapeCharacter,
    ),
    'encoding' => options.copyWith(
      encoding: _encoding(option.defaultValue as String?),
    ),
    'malformed_row_strategy' => options.copyWith(
      malformedRowStrategy: _malformedStrategy(option.defaultValue as String?),
    ),
    'structured_strategy' => options.copyWith(
      structuredStrategy: _structuredStrategy(option.defaultValue as String?),
    ),
    'preserve_html_metadata' => options.copyWith(
      preserveHtmlMetadata:
          option.defaultValue as bool? ?? options.preserveHtmlMetadata,
    ),
    _ => options,
  };
}

GenericImportEncoding _encoding(String? value) {
  return switch (value) {
    'utf8' => GenericImportEncoding.utf8,
    'latin1' => GenericImportEncoding.latin1,
    _ => GenericImportEncoding.auto,
  };
}

DelimitedMalformedRowStrategy _malformedStrategy(String? value) {
  return switch (value) {
    'skipRow' => DelimitedMalformedRowStrategy.skipRow,
    _ => DelimitedMalformedRowStrategy.padOrTruncate,
  };
}

StructuredImportStrategy _structuredStrategy(String? value) {
  return switch (value) {
    'normalize' => StructuredImportStrategy.normalize,
    _ => StructuredImportStrategy.flatten,
  };
}
