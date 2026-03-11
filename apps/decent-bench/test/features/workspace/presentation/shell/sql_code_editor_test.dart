import 'package:decent_bench/app/theme.dart';
import 'package:decent_bench/app/theme_system/theme_presets.dart';
import 'package:decent_bench/features/workspace/presentation/shell/sql_code_editor.dart';
import 'package:decent_bench/features/workspace/presentation/shell/sql_highlighting_text_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sql code editor renders the custom painted surface', (
    tester,
  ) async {
    final controller = SqlHighlightingTextEditingController(
      text: 'SELECT\n  customer_id\nFROM orders;',
    );
    final focusNode = FocusNode();
    final scrollController = ScrollController();
    final undoController = UndoHistoryController();

    addTearDown(() {
      undoController.dispose();
      scrollController.dispose();
      focusNode.dispose();
      controller.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDecentBenchTheme(buildEmergencyTheme()),
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 280,
            child: SqlCodeEditor(
              controller: controller,
              focusNode: focusNode,
              scrollController: scrollController,
              undoController: undoController,
              onChanged: (_) {},
              zoomFactor: 1.25,
              indentSpaces: 2,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final paintFinder = find.descendant(
      of: find.byType(SqlCodeEditor),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter is SqlEditorBackgroundPainter,
      ),
    );

    expect(find.byType(EditableText), findsOneWidget);
    expect(paintFinder, findsOneWidget);

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    final span = controller.buildTextSpan(
      context: tester.element(find.byType(EditableText)),
      style: editable.style,
      withComposing: false,
    );

    expect(span.style?.fontSize, editable.style.fontSize);
    expect(span.style?.fontFamily, editable.style.fontFamily);
  });

  testWidgets('sql code editor shows and hides its placeholder', (
    tester,
  ) async {
    final controller = SqlHighlightingTextEditingController();
    final focusNode = FocusNode();
    final scrollController = ScrollController();
    final undoController = UndoHistoryController();

    addTearDown(() {
      undoController.dispose();
      scrollController.dispose();
      focusNode.dispose();
      controller.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDecentBenchTheme(buildEmergencyTheme()),
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 280,
            child: SqlCodeEditor(
              controller: controller,
              focusNode: focusNode,
              scrollController: scrollController,
              undoController: undoController,
              onChanged: (_) {},
              zoomFactor: 1,
              indentSpaces: 2,
            ),
          ),
        ),
      ),
    );

    expect(find.text('SELECT *\nFROM your_table\nLIMIT 100;'), findsOneWidget);

    controller.text = 'SELECT 1;';
    await tester.pump();

    expect(find.text('SELECT *\nFROM your_table\nLIMIT 100;'), findsNothing);
  });
}
