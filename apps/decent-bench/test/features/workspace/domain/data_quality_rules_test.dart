import 'package:decent_bench/features/workspace/domain/data_quality_models.dart';
import 'package:decent_bench/features/workspace/domain/data_quality_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';

void main() {
  test('default profile builder creates schema-derived checks', () {
    final schema = FakeWorkspaceGateway().snapshot;

    final profile = const DefaultQualityProfileBuilder().build(
      schema: schema,
      now: DateTime.utc(2026, 5, 22),
    );

    expect(profile.name, 'Default Import Quality');
    expect(
      profile.rules.map((rule) => rule.ruleType),
      containsAll(<ValidationRuleType>[
        ValidationRuleType.required,
        ValidationRuleType.unique,
      ]),
    );
    expect(profile.validate(), isEmpty);
  });

  test(
    'validation rule parameter contract accepts every supported rule type',
    () {
      for (final rule in _validRulesByType().values) {
        expect(
          rule.validate(),
          isEmpty,
          reason:
              '${rule.ruleType.wireName} should accept its required params.',
        );
      }
    },
  );

  test('validation rule parameter contract rejects invalid rule params', () {
    final invalidCases = <ValidationRule>[
      _validRulesByType()[ValidationRuleType.required]!.copyWith(
        targetColumn: null,
      ),
      _validRulesByType()[ValidationRuleType.allowedValues]!.copyWith(
        params: const <String, Object?>{'values': <String>[]},
      ),
      _validRulesByType()[ValidationRuleType.regex]!.copyWith(
        params: const <String, Object?>{'pattern': ''},
      ),
      _validRulesByType()[ValidationRuleType.numericRange]!.copyWith(
        params: const <String, Object?>{'min': 'zero'},
      ),
      _validRulesByType()[ValidationRuleType.dateRange]!.copyWith(
        params: const <String, Object?>{'min': 'not-a-date'},
      ),
      _validRulesByType()[ValidationRuleType.stringLength]!.copyWith(
        params: const <String, Object?>{'min_length': '1'},
      ),
      _validRulesByType()[ValidationRuleType.crossColumn]!.copyWith(
        params: const <String, Object?>{
          'sql_expression': 'DROP TABLE tasks',
          'referenced_columns': <String>['title'],
        },
      ),
      _validRulesByType()[ValidationRuleType.referential]!.copyWith(
        params: const <String, Object?>{
          'source_columns': <String>['project_id'],
          'reference_table': 'projects',
          'reference_columns': <String>['id', 'tenant_id'],
        },
      ),
      _validRulesByType()[ValidationRuleType.customSqlPredicate]!.copyWith(
        params: const <String, Object?>{
          'predicate_sql': 'title IS NOT NULL; DELETE FROM tasks',
          'referenced_columns': <String>['title'],
        },
      ),
      _validRulesByType()[ValidationRuleType.exactDuplicateRows]!.copyWith(
        params: const <String, Object?>{'columns': <String>[]},
      ),
      _validRulesByType()[ValidationRuleType.nearDuplicateRows]!.copyWith(
        params: const <String, Object?>{
          'columns': <String>['title'],
          'threshold': 1.1,
          'candidate_limit': 0,
        },
      ),
    ];

    for (final rule in invalidCases) {
      expect(
        rule.validate(),
        isNotEmpty,
        reason: '${rule.ruleType.wireName} should reject invalid params.',
      );
    }
  });
}

Map<ValidationRuleType, ValidationRule> _validRulesByType() {
  return <ValidationRuleType, ValidationRule>{
    ValidationRuleType.required: _rule(
      ValidationRuleType.required,
      targetColumn: 'title',
      params: const <String, Object?>{
        'trim_strings': true,
        'treat_empty_string_as_null': true,
      },
    ),
    ValidationRuleType.unique: _rule(
      ValidationRuleType.unique,
      targetColumn: 'id',
      params: const <String, Object?>{
        'columns': <String>['id'],
        'ignore_nulls': true,
        'trim_strings': false,
      },
    ),
    ValidationRuleType.allowedValues: _rule(
      ValidationRuleType.allowedValues,
      targetColumn: 'status',
      params: const <String, Object?>{
        'values': <String>['open', 'closed'],
        'case_sensitive': false,
        'trim_strings': true,
        'allow_null': true,
      },
    ),
    ValidationRuleType.regex: _rule(
      ValidationRuleType.regex,
      targetColumn: 'title',
      params: const <String, Object?>{
        'pattern': r'^[A-Z]+$',
        'case_sensitive': true,
        'allow_null': false,
      },
    ),
    ValidationRuleType.numericRange: _rule(
      ValidationRuleType.numericRange,
      targetColumn: 'id',
      params: const <String, Object?>{
        'min': 1,
        'max': 100,
        'inclusive_min': true,
        'inclusive_max': true,
        'allow_null': true,
      },
    ),
    ValidationRuleType.dateRange: _rule(
      ValidationRuleType.dateRange,
      targetColumn: 'created_at',
      params: const <String, Object?>{
        'min': '2026-01-01',
        'max': '2026-12-31T23:59:59Z',
        'inclusive_min': true,
        'inclusive_max': true,
        'allow_null': true,
      },
    ),
    ValidationRuleType.stringLength: _rule(
      ValidationRuleType.stringLength,
      targetColumn: 'title',
      params: const <String, Object?>{
        'min_length': 1,
        'max_length': 120,
        'trim_strings': true,
        'allow_null': true,
      },
    ),
    ValidationRuleType.crossColumn: _rule(
      ValidationRuleType.crossColumn,
      params: const <String, Object?>{
        'sql_expression': '"updated_at" >= "created_at"',
        'referenced_columns': <String>['created_at', 'updated_at'],
      },
    ),
    ValidationRuleType.referential: _rule(
      ValidationRuleType.referential,
      targetColumn: 'project_id',
      params: const <String, Object?>{
        'source_columns': <String>['project_id'],
        'reference_table': 'projects',
        'reference_columns': <String>['id'],
        'ignore_nulls': true,
      },
    ),
    ValidationRuleType.customSqlPredicate: _rule(
      ValidationRuleType.customSqlPredicate,
      params: const <String, Object?>{
        'predicate_sql': 'LENGTH("title") > 0',
        'referenced_columns': <String>['title'],
      },
    ),
    ValidationRuleType.exactDuplicateRows: _rule(
      ValidationRuleType.exactDuplicateRows,
      params: const <String, Object?>{
        'columns': <String>['title'],
        'ignore_nulls': true,
        'trim_strings': true,
      },
    ),
    ValidationRuleType.nearDuplicateRows: _rule(
      ValidationRuleType.nearDuplicateRows,
      params: const <String, Object?>{
        'columns': <String>['title'],
        'similarity': 'normalized_levenshtein',
        'threshold': 0.7,
        'candidate_limit': 100,
        'blocking_columns': <String>['title'],
        'trim_strings': true,
        'case_sensitive': false,
      },
    ),
  };
}

ValidationRule _rule(
  ValidationRuleType type, {
  String? targetColumn,
  Map<String, Object?> params = const <String, Object?>{},
}) {
  return ValidationRule(
    id: '${type.wireName}-rule',
    name: '${type.wireName} rule',
    description: '',
    enabled: true,
    severity: QualitySeverity.error,
    targetTable: 'tasks',
    targetColumn: targetColumn,
    ruleType: type,
    params: params,
  );
}
