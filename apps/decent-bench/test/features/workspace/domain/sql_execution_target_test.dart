import 'package:decent_bench/features/workspace/domain/sql_execution_target.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'resolves the current statement when the caret is in a multi-statement buffer',
    () {
      const text = 'SELECT 1;\nSELECT 2;\nSELECT 3;';
      final value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(
          offset: text.indexOf('SELECT 2;') + 3,
        ),
      );

      final target = resolveSqlExecutionTarget(value);

      expect(target.kind, SqlExecutionTargetKind.statement);
      expect(target.sql, 'SELECT 2;');
      expect(target.startLine, 2);
      expect(target.startColumn, 1);
      expect(target.runLabel, 'Run Statement');
    },
  );

  test('selection takes precedence over current statement targeting', () {
    const text = 'SELECT 1;\nSELECT 2;\nSELECT 3;';
    final start = text.indexOf('SELECT 3;');
    final value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: start, extentOffset: text.length),
    );

    final target = resolveSqlExecutionTarget(value);

    expect(target.kind, SqlExecutionTargetKind.selection);
    expect(target.sql, 'SELECT 3;');
    expect(target.runLabel, 'Run Selection');
  });

  test(
    'selection targets trim surrounding whitespace and keep SQL offsets',
    () {
      const text = 'SELECT 1;\n   SELECT 2;\nSELECT 3;';
      final value = TextEditingValue(
        text: text,
        selection: TextSelection(
          baseOffset: text.indexOf('\n'),
          extentOffset: text.indexOf('\nSELECT 3;'),
        ),
      );

      final target = resolveSqlExecutionTarget(value);

      expect(target.kind, SqlExecutionTargetKind.selection);
      expect(target.sql, 'SELECT 2;');
      expect(target.startLine, 2);
      expect(target.startColumn, 4);
    },
  );

  test('statement parser ignores semicolons inside literals and comments', () {
    const text =
        "SELECT ';' AS sample; -- keep ; here\nSELECT /* ; */ 2 AS value;";
    final value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.lastIndexOf('SELECT')),
    );

    final target = resolveSqlExecutionTarget(value);

    expect(target.kind, SqlExecutionTargetKind.statement);
    expect(target.sql, 'SELECT /* ; */ 2 AS value;');
    expect(target.startLine, 2);
  });

  test('single-statement buffers stay on the full buffer target', () {
    const value = TextEditingValue(
      text: 'SELECT * FROM tasks;',
      selection: TextSelection.collapsed(offset: 7),
    );

    final target = resolveSqlExecutionTarget(value);

    expect(target.kind, SqlExecutionTargetKind.buffer);
    expect(target.sql, 'SELECT * FROM tasks;');
    expect(target.runLabel, 'Run');
  });
}
