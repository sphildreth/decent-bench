import 'dart:convert';
import 'dart:io';

import '../../../app/app_metadata.dart';
import '../domain/data_quality_models.dart';
import '../domain/data_quality_reports.dart';

class DataQualityReportWriter {
  const DataQualityReportWriter();

  Future<void> writeReport({
    required QualityRunResult result,
    required QualityReportOptions options,
  }) async {
    final errors = options.validate();
    if (errors.isNotEmpty) {
      throw FormatException(errors.map((error) => error.toString()).join('; '));
    }
    final document = QualityReportDocument(
      result: result,
      options: options,
      generatedAt: DateTime.now().toUtc(),
      appName: kDecentBenchDisplayName,
      appVersion: kDecentBenchVersion,
    );
    final output = switch (options.format) {
      QualityReportFormat.markdown => writeMarkdown(document),
      QualityReportFormat.html => writeHtml(document),
      QualityReportFormat.json => writeJson(document),
    };
    final file = File(options.destinationPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(output);
  }

  String writeMarkdown(QualityReportDocument document) {
    final result = document.exportResult;
    final buffer = StringBuffer()
      ..writeln('# Data Quality Report')
      ..writeln()
      ..writeln('- App: ${document.appName} ${document.appVersion}')
      ..writeln('- Generated: ${document.generatedAt.toIso8601String()}')
      ..writeln('- Run: ${result.runId}')
      ..writeln('- Target: ${result.targetLabel}')
      ..writeln('- Status: ${result.status.wireName}')
      ..writeln('- Mode: ${result.mode.wireName}')
      ..writeln('- Freshness: ${document.options.freshnessStatus.name}')
      ..writeln('- Schema fingerprint: `${result.schemaFingerprint}`')
      ..writeln()
      ..writeln('## Summary Counts')
      ..writeln()
      ..writeln('| Metric | Value |')
      ..writeln('| --- | ---: |')
      ..writeln('| Tables scanned | ${result.profileSummaries.length} |')
      ..writeln('| Validation issues | ${result.validationIssues.length} |')
      ..writeln('| Error issues | ${result.errorIssueCount} |')
      ..writeln('| Warning issues | ${result.warningIssueCount} |')
      ..writeln('| Duplicate summaries | ${result.duplicateSummaries.length} |')
      ..writeln();
    _writeMarkdownImport(buffer, result, document.options);
    _writeMarkdownProfiles(buffer, result);
    _writeMarkdownIssues(buffer, result);
    _writeMarkdownDuplicates(buffer, result);
    _writeMarkdownWarnings(buffer, result);
    if (!document.options.includeSampleValues) {
      buffer
        ..writeln()
        ..writeln(
          '> Raw failing row values are hidden by default. Re-export with sample values enabled only when the report destination is allowed to contain source data.',
        );
    }
    return buffer.toString();
  }

  String writeHtml(QualityReportDocument document) {
    final markdown = writeMarkdown(document);
    final escaped = const HtmlEscape().convert(markdown);
    return '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Data Quality Report</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 32px; color: #1f2933; background: #ffffff; }
    pre { white-space: pre-wrap; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
  </style>
</head>
<body>
<pre>$escaped</pre>
</body>
</html>
''';
  }

  String writeJson(QualityReportDocument document) {
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'report_schema_version': 1,
      'report_options': document.options.toJson(),
      'app_name': document.appName,
      'app_version': document.appVersion,
      'generated_at': document.generatedAt.toIso8601String(),
      'quality_result': document.exportResult.toJson(),
    });
  }

  void _writeMarkdownImport(
    StringBuffer buffer,
    QualityRunResult result,
    QualityReportOptions options,
  ) {
    buffer
      ..writeln('## Import Reconciliation')
      ..writeln();
    final reconciliation = result.importReconciliation;
    if (!options.includeImportReconciliation || reconciliation == null) {
      buffer
        ..writeln('No import reconciliation was included.')
        ..writeln();
      return;
    }
    buffer
      ..writeln('- Source: ${reconciliation.sourcePathDisplay}')
      ..writeln('- Format: ${reconciliation.sourceFormat}')
      ..writeln('- Warnings: ${reconciliation.warningCount}')
      ..writeln()
      ..writeln(
        '| Source | Target | Source rows | Imported | Skipped | Rejected | Warnings |',
      )
      ..writeln('| --- | --- | ---: | ---: | ---: | ---: | ---: |');
    for (final mapping in reconciliation.tableMappings) {
      buffer.writeln(
        '| ${mapping.sourceName} | ${mapping.targetTable} | ${mapping.sourceRowCount ?? 'unknown'} | ${mapping.importedRowCount} | ${mapping.skippedRowCount} | ${mapping.rejectedRowCount} | ${mapping.warningCount} |',
      );
    }
    buffer.writeln();
  }

  void _writeMarkdownProfiles(StringBuffer buffer, QualityRunResult result) {
    buffer
      ..writeln('## Table Profile Summaries')
      ..writeln();
    if (result.profileSummaries.isEmpty) {
      buffer
        ..writeln('No profiling summaries were produced.')
        ..writeln();
      return;
    }
    for (final table in result.profileSummaries) {
      buffer
        ..writeln('### ${table.tableName}')
        ..writeln()
        ..writeln(
          '| Column | Type | Null % | Empty % | Distinct | Potential key |',
        )
        ..writeln('| --- | --- | ---: | ---: | ---: | --- |');
      for (final column in table.columnSummaries) {
        buffer.writeln(
          '| ${column.columnName} | ${column.typeName} | ${column.nullPercent.toStringAsFixed(1)} | ${column.emptyStringPercent.toStringAsFixed(1)} | ${column.distinctCount} | ${column.potentialKey ? 'yes' : 'no'} |',
        );
      }
      buffer.writeln();
    }
  }

  void _writeMarkdownIssues(StringBuffer buffer, QualityRunResult result) {
    buffer
      ..writeln('## Validation Issue Summaries')
      ..writeln();
    if (result.validationIssues.isEmpty) {
      buffer
        ..writeln('No validation issues were found.')
        ..writeln();
      return;
    }
    buffer
      ..writeln('| Severity | Rule | Table | Column | Issue | Failures |')
      ..writeln('| --- | --- | --- | --- | --- | ---: |');
    for (final issue in result.validationIssues) {
      buffer.writeln(
        '| ${issue.severity.wireName} | ${issue.ruleName} | ${issue.targetTable} | ${issue.targetColumn ?? ''} | ${issue.issueCode} | ${issue.failureCount} |',
      );
    }
    buffer.writeln();
  }

  void _writeMarkdownDuplicates(StringBuffer buffer, QualityRunResult result) {
    buffer
      ..writeln('## Duplicate Summaries')
      ..writeln();
    if (result.duplicateSummaries.isEmpty) {
      buffer
        ..writeln('No duplicate summaries were produced.')
        ..writeln();
      return;
    }
    buffer
      ..writeln('| Table | Type | Columns | Groups | Candidate limit |')
      ..writeln('| --- | --- | --- | ---: | ---: |');
    for (final duplicate in result.duplicateSummaries) {
      buffer.writeln(
        '| ${duplicate.targetTable} | ${duplicate.duplicateType} | ${duplicate.columns.join(', ')} | ${duplicate.groupCount} | ${duplicate.candidateLimit ?? ''} |',
      );
    }
    buffer.writeln();
  }

  void _writeMarkdownWarnings(StringBuffer buffer, QualityRunResult result) {
    buffer
      ..writeln('## Warnings And Limitations')
      ..writeln();
    if (result.warningMessages.isEmpty) {
      buffer
        ..writeln('No warnings were recorded.')
        ..writeln();
      return;
    }
    for (final warning in result.warningMessages) {
      buffer.writeln('- $warning');
    }
    buffer.writeln();
  }
}
