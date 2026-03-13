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

  test('reflows create table column definitions across lines', () {
    final formatted = formatter.format(
      'create table "basic_types"("id" INT64, "tinyint_col" INT64, "numeric_col" DECIMAL(18, 6), "uuid_col" UUID);',
      settings: EditorSettings.defaults().copyWith(
        formatUppercaseKeywords: false,
      ),
    );

    expect(
      formatted,
      'create table "basic_types"(\n'
      '"id" INT64,\n'
      '"tinyint_col" INT64,\n'
      '"numeric_col" DECIMAL(18, 6),\n'
      '"uuid_col" UUID);',
    );
  });
}
