import 'package:flutter/material.dart';

import '../infrastructure/decentdb_doctor_service.dart';

class DecentDbDoctorDialog extends StatefulWidget {
  const DecentDbDoctorDialog({super.key, required this.future});

  final Future<DecentDbDoctorReport> future;

  static Future<void> show({
    required BuildContext context,
    required Future<DecentDbDoctorReport> future,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DecentDbDoctorDialog(future: future),
    );
  }

  @override
  State<DecentDbDoctorDialog> createState() => _DecentDbDoctorDialogState();
}

class _DecentDbDoctorDialogState extends State<DecentDbDoctorDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: <Widget>[
          const Icon(Icons.medical_services_outlined),
          const SizedBox(width: 8),
          const Text('Database Doctor'),
        ],
      ),
      content: SizedBox(
        width: 640,
        child: FutureBuilder<DecentDbDoctorReport>(
          future: widget.future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      LinearProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Running diagnostics…'),
                    ],
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              return SizedBox(
                width: 560,
                child: SelectableText(
                  snapshot.error.toString(),
                  style: theme.textTheme.bodySmall,
                ),
              );
            }
            final report = snapshot.data!;
            return _DecentDbDoctorReportView(report: report);
          },
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DecentDbDoctorReportView extends StatelessWidget {
  const _DecentDbDoctorReportView({required this.report});

  final DecentDbDoctorReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = <String, List<DecentDbDoctorFinding>>{};
    for (final finding in report.findings) {
      grouped.putIfAbsent(finding.category, () => <DecentDbDoctorFinding>[])
          .add(finding);
    }
    final categories = grouped.keys.toList()..sort();
    return SizedBox(
      width: 640,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (report.degraded)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Degraded results: the decentdb CLI was unavailable, so this '
                'report was assembled from the in-process sys.* views and '
                'may not cover every category. A clean bill of health '
                'requires the CLI.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          if (!report.degraded && report.findings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No findings. The doctor did not flag any issues.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          for (final category in categories) ...<Widget>[
            Text(
              category.toUpperCase(),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final finding in grouped[category]!) ...<Widget>[
              _DecentDbFindingRow(finding: finding),
              const SizedBox(height: 4),
            ],
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _DecentDbFindingRow extends StatelessWidget {
  const _DecentDbFindingRow({required this.finding});

  final DecentDbDoctorFinding finding;

  Color _severityColor(ThemeData theme) {
    switch (finding.severity) {
      case 'error':
        return theme.colorScheme.error;
      case 'warning':
        return Colors.orange.shade700;
      case 'info':
      default:
        return theme.colorScheme.primary;
    }
  }

  IconData _severityIcon() {
    switch (finding.severity) {
      case 'error':
        return Icons.error_outline;
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'info':
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _severityColor(theme);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(_severityIcon(), color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  finding.message,
                  style: theme.textTheme.bodyMedium,
                ),
                if (finding.recommendation != null &&
                    finding.recommendation!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Recommended: ${finding.recommendation}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}