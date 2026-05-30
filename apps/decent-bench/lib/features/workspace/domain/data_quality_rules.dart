import 'data_quality_models.dart';
import 'workspace_models.dart';

class DefaultQualityProfileBuilder {
  const DefaultQualityProfileBuilder();

  QualityProfileDocument build({
    required SchemaSnapshot schema,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final rules = <ValidationRule>[];
    for (final table in schema.tables) {
      for (final column in table.columns) {
        if (column.notNull || column.primaryKey) {
          rules.add(
            ValidationRule(
              id: generateQualityUuid(),
              name: '${table.name}.${column.name} is required',
              description: 'Schema metadata marks this column as non-null.',
              enabled: true,
              severity: QualitySeverity.error,
              targetTable: table.name,
              targetColumn: column.name,
              ruleType: ValidationRuleType.required,
              params: const <String, Object?>{
                'trim_strings': true,
                'treat_empty_string_as_null': true,
              },
            ),
          );
        }
        if (column.primaryKey || column.unique) {
          rules.add(
            ValidationRule(
              id: generateQualityUuid(),
              name: '${table.name}.${column.name} is unique',
              description: 'Schema metadata marks this column as unique.',
              enabled: true,
              severity: QualitySeverity.error,
              targetTable: table.name,
              targetColumn: column.name,
              ruleType: ValidationRuleType.unique,
              params: <String, Object?>{
                'columns': <String>[column.name],
                'ignore_nulls': true,
                'trim_strings': false,
              },
            ),
          );
        }
        if (column.hasForeignKey) {
          rules.add(
            ValidationRule(
              id: generateQualityUuid(),
              name:
                  '${table.name}.${column.name} references ${column.refTable}.${column.refColumn}',
              description:
                  'Schema metadata exposes a foreign-key relationship.',
              enabled: true,
              severity: QualitySeverity.error,
              targetTable: table.name,
              targetColumn: column.name,
              ruleType: ValidationRuleType.referential,
              params: <String, Object?>{
                'source_columns': <String>[column.name],
                'reference_table': column.refTable,
                'reference_columns': <String>[column.refColumn ?? ''],
                'ignore_nulls': true,
              },
            ),
          );
        }
      }
    }
    return QualityProfileDocument(
      configVersion: QualityProfileDocument.currentConfigVersion,
      profileId: generateQualityUuid(),
      name: 'Default Import Quality',
      description:
          'Generated from schema metadata: required, unique, and referential checks.',
      createdAt: timestamp,
      updatedAt: timestamp,
      defaultMode: QualityRunMode.full,
      sampleRowLimit: 10000,
      includeImportReconciliation: true,
      includeDuplicateChecks: true,
      duplicateCandidateLimit: 50000,
      rules: rules,
    );
  }
}

class ValidationRuleMetadata {
  const ValidationRuleMetadata({
    required this.type,
    required this.label,
    required this.description,
    required this.sqlBacked,
    required this.parameterLabels,
  });

