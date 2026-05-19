import 'package:flutter/material.dart';

typedef JsonExportBrowseCallback = Future<String?> Function(String currentPath);

class JsonExportDialogResult {
  const JsonExportDialogResult({
    required this.path,
    required this.format,
    required this.pretty,
    required this.includeMetadata,
  });

  final String path;
  final String format;
  final bool pretty;
  final bool includeMetadata;
}

class JsonExportDialog extends StatefulWidget {
  const JsonExportDialog({
    super.key,
    required this.queryTitle,
    required this.initialPath,
    required this.onBrowse,
  });

  final String queryTitle;
  final String initialPath;
  final JsonExportBrowseCallback onBrowse;

  @override
  State<JsonExportDialog> createState() => _JsonExportDialogState();
}

class _JsonExportDialogState extends State<JsonExportDialog> {
  late final TextEditingController _pathController = TextEditingController(
    text: widget.initialPath,
  );

  String _format = 'json';
  bool _pretty = true;
  bool _includeMetadata = true;
  String _validationMessage = '';

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export Results as JSON'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Export the current results for ${widget.queryTitle}.'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _pathController,
                    decoration: const InputDecoration(
                      labelText: 'Destination',
                      hintText: '/tmp/results.json',
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
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: 'json',
                  icon: Icon(Icons.data_object_outlined),
                  label: Text('JSON'),
                ),
                ButtonSegment<String>(
                  value: 'ndjson',
                  icon: Icon(Icons.subject_outlined),
                  label: Text('NDJSON'),
                ),
              ],
              selected: <String>{_format},
              onSelectionChanged: (values) {
                setState(() {
                  _format = values.single;
                  if (_format == 'ndjson') {
                    _pretty = false;
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeMetadata,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Include column type metadata'),
              onChanged: (value) {
                setState(() {
                  _includeMetadata = value ?? true;
                });
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _pretty,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Pretty print JSON'),
              onChanged: _format == 'ndjson'
                  ? null
                  : (value) {
                      setState(() {
                        _pretty = value ?? true;
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
        _validationMessage = 'Choose a JSON destination before exporting.';
      });
      return;
    }
    Navigator.of(context).pop(
      JsonExportDialogResult(
        path: path,
        format: _format,
        pretty: _pretty,
        includeMetadata: _includeMetadata,
      ),
    );
  }
}
