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

  test('uppercases phase-1 v2.8 keywords and functions', () {
    final formatted = formatter.format(
      'pragma user_version = 7; select * from generate_series(1, 3) '
      'order by value collate nocase, value collate rtrim, value collate binary',
      settings: EditorSettings.defaults(),
    );

    expect(formatted, contains('PRAGMA user_version = 7'));
    expect(formatted, contains('FROM GENERATE_SERIES(1, 3)'));
    expect(formatted, contains('COLLATE NOCASE'));
    expect(formatted, contains('COLLATE RTRIM'));
    expect(formatted, contains('COLLATE BINARY'));
  });
}