  final ValidationRuleType type;
  final String label;
  final String description;
  final bool sqlBacked;
  final Map<String, String> parameterLabels;
}

const validationRuleMetadata = <ValidationRuleMetadata>[
  ValidationRuleMetadata(
    type: ValidationRuleType.required,
    label: 'Required',
    description: 'Fails when a value is null or configured empty string.',
    sqlBacked: true,
    parameterLabels: <String, String>{
      'trim_strings': 'Trim strings',
      'treat_empty_string_as_null': 'Treat empty string as null',
    },
  ),
  ValidationRuleMetadata(
    type: ValidationRuleType.unique,
    label: 'Unique',
    description: 'Fails when one key appears more than once.',
    sqlBacked: true,
    parameterLabels: <String, String>{
      'columns': 'Columns',
      'ignore_nulls': 'Ignore nulls',
      'trim_strings': 'Trim strings',
    },
  ),
  ValidationRuleMetadata(
    type: ValidationRuleType.allowedValues,
    label: 'Allowed values',
    description: 'Fails when a value is outside the configured value set.',
    sqlBacked: true,
    parameterLabels: <String, String>{
      'values': 'Values',
      'case_sensitive': 'Case sensitive',
      'trim_strings': 'Trim strings',
      'allow_null': 'Allow null',
    },
  ),
  ValidationRuleMetadata(
    type: ValidationRuleType.regex,
    label: 'Regex',
    description:
        'Fails when a value does not match a pattern. Runs in a background isolate when SQL regex is unavailable.',
    sqlBacked: false,
    parameterLabels: <String, String>{
      'pattern': 'Pattern',
      'case_sensitive': 'Case sensitive',
      'allow_null': 'Allow null',
    },
  ),
  ValidationRuleMetadata(
    type: ValidationRuleType.numericRange,
    label: 'Numeric range',
    description: 'Fails when a numeric value is outside the configured range.',
    sqlBacked: true,
    parameterLabels: <String, String>{
      'min': 'Minimum',
      'max': 'Maximum',
      'inclusive_min': 'Inclusive minimum',
      'inclusive_max': 'Inclusive maximum',
      'allow_null': 'Allow null',
    },
  ),
  ValidationRuleMetadata(
    type: ValidationRuleType.dateRange,
    label: 'Date range',
    description:
        'Fails when a temporal value is malformed or outside the configured range.',
    sqlBacked: true,
    parameterLabels: <String, String>{
      'min': 'Minimum',
      'max': 'Maximum',
      'inclusive_min': 'Inclusive minimum',
      'inclusive_max': 'Inclusive maximum',
      'allow_null': 'Allow null',
    },
  ),
  ValidationRuleMetadata(
    type: ValidationRuleType.stringLength,
    label: 'String length',
    description: 'Fails when string length is outside configured bounds.',
    sqlBacked: true,
    parameterLabels: <String, String>{
      'min_length': 'Minimum length',
      'max_length': 'Maximum length',
      'trim_strings': 'Trim strings',
      'allow_null': 'Allow null',
    },
  ),
  ValidationRuleMetadata(
    type: ValidationRuleType.crossColumn,
    label: 'Cross-column predicate',
    description: 'Fails when a safe SQL expression evaluates to false or null.',
    sqlBacked: true,
    parameterLabels: <String, String>{
      'sql_expression': 'SQL expression',
      'referenced_columns': 'Referenced columns',
    },
  ),
  ValidationRuleMetadata(
    type: ValidationRuleType.referential,
    label: 'Referential',
    description: 'Fails when a source key has no matching reference row.',
    sqlBacked: true,
    parameterLabels: <String, String>{
      'source_columns': 'Source columns',
      'reference_table': 'Reference table',
      'reference_columns': 'Reference columns',
      'ignore_nulls': 'Ignore nulls',
    },
  ),
  ValidationRuleMetadata(
    type: ValidationRuleType.customSqlPredicate,
    label: 'Custom SQL predicate',
    description: 'Advanced safe SQL predicate rule.',
    sqlBacked: true,
    parameterLabels: <String, String>{
      'predicate_sql': 'Predicate SQL',
      'referenced_columns': 'Referenced columns',
    },
  ),
  ValidationRuleMetadata(
    type: ValidationRuleType.exactDuplicateRows,
    label: 'Exact duplicate rows',
    description: 'Fails when configured columns form duplicate row groups.',
    sqlBacked: true,
    parameterLabels: <String, String>{
      'columns': 'Columns',
      'ignore_nulls': 'Ignore nulls',
      'trim_strings': 'Trim strings',
    },
  ),
  ValidationRuleMetadata(
    type: ValidationRuleType.nearDuplicateRows,
    label: 'Near duplicate rows',
    description:
        'Runs a bounded near-duplicate scan with candidate and blocking limits.',
    sqlBacked: false,
    parameterLabels: <String, String>{
      'columns': 'Columns',
      'similarity': 'Similarity',
      'threshold': 'Threshold',
      'candidate_limit': 'Candidate limit',
      'blocking_columns': 'Blocking columns',
      'trim_strings': 'Trim strings',
      'case_sensitive': 'Case sensitive',
    },
  ),
];

ValidationRuleMetadata metadataForRuleType(ValidationRuleType type) {
  return validationRuleMetadata.firstWhere((item) => item.type == type);
}
