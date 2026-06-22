import 'package:decent_bench/features/workspace/domain/query_phase_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BridgeFailure', () {
    test('carries structured diagnostic fields from v2.14.0', () {
      const failure = BridgeFailure(
        'syntax error near "SELCT"',
        code: 'DDB_ERR_SQL',
        subcode: 'sql.syntax',
        permanent: true,
        sqlstate: '42601',
        docAnchor: 'errors/sql-syntax',
      );

      expect(failure.code, 'DDB_ERR_SQL');
      expect(failure.subcode, 'sql.syntax');
      expect(failure.sqlstate, '42601');
      expect(failure.docAnchor, 'errors/sql-syntax');
      expect(failure.retryable, isFalse);
      expect(failure.permanent, isTrue);
      expect(failure.toString(), 'DDB_ERR_SQL: syntax error near "SELCT"');
    });

    test('defaults diagnostic fields to safe values', () {
      const failure = BridgeFailure('generic error');

      expect(failure.code, isNull);
      expect(failure.subcode, isNull);
      expect(failure.sqlstate, isNull);
      expect(failure.docAnchor, isNull);
      expect(failure.retryable, isFalse);
      expect(failure.permanent, isFalse);
      expect(failure.hasStructuredDiagnostic, isFalse);
    });

    test('preserves diagnostic JSON when available', () {
      const json =
          '{"version":1,"code":5,"code_name":"ERR_SQL","subcode":"sql.syntax",'
          '"message":"syntax error","retryable":false,"permanent":true}';
      const failure = BridgeFailure(
        'syntax error',
        code: 'DDB_ERR_SQL',
        subcode: 'sql.syntax',
        diagnosticJson: json,
      );

      expect(failure.hasStructuredDiagnostic, isTrue);
      expect(failure.diagnosticJson, json);
    });
  });

  group('QueryErrorDetails', () {
    test('propagates structured diagnostic fields from BridgeFailure', () {
      const failure = BridgeFailure(
        'column not found',
        code: 'DDB_ERR_SQL',
        subcode: 'sql.column_not_found',
        permanent: true,
        sqlstate: '42703',
        docAnchor: 'errors/sql-column-not-found',
      );

      final details = QueryErrorDetails.fromError(
        failure,
        stage: QueryErrorStage.paging,
      );

      expect(details.code, 'DDB_ERR_SQL');
      expect(details.subcode, 'sql.column_not_found');
      expect(details.permanent, isTrue);
      expect(details.sqlstate, '42703');
      expect(details.docAnchor, 'errors/sql-column-not-found');
    });

    test('toClipboardText includes diagnostic fields', () {
      const details = QueryErrorDetails(
        stage: QueryErrorStage.opening,
        message: 'busy: writer lock held',
        code: 'DDB_ERR_BUSY',
        subcode: 'busy.writer_lock',
        retryable: true,
        permanent: false,
        docAnchor: 'errors/busy-writer-lock',
      );

      final text = details.toClipboardText();

      expect(text, contains('Stage: Open'));
      expect(text, contains('Code: DDB_ERR_BUSY'));
      expect(text, contains('Subcode: busy.writer_lock'));
      expect(text, contains('Retryable: yes'));
      expect(text, contains('Docs: errors/busy-writer-lock'));
      expect(text, isNot(contains('Permanent')));
    });

    test('toClipboardText omits diagnostic fields when absent', () {
      const details = QueryErrorDetails(
        stage: QueryErrorStage.validation,
        message: 'simple error',
      );

      final text = details.toClipboardText();

      expect(text, contains('Stage: Validation'));
      expect(text, contains('Message: simple error'));
      expect(text, isNot(contains('Subcode')));
      expect(text, isNot(contains('SQLSTATE')));
      expect(text, isNot(contains('Retryable')));
      expect(text, isNot(contains('Docs')));
    });

    test('fromError handles non-structured exceptions gracefully', () {
      final details = QueryErrorDetails.fromError(
        StateError('something went wrong'),
        stage: QueryErrorStage.cancellation,
      );

      expect(details.message, contains('something went wrong'));
      expect(details.code, isNull);
      expect(details.subcode, isNull);
    });
  });
}
