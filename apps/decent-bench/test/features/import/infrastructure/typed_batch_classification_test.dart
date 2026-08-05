import 'package:decent_bench/features/import/infrastructure/typed_batch_classification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('INTEGER / DOUBLE / TEXT map to i/f/t; BOOLEAN is excluded in v2.17',
      () {
    expect(typedBatchSignatureChar('INTEGER'), 'i');
    expect(typedBatchSignatureChar('BIGINT'), 'i');
    expect(
      typedBatchSignatureChar('BOOLEAN'),
      isNull,
      reason:
          'The Dart binding for v2.17 only accepts i/t/f; BOOLEAN rides the '
          'bindAll path.',
    );
    expect(typedBatchSignatureChar('DOUBLE PRECISION'), 'f');
    expect(typedBatchSignatureChar('TEXT'), 't');
    expect(typedBatchSignatureChar('VARCHAR(64)'), 't');
  });

  test(
      'UUID is excluded from the typed batch because UuidValue does not '
      'fit the t slot', () {
    expect(typedBatchSignatureChar('UUID'), isNull);
  });

  test('BLOB / DECIMAL / NUMERIC return null (typed-batch unsupported)', () {
    expect(typedBatchSignatureChar('BLOB'), isNull);
    expect(typedBatchSignatureChar('DECIMAL(10,2)'), isNull);
    expect(typedBatchSignatureChar('NUMERIC(8,4)'), isNull);
  });

  test('canUseTypedBatchForTargets is true only when every column is supported',
      () {
    expect(
      canUseTypedBatchForTargets(<String>['INTEGER', 'TEXT']),
      isTrue,
    );
    expect(
      canUseTypedBatchForTargets(<String>['INTEGER', 'BLOB']),
      isFalse,
    );
  });

  test('renderTypedBatchSignature concatenates one char per target type', () {
    expect(
      renderTypedBatchSignature(<String>['INTEGER', 'TEXT', 'DOUBLE']),
      'itf',
    );
    expect(
      () => renderTypedBatchSignature(<String>['INTEGER', 'BLOB']),
      throwsArgumentError,
    );
  });
}
