import 'package:decent_bench/features/workspace/domain/sql_risk_assessment.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifies read-only statements as safe', () {
    final assessment = assessSqlRisk('/* comment */\nSELECT * FROM tasks');

    expect(assessment.level, SqlRiskLevel.readOnly);
    expect(assessment.requiresConfirmation, isFalse);
  });

  test(
    'classifies mutating and destructive statements for safe-run prompts',
    () {
      final update = assessSqlRisk('UPDATE tasks SET title = \$1');
      final drop = assessSqlRisk('DROP TABLE tasks');

      expect(update.level, SqlRiskLevel.mutating);
      expect(update.requiresConfirmation, isTrue);
      expect(drop.level, SqlRiskLevel.destructive);
      expect(drop.requiresConfirmation, isTrue);
    },
  );

  test(
    'uses query contract non-read-only metadata when keyword is ambiguous',
    () {
      final contract = QueryContract(
        contractVersion: 1,
        sql: 'WITH changed AS (...) SELECT 1',
        statementKind: 'unknown',
        readOnly: false,
        schemaCookie: 1,
        tempSchemaCookie: 0,
        schemaFingerprint: 'fingerprint',
        parameters: const <QueryParameterContract>[],
        resultColumns: const <QueryResultColumnContract>[],
        diagnostics: const <String>[],
      );

      final assessment = assessSqlRisk(
        'CALL user_defined_mutator()',
        contract: contract,
      );

      expect(assessment.level, SqlRiskLevel.mutating);
      expect(assessment.requiresConfirmation, isTrue);
    },
  );
}
