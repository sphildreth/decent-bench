import 'dart:async';

import 'package:flutter/material.dart';

import '../../import/utils/docker_cli.dart';
import '../application/workspace_controller.dart';

class MsSqlBakImportDialog extends StatefulWidget {
  const MsSqlBakImportDialog({
    super.key,
    required this.controller,
    required this.sourcePath,
  });

  final WorkspaceController controller;
  final String sourcePath;

  @override
  State<MsSqlBakImportDialog> createState() => _MsSqlBakImportDialogState();
}

class _MsSqlBakImportDialogState extends State<MsSqlBakImportDialog> {
  bool _isCheckingDocker = true;
  bool _isDockerAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkDocker();
  }

  Future<void> _checkDocker() async {
    final available = await DockerCli.isDockerAvailable();
    if (mounted) {
      setState(() {
        _isDockerAvailable = available;
        _isCheckingDocker = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingDocker) {
      return const AlertDialog(
        title: Text('Checking Environment'),
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressContainer()),
        ),
      );
    }

    if (!_isDockerAvailable) {
      return AlertDialog(
        title: const Text('Docker Required'),
        content: const Text(
          'Importing MS SQL Server Backup (.bak) files requires Docker Desktop '
          'to be installed and running on your system. We use a temporary container '
          'running the official Microsoft SQL Server engine to safely restore and '
          'extract your data.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Import MS SQL Backup'),
      content: const SizedBox(
        width: 600,
        child: Text(
          'Docker is available. The container orchestration is planned for the next iteration (ADR-0027).',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class CircularProgressContainer extends StatelessWidget {
  const CircularProgressContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return const CircularProgressIndicator();
  }
}
