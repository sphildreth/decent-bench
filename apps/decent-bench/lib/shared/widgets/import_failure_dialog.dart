import 'package:flutter/material.dart';

String summarizeImportFailure(String message) {
  final normalizedLines = message
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);
  return normalizedLines.isEmpty ? 'The import failed.' : normalizedLines.first;
}

Future<void> showImportFailureDialog({
  required BuildContext context,
  required String title,
  required String message,
  required VoidCallback onAcknowledged,
}) {
  final summary = summarizeImportFailure(message);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Import failure',
    transitionDuration: Duration.zero,
    pageBuilder: (dialogContext, _, _) {
      final theme = Theme.of(dialogContext);
      final colorScheme = theme.colorScheme;
      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 720,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Summary', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    summary,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Details', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(message),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onAcknowledged();
            },
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}
