import 'package:decent_bench/features/workspace/domain/help/help_documentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('help search ranks matching titles before body-only matches', () {
    final documentation = HelpDocumentation(
      articles: const <HelpArticle>[
        HelpArticle(
          id: 'exporting-results',
          title: 'Exporting Results',
          category: 'Exporting',
          summary: 'Export query results.',
          tags: <String>['csv', 'parquet'],
          assetPath: 'assets/help/exporting-results.md',
          body: 'Choose CSV, JSON, Excel, or Parquet for downstream use.',
        ),
        HelpArticle(
          id: 'troubleshooting',
          title: 'Troubleshooting',
          category: 'Help',
          summary: 'Resolve common issues.',
          tags: <String>['error'],
          assetPath: 'assets/help/troubleshooting.md',
          body: 'If a Parquet export is not available, check the export menu.',
        ),
      ],
    );

    final results = HelpSearchIndex(documentation).search('parquet');

    expect(results, hasLength(2));
    expect(results.first.article.id, 'exporting-results');
    expect(results.first.snippet.toLowerCase(), contains('parquet'));
  });

  test('help documentation keeps category order from the manifest', () {
    final documentation = HelpDocumentation(
      articles: const <HelpArticle>[
        HelpArticle(
          id: 'getting-started',
          title: 'Getting Started',
          category: 'Start Here',
          summary: 'Open or import data.',
          tags: <String>[],
          assetPath: 'assets/help/getting-started.md',
          body: 'Open a DecentDB file.',
        ),
        HelpArticle(
          id: 'writing-sql',
          title: 'Writing SQL',
          category: 'Working With Data',
          summary: 'Run queries.',
          tags: <String>[],
          assetPath: 'assets/help/writing-sql.md',
          body: 'Run a query.',
        ),
        HelpArticle(
          id: 'results-grid',
          title: 'Results',
          category: 'Working With Data',
          summary: 'Read rows.',
          tags: <String>[],
          assetPath: 'assets/help/results-grid.md',
          body: 'Read results.',
        ),
      ],
    );

    expect(documentation.categories, <String>[
      'Start Here',
      'Working With Data',
    ]);
    expect(
      documentation.articlesForCategory('Working With Data').map((a) => a.id),
      <String>['writing-sql', 'results-grid'],
    );
  });
}
