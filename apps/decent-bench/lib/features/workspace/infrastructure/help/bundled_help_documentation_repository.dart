import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/help/help_documentation.dart';

class BundledHelpDocumentationRepository
    implements HelpDocumentationRepository {
  const BundledHelpDocumentationRepository({
    AssetBundle? assetBundle,
    this.manifestPath = 'assets/help/help_manifest.json',
  }) : _assetBundle = assetBundle;

  final AssetBundle? _assetBundle;
  final String manifestPath;

  AssetBundle get _bundle => _assetBundle ?? rootBundle;

  @override
  Future<HelpDocumentation> load() async {
    final manifestSource = await _bundle.loadString(manifestPath);
    final manifest = jsonDecode(manifestSource) as Map<String, Object?>;
    final rawArticles = manifest['articles'];
    if (rawArticles is! List<Object?> || rawArticles.isEmpty) {
      throw const FormatException('Help manifest must define articles.');
    }

    final articles = <HelpArticle>[];
    final seenIds = <String>{};
    for (final rawArticle in rawArticles) {
      if (rawArticle is! Map<String, Object?>) {
        throw const FormatException('Help article manifest entry is invalid.');
      }
      final id = _requiredString(rawArticle, 'id');
      if (!seenIds.add(id)) {
        throw FormatException('Duplicate help article id "$id".');
      }
      final assetPath = _requiredString(rawArticle, 'asset');
      articles.add(
        HelpArticle(
          id: id,
          title: _requiredString(rawArticle, 'title'),
          category: _requiredString(rawArticle, 'category'),
          summary: _requiredString(rawArticle, 'summary'),
          tags: _stringList(rawArticle['tags']),
          assetPath: assetPath,
          body: await _bundle.loadString(assetPath),
        ),
      );
    }

    return HelpDocumentation(articles: articles);
  }

  String _requiredString(Map<String, Object?> source, String key) {
    final value = source[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Help manifest field "$key" must be a string.');
    }
    return value;
  }

  List<String> _stringList(Object? value) {
    if (value == null) {
      return const <String>[];
    }
    if (value is! List<Object?>) {
      throw const FormatException('Help manifest list field is invalid.');
    }
    return List<String>.unmodifiable(
      value.map((entry) {
        if (entry is! String || entry.trim().isEmpty) {
          throw const FormatException('Help manifest list entry is invalid.');
        }
        return entry;
      }),
    );
  }
}
