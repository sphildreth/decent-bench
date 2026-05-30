class EditorSettings {
  static const bool defaultAutocompleteEnabled = true;
  static const int defaultAutocompleteMaxSuggestions = 12;
  static const bool defaultFormatUppercaseKeywords = true;
  static const int defaultIndentSpaces = 2;
  static const bool defaultShowLineNumbers = true;

  const EditorSettings({
    required this.autocompleteEnabled,
    required this.autocompleteMaxSuggestions,
    required this.formatUppercaseKeywords,
    required this.indentSpaces,
    required this.showLineNumbers,
  });

  final bool autocompleteEnabled;
  final int autocompleteMaxSuggestions;
  final bool formatUppercaseKeywords;
  final int indentSpaces;
  final bool showLineNumbers;

  factory EditorSettings.defaults() {
    return const EditorSettings(
      autocompleteEnabled: defaultAutocompleteEnabled,
      autocompleteMaxSuggestions: defaultAutocompleteMaxSuggestions,
      formatUppercaseKeywords: defaultFormatUppercaseKeywords,
      indentSpaces: defaultIndentSpaces,
      showLineNumbers: defaultShowLineNumbers,
    );
  }

  EditorSettings copyWith({
    bool? autocompleteEnabled,
    int? autocompleteMaxSuggestions,
    bool? formatUppercaseKeywords,
    int? indentSpaces,
    bool? showLineNumbers,
  }) {
    return EditorSettings(
      autocompleteEnabled: autocompleteEnabled ?? this.autocompleteEnabled,
      autocompleteMaxSuggestions:
          autocompleteMaxSuggestions ?? this.autocompleteMaxSuggestions,
      formatUppercaseKeywords:
          formatUppercaseKeywords ?? this.formatUppercaseKeywords,
      indentSpaces: indentSpaces ?? this.indentSpaces,
      showLineNumbers: showLineNumbers ?? this.showLineNumbers,
    );
  }
}
