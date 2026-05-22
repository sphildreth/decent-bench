import 'package:flutter/foundation.dart';

@immutable
class HelpArticle {
  const HelpArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.tags,
    required this.assetPath,
    required this.body,
  });

  final String id;
  final String title;
  final String category;
  final String summary;
  final List<String> tags;
  final String assetPath;
  final String body;
}

@immutable
class HelpDocumentation {
  HelpDocumentation({required List<HelpArticle> articles})
    : articles = List<HelpArticle>.unmodifiable(articles),
      _articleById = <String, HelpArticle>{
        for (final article in articles) article.id: article,
      };

  final List<HelpArticle> articles;
  final Map<String, HelpArticle> _articleById;

  HelpArticle? article(String id) => _articleById[id];

  HelpArticle get defaultArticle {
    if (articles.isEmpty) {
      throw StateError('Help documentation has no articles.');
    }
    return articles.first;
  }

  List<String> get categories {
    final seen = <String>{};
    return <String>[
      for (final article in articles)
        if (seen.add(article.category)) article.category,
    ];
  }

  List<HelpArticle> articlesForCategory(String category) {
    return articles
        .where((article) => article.category == category)
        .toList(growable: false);
  }
}

abstract interface class HelpDocumentationRepository {
  Future<HelpDocumentation> load();
}

@immutable
class HelpSearchResult {
  const HelpSearchResult({
    required this.article,
    required this.score,
    required this.snippet,
  });

  final HelpArticle article;
  final int score;
  final String snippet;
}

class HelpSearchIndex {
  HelpSearchIndex(HelpDocumentation documentation)
    : _articles = documentation.articles;

  final List<HelpArticle> _articles;

  List<HelpSearchResult> search(String query) {
    final terms = _tokenize(query);
    if (terms.isEmpty) {
      return const <HelpSearchResult>[];
    }

    final results = <HelpSearchResult>[];
    for (final article in _articles) {
      final score = _score(article, terms);
      if (score <= 0) {
        continue;
      }
      results.add(
        HelpSearchResult(
          article: article,
          score: score,
          snippet: _snippet(article, terms),
        ),
      );
    }

    results.sort((left, right) {
      final byScore = right.score.compareTo(left.score);
      if (byScore != 0) {
        return byScore;
      }
      return left.article.title.compareTo(right.article.title);
    });
    return results;
  }

  int _score(HelpArticle article, List<String> terms) {
    var score = 0;
    final title = article.title.toLowerCase();
    final category = article.category.toLowerCase();
    final summary = article.summary.toLowerCase();
    final body = article.body.toLowerCase();
    final tags = article.tags.map((tag) => tag.toLowerCase()).toList();

    for (final term in terms) {
      if (title == term) {
        score += 80;
      }
      if (title.contains(term)) {
        score += 40;
      }
      if (tags.any((tag) => tag == term || tag.contains(term))) {
        score += 32;
      }
      if (category.contains(term)) {
        score += 18;
      }
      if (summary.contains(term)) {
        score += 16;
      }
      score += _boundedOccurrences(body, term, max: 12);
    }
    return score;
  }

  String _snippet(HelpArticle article, List<String> terms) {
    final plain = _plainText(article.body);
    final lower = plain.toLowerCase();
    var index = -1;
    for (final term in terms) {
      index = lower.indexOf(term);
      if (index >= 0) {
        break;
      }
    }
    if (index < 0) {
      return article.summary;
    }

    final start = (index - 72).clamp(0, plain.length).toInt();
    final end = (index + 180).clamp(0, plain.length).toInt();
    final prefix = start > 0 ? '...' : '';
    final suffix = end < plain.length ? '...' : '';
    return '$prefix${plain.substring(start, end).trim()}$suffix';
  }

  int _boundedOccurrences(String source, String term, {required int max}) {
    var count = 0;
    var index = source.indexOf(term);
    while (index >= 0 && count < max) {
      count++;
      index = source.indexOf(term, index + term.length);
    }
    return count;
  }

  List<String> _tokenize(String query) {
    return query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9_]+'))
        .map((part) => part.trim())
        .where((part) => part.length > 1)
        .toSet()
        .toList(growable: false);
  }

  String _plainText(String markdown) {
    return markdown
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAllMapped(RegExp(r'`([^`]+)`'), (match) => match.group(1)!)
        .replaceAll(RegExp(r'[#>*_\[\]()]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
