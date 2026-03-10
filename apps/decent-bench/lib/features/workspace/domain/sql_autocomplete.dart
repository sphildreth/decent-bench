import 'app_config.dart';
import 'sql_vocabulary.dart';
import 'workspace_models.dart';

enum AutocompleteSuggestionKind { keyword, function, object, column, snippet }

class AutocompleteSuggestion {
  const AutocompleteSuggestion({
    required this.label,
    required this.insertText,
    required this.detail,
    required this.kind,
  });

  final String label;
  final String insertText;
  final String detail;
  final AutocompleteSuggestionKind kind;
}

class AutocompleteResult {
  const AutocompleteResult({
    required this.replaceStart,
    required this.replaceEnd,
    required this.suggestions,
  });

  final int replaceStart;
  final int replaceEnd;
  final List<AutocompleteSuggestion> suggestions;

  bool get isEmpty => suggestions.isEmpty;
}

class SqlAutocompleteEngine {
  const SqlAutocompleteEngine();

  AutocompleteResult suggest({
    required String sql,
    required int cursorOffset,
    required SchemaSnapshot schema,
    required AppConfig config,
  }) {
    if (!config.editorSettings.autocompleteEnabled) {
      return const AutocompleteResult(
        replaceStart: 0,
        replaceEnd: 0,
        suggestions: <AutocompleteSuggestion>[],
      );
    }

    final clampedCursor = cursorOffset.clamp(0, sql.length);
    final beforeCursor = sql.substring(0, clampedCursor);
    final aliasContext = RegExp(
      r'([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_0-9]*)$',
    ).firstMatch(beforeCursor);
    final prefixMatch = RegExp(
      r'([A-Za-z_][A-Za-z0-9_]*)$',
    ).firstMatch(beforeCursor);

    final replaceStart = aliasContext != null
        ? clampedCursor - aliasContext.group(2)!.length
        : prefixMatch != null
        ? clampedCursor - prefixMatch.group(1)!.length
        : clampedCursor;
    final prefix =
        aliasContext?.group(2)?.toLowerCase() ??
        prefixMatch?.group(1)?.toLowerCase() ??
        '';

    final suggestions = aliasContext != null
        ? _columnSuggestions(
            alias: aliasContext.group(1)!,
            prefix: prefix,
            sql: sql,
            schema: schema,
          )
        : _contextSuggestions(
            prefix: prefix,
            beforeCursor: beforeCursor,
            schema: schema,
            config: config,
          );

    final limited = suggestions
        .take(config.editorSettings.autocompleteMaxSuggestions)
        .toList();
    return AutocompleteResult(
      replaceStart: replaceStart,
      replaceEnd: clampedCursor,
      suggestions: limited,
    );
  }

  List<AutocompleteSuggestion> _contextSuggestions({
    required String prefix,
    required String beforeCursor,
    required SchemaSnapshot schema,
    required AppConfig config,
  }) {
    final previousKeyword = _previousKeyword(beforeCursor);
    final objectContextKeywords = <String>{
      'FROM',
      'JOIN',
      'UPDATE',
      'INTO',
      'TABLE',
      'VIEW',
    };

    if (objectContextKeywords.contains(previousKeyword)) {
      return _schemaObjectSuggestions(schema.objects, prefix);
    }

    if (prefix.isEmpty) {
      return const <AutocompleteSuggestion>[];
    }

    final suggestions = <AutocompleteSuggestion>[
      ..._schemaObjectSuggestions(schema.objects, prefix),
      ..._keywordSuggestions(prefix),
      ..._functionSuggestions(prefix),
      ..._snippetSuggestions(prefix, config.snippets),
    ];

    suggestions.sort(
      (left, right) => _compareSuggestions(left, right, prefix: prefix),
    );
    return suggestions;
  }

  List<AutocompleteSuggestion> _columnSuggestions({
    required String alias,
    required String prefix,
    required String sql,
    required SchemaSnapshot schema,
  }) {
    final aliasMap = _collectAliases(sql, schema);
    final object = aliasMap[alias.toLowerCase()];
    if (object == null) {
      return const <AutocompleteSuggestion>[];
    }

    final suggestions = <AutocompleteSuggestion>[
      for (final column in object.columns)
        if (prefix.isEmpty || column.name.toLowerCase().startsWith(prefix))
          AutocompleteSuggestion(
            label: column.name,
            insertText: column.name,
            detail: '${object.name} column',
            kind: AutocompleteSuggestionKind.column,
          ),
    ];
    suggestions.sort(
      (left, right) => _compareSuggestions(left, right, prefix: prefix),
    );
    return suggestions;
  }

