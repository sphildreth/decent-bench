import 'dart:convert';

import 'package:decent_bench/app/theme.dart';
import 'package:decent_bench/app/theme_system/theme_presets.dart';
import 'package:decent_bench/features/workspace/domain/app_config.dart';
import 'package:decent_bench/features/workspace/domain/sql_autocomplete.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:decent_bench/features/workspace/presentation/shell/sql_editor_pane.dart';
import 'package:decent_bench/features/workspace/presentation/shell/sql_highlighting_text_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('escape dismisses open autocomplete suggestions', (tester) async {
    final sqlController = SqlHighlightingTextEditingController(text: 'SEL');
    final paramsController = TextEditingController();
    final findController = TextEditingController();
    final editorScrollController = ScrollController();
    final focusNode = FocusNode();
    final paramsFocusNode = FocusNode();
    final findFocusNode = FocusNode();
    final undoController = UndoHistoryController();
    final paramsUndoController = UndoHistoryController();
    var autocompleteResult = const AutocompleteResult(
      replaceStart: 0,
      replaceEnd: 3,
      suggestions: <AutocompleteSuggestion>[
        AutocompleteSuggestion(
          label: 'SELECT',
          insertText: 'SELECT',
          detail: 'keyword',
          kind: AutocompleteSuggestionKind.keyword,
        ),
      ],
    );

    addTearDown(() {
      paramsUndoController.dispose();
      undoController.dispose();
      findFocusNode.dispose();
      paramsFocusNode.dispose();
      focusNode.dispose();
      editorScrollController.dispose();
      findController.dispose();
      paramsController.dispose();
      sqlController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDecentBenchTheme(buildEmergencyTheme()),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 900,
                height: 600,
                child: SqlEditorPane(
                  tabs: <QueryTabState>[
                    QueryTabState.initial(id: 'query-1', title: 'Query 1'),
                  ],
                  activeTab: QueryTabState.initial(
                    id: 'query-1',
                    title: 'Query 1',
                    sql: 'SEL',
                  ),
                  sqlController: sqlController,
                  paramsController: paramsController,
                  editorScrollController: editorScrollController,
                  focusNode: focusNode,
                  paramsFocusNode: paramsFocusNode,
                  undoController: undoController,
                  paramsUndoController: paramsUndoController,
                  autocompleteResult: autocompleteResult,
                  snippets: const <SqlSnippet>[],
                  zoomFactor: 1,
                  indentSpaces: 2,
                  showLineNumbers: true,
                  showFindBar: false,
                  findController: findController,
                  findFocusNode: findFocusNode,
                  findStatusLabel: '0/0',
                  onSqlChanged: (_) {},
                  onParamsChanged: (_) {},
                  onSelectTab: (_) {},
                  onCloseTab: (_) async {},
                  onNewTab: () {},
                  onRunQuery: () {},
                  onRunBuffer: () {},
                  onStopQuery: () {},
                  onFormatSql: () {},
                  onInsertSnippet: (_) {},
                  onApplyAutocomplete: (_) {},
                  selectedAutocompleteIndex: 0,
                  onAutocompleteNext: () {},
                  onAutocompletePrevious: () {},
                  onAcceptAutocomplete: () {},
                  onDismissAutocomplete: () {
                    setState(() {
                      autocompleteResult = const AutocompleteResult(
                        replaceStart: 0,
                        replaceEnd: 0,
                        suggestions: <AutocompleteSuggestion>[],
                      );
                    });
                  },
                  canRun: true,
                  canStop: false,
                  onFindChanged: (_) {},
                  onFindNext: () {},
                  onFindPrevious: () {},
                  onCloseFind: () {},
                  runLabel: 'Run',
                  formatLabel: 'Format',
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('sql_editor.autocomplete_popup')),
      findsOneWidget,
    );

    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('sql_editor.autocomplete_popup')),
      findsNothing,
    );
  });

  testWidgets('query contract parameters update JSON values', (tester) async {
    final sqlController = SqlHighlightingTextEditingController(
      text: 'SELECT * FROM tasks WHERE id = \$1',
    );
    final paramsController = TextEditingController(text: '[1]');
    final findController = TextEditingController();
    final editorScrollController = ScrollController();
    final focusNode = FocusNode();
    final paramsFocusNode = FocusNode();
    final findFocusNode = FocusNode();
    final undoController = UndoHistoryController();
    final paramsUndoController = UndoHistoryController();
    var latestParams = '[1]';
    QueryTabState tab =
        QueryTabState.initial(
          id: 'query-1',
          title: 'Query 1',
          sql: 'SELECT * FROM tasks WHERE id = \$1',
          parameterJson: '[1]',
        ).copyWith(
          queryContract: QueryContract(
            contractVersion: 1,
            sql: 'SELECT * FROM tasks WHERE id = \$1',
            statementKind: 'query',
            readOnly: true,
            schemaCookie: 1,
            tempSchemaCookie: 0,
            schemaFingerprint: 'fingerprint',
            parameters: const <QueryParameterContract>[
              QueryParameterContract(
                position: 1,
                name: r'$1',
                typeName: 'INT64',
                nullable: false,
                source: 'catalog_column',
                sourceTable: 'tasks',
                sourceColumn: 'id',
                diagnostics: <String>[],
              ),
            ],
            resultColumns: const <QueryResultColumnContract>[],
            diagnostics: const <String>[],
          ),
        );

    addTearDown(() {
      paramsUndoController.dispose();
      undoController.dispose();
      findFocusNode.dispose();
      paramsFocusNode.dispose();
      focusNode.dispose();
      editorScrollController.dispose();
      findController.dispose();
      paramsController.dispose();
      sqlController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDecentBenchTheme(buildEmergencyTheme()),
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 600,
            child: SqlEditorPane(
              tabs: <QueryTabState>[tab],
              activeTab: tab,
              sqlController: sqlController,
              paramsController: paramsController,
              editorScrollController: editorScrollController,
              focusNode: focusNode,
              paramsFocusNode: paramsFocusNode,
              undoController: undoController,
              paramsUndoController: paramsUndoController,
              autocompleteResult: const AutocompleteResult(
                replaceStart: 0,
                replaceEnd: 0,
                suggestions: <AutocompleteSuggestion>[],
              ),
              snippets: const <SqlSnippet>[],
              zoomFactor: 1,
              indentSpaces: 2,
              showLineNumbers: true,
              showFindBar: false,
              findController: findController,
              findFocusNode: findFocusNode,
              findStatusLabel: '0/0',
              onSqlChanged: (_) {},
              onParamsChanged: (value) {
                latestParams = value;
              },
              onSelectTab: (_) {},
              onCloseTab: (_) async {},
              onNewTab: () {},
              onRunQuery: () {},
              onRunBuffer: () {},
              onStopQuery: () {},
              onFormatSql: () {},
              onInsertSnippet: (_) {},
              onApplyAutocomplete: (_) {},
              selectedAutocompleteIndex: 0,
              onAutocompleteNext: () {},
              onAutocompletePrevious: () {},
              onAcceptAutocomplete: () {},
              onDismissAutocomplete: () {},
              canRun: true,
              canStop: false,
              onFindChanged: (_) {},
              onFindNext: () {},
              onFindPrevious: () {},
              onCloseFind: () {},
              runLabel: 'Run',
              formatLabel: 'Format',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>(r'sql_editor.parameter.query-1.$1')),
      '42',
    );
    await tester.pump();

    expect(jsonDecode(latestParams), <Object?>[42]);
    expect(jsonDecode(paramsController.text), <Object?>[42]);
  });

  testWidgets(
    'typed parameters coerce boolean, numeric, and native string-ish values',
    (tester) async {
      final sqlController = SqlHighlightingTextEditingController(
        text: 'SELECT * FROM tasks WHERE id = \$1 AND active = \$2',
      );
      final paramsController = TextEditingController(text: '[1, true, "uuid"]');
      final findController = TextEditingController();
      final editorScrollController = ScrollController();
      final focusNode = FocusNode();
      final paramsFocusNode = FocusNode();
      final findFocusNode = FocusNode();
      final undoController = UndoHistoryController();
      final paramsUndoController = UndoHistoryController();
      var latestParams = '[1, true, "uuid"]';
      QueryTabState tab =
          QueryTabState.initial(
            id: 'query-1',
            title: 'Query 1',
            sql: 'SELECT * FROM tasks WHERE id = \$1 AND active = \$2',
            parameterJson: '[1, true, "uuid"]',
          ).copyWith(
            queryContract: QueryContract(
              contractVersion: 1,
              sql: 'SELECT * FROM tasks WHERE id = \$1 AND active = \$2',
              statementKind: 'query',
              readOnly: true,
              schemaCookie: 1,
              tempSchemaCookie: 0,
              schemaFingerprint: 'fingerprint',
              parameters: const <QueryParameterContract>[
                QueryParameterContract(
                  position: 1,
                  name: r'$1',
                  typeName: 'UUID',
                  nullable: false,
                  source: 'catalog_column',
                  sourceTable: 'tasks',
                  sourceColumn: 'id',
                  diagnostics: <String>[],
                ),
                QueryParameterContract(
                  position: 2,
                  name: r'$2',
                  typeName: 'BOOL',
                  nullable: false,
                  source: 'catalog_column',
                  sourceTable: 'tasks',
                  sourceColumn: 'active',
                  diagnostics: <String>[],
                ),
                QueryParameterContract(
                  position: 3,
                  name: r'$3',
                  typeName: 'INET',
                  nullable: false,
                  source: 'catalog_column',
                  sourceTable: 'tasks',
                  sourceColumn: 'ip',
                  diagnostics: <String>[],
                ),
              ],
              resultColumns: const <QueryResultColumnContract>[],
              diagnostics: const <String>[],
            ),
          );

      addTearDown(() {
        paramsUndoController.dispose();
        undoController.dispose();
        findFocusNode.dispose();
        paramsFocusNode.dispose();
        focusNode.dispose();
        editorScrollController.dispose();
        findController.dispose();
        paramsController.dispose();
        sqlController.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildDecentBenchTheme(buildEmergencyTheme()),
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 600,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return SqlEditorPane(
                    tabs: <QueryTabState>[tab],
                    activeTab: tab,
                    sqlController: sqlController,
                    paramsController: paramsController,
                    editorScrollController: editorScrollController,
                    focusNode: focusNode,
                    paramsFocusNode: paramsFocusNode,
                    undoController: undoController,
                    paramsUndoController: paramsUndoController,
                    autocompleteResult: const AutocompleteResult(
                      replaceStart: 0,
                      replaceEnd: 0,
                      suggestions: <AutocompleteSuggestion>[],
                    ),
                    snippets: const <SqlSnippet>[],
                    zoomFactor: 1,
                    indentSpaces: 2,
                    showLineNumbers: true,
                    showFindBar: false,
                    findController: findController,
                    findFocusNode: findFocusNode,
                    findStatusLabel: '0/0',
                    onSqlChanged: (_) {},
                    onParamsChanged: (value) {
                      latestParams = value;
                      setState(() {
                        tab = tab.copyWith(parameterJson: value);
                      });
                    },
                    onSelectTab: (_) {},
                    onCloseTab: (_) async {},
                    onNewTab: () {},
                    onRunQuery: () {},
                    onRunBuffer: () {},
                    onStopQuery: () {},
                    onFormatSql: () {},
                    onInsertSnippet: (_) {},
                    onApplyAutocomplete: (_) {},
                    selectedAutocompleteIndex: 0,
                    onAutocompleteNext: () {},
                    onAutocompletePrevious: () {},
                    onAcceptAutocomplete: () {},
                    onDismissAutocomplete: () {},
                    canRun: true,
                    canStop: false,
                    onFindChanged: (_) {},
                    onFindNext: () {},
                    onFindPrevious: () {},
                    onCloseFind: () {},
                    runLabel: 'Run',
                    formatLabel: 'Format',
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>(r'sql_editor.parameter.query-1.$1')),
        '550e8400-e29b-41d4-a716-446655440000',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>(r'sql_editor.parameter.query-1.$2')),
        'false',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>(r'sql_editor.parameter.query-1.$3')),
        '192.168.0.1',
      );
      await tester.pump();

      expect(jsonDecode(latestParams), <Object?>[
        '550e8400-e29b-41d4-a716-446655440000',
        false,
        '192.168.0.1',
      ]);
    },
  );

  testWidgets('typed numeric and boolean inputs show parse feedback', (
    tester,
  ) async {
    final sqlController = SqlHighlightingTextEditingController(
      text: 'SELECT * FROM tasks WHERE id = \$1 AND active = \$2',
    );
    final paramsController = TextEditingController(text: '[1, true]');
    final findController = TextEditingController();
    final editorScrollController = ScrollController();
    final focusNode = FocusNode();
    final paramsFocusNode = FocusNode();
    final findFocusNode = FocusNode();
    final undoController = UndoHistoryController();
    final paramsUndoController = UndoHistoryController();
    QueryTabState tab =
        QueryTabState.initial(
          id: 'query-1',
          title: 'Query 1',
          sql: 'SELECT * FROM tasks WHERE id = \$1 AND active = \$2',
          parameterJson: '[1, true]',
        ).copyWith(
          queryContract: QueryContract(
            contractVersion: 1,
            sql: 'SELECT * FROM tasks WHERE id = \$1 AND active = \$2',
            statementKind: 'query',
            readOnly: true,
            schemaCookie: 1,
            tempSchemaCookie: 0,
            schemaFingerprint: 'fingerprint',
            parameters: const <QueryParameterContract>[
              QueryParameterContract(
                position: 1,
                name: r'$1',
                typeName: 'INT64',
                nullable: false,
                source: 'catalog_column',
                sourceTable: 'tasks',
                sourceColumn: 'id',
                diagnostics: <String>[],
              ),
              QueryParameterContract(
                position: 2,
                name: r'$2',
                typeName: 'BOOL',
                nullable: false,
                source: 'catalog_column',
                sourceTable: 'tasks',
                sourceColumn: 'active',
                diagnostics: <String>[],
              ),
            ],
            resultColumns: const <QueryResultColumnContract>[],
            diagnostics: const <String>[],
          ),
        );

    addTearDown(() {
      paramsUndoController.dispose();
      undoController.dispose();
      findFocusNode.dispose();
      paramsFocusNode.dispose();
      focusNode.dispose();
      editorScrollController.dispose();
      findController.dispose();
      paramsController.dispose();
      sqlController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDecentBenchTheme(buildEmergencyTheme()),
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 600,
            child: StatefulBuilder(
              builder: (context, setState) {
                return SqlEditorPane(
                  tabs: <QueryTabState>[tab],
                  activeTab: tab,
                  sqlController: sqlController,
                  paramsController: paramsController,
                  editorScrollController: editorScrollController,
                  focusNode: focusNode,
                  paramsFocusNode: paramsFocusNode,
                  undoController: undoController,
                  paramsUndoController: paramsUndoController,
                  autocompleteResult: const AutocompleteResult(
                    replaceStart: 0,
                    replaceEnd: 0,
                    suggestions: <AutocompleteSuggestion>[],
                  ),
                  snippets: const <SqlSnippet>[],
                  zoomFactor: 1,
                  indentSpaces: 2,
                  showLineNumbers: true,
                  showFindBar: false,
                  findController: findController,
                  findFocusNode: findFocusNode,
                  findStatusLabel: '0/0',
                  onSqlChanged: (_) {},
                  onParamsChanged: (value) {
                    setState(() {
                      tab = tab.copyWith(parameterJson: value);
                    });
                  },
                  onSelectTab: (_) {},
                  onCloseTab: (_) async {},
                  onNewTab: () {},
                  onRunQuery: () {},
                  onRunBuffer: () {},
                  onStopQuery: () {},
                  onFormatSql: () {},
                  onInsertSnippet: (_) {},
                  onApplyAutocomplete: (_) {},
                  selectedAutocompleteIndex: 0,
                  onAutocompleteNext: () {},
                  onAutocompletePrevious: () {},
                  onAcceptAutocomplete: () {},
                  onDismissAutocomplete: () {},
                  canRun: true,
                  canStop: false,
                  onFindChanged: (_) {},
                  onFindNext: () {},
                  onFindPrevious: () {},
                  onCloseFind: () {},
                  runLabel: 'Run',
                  formatLabel: 'Format',
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>(r'sql_editor.parameter.query-1.$1')),
      'abc',
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>(r'sql_editor.parameter.query-1.$2')),
      'maybe',
    );
    await tester.pump();

    expect(find.text('Invalid integer'), findsOneWidget);
    expect(find.text('Use true or false'), findsOneWidget);
  });
}
