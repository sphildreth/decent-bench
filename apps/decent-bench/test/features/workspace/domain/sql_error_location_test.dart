import 'package:decent_bench/features/workspace/domain/sql_error_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps near-token syntax errors back into the editor buffer', () {
    const bufferText =
        'SELECT id\nFROM tasks;\nBROKEN SELECT *\nFROM projects;';
    final startOffset = bufferText.indexOf('BROKEN');

    final location = resolveQueryErrorLocation(
      message: 'syntax error near BROKEN',
      executedSql: 'BROKEN SELECT *\nFROM projects;',
      bufferText: bufferText,
      bufferStartOffset: startOffset,
    );

    expect(location, isNotNull);
    expect(location!.line, 3);
    expect(location.column, 1);
    expect(location.token, 'BROKEN');
  });

  test('maps line and column diagnostics back into the full buffer', () {
    const bufferText = 'SELECT 1;\n  SELECT 2;\n  BROKEN SELECT 3;';
    final startOffset = bufferText.indexOf('SELECT 2;');

    final location = resolveQueryErrorLocation(
      message: 'syntax error at line 2 column 3',
      executedSql: 'SELECT 2;\n  BROKEN SELECT 3;',
      bufferText: bufferText,
      bufferStartOffset: startOffset,
    );

    expect(location, isNotNull);
    expect(location!.line, 3);
    expect(location.column, 3);
  });
}