  Map<String, SchemaObjectSummary> _collectAliases(
    String sql,
    SchemaSnapshot schema,
  ) {
    final aliasMap = <String, SchemaObjectSummary>{};
    final regex = RegExp(
      r'\b(?:FROM|JOIN|UPDATE|INTO)\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s+(?:AS\s+)?([A-Za-z_][A-Za-z0-9_]*))?',
      caseSensitive: false,
    );

    for (final match in regex.allMatches(sql)) {
      final objectName = match.group(1);
      if (objectName == null) {
        continue;
      }
      final object = schema.objectNamed(objectName);
      if (object == null) {
        continue;
      }
      aliasMap[object.name.toLowerCase()] = object;
      final alias = match.group(2);
      if (alias != null) {
        aliasMap[alias.toLowerCase()] = object;
      }
    }
    return aliasMap;
  }

  String? _previousKeyword(String beforeCursor) {
    final sanitized = beforeCursor.replaceAll(
      RegExp(r'([A-Za-z_][A-Za-z0-9_]*)$'),
      '',
    );
    final matches = RegExp(r'([A-Za-z_][A-Za-z0-9_]*)').allMatches(sanitized);
    if (matches.isEmpty) {
      return null;
    }
    return matches.last.group(1)?.toUpperCase();
  }

  List<AutocompleteSuggestion> _schemaObjectSuggestions(
    List<SchemaObjectSummary> objects,
    String prefix,
  ) {
    return <AutocompleteSuggestion>[
      for (final object in objects)
        if (prefix.isEmpty || object.name.toLowerCase().startsWith(prefix))
          AutocompleteSuggestion(
            label: object.name,
            insertText: object.name,
            detail: object.kind == SchemaObjectKind.table ? 'table' : 'view',
            kind: AutocompleteSuggestionKind.object,
          ),
    ]..sort((left, right) => _compareSuggestions(left, right, prefix: prefix));
  }

  List<AutocompleteSuggestion> _keywordSuggestions(String prefix) {
    return <AutocompleteSuggestion>[
      for (final keyword in decentDbSqlKeywords)
        if (prefix.isEmpty || keyword.toLowerCase().startsWith(prefix))
          AutocompleteSuggestion(
            label: keyword,
            insertText: keyword,
            detail: 'keyword',
            kind: AutocompleteSuggestionKind.keyword,
          ),
    ];
  }

  List<AutocompleteSuggestion> _functionSuggestions(String prefix) {
    return <AutocompleteSuggestion>[
      for (final functionName in decentDbSqlFunctions)
        if (prefix.isEmpty || functionName.toLowerCase().startsWith(prefix))
          AutocompleteSuggestion(
            label: functionName,
            insertText: functionName.endsWith(')')
                ? functionName
                : '$functionName()',
            detail: 'function',
            kind: AutocompleteSuggestionKind.function,
          ),
    ];
  }

  List<AutocompleteSuggestion> _snippetSuggestions(
    String prefix,
    List<SqlSnippet> snippets,
  ) {
    return <AutocompleteSuggestion>[
      for (final snippet in snippets)
        if (prefix.isEmpty ||
            snippet.trigger.toLowerCase().startsWith(prefix) ||
            snippet.name.toLowerCase().startsWith(prefix))
          AutocompleteSuggestion(
            label: snippet.trigger,
            insertText: snippet.body,
            detail: 'snippet: ${snippet.name}',
            kind: AutocompleteSuggestionKind.snippet,
          ),
    ];
  }

  int _compareSuggestions(
    AutocompleteSuggestion left,
    AutocompleteSuggestion right, {
    required String prefix,
  }) {
    final leftRank = _kindRank(left.kind);
    final rightRank = _kindRank(right.kind);
    final leftStarts = left.label.toLowerCase().startsWith(prefix);
    final rightStarts = right.label.toLowerCase().startsWith(prefix);
    if (leftStarts != rightStarts) {
      return leftStarts ? -1 : 1;
    }
    if (leftRank != rightRank) {
      return leftRank.compareTo(rightRank);
    }
    return left.label.compareTo(right.label);
  }

  int _kindRank(AutocompleteSuggestionKind kind) {
    return switch (kind) {
      AutocompleteSuggestionKind.object => 0,
      AutocompleteSuggestionKind.column => 1,
      AutocompleteSuggestionKind.function => 2,
      AutocompleteSuggestionKind.keyword => 3,
      AutocompleteSuggestionKind.snippet => 4,
    };
  }
}
