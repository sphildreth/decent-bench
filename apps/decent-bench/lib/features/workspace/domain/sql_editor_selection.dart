import 'package:flutter/services.dart';

class SqlEditorSelectionInfo {
  const SqlEditorSelectionInfo({
    required this.selection,
    required this.selectedText,
  });

  final TextSelection selection;
  final String selectedText;

  bool get hasSelection => selection.isValid && !selection.isCollapsed;

  bool get hasRunnableSelection =>
      hasSelection && selectedText.trim().isNotEmpty;

  String get runnableSql => hasRunnableSelection ? selectedText.trim() : '';

  int get selectedCharacterCount =>
      hasSelection ? selection.end - selection.start : 0;

  int get selectedLineCount {
    if (!hasSelection || selectedText.isEmpty) {
      return 0;
    }
    return '\n'.allMatches(selectedText).length + 1;
  }
}

SqlEditorSelectionInfo resolveSqlEditorSelectionInfo(TextEditingValue value) {
  final selection = value.selection;
  if (!selection.isValid || selection.isCollapsed) {
    return const SqlEditorSelectionInfo(
      selection: TextSelection.collapsed(offset: -1),
      selectedText: '',
    );
  }

  final start = selection.start.clamp(0, value.text.length).toInt();
  final end = selection.end.clamp(0, value.text.length).toInt();
  return SqlEditorSelectionInfo(
    selection: TextSelection(baseOffset: start, extentOffset: end),
    selectedText: value.text.substring(start, end),
  );
}

TextEditingValue replaceSelectedTextOrAll(
  TextEditingValue currentValue, {
  required String replacement,
  required bool useSelection,
}) {
  if (!useSelection) {
    return TextEditingValue(
      text: replacement,
      selection: TextSelection.collapsed(offset: replacement.length),
    );
  }

  final selection = currentValue.selection;
  final start = selection.start.clamp(0, currentValue.text.length).toInt();
  final end = selection.end.clamp(0, currentValue.text.length).toInt();
  final updated =
      currentValue.text.substring(0, start) +
      replacement +
      currentValue.text.substring(end);
  return TextEditingValue(
    text: updated,
    selection: TextSelection(
      baseOffset: start,
      extentOffset: start + replacement.length,
    ),
  );
}
