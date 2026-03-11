import 'package:decent_bench/features/workspace/domain/sql_editor_selection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selection info resolves runnable SQL from the selected range', () {
    const text = 'SELECT *\nFROM tasks;\nSELECT *\nFROM projects;';
    final selectionStart = text.indexOf('SELECT *\nFROM projects;');
    final value = TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: selectionStart,
        extentOffset: text.length,
      ),
    );

    final info = resolveSqlEditorSelectionInfo(value);

    expect(info.hasSelection, isTrue);
    expect(info.hasRunnableSelection, isTrue);
    expect(info.runnableSql, 'SELECT *\nFROM projects;');
    expect(info.selectedLineCount, 2);
  });

  test('whitespace-only selections are not treated as runnable SQL', () {
    const value = TextEditingValue(
      text: 'SELECT 1;\n   \nSELECT 2;',
      selection: TextSelection(baseOffset: 9, extentOffset: 13),
    );

    final info = resolveSqlEditorSelectionInfo(value);

    expect(info.hasSelection, isTrue);
    expect(info.hasRunnableSelection, isFalse);
    expect(info.runnableSql, isEmpty);
  });

  test('replaceSelectedTextOrAll replaces only the selected range', () {
    const text = 'SELECT *\nFROM tasks;';
    final selectionStart = text.indexOf('FROM tasks;');
    final value = TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: selectionStart,
        extentOffset: text.length,
      ),
    );

    final updated = replaceSelectedTextOrAll(
      value,
      replacement: 'id\nFROM tasks',
      useSelection: true,
    );

    expect(updated.text, 'SELECT *\nid\nFROM tasks');
    expect(updated.selection.baseOffset, selectionStart);
    expect(
      updated.selection.extentOffset,
      selectionStart + 'id\nFROM tasks'.length,
    );
  });
}
