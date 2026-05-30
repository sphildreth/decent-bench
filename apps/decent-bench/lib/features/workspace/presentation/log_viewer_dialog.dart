import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class LogViewerDialog extends StatefulWidget {
  const LogViewerDialog({super.key, required this.logDirectoryPath});

  final String logDirectoryPath;

  static Future<void> show(
    BuildContext context, {
    required String logDirectoryPath,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => LogViewerDialog(logDirectoryPath: logDirectoryPath),
    );
  }

  @override
  State<LogViewerDialog> createState() => _LogViewerDialogState();
}

class _LogViewerDialogState extends State<LogViewerDialog> {
  List<FileSystemEntity> _logFiles = [];
  FileSystemEntity? _selectedFile;
  String? _fileContent;
  bool _loadingContent = false;

  @override
  void initState() {
    super.initState();
    _refreshFileList();
  }

  void _refreshFileList() {
    final dir = Directory(widget.logDirectoryPath);
    if (!dir.existsSync()) {
      setState(() {
        _logFiles = [];
        _selectedFile = null;
        _fileContent = null;
      });
      return;
    }
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.log'))
        .toList()
      ..sort((a, b) => File(b.path).lastModifiedSync()
          .compareTo(File(a.path).lastModifiedSync()));
    setState(() {
      _logFiles = files;
      if (_selectedFile != null &&
          !_logFiles.any((f) => f.path == _selectedFile!.path)) {
        _selectedFile = null;
        _fileContent = null;
      }
      if (_selectedFile == null && _logFiles.isNotEmpty) {
        _selectFile(_logFiles.first);
      }
    });
  }

  void _selectFile(FileSystemEntity file) {
    setState(() {
      _selectedFile = file;
      _fileContent = null;
      _loadingContent = true;
    });
    try {
      final content = File(file.path).readAsStringSync();
      setState(() {
        _fileContent = content;
        _loadingContent = false;
      });
    } catch (e) {
      setState(() {
        _fileContent = 'Error reading file: $e';
        _loadingContent = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Application Logs',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: _refreshFileList,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _logFiles.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No log files found.',
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Log directory: ${widget.logDirectoryPath}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        SizedBox(
                          width: 320,
                          child: Material(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            child: ListView.builder(
                              itemCount: _logFiles.length,
                              itemBuilder: (context, index) {
                                final file = _logFiles[index];
                                final isSelected =
                                    _selectedFile?.path == file.path;
                                final fileName = p.basename(file.path);
                                final lastModified =
                                    File(file.path).lastModifiedSync();
                                final fileSize = File(file.path).lengthSync();
                                return ListTile(
                                  selected: isSelected,
                                  dense: true,
                                  title: Text(
                                    fileName,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : null,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${_formatDateTime(lastModified)}  '
                                    '${_formatFileSize(fileSize)}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  onTap: () => _selectFile(file),
                                );
                              },
                            ),
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: _selectedFile == null
                              ? const Center(
                                  child: Text('Select a log file.'),
                                )
                              : _loadingContent
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : _buildLogContent(theme),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  p.basename(_selectedFile!.path),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                _formatFileSize(File(_selectedFile!.path).lengthSync()),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                _fileContent ?? '',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
        '${_pad(dt.hour)}:${_pad(dt.minute)}:${_pad(dt.second)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
