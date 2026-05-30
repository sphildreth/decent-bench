import 'package:decent_bench/features/workspace/domain/column_statistics.dart';
import 'package:decent_bench/features/workspace/domain/workspace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('summarizes nulls distinct values and numeric ranges', () {
    final stats = buildColumnStatistics(
      columnName: 'amount',
      rows: const <Map<String, Object?>>[
        <String, Object?>{'amount': 10},
        <String, Object?>{'amount': 25},
        <String, Object?>{'amount': 25},
        <String, Object?>{'amount': null},
      ],
      nativeType: describeNativeType(typeName: 'INT64'),
    );

    expect(stats.loadedRowCount, 4);
    expect(stats.nonNullCount, 3);
    expect(stats.nullCount, 1);
    expect(stats.distinctCount, 2);
    expect(stats.numericMin, 10);
    expect(stats.numericMax, 25);
    expect(stats.numericAverage, 20);
    expect(stats.topValues.first.label, '25');
    expect(stats.topValues.first.count, 2);
    expect(stats.toClipboardText(), contains('Nulls: 1 (25.0%)'));
  });

  test('summarizes temporal and string ranges', () {
    final stats = buildColumnStatistics(
      columnName: 'created_at',
      rows: const <Map<String, Object?>>[
        <String, Object?>{'created_at': '2026-05-19T12:00:00Z'},
        <String, Object?>{'created_at': '2026-05-20T12:00:00Z'},
      ],
      nativeType: describeNativeType(typeName: 'TIMESTAMPTZ'),
    );

    expect(stats.hasTemporalSummary, isTrue);
    expect(stats.temporalMin!.toIso8601String(), '2026-05-19T12:00:00.000Z');
    expect(stats.temporalMax!.toIso8601String(), '2026-05-20T12:00:00.000Z');
    expect(stats.stringMinLength, 20);
    expect(stats.stringMaxLength, 20);
  });

  test('formats enum top values with native labels when available', () {
    final descriptor = describeNativeType(typeName: "ENUM('open','closed')");
    final stats = buildColumnStatistics(
      columnName: 'status',
      rows: const <Map<String, Object?>>[
        <String, Object?>{'status': NativeEnumCellValue(typeId: 1, labelId: 1)},
        <String, Object?>{'status': NativeEnumCellValue(typeId: 1, labelId: 1)},
        <String, Object?>{'status': NativeEnumCellValue(typeId: 1, labelId: 2)},
      ],
      nativeType: descriptor,
    );

    expect(stats.nativeType!.familyLabel, 'Enum');
    expect(stats.topValues.first.label, 'open (type 1, label 1)');
    expect(stats.topValues.first.count, 2);
  });
}
