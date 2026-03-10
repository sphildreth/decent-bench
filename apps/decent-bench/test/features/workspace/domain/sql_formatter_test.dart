import 'package:decent_bench/features/workspace/domain/app_config.dart';
import 'package:decent_bench/features/workspace/domain/sql_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const formatter = SqlFormatter();

  test('formats keywords deterministically and preserves string literals', () {
    final formatted = formatter.format(
      "select id, title from tasks where title = 'from here' and id = 1",
      settings: EditorSettings.defaults(),
    );

    expect(formatted, contains('SELECT id, title'));
    expect(formatted, contains('\nFROM tasks'));
    expect(formatted, contains("\nWHERE title = 'from here'"));
    expect(formatted, contains('\n  AND id = 1'));
  });

  test('preserves comments while reflowing clauses', () {
    final formatted = formatter.format(
      'select 1 -- keep comment\nfrom tasks where id = 1',
      settings: EditorSettings.defaults(),
    );

    expect(formatted, contains('-- keep comment'));
    expect(formatted, contains('\nFROM tasks'));
    expect(formatted, contains('\nWHERE id = 1'));
  });
}
