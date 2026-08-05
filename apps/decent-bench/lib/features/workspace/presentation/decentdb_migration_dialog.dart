import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class DecentDbMigrationDialogResult {
  const DecentDbMigrationDialogResult({required this.destinationPath});

  final String destinationPath;
}

class DecentDbMigrationDialog extends StatefulWidget {
  const DecentDbMigrationDialog({
    super.key,
    required this.sourcePath,
    required this.initialDestinationPath,
    required this.openError,
    required this.onBrowse,
  });

  final String sourcePath;
  final String initialDestinationPath;
  final String openError;
  final Future<String?> Function(String currentPath) onBrowse;

  @override
  State<DecentDbMigrationDialog> createState() =>
      _DecentDbMigrationDialogState();
}

class _DecentDbMigrationDialogState extends State<DecentDbMigrationDialog> {
  late final TextEditingController _destinationController =
      TextEditingController(text: widget.initialDestinationPath);

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destination = _destinationController.text.trim();
    final canMigrate =
        destination.isNotEmpty && destination != widget.sourcePath.trim();
    return AlertDialog(
      title: const Text('Migrate legacy DecentDB file?'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'This database uses an older DecentDB file format. Decent Bench can run the official migration tool to create a new current-format copy, then open that copy.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _PathSummary(label: 'Source', path: widget.sourcePath),
            const SizedBox(height: 12),
            TextField(
              controller: _destinationController,
              decoration: InputDecoration(
                labelText: 'Migrated copy',
                helperText: 'The original file is left untouched.',
                suffixIcon: IconButton(
                  tooltip: 'Choose destination',
                  icon: const Icon(Icons.folder_open_outlined),
                  onPressed: () async {
                    final selected = await widget.onBrowse(
                      _destinationController.text,
                    );
                    if (selected == null || !mounted) {
                      return;
                    }
                    setState(() {
                      _destinationController.text = selected;
                    });
                  },
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('Open error'),
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    widget.openError,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
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
          onPressed: canMigrate
              ? () {
                  Navigator.of(context).pop(
                    DecentDbMigrationDialogResult(
                      destinationPath: _destinationController.text.trim(),
                    ),
                  );
                }
              : null,
          icon: const Icon(Icons.upgrade_outlined),
          label: const Text('Migrate Copy'),
        ),
      ],
    );
  }
}

class DecentDbInPlaceMigrationDialog extends StatelessWidget {
  const DecentDbInPlaceMigrationDialog({
    super.key,
    required this.sourcePath,
    required this.backupPath,
    required this.openError,
  });

  final String sourcePath;
  final String backupPath;
  final String openError;

  static Future<bool> show({
    required BuildContext context,
    required String sourcePath,
    required String backupPath,
    required String openError,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DecentDbInPlaceMigrationDialog(
        sourcePath: sourcePath,
        backupPath: backupPath,
        openError: openError,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Upgrade legacy DecentDB file in place?'),
      content: SizedBox(
        width: 580,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'This database uses an older DecentDB file format. Decent Bench '
              'can upgrade the file in place using the official decentdb-migrate '
              'tool. The original file will be kept as a backup so you can roll '
              'back if anything goes wrong.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _PathSummary(label: 'Database', path: sourcePath),
            const SizedBox(height: 8),
            _PathSummary(label: 'Backup will be at', path: backupPath),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'The upgrade is one-way. After it completes, older Decent Bench '
                'builds and older DecentDB releases will refuse to open the '
                'upgraded file. Keep the .v13.bak backup until you have '
                'verified the new file works for you.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('Open error'),
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    openError,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.upgrade_outlined),
          label: const Text('Upgrade in place'),
        ),
      ],
    );
  }
}

class DecentDbMigrationProgressDialog extends StatelessWidget {
  const DecentDbMigrationProgressDialog({
    super.key,
    required this.sourcePath,
    required this.destinationPath,
  });

  final String sourcePath;
  final String destinationPath;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Migrating DecentDB file'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Text('Source: ${p.basename(sourcePath)}'),
            Text('Copy: ${p.basename(destinationPath)}'),
          ],
        ),
      ),
    );
  }
}

class _PathSummary extends StatelessWidget {
  const _PathSummary({required this.label, required this.path});

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: SelectableText(path),
    );
  }
}

Future<String?> browseDecentDbMigrationDestination({
  required String currentPath,
  required String fallbackPath,
}) async {
  final initialPath = currentPath.trim().isEmpty ? fallbackPath : currentPath;
  final location = await getSaveLocation(
    suggestedName: p.basename(initialPath),
    acceptedTypeGroups: const <XTypeGroup>[
      XTypeGroup(label: 'DecentDB', extensions: <String>['ddb']),
    ],
  );
  return location?.path;
}
