import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme_system/decent_bench_theme_extension.dart';

const EdgeInsets kSqlEditorContentPadding = EdgeInsets.all(16);
const double kSqlEditorGutterWidth = 60;

class SqlCodeEditor extends StatelessWidget {
  const SqlCodeEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.undoController,
    required this.onChanged,
    required this.zoomFactor,
    required this.indentSpaces,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final UndoHistoryController undoController;
  final ValueChanged<String> onChanged;
  final double zoomFactor;
  final int indentSpaces;

  @override
  Widget build(BuildContext context) {
    final theme = context.decentBenchTheme;
    final textStyle = TextStyle(
      fontSize: theme.fonts.editorSize * zoomFactor,
      fontFamily: theme.fonts.editorFamily,
      height: theme.fonts.lineHeight,
      color: theme.editor.text,
    );
    final repaint = Listenable.merge(<Listenable>[
      controller,
      focusNode,
      scrollController,
    ]);

    return DecoratedBox(
      decoration: BoxDecoration(color: theme.editor.background),
      child: ClipRect(
        child: AnimatedBuilder(
          animation: repaint,
          builder: (context, _) {
            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: SqlEditorBackgroundPainter(
                      text: controller.text,
                      selection: controller.selection,
                      scrollOffset: scrollController.hasClients
                          ? scrollController.offset
                          : 0,
                      textStyle: textStyle,
                      contentPadding: kSqlEditorContentPadding,
                      indentSpaces: indentSpaces,
                      currentLineColor: theme.editor.currentLineBackground,
                      whitespaceColor: theme.editor.whitespace,
                      indentGuideColor: theme.editor.indentGuide,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: kSqlEditorContentPadding,
                    child: EditableText(
                      controller: controller,
                      focusNode: focusNode,
                      scrollController: scrollController,
                      undoController: undoController,
                      style: textStyle,
                      cursorColor: theme.editor.cursor,
                      backgroundCursorColor: theme.colors.panelBg,
                      selectionColor: theme.editor.selectionBackground,
                      maxLines: null,
                      minLines: null,
                      expands: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      selectionControls: materialTextSelectionControls,
                      onChanged: onChanged,
                    ),
                  ),
                ),
                if (controller.text.isEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Padding(
                        padding: kSqlEditorContentPadding,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            'SELECT *\nFROM your_table\nLIMIT 100;',
                            style: textStyle.copyWith(
                              color: theme.editor.whitespace,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class SqlEditorBackgroundPainter extends CustomPainter {
  const SqlEditorBackgroundPainter({
    required this.text,
    required this.selection,
    required this.scrollOffset,
    required this.textStyle,
    required this.contentPadding,
    required this.indentSpaces,
    required this.currentLineColor,
    required this.whitespaceColor,
    required this.indentGuideColor,
  });

  final String text;
  final TextSelection selection;
  final double scrollOffset;
  final TextStyle textStyle;
  final EdgeInsets contentPadding;
  final int indentSpaces;
  final Color currentLineColor;
  final Color whitespaceColor;
  final Color indentGuideColor;

  @override
  void paint(Canvas canvas, Size size) {
    final lineHeight = (textStyle.fontSize ?? 13) * (textStyle.height ?? 1.35);
    final characterWidth = _characterWidth(textStyle);
    final lines = text.split('\n');
    final currentLine = _currentLineIndex(text, selection);

    _paintCurrentLine(canvas, size, lineHeight, currentLine);
    _paintIndentGuides(canvas, lines, size, lineHeight, characterWidth);
    _paintWhitespace(canvas, lines, size, lineHeight, characterWidth);
  }

  void _paintCurrentLine(
    Canvas canvas,
    Size size,
    double lineHeight,
    int currentLine,
  ) {
    final y = contentPadding.top + (currentLine * lineHeight) - scrollOffset;
    if (y + lineHeight < 0 || y > size.height) {
      return;
    }

    canvas.drawRect(
      Rect.fromLTWH(0, y, size.width, lineHeight),
      Paint()..color = currentLineColor,
    );
  }

  void _paintIndentGuides(
    Canvas canvas,
    List<String> lines,
    Size size,
    double lineHeight,
    double characterWidth,
  ) {
    final paint = Paint()
      ..color = indentGuideColor
      ..strokeWidth = 1;
    final visibleRange = _visibleLineRange(
      size.height,
      lineHeight,
      lines.length,
    );

    for (
      var lineIndex = visibleRange.$1;
      lineIndex <= visibleRange.$2;
      lineIndex++
    ) {
      final line = lines[lineIndex];
      final leadingColumns = _leadingIndentColumns(line);
      final guideCount = leadingColumns ~/ math.max(indentSpaces, 1);
      if (guideCount == 0) {
        continue;
      }
      final top = contentPadding.top + (lineIndex * lineHeight) - scrollOffset;
      final bottom = top + lineHeight;
      for (var guide = 1; guide <= guideCount; guide++) {
        final x =
            contentPadding.left +
            (guide * indentSpaces * characterWidth) -
            (characterWidth / 2);
        canvas.drawLine(Offset(x, top + 2), Offset(x, bottom - 2), paint);
      }
    }
  }

  void _paintWhitespace(
    Canvas canvas,
    List<String> lines,
    Size size,
    double lineHeight,
    double characterWidth,
  ) {
    final dotPaint = Paint()
      ..color = whitespaceColor
      ..style = PaintingStyle.fill;
    final tabPaint = Paint()
      ..color = whitespaceColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final visibleRange = _visibleLineRange(
      size.height,
      lineHeight,
      lines.length,
    );

    for (
      var lineIndex = visibleRange.$1;
      lineIndex <= visibleRange.$2;
      lineIndex++
    ) {
      final line = lines[lineIndex];
      final baseY =
          contentPadding.top + (lineIndex * lineHeight) - scrollOffset;
      final centerY = baseY + (lineHeight / 2);
      var visualColumn = 0;

      for (var i = 0; i < line.length; i++) {
        final char = line[i];
        if (char == ' ') {
          final x =
              contentPadding.left + ((visualColumn + 0.5) * characterWidth);
          canvas.drawCircle(Offset(x, centerY), 1.2, dotPaint);
          visualColumn++;
          continue;
        }
        if (char == '\t') {
          final startX = contentPadding.left + (visualColumn * characterWidth);
          final endX =
              startX + (math.max(indentSpaces, 1) * characterWidth) - 4;
          final path = Path()
            ..moveTo(startX + 2, centerY)
            ..lineTo(endX, centerY)
            ..lineTo(endX - 4, centerY - 3)
            ..moveTo(endX, centerY)
            ..lineTo(endX - 4, centerY + 3);
          canvas.drawPath(path, tabPaint);
          visualColumn += math.max(indentSpaces, 1);
          continue;
        }
        visualColumn++;
      }
    }
  }

  (int, int) _visibleLineRange(
    double height,
    double lineHeight,
    int lineCount,
  ) {
    final first = math.max(0, (scrollOffset / lineHeight).floor() - 1);
    final last = math.min(
      lineCount - 1,
      ((scrollOffset + height) / lineHeight).ceil() + 1,
    );
    return (first, math.max(first, last));
  }

  int _leadingIndentColumns(String line) {
    var columns = 0;
    for (final rune in line.runes) {
      final char = String.fromCharCode(rune);
      if (char == ' ') {
        columns++;
        continue;
      }
      if (char == '\t') {
        columns += math.max(indentSpaces, 1);
        continue;
      }
      break;
    }
    return columns;
  }

  static int _currentLineIndex(String text, TextSelection selection) {
    final offset = selection.isValid
        ? selection.extentOffset.clamp(0, text.length).toInt()
        : text.length;
    if (offset <= 0) {
      return 0;
    }
    return '\n'.allMatches(text.substring(0, offset)).length;
  }

  static double _characterWidth(TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: 'M', style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return textPainter.width;
  }

  @override
  bool shouldRepaint(covariant SqlEditorBackgroundPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.selection != selection ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.contentPadding != contentPadding ||
        oldDelegate.indentSpaces != indentSpaces ||
        oldDelegate.currentLineColor != currentLineColor ||
        oldDelegate.whitespaceColor != whitespaceColor ||
        oldDelegate.indentGuideColor != indentGuideColor;
  }
}
