import 'data_quality_models.dart';

class QualityReportOptions {
  const QualityReportOptions({
    required this.format,
    required this.destinationPath,
    this.includeSampleValues = false,
    this.includeViolationDetailRows = false,
    this.includeImportReconciliation = true,
    this.includeRuleDefinitions = true,
    this.includeStaleRuns = false,
    this.freshnessStatus = QualityFreshnessStatus.noRun,
  });

  final QualityReportFormat format;
  final String destinationPath;
  final bool includeSampleValues;
  final bool includeViolationDetailRows;
  final bool includeImportReconciliation;
  final bool includeRuleDefinitions;
  final bool includeStaleRuns;
  final QualityFreshnessStatus freshnessStatus;

  List<DataQualityValidationError> validate() {
    final errors = <DataQualityValidationError>[];
    if (destinationPath.trim().isEmpty) {
      errors.add(
        const DataQualityValidationError(
          field: 'destination_path',
          message: 'Destination path is required.',
        ),
      );
    }
    if (destinationPath.trim().isNotEmpty &&
        !destinationPath.toLowerCase().endsWith(format.extension)) {
      errors.add(
        DataQualityValidationError(
          field: 'destination_path',
          message: 'Destination must use the ${format.extension} extension.',
        ),
      );
    }
    return errors;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'format': format.wireName,
      'destination_path': destinationPath,
      'include_sample_values': includeSampleValues,
      'include_violation_detail_rows': includeViolationDetailRows,
      'include_import_reconciliation': includeImportReconciliation,
      'include_rule_definitions': includeRuleDefinitions,
      'include_stale_runs': includeStaleRuns,
      'freshness_status': freshnessStatus.name,
    };
  }
}

class QualityReportDocument {
  const QualityReportDocument({
    required this.result,
    required this.options,
    required this.generatedAt,
    required this.appName,
    required this.appVersion,
  });

  final QualityRunResult result;
  final QualityReportOptions options;
  final DateTime generatedAt;
  final String appName;
  final String appVersion;

  QualityRunResult get exportResult => result.redactedForReport(
    includeSampleValues:
        options.includeSampleValues || options.includeViolationDetailRows,
  );
}
