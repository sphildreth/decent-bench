import 'package:decent_bench/features/workspace/domain/help/help_documentation.dart';
import 'package:decent_bench/features/workspace/infrastructure/help/bundled_help_documentation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled help manifest loads every article asset', () async {
    final documentation = await const BundledHelpDocumentationRepository()
        .load();

    expect(documentation.articles.length, greaterThanOrEqualTo(10));
    expect(documentation.article('getting-started'), isNotNull);
    expect(documentation.article('writing-sql'), isNotNull);
    expect(documentation.article('exporting-results'), isNotNull);
    expect(
      documentation.articles.map((article) => article.id).toSet(),
      hasLength(documentation.articles.length),
    );
    for (final article in documentation.articles) {
      expect(article.title, isNotEmpty);
      expect(article.summary, isNotEmpty);
      expect(article.body, contains('# '));
    }
  });

  test('bundled help search finds user-facing topics', () async {
    final documentation = await const BundledHelpDocumentationRepository()
        .load();

    final exportResults = HelpSearchIndex(documentation).search('parquet');
    expect(exportResults.first.article.id, 'exporting-results');

    final importResults = HelpSearchIndex(documentation).search('excel import');
    expect(
      importResults.map((result) => result.article.id),
      contains('importing-data'),
    );
  });
}
