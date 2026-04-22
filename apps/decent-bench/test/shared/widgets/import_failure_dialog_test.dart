import 'package:decent_bench/shared/widgets/import_failure_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('summarizeImportFailure uses the first non-empty line', () {
    expect(
      summarizeImportFailure(
        '\n  Import failed while copying rows.\nDecentDbException(sql): full details',
      ),
      'Import failed while copying rows.',
    );
  });

  test('summarizeImportFailure falls back when the message is blank', () {
    expect(summarizeImportFailure(' \n\t '), 'The import failed.');
  });
}
