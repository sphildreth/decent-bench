import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../domain/help/help_documentation.dart';
import '../../infrastructure/help/bundled_help_documentation_repository.dart';

class HelpCenterDialog extends StatefulWidget {
  const HelpCenterDialog({
    super.key,
    this.repository = const BundledHelpDocumentationRepository(),
    this.initialArticleId,
  });

  final HelpDocumentationRepository repository;
  final String? initialArticleId;

  @override
  State<HelpCenterDialog> createState() => _HelpCenterDialogState();
}

class _HelpCenterDialogState extends State<HelpCenterDialog> {
  late final Future<HelpDocumentation> _documentationFuture;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  String? _selectedArticleId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedArticleId = widget.initialArticleId;
    _documentationFuture = widget.repository.load();
    _searchController = TextEditingController()
      ..addListener(() {
        setState(() {
          _query = _searchController.text.trim();
        });
      });
    _searchFocusNode = FocusNode(debugLabel: 'help-center-search');
  }

  @override
  void didUpdateWidget(covariant HelpCenterDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialArticleId != oldWidget.initialArticleId) {
      _selectedArticleId = widget.initialArticleId;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 760),
        child: Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.keyF, control: true):
                _FocusHelpSearchIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _FocusHelpSearchIntent: CallbackAction<_FocusHelpSearchIntent>(
                onInvoke: (_) {
                  _searchFocusNode.requestFocus();
                  _searchController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _searchController.text.length,
                  );
                  return null;
                },
              ),
            },
            child: FutureBuilder<HelpDocumentation>(
              future: _documentationFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _HelpCenterScaffold(
                    child: _HelpError(error: snapshot.error),
                  );
                }
                if (!snapshot.hasData) {
                  return const _HelpCenterScaffold(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _buildLoaded(context, snapshot.requireData);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, HelpDocumentation documentation) {
    final selectedArticle = _selectedArticle(documentation);
    final searchResults = HelpSearchIndex(documentation).search(_query);

    return _HelpCenterScaffold(
      child: Column(
        children: <Widget>[
          _HelpHeader(onClose: () => Navigator.of(context).pop()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: TextField(
              key: const ValueKey<String>('help_center.search_field'),
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: _searchController.clear,
                      ),
                hintText: 'Search help',
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: 300,
                  child: _HelpNavigationPane(
                    documentation: documentation,
                    query: _query,
                    searchResults: searchResults,
                    selectedArticleId: selectedArticle.id,
                    onSelect: _selectArticle,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _HelpArticlePane(article: selectedArticle)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  HelpArticle _selectedArticle(HelpDocumentation documentation) {
    final requestedId = _selectedArticleId;
    final requested = requestedId == null
        ? null
        : documentation.article(requestedId);
    final article = requested ?? documentation.defaultArticle;
    _selectedArticleId = article.id;
    return article;
  }

  void _selectArticle(String articleId) {
    setState(() {
      _selectedArticleId = articleId;
    });
  }
}

class _FocusHelpSearchIntent extends Intent {
  const _FocusHelpSearchIntent();
}

class _HelpCenterScaffold extends StatelessWidget {
  const _HelpCenterScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(color: Theme.of(context).colorScheme.surface, child: child);
  }
}

class _HelpHeader extends StatelessWidget {
  const _HelpHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.menu_book_outlined,
            color: theme.colorScheme.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Decent Bench Help Center',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Practical guides for opening data, importing files, writing SQL, and exporting results.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _HelpNavigationPane extends StatelessWidget {
  const _HelpNavigationPane({
    required this.documentation,
    required this.query,
    required this.searchResults,
    required this.selectedArticleId,
    required this.onSelect,
  });

  final HelpDocumentation documentation;
  final String query;
  final List<HelpSearchResult> searchResults;
  final String selectedArticleId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: query.isEmpty
          ? _HelpCategoryList(
              documentation: documentation,
              selectedArticleId: selectedArticleId,
              onSelect: onSelect,
            )
          : _HelpSearchResults(
              query: query,
              results: searchResults,
              selectedArticleId: selectedArticleId,
              onSelect: onSelect,
            ),
    );
  }
}

class _HelpCategoryList extends StatelessWidget {
  const _HelpCategoryList({
    required this.documentation,
    required this.selectedArticleId,
    required this.onSelect,
  });

  final HelpDocumentation documentation;
  final String selectedArticleId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: <Widget>[
        for (final category in documentation.categories) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
            child: Text(
              category,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          for (final article in documentation.articlesForCategory(category))
            _HelpArticleListTile(
              article: article,
              selected: article.id == selectedArticleId,
              onTap: () => onSelect(article.id),
            ),
        ],
      ],
    );
  }
}

class _HelpSearchResults extends StatelessWidget {
  const _HelpSearchResults({
    required this.query,
    required this.results,
    required this.selectedArticleId,
    required this.onSelect,
  });

  final String query;
  final List<HelpSearchResult> results;
  final String selectedArticleId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No help topics match "$query".',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Text(
            '${results.length} result${results.length == 1 ? '' : 's'}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        for (final result in results)
          _HelpSearchResultTile(
            result: result,
            selected: result.article.id == selectedArticleId,
            onTap: () => onSelect(result.article.id),
          ),
      ],
    );
  }
}

class _HelpArticleListTile extends StatelessWidget {
  const _HelpArticleListTile({
    required this.article,
    required this.selected,
    required this.onTap,
  });

  final HelpArticle article;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      title: Text(article.title),
      subtitle: Text(
        article.summary,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}

class _HelpSearchResultTile extends StatelessWidget {
  const _HelpSearchResultTile({
    required this.result,
    required this.selected,
    required this.onTap,
  });

  final HelpSearchResult result;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      selected: selected,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.55,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      title: Text(result.article.title),
      subtitle: Text(
        result.snippet,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}

class _HelpArticlePane extends StatelessWidget {
  const _HelpArticlePane({required this.article});

  final HelpArticle article;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(article.category, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(article.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                article.summary,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (article.tags.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final tag in article.tags.take(6))
                      Chip(
                        label: Text(tag),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Markdown(
            key: ValueKey<String>('help_center.article.${article.id}'),
            data: article.body,
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
            selectable: true,
          ),
        ),
      ],
    );
  }
}

class _HelpError extends StatelessWidget {
  const _HelpError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          Icons.error_outline,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          'Help content could not be loaded.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            '$error',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
