import 'package:decent_bench/features/workspace/infrastructure/decentdb_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    DecentDbBridge.setPinnedDecentDbTag(null);
  });

  test('returns null when no pinned tag is set (initial bootstrap)', () {
    expect(
      DecentDbBridge.engineVersionMismatchWarning('2.17.0'),
      isNull,
    );
  });

  test('returns null when the loaded version matches the pinned tag', () {
    DecentDbBridge.setPinnedDecentDbTag('v2.17.0');
    expect(
      DecentDbBridge.engineVersionMismatchWarning('2.17.0'),
      isNull,
    );
    expect(
      DecentDbBridge.engineVersionMismatchWarning('v2.17.0'),
      isNull,
    );
  });

  test('returns a warning when major version differs', () {
    DecentDbBridge.setPinnedDecentDbTag('v2.17.0');
    final warning =
        DecentDbBridge.engineVersionMismatchWarning('2.5.1');
    expect(warning, isNotNull);
    expect(warning, contains('2.5.1'));
    expect(warning, contains('v2.17.0'));
    expect(warning, contains('Rebuild'));
    expect(warning, contains('DDB_ERR_TIMEOUT'));
  });

  test('returns a warning when minor version differs', () {
    DecentDbBridge.setPinnedDecentDbTag('v2.17.0');
    final warning =
        DecentDbBridge.engineVersionMismatchWarning('2.7.0');
    expect(warning, isNotNull);
  });

  test('returns null when only the patch version differs (compatible)', () {
    DecentDbBridge.setPinnedDecentDbTag('v2.17.0');
    expect(
      DecentDbBridge.engineVersionMismatchWarning('2.17.1'),
      isNull,
    );
  });

  test('returns null for an unparseable loaded version', () {
    DecentDbBridge.setPinnedDecentDbTag('v2.17.0');
    expect(
      DecentDbBridge.engineVersionMismatchWarning('garbage'),
      isNull,
    );
  });
}