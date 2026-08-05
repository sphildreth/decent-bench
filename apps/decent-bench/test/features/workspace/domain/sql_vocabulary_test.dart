import 'package:decent_bench/features/workspace/domain/app_config.dart';
import 'package:decent_bench/features/workspace/domain/sql_autocomplete.dart';
import 'package:decent_bench/features/workspace/domain/sql_vocabulary.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fulltext and ALTER INDEX maintenance keywords are recognized', () {
    expect(decentDbSqlKeywords, containsAll(<String>[
      'FULLTEXT',
      'BM25',
      'REBUILD',
      'VERIFY',
      'INDEXED',
    ]));
  });

  test('fulltext and rank functions are recognized', () {
    expect(decentDbSqlFunctions, containsAll(<String>[
      'FULLTEXT_MATCH',
      'BM25',
      'BM25_SCORE',
      'FULLTEXT_RANK',
    ]));
  });

  test('formatter recognizes USING fulltext / spatial / trigram / btree', () {
    expect(formatterClauseKeywords, containsAll(<String>[
      'USING FULLTEXT',
      'USING BTREE',
      'USING SPATIAL',
      'USING TRIGRAM',
      'ALTER INDEX',
    ]));
  });

  test('FULLTEXT appears in keyword autocomplete suggestions', () {
    final result = const SqlAutocompleteEngine().suggest(
      sql: 'SELECT * FROM docs WHERE FULLT',
      cursorOffset: 'SELECT * FROM docs WHERE FULLT'.length,
      schema: SchemaSnapshot.empty(),
      config: AppConfig.defaults(),
    );
    expect(
      result.suggestions.map((item) => item.label),
      contains('FULLTEXT'),
    );
  });
}