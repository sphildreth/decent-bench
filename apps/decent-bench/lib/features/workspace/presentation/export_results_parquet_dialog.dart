import 'package:flutter/material.dart';

typedef ParquetExportBrowseCallback = Future<String?> Function(String currentPath);

class ParquetExportDialogResult {
  const ParquetExportDialogResult({
    required this.path,
    required this.includeSchemaFingerprint,
  });

  final String path;
  final bool includeSchemaFingerprint;
}

class ParquetExportDialog extends StatefulWidget {
  const ParquetExportDialog({
    super.key,
    required this.queryTitle,
    required this.initialPath,
    required this.initialIncludeSchemaFingerprint,
    required this.onBrowse,
  });

  final String queryTitle;
  final String initialPath;
  final bool initialIncludeSchemaFingerprint;
  final ParquetExportBrowseCallback onBrowse;

  @override
  State<ParquetExportDialog> createState() => _ParquetExportDialogState();
}

class _ParquetExportDialogState extends State<ParquetExportDialog> {
  late final TextEditingController _pathController = TextEditingController(
    text: widget.initialPath,
  );

  late bool _includeSchemaFingerprint = widget.initialIncludeSchemaFingerprint;
  String _validationMessage = '';

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export Results as Parquet'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Export the current results for ${widget.queryTitle} as Parquet (.parquet).'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _pathController,
                    decoration: const InputDecoration(
                      labelText: 'Destination',
                      hintText: '/tmp/results.parquet',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _browseForPath,
                  child: const Text('Browse...'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeSchemaFingerprint,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Include schema fingerprint'),
              onChanged: (value) {
                setState(() {
                  _includeSchemaFingerprint = value ?? true;
                });
              },
            ),
            if (_validationMessage.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _validationMessage,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Export')),
      ],
    );
  }

  Future<void> _browseForPath() async {
    final path = await widget.onBrowse(_pathController.text);
    if (!mounted || path == null) {
      return;
    }
    setState(() {
      _pathController.text = path;
    });
  }

  void _submit() {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      setState(() {
        _validationMessage = 'Choose a Parquet destination before exporting.';
      });
      return;
    }

    Navigator.of(
      context,
    ).pop(ParquetExportDialogResult(path: path, includeSchemaFingerprint: _includeSchemaFingerprint));
  }
}
