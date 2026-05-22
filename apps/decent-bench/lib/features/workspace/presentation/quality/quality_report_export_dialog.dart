import 'package:flutter/material.dart';

import '../../domain/data_quality_models.dart';

class QualityReportExportDialogResult {
  const QualityReportExportDialogResult({
    required this.format,
    required this.path,
    required this.includeSampleValues,
    required this.includeViolationSamples,
    required this.includeImportReconciliation,
    required this.includeRuleDefinitions,
  });

  final QualityReportFormat format;
  final String path;
  final bool includeSampleValues;
  final bool includeViolationSamples;
  final bool includeImportReconciliation;
  final bool includeRuleDefinitions;
}

typedef QualityReportBrowseCallback =
    Future<String?> Function(QualityReportFormat format, String currentPath);

class QualityReportExportDialog extends StatefulWidget {
  const QualityReportExportDialog({
    super.key,
    required this.initialPath,
    required this.onBrowse,
  });

  final String initialPath;
  final QualityReportBrowseCallback onBrowse;

  @override
  State<QualityReportExportDialog> createState() =>
      _QualityReportExportDialogState();
}

class _QualityReportExportDialogState extends State<QualityReportExportDialog> {
  late final TextEditingController pathController = TextEditingController(
    text: widget.initialPath,
  );
  QualityReportFormat format = QualityReportFormat.markdown;
  bool includeSampleValues = false;
  bool includeViolationSamples = true;
  bool includeImportReconciliation = true;
  bool includeRuleDefinitions = true;

  @override
  void dispose() {
    pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canExport = pathController.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Export Quality Report'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DropdownButtonFormField<QualityReportFormat>(
              initialValue: format,
              decoration: const InputDecoration(labelText: 'Format'),
              items: const <DropdownMenuItem<QualityReportFormat>>[
                DropdownMenuItem<QualityReportFormat>(
                  value: QualityReportFormat.markdown,
                  child: Text('Markdown'),
                ),
                DropdownMenuItem<QualityReportFormat>(
                  value: QualityReportFormat.html,
                  child: Text('HTML'),
                ),
                DropdownMenuItem<QualityReportFormat>(
                  value: QualityReportFormat.json,
                  child: Text('JSON'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  format = value;
                  pathController.text = _replaceExtension(
                    pathController.text,
                    value.extension,
                  );
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: pathController,
                    decoration: const InputDecoration(labelText: 'Destination'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Choose destination',
                  onPressed: () async {
                    final path = await widget.onBrowse(
                      format,
                      pathController.text,
                    );
                    if (path == null || !context.mounted) {
                      return;
                    }
                    setState(() {
                      pathController.text = path;
                    });
                  },
                  icon: const Icon(Icons.folder_open_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Include sample values'),
              subtitle: const Text('Off by default for report privacy.'),
              value: includeSampleValues,
              onChanged: (value) =>
                  setState(() => includeSampleValues = value ?? false),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Include violation samples'),
              value: includeViolationSamples,
              onChanged: (value) =>
                  setState(() => includeViolationSamples = value ?? true),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Include import reconciliation'),
              value: includeImportReconciliation,
              onChanged: (value) =>
                  setState(() => includeImportReconciliation = value ?? true),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Include rule definitions'),
              value: includeRuleDefinitions,
              onChanged: (value) =>
                  setState(() => includeRuleDefinitions = value ?? true),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: canExport
              ? () => Navigator.of(context).pop(
                  QualityReportExportDialogResult(
                    format: format,
                    path: pathController.text.trim(),
                    includeSampleValues: includeSampleValues,
                    includeViolationSamples: includeViolationSamples,
                    includeImportReconciliation: includeImportReconciliation,
                    includeRuleDefinitions: includeRuleDefinitions,
                  ),
                )
              : null,
          icon: const Icon(Icons.ios_share_outlined, size: 18),
          label: const Text('Export'),
        ),
      ],
    );
  }

  String _replaceExtension(String path, String extension) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final dot = trimmed.lastIndexOf('.');
    if (dot <= trimmed.lastIndexOf('/') || dot <= trimmed.lastIndexOf(r'\')) {
      return '$trimmed$extension';
    }
    return '${trimmed.substring(0, dot)}$extension';
  }
}
