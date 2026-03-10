class StartupLaunchOptions {
  const StartupLaunchOptions({this.importSourcePath, this.startupNotice});

  final String? importSourcePath;
  final String? startupNotice;

  bool get hasPendingAction =>
      (importSourcePath != null && importSourcePath!.trim().isNotEmpty) ||
      (startupNotice != null && startupNotice!.trim().isNotEmpty);
}

StartupLaunchOptions parseStartupLaunchOptions(List<String> rawArgs) {
  String? importSourcePath;
  String? startupNotice;

  for (var index = 0; index < rawArgs.length; index++) {
    final argument = rawArgs[index].trim();
    if (argument.isEmpty) {
      continue;
    }

    if (argument == '--import') {
      final nextIndex = index + 1;
      if (nextIndex >= rawArgs.length) {
        startupNotice ??= '`--import` expects a filename.';
        continue;
      }

      final value = rawArgs[nextIndex].trim();
      if (value.isEmpty || value.startsWith('--')) {
        startupNotice ??= '`--import` expects a filename.';
        continue;
      }

      importSourcePath ??= value;
      index = nextIndex;
      continue;
    }

    if (argument.startsWith('--import=')) {
      final value = argument.substring('--import='.length).trim();
      if (value.isEmpty) {
        startupNotice ??= '`--import` expects a filename.';
        continue;
      }
      importSourcePath ??= value;
    }
  }

  return StartupLaunchOptions(
    importSourcePath: importSourcePath,
    startupNotice: startupNotice,
  );
}
