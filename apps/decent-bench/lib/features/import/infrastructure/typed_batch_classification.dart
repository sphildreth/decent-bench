/// Shared classification of import-target column types to the
/// `Statement.executeBatchTyped` signature characters used by the Dart
/// binding. Signature chars follow the upstream contract for v2.17:
///   `i` = INT64, `f` = FLOAT64, `t` = TEXT.
///
/// The BLOB / DECIMAL / NUMERIC / TIMESTAMP / UUID / IPADDR / CIDR /
/// MACADDR / INET / DATE / TIME / BOOLEAN types fall back to the standard
/// `bindAll` path because the typed batches do not currently cover them
/// (and `UuidValue` / `Uint8List` do not fit the `t` slot).
library;

/// Returns the typed-batch signature char for [targetType], or `null` if
/// the column cannot participate in a typed batch.
String? typedBatchSignatureChar(String targetType) {
  final upper = targetType.toUpperCase().trim();
  if (upper.startsWith('INT') ||
      upper == 'INTEGER' ||
      upper == 'BIGINT' ||
      upper == 'SMALLINT' ||
      upper == 'TINYINT' ||
      upper == 'OID' ||
      upper == 'ROWID') {
    return 'i';
  }
  if (upper == 'BOOLEAN' || upper == 'BOOL') {
    return null;
  }
  if (upper == 'REAL' ||
      upper == 'DOUBLE' ||
      upper == 'DOUBLE PRECISION' ||
      upper == 'FLOAT' ||
      upper.startsWith('FLOAT8') ||
      upper == 'FLOAT4') {
    return 'f';
  }
  if (upper == 'TEXT' ||
      upper == 'VARCHAR' ||
      upper.startsWith('VARCHAR(') ||
      upper.startsWith('CHARACTER VARYING') ||
      upper == 'CHAR' ||
      upper == 'CHARACTER' ||
      upper == 'JSON' ||
      upper == 'JSONB' ||
      upper == 'XML') {
    return 't';
  }
  return null;
}

/// True when every column in [targetTypes] can be expressed via the typed
/// batch signature (`i`/`f`/`t`) AND none of the columns are observed
/// to contain null values (the v2.17 Dart binding rejects `null` for
/// typed-batch slots).
bool canUseTypedBatchForTargets(
  List<String> targetTypes, {
  List<bool> containsNulls = const <bool>[],
}) {
  for (var i = 0; i < targetTypes.length; i++) {
    if (typedBatchSignatureChar(targetTypes[i]) == null) {
      return false;
    }
    if (i < containsNulls.length && containsNulls[i]) {
      return false;
    }
  }
  return true;
}

/// Renders the typed-batch signature for the supplied target types.
String renderTypedBatchSignature(List<String> targetTypes) {
  final buffer = StringBuffer();
  for (final targetType in targetTypes) {
    final char = typedBatchSignatureChar(targetType);
    if (char == null) {
      throw ArgumentError(
          'Cannot build typed-batch signature for target type "$targetType"');
    }
    buffer.write(char);
  }
  return buffer.toString();
}

/// Normalizes a coerced cell value into the Dart type expected by the
/// `executeBatchTyped` ABI for [targetType]. Without this, values that
/// round-trip through `typeInferenceService.coerceValue` may still be a
/// `bool` or `int` even when the column is declared `TEXT`, which the
/// typed-batch `t` slot rejects.
Object? normalizeValueForTypedBatch(Object? value, String targetType) {
  final char = typedBatchSignatureChar(targetType);
  if (char == null) {
    return value;
  }
  if (value == null) {
    return null;
  }
  switch (char) {
    case 'i':
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is bool) {
        return value ? 1 : 0;
      }
      if (value is String) {
        return int.tryParse(value.trim());
      }
      return null;
    case 'f':
      if (value is double) {
        return value;
      }
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.tryParse(value.trim());
      }
      return null;
    case 't':
      return '$value';
    default:
      return value;
  }
}